package io.legado.flutter

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.WebChromeClient
import android.webkit.JsPromptResult
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.CookieManager
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * WebView 桥接 — 反爬验证 + BackstageWebView 语义（cacheMode / java·source 注入）
 *
 * 支持方法：
 * - loadUrl / evaluateJs / close：既有验证码通道（纯字符串语义不变）
 * - backstageEval：对齐 Kotlin BackstageWebView（cacheFirst→LOAD_CACHE_ELSE_NETWORK；
 *   规则HTML通过同步prompt门面访问Rust的java/source/cache；B1 加法式返回 cookie 回流信封，见 [buildEnvelope]；
 *   B2 webView 主路径 eval 结果空/命中挑战签名时按阶梯重试，见
 *   [RETRY_LADDER_MS] / [CHALLENGE_SIGNATURES]）
 *
 * — WebViewBridge + Bridge｜2026-08-13｜项 B/B1 cookie 回流 + sourceKey
 * ｜2026-09-26 项 B/B2 eval 重试阶梯
 */
class WebViewBridge {

    private val pagePrompts = mutableSetOf<JsPromptResult>()
    private var requestKey: String? = null
    private var pendingResult: SafeResult? = null
    private var webView: WebView? = null
    // [销毁竞态防护 | 2026-09-26] 已销毁标志：置位后一切后续回调立即让路
    private var destroyed = false
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        private val backstageRequests = ConcurrentHashMap<String, WebViewBridge>()
        private const val TIMEOUT_MS = 60_000L

        /** B2 eval 重试阶梯（可配置常量）：[200,400,600,800,1000]ms 循环 */
        private val RETRY_LADDER_MS = longArrayOf(200L, 400L, 600L, 800L, 1000L)

        /** B2 最大重试次数（30 次，累计阶梯 ≤18s，总预算受 TIMEOUT_MS 约束） */
        private const val MAX_EVAL_RETRIES = 30

