package io.legado.flutter

import android.annotation.SuppressLint
import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** 可选额外唤醒锁按引擎持有；系统媒体服务由 audio_service 独立管理。— Codex + UI */
class PlaybackWakeLockPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    private var lock: PowerManager.WakeLock? = null

    @SuppressLint("WakelockTimeout")
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val manager = binding.applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
        lock = manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "legado:AudioPlayWakeLock")
        lock?.setReferenceCounted(false)
        channel = MethodChannel(binding.binaryMessenger, "legado/audio_wake_lock").also { ch ->
            ch.setMethodCallHandler { call, result ->
                if (call.method != "update") {
                    result.notImplemented()
                } else {
                    val enabled = call.argument<Any>("enabled") as? Boolean
                    val playing = call.argument<Any>("playing") as? Boolean
                    if (enabled == null || playing == null) {
                        result.error("INVALID_ARGUMENT", "enabled 与 playing 必须为布尔值", null)
                    } else {
                        try {
                            if (enabled && playing) {
                                if (lock?.isHeld != true) lock?.acquire()
                            } else if (lock?.isHeld == true) {
                                lock?.release()
                            }
                            result.success(null)
                        } catch (failure: RuntimeException) {
                            result.error("WAKE_LOCK_FAILED", "更新听书唤醒锁失败", null)
                        }
                    }
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        if (lock?.isHeld == true) lock?.release()
        lock = null
    }
}