        /** B2 挑战签名（可配置常量）：WAF 挑战页标志，命中即按阶梯重试 */
        private val CHALLENGE_SIGNATURES = listOf("acw_sc__v2", "setCookie", "正在验证")


    }

    /** 包装 MethodChannel.Result，防止重复回复 */
    private class SafeResult(private val result: MethodChannel.Result) {
        private val completed = AtomicBoolean(false)

        val isCompleted: Boolean get() = completed.get()

        fun success(value: Any?) {
            if (completed.compareAndSet(false, true)) {
                result.success(value)
            }
        }

        fun error(code: String, message: String?, details: Any?) {
            if (completed.compareAndSet(false, true)) {
                result.error(code, message, details)
            }
        }

        fun notImplemented() {
            if (completed.compareAndSet(false, true)) {
                result.notImplemented()
            }
        }
    }

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result, context: Context, channel: MethodChannel) {
        val safeResult = SafeResult(result)
        when (call.method) {
            "loadUrl" -> {
                val url = call.argument<String>("url")
                    ?: return safeResult.error("ARG_ERROR", "url is required", null)
                val js = call.argument<String>("javaScript")
                loadUrlWithJs(url, js, safeResult, context)
            }
            "evaluateJs" -> {
                val js = call.argument<String>("javaScript")
                    ?: return safeResult.error("ARG_ERROR", "javaScript is required", null)
                evaluateJs(js, safeResult)
            }
            "backstageEval" -> {
                // [并发竞态修复 | 2026-09-26] 每次调用独立实例：共享实例的
                // destroyInternal 会销毁上一个（在途）调用正在使用的 WebView，
                // 被销毁 WebView 的 chromium 回调再触发即在原生层 NPE 崩溃
                // 整个应用（真机实测：916 源并发搜索）。backstageEval 的
                // WebView 生命周期由本次调用闭环（完成自毁 + 超时兜底），
                // 独立实例无共享状态损失。
                val key = call.argument<String>("key")?.takeIf { it.isNotEmpty() } ?: UUID.randomUUID().toString()
                val instance = WebViewBridge().apply { requestKey = key; pendingResult = safeResult }
                if (backstageRequests.putIfAbsent(key, instance) != null) {
                    return safeResult.error("DUPLICATE_REQUEST", "重复WebView请求", null)
                }
                instance.backstageEval(call, safeResult, context, channel)
            }
            "cancelBackstage" -> {
                val key = call.argument<String>("key").orEmpty()
                backstageRequests.remove(key)?.let { instance ->
                    instance.pendingResult?.error("WEBVIEW_CANCELLED", "WebView请求已取消", null)
                    instance.destroyInternal()
                }
                safeResult.success(null)
            }
            "close" -> {
                destroy()
                safeResult.success(null)
            }
            else -> safeResult.notImplemented()
        }
    }

    /**
     * 对齐 BackstageWebView.getStrResponse：
     * action=webView | webViewGetSource | webViewGetOverrideUrl
     *
     * B1 加法式返回值：有 cookie 回流时返回信封
     * `{"result": ..., "cookies": {"<url>": "k=v; ..."}}`（CookieManager
     * 按 finalUrl 读取）；无 cookie 时返回纯结果串（与旧版语义一致，
     * 旧版 Kotlin 返回的纯串 Dart 侧按「非信封」兜底解析）。
     */
    @SuppressLint("SetJavaScriptEnabled")
    private fun backstageEval(call: MethodCall, result: SafeResult, context: Context, channel: MethodChannel) {
        val action = call.argument<String>("action") ?: "webView"
        val url = call.argument<String>("url").orEmpty()
        val html = call.argument<String>("html").orEmpty()
        val js = call.argument<String>("javaScript").orEmpty()
        val sourceRegex = call.argument<String>("sourceRegex").orEmpty()
        val overrideUrlRegex = call.argument<String>("overrideUrlRegex").orEmpty()
        val cacheFirst = call.argument<Boolean>("cacheFirst") == true
        val isRule = call.argument<Boolean>("isRule") == true
        val resultJson = call.argument<String>("result").orEmpty()
        val delayTime = (call.argument<Number>("delayTime")?.toLong() ?: 0L).coerceAtLeast(0L)
        val sourceKey = call.argument<String>("sourceKey").orEmpty()
        // B4（设计文档 §3 项 B）：Rust 按请求 URL 域从 JS cookie store
        // 预取的属域 cookie（"k1=v1; k2=v2"，无则空串）
        val cookie = call.argument<String>("cookie").orEmpty()
        val headers = call.argument<Map<String, String>>("headers").orEmpty()

        // B1（设计文档 §2.2 G4）：sourceKey 非空按 isRule 同等口径生效
        // （对齐上游 tag 语义）——注入 java/source/cache 接口、
        // window.result 与 eval 前缀，页内 JS 可经 java 桥读取源 key
        val ruleLike = isRule || sourceKey.isNotEmpty()

        // 没有资源规则时沿用空结果，不因事件化改为等待完整超时。
        if ((url.isEmpty() && html.isEmpty()) ||
            (action == "webViewGetSource" && sourceRegex.isEmpty())
        ) {
            result.success(buildEnvelope("", "", url))
            destroyInternal()
            return
        }

        this@WebViewBridge.handler.post {
            // 每次后台请求拥有独立实例；取消后不得重新创建页面。
            if (destroyed || result.isCompleted) return@post
            try {
                // B2：eval 重试阶梯的总预算锚点（与全局超时同一起算口径，
                // 保证等待 + 重试总耗时不超 TIMEOUT_MS=60s）
                val opStartMs = System.currentTimeMillis()
                val pageScript = call.argument<String>("pageScript").orEmpty()
                val pageToken = call.argument<String>("pageToken").orEmpty()
                // 在加载前编译一次；坏正则经外层错误通道返回，不在WebView回调中抛出。
                val sourcePattern = sourceRegex.takeIf { action == "webViewGetSource" && it.isNotEmpty() }?.toRegex()
                val overridePattern = overrideUrlRegex.takeIf { action == "webViewGetOverrideUrl" && it.isNotEmpty() }?.toRegex()
                // B1：当前页 cookie 快照（onPageFinished 捕获 + 最终 eval
                // 前重读），随结果信封回传，Rust 侧按 ETLD+1 归一落库
                var capturedCookies = ""

                webView = WebView(context).apply {
                    headers.entries.firstOrNull { it.key.equals("User-Agent", true) }?.let {
                        settings.userAgentString = it.value
                    }
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true
                    settings.blockNetworkImage = true
                    settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                    settings.cacheMode =
                        if (cacheFirst) WebSettings.LOAD_CACHE_ELSE_NETWORK
                        else WebSettings.LOAD_DEFAULT

                    // prompt在JS侧同步返回；主线程只异步转发到所属Rust请求，不阻塞等待。
                    webChromeClient = object : WebChromeClient() {
                        override fun onJsPrompt(view: WebView?, pageUrl: String?, message: String?, defaultValue: String?, prompt: JsPromptResult): Boolean {
                            if (destroyed || result.isCompleted || pageToken.isEmpty() || message != pageToken || !ruleLike || html.isEmpty()) {
                                prompt.cancel()
                                return true
                            }
                            pagePrompts.add(prompt)
                            channel.invokeMethod("pageCall", mapOf("key" to requestKey, "payload" to defaultValue), object : MethodChannel.Result {
                                override fun success(value: Any?) {
                                    if (pagePrompts.remove(prompt)) prompt.confirm(value as? String ?: pageError("页内宿主返回了无效结果"))
                                }
                                override fun error(code: String, message: String?, details: Any?) {
                                    if (pagePrompts.remove(prompt)) prompt.confirm(pageError(message ?: "页内调用失败"))
                                }
                                override fun notImplemented() {
                                    if (pagePrompts.remove(prompt)) prompt.confirm(pageError("页内宿主未注册"))
                                }
                            })
                            return true
                        }
                    }

                    webViewClient = object : WebViewClient() {
                        private var pageFinished = false

                        private fun capture(view: WebView?, candidate: String) {
                            if (destroyed || result.isCompleted) return
                            // 资源/跳转结果与所属页面地址分开，不把资源地址当作页面地址。
                            val pageUrl = view?.url?.takeIf { it.isNotEmpty() } ?: url
                            result.success(buildEnvelope(
                                candidate,
                                CookieManager.getInstance().getCookie(pageUrl).orEmpty(),
                                pageUrl,
                            ))
                            destroyInternal()
                        }

                        private fun captureNavigation(view: WebView?, candidate: String): Boolean {
                            if (destroyed || result.isCompleted) return false
                            if (overridePattern?.matches(candidate) != true) return false
                            capture(view, candidate)
                            return true
                        }

                        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
                            captureNavigation(view, request.url.toString())

                        @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
                        override fun shouldOverrideUrlLoading(view: WebView?, candidate: String): Boolean =
                            captureNavigation(view, candidate)

                        override fun onLoadResource(view: WebView?, resourceUrl: String?) {
                            // 连续监听真实资源事件，包括加载完成后脚本动态触发的资源。
                            if (resourceUrl != null && sourcePattern?.matches(resourceUrl) == true) {
                                capture(view, resourceUrl)
                            }
                        }

                        override fun onPageFinished(view: WebView?, finishedUrl: String?) {
                            super.onPageFinished(view, finishedUrl)
                            if (pageFinished) return
                            pageFinished = true
                            if (result.isCompleted) return
                            if (destroyed) return

                            // B1：首次 onPageFinished 捕获当前页 cookie（WAF 挑战
                            // 页通常由验证 JS 写入 cookie，最终 eval 前再重读）
                            val fUrl = finishedUrl ?: view?.url?.toString().orEmpty()
                            if (fUrl.isNotEmpty()) {
                                capturedCookies =
                                    CookieManager.getInstance().getCookie(fUrl).orEmpty()
                            }

                            fun continueAfterCookieSync() {
                                if (destroyed || result.isCompleted) return
                                // 页面Cookie同步完成后设置原始结果，再执行规则。
                                if (ruleLike && resultJson.isNotEmpty()) {
                                    view?.evaluateJavascript(
                                        "window.result = $resultJson;",
                                        null
                                    )
                                }

                                if (ruleLike && html.isNotEmpty() && pageScript.isNotEmpty()) {
                                    view?.evaluateJavascript(pageScript, null)
                                }

                                when (action) {
                                    "webViewGetOverrideUrl" -> {
                                        // 触发型 JS 后等待跳转；超时见下方 handler
                                        if (js.isNotEmpty()) {
                                            this@WebViewBridge.handler.postDelayed({
                                                view?.evaluateJavascript(js, null)
                                            }, 1000L + delayTime)
                                        }
                                    }
                                    "webViewGetSource" -> {
                                        // 嗅探期间持续等资源事件；规则只按上游时机触发一次。
                                        if (js.isNotEmpty()) {
                                            this@WebViewBridge.handler.postDelayed({
                                                if (!destroyed && !result.isCompleted) view?.evaluateJavascript(js, null)
                                            }, 1000L + delayTime)
                                        }
                                    }
                                    else -> {
                                        // webView：延时后执行 JS（缺省 outerHTML）
                                        val wait = if (js.isEmpty()) {
                                            if (delayTime > 0) delayTime else 900L
                                        } else {
                                            100L + delayTime
                                        }
                                        // B2 eval 重试阶梯（局部递归函数：捕获局部
                                        // capturedCookies / result / opStartMs）
                                        //
                                        // eval 结果空 / 命中挑战签名（CHALLENGE_SIGNATURES，
                                        // WAF 挑战页标志）→ 按 [200,400,600,800,1000]ms
                                        // 阶梯重试至多 MAX_EVAL_RETRIES 次；总预算受
                                        // TIMEOUT_MS 约束（自 opStartMs 起算，剩余不足
                                        // 直接采纳最后结果——全局超时兜底会先触发）。
                                        // cookie 快照在最终采纳时重读（重试窗口内验证
                                        // 流程可能新写 cookie，以最新快照为准，B1 口径）
                                        fun evalWithRetry(wv: WebView, script: String, attempt: Int) {
                                            wv.evaluateJavascript(script) { value ->
                                                if (result.isCompleted) return@evaluateJavascript
                                                val text = unescapeJsResult(value)
                                                val remaining =
                                                    TIMEOUT_MS - (System.currentTimeMillis() - opStartMs)
                                                if (attempt < MAX_EVAL_RETRIES &&
                                                    needsRetryResult(text) &&
                                                    remaining > 0
                                                ) {
                                                    val delay = RETRY_LADDER_MS[
                                                        attempt % RETRY_LADDER_MS.size
                                                    ].coerceAtMost(remaining)
                                                    this@WebViewBridge.handler.postDelayed({
                                                        if (!result.isCompleted) {
                                                            evalWithRetry(wv, script, attempt + 1)
                                                        }
                                                    }, delay)
                                                    return@evaluateJavascript
                                                }
                                                val cUrl = wv.url?.toString().orEmpty()
                                                capturedCookies =
                                                    CookieManager.getInstance()
                                                        .getCookie(cUrl).orEmpty()
                                                result.success(
                                                    buildEnvelope(text, capturedCookies, cUrl)
                                                )
                                                destroyInternal()
                                            }
                                        }
                                        this@WebViewBridge.handler.postDelayed({
                                            // [崩溃防护 | 2026-09-26] 簇B 修复使
                                            // java.webView(null,…) 真正可达，桥内
                                            // 并发竞态的 NPE（WebViewBridge.kt:217
                                            // 真机实测）会杀死整个应用——降级为日志，
                                            // 该源按超时/空结果失败
                                            try {
                                                if (!result.isCompleted) {
                                                    val userJs =
                                                        if (js.isNotEmpty()) js
                                                        else "document.documentElement.outerHTML"
                                                    val injection =
                                                        if (ruleLike && html.isNotEmpty()) {
                                                            pageScript + "\n"
                                                        } else ""
                                                    view?.let { wv ->
                                                        evalWithRetry(wv, injection + userJs, 0)
                                                    }
                                                }
                                            } catch (t: Throwable) {
                                                android.util.Log.e("WebViewBridge", "webViewEval", t)
                                                destroyInternal()
                                            }
                                        }, wait)
                                    }
                                }
                            }
                            if (call.argument<Boolean>("syncCookiesEnabled") == true) {
                                val cookies = if (fUrl.startsWith("http://") || fUrl.startsWith("https://")) mapOf(fUrl to capturedCookies) else emptyMap<String, String>()
                                channel.invokeMethod("syncCookies", mapOf("key" to requestKey, "cookies" to cookies), object : MethodChannel.Result {
                                    private fun failed(message: String) {
                                        if (destroyed || result.isCompleted) return
                                        result.error("COOKIE_SYNC_FAILED", message, null)
                                        destroyInternal()
                                    }
                                    override fun success(value: Any?) {
                                        if (value == true) continueAfterCookieSync() else failed("Cookie同步未获确认")
                                    }
                                    override fun error(code: String, message: String?, details: Any?) { failed(message ?: "Cookie同步失败") }
                                    override fun notImplemented() { failed("Cookie同步宿主未注册") }
                                })
                            } else {
                                continueAfterCookieSync()
                            }
                        }

                        override fun onReceivedError(
                            view: WebView?,
                            request: WebResourceRequest?,
                            error: WebResourceError?
                        ) {
                            super.onReceivedError(view, request, error)
                            if (request?.isForMainFrame == true && !result.isCompleted) {
                                // 对齐 Flutter 路径：资源错误按终态放行，仍尝试取结果
                                onPageFinished(view, view?.url)
                            }
                        }
                    }
                }

                this@WebViewBridge.handler.postDelayed({
                    if (!result.isCompleted) {
                        result.error(
                            "TIMEOUT",
                            "WebView backstage timed out after ${TIMEOUT_MS}ms",
                            null
                        )
                        destroyInternal()
                    }
                }, TIMEOUT_MS)

                // B4（设计文档 §3 项 B）：load 前把 Rust 预取的属域 cookie
                // 逐对写入 WebView cookie jar（对齐上游 CookieManager
                // 预写口径，首请求即携带 JS 侧会话态）；cookie 与 url
                // 同生同灭——html-only 无 url 时 cookie 恒空，天然跳过
                if (cookie.isNotEmpty() && url.isNotEmpty()) {
                    val cm = CookieManager.getInstance()
                    for (pair in cookie.split(';')) {
                        val p = pair.trim()
                        if (p.isNotEmpty()) cm.setCookie(url, p)
                    }
                }

                val wv = webView!!
                if (html.isNotEmpty()) {
                    val base = if (url.isNotEmpty()) url else null
                    wv.loadDataWithBaseURL(base, html, "text/html", "utf-8", base)
                } else {
                    wv.loadUrl(url, headers)
                }
            } catch (e: Exception) {
                result.error("WEBVIEW_ERROR", e.message, e.stackTraceToString())
                destroyInternal()
            }
        }
    }

    /** B2 重试判定：结果空（页面未就绪/外框空）或命中挑战签名（WAF 挑战页标志） */
    private fun needsRetryResult(text: String): Boolean {
        if (text.isEmpty()) return true
        return CHALLENGE_SIGNATURES.any { sig -> text.contains(sig) }
    }

    /**
     * B1 cookie 回流信封（加法式）：无 cookie 时返回纯结果串（与旧版
     * 语义逐字节一致，旧版 Kotlin 兼容）；有 cookie 时返回
     * `{"result": ..., "cookies": {"<cookieUrl>": "k=v; ..."}}`。
     * Dart 侧 [PlatformBridgeService] 解析信封，非信封值按纯结果兜底。
     */
    private fun buildEnvelope(
        resultText: String,
        cookies: String,
        cookieUrl: String,
    ): String {
        return JSONObject().apply {
            put("result", resultText)
            put("finalUrl", cookieUrl)
            put("cookies", JSONObject().apply { if (cookieUrl.isNotEmpty() && cookies.isNotEmpty()) put(cookieUrl, cookies) })
        }.toString()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun loadUrlWithJs(
        url: String,
        js: String?,
        result: SafeResult,
        context: Context
    ) {
        this@WebViewBridge.handler.post {
            try {
                destroyInternal()

                webView = WebView(context).apply {
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true
                    settings.userAgentString = settings.userAgentString
                    settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

                    webViewClient = object : WebViewClient() {
                        private var pageFinished = false

                        override fun onPageFinished(view: WebView?, finishedUrl: String?) {
                            super.onPageFinished(view, finishedUrl)
                            if (pageFinished) return
                            pageFinished = true

                            if (js != null) {
                                this@WebViewBridge.handler.postDelayed({
                                    evaluateJsInternal(js, result)
                                }, 500)
                            } else {
                                result.success(finishedUrl)
                            }
                        }

                        override fun onReceivedError(
                            view: WebView?,
                            request: WebResourceRequest?,
                            error: WebResourceError?
                        ) {
                            super.onReceivedError(view, request, error)
                            if (request?.isForMainFrame == true) {
                                result.error(
                                    "LOAD_ERROR",
                                    "Failed to load: ${error?.description}",
                                    null
                                )
                            }
                        }
                    }
                }

                this@WebViewBridge.handler.postDelayed({
                    if (!result.isCompleted) {
                        result.error("TIMEOUT", "WebView load timed out after ${TIMEOUT_MS}ms", null)
                        destroyInternal()
                    }
                }, TIMEOUT_MS)

                webView?.loadUrl(url)
            } catch (e: Exception) {
                result.error("WEBVIEW_ERROR", e.message, e.stackTraceToString())
            }
        }
    }

    private fun evaluateJs(js: String, result: SafeResult) {
        this@WebViewBridge.handler.post {
            if (webView == null) {
                result.error("NO_WEBVIEW", "WebView not initialized. Call loadUrl first.", null)
                return@post
            }
            evaluateJsInternal(js, result)
        }
    }

    @Suppress("DEPRECATION")
    private fun evaluateJsInternal(js: String, result: SafeResult) {
        webView?.evaluateJavascript(js) { value ->
            if (!result.isCompleted) {
                result.success(value)
            }
        }
    }

    fun destroy() {
        this@WebViewBridge.handler.post { destroyInternal() }
    }

    private fun destroyInternal() {
        if (destroyed) return
        destroyed = true
        requestKey?.let { backstageRequests.remove(it, this) }
        pendingResult?.error("WEBVIEW_CLOSED", "WebView执行已关闭", null)
        pendingResult = null
        pagePrompts.toList().forEach { it.cancel() }
        pagePrompts.clear()
        this@WebViewBridge.handler.removeCallbacksAndMessages(null)
        val wv = webView
        webView = null
        try { wv?.stopLoading() } catch (_: Exception) {}
        // stopLoading只停加载，不能停止已注册的JS定时器；立即离开旧文档。
        // 监听器已受destroyed门禁保护，原生destroy仍延迟，避免在途回调空指针。
        try { wv?.loadUrl("about:blank") } catch (_: Exception) {}
        wv?.let {
            // 真销毁延迟 2s：让在途 chromium 回调（onPageFinished 等）先
            // 落地——同步 destroy() 会把在途内部 Handler 置空，回调里的
            // evaluateJavascript 再触发即 NPE（真机崩溃根因）
            this@WebViewBridge.handler.postDelayed({
                try {
                    it.stopLoading()
                    it.clearHistory()
                    it.removeJavascriptInterface("java")
                    it.destroy()
                } catch (_: Exception) {
                }
            }, 2000L)
        }
    }

    /** evaluateJavascript 回调值为 JSON 编码字符串 */
    private fun unescapeJsResult(raw: String?): String {
        if (raw.isNullOrEmpty() || raw == "null") return ""
        return try {
            org.json.JSONTokener(raw).nextValue()?.let {
                when (it) {
                    is String -> it
                    else -> it.toString()
                }
            } ?: raw
        } catch (_: Exception) {
            var s = raw
            if (s.length >= 2 && s.startsWith("\"") && s.endsWith("\"")) {
                s = s.substring(1, s.length - 1)
                    .replace("\\\"", "\"")
                    .replace("\\n", "\n")
                    .replace("\\\\", "\\")
            }
            s
        }
    }

    private fun pageError(message: String): String = JSONObject().put("error", message).toString()
}
