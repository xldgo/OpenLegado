// 只适配 JSON 输入输出；断行与分页执行未经改写的固定上游 Kotlin 文件。
package io.legado.app.feature.reader.core.layout

import com.google.gson.*
import io.legado.app.feature.reader.core.model.*

private val gson = GsonBuilder().serializeNulls().create()
private fun JsonObject.str(key: String) = get(key).asString
private fun JsonObject.int(key: String) = get(key).asInt
private fun JsonObject.float(key: String) = get(key).asFloat
private fun <T> merge(base: T, input: JsonObject, clazz: Class<T>): T {
    val value = gson.toJsonTree(base).asJsonObject
    input.entrySet().forEach { (key, entry) -> if (key != "type") value.add(key, entry) }
    return gson.fromJson(value, clazz)
}
private fun alignment(o: JsonObject, key: String, fallback: ReaderTextAlignment): ReaderTextAlignment =
    o.get(key)?.takeUnless { it.isJsonNull }?.asString?.uppercase()?.let(ReaderTextAlignment::valueOf) ?: fallback
private fun style(o: JsonObject): ReaderTextStyle {
    val base = ReaderTextStyle(o.int("colorArgb"), o.float("fontSizePx"))
    val result = merge(base, o, ReaderTextStyle::class.java)
    if (o.get("backgroundImage")?.isJsonObject == true) {
        val b = o.getAsJsonObject("backgroundImage")
        return result.copy(backgroundImage = merge(ReaderTextBackgroundImage(b.str("source"),b.int("fit"),b.float("scale")),b,ReaderTextBackgroundImage::class.java))
    }
    return result
}
private fun config(o: JsonObject): ReaderPaginationConfig {
    val base = ReaderPaginationConfig(o.int("chapterIndex"),o.str("chapterTitle"),o.int("viewportWidthPx"),o.int("viewportHeightPx"),o.float("paddingLeftPx"),o.float("paddingTopPx"),o.float("paddingRightPx"),o.float("paddingBottomPx"),o.float("lineHeightPx"),o.float("baselineOffsetPx"))
    var c = merge(base,o,ReaderPaginationConfig::class.java)
    o.get("pageUnderline")?.takeIf {it.isJsonObject}?.asJsonObject?.let { u ->
        c = c.copy(pageUnderline = merge(ReaderPageUnderline(u.int("colorArgb"),u.float("widthPx"),u.float("offsetPx"),u.get("extendToColumn").asBoolean,u.get("dashed").asBoolean),u,ReaderPageUnderline::class.java))
    }
    return c
}
private fun item(o: JsonObject): ReaderMeasuredInlineItem = when(o.str("type")) {
    "text" -> merge(ReaderMeasuredInlineItem.Text(o.str("value"),o.float("widthPx"),style(o.getAsJsonObject("style")),o.int("chapterPosition")),o.deepCopy().apply{add("style",gson.toJsonTree(style(getAsJsonObject("style"))))},ReaderMeasuredInlineItem.Text::class.java)
    "image" -> merge(ReaderMeasuredInlineItem.Image(o.str("source"),o.float("widthPx"),o.float("heightPx"),o.int("chapterPosition")),o,ReaderMeasuredInlineItem.Image::class.java)
    "roleCast" -> merge(ReaderMeasuredInlineItem.RoleCast(o.float("widthPx"),o.float("heightPx"),o.int("chapterPosition"),o.str("raw"),o.str("name"),o.str("voicePoolLabel"),o.int("quoteOrdinal")),o,ReaderMeasuredInlineItem.RoleCast::class.java)
    "bgmScene" -> merge(ReaderMeasuredInlineItem.BgmScene(o.float("widthPx"),o.float("heightPx"),o.int("chapterPosition"),o.int("paragraphIndex"),o.str("poolName"),o.str("trackName")),o,ReaderMeasuredInlineItem.BgmScene::class.java)
    else -> error("上游不支持的行内项")
}
private fun block(o: JsonObject): ReaderMeasuredBlock = when(o.str("type")) {
    "paragraph" -> {
        val p=o.getAsJsonObject("value")
        val base=ReaderMeasuredParagraph(p.str("text"),p.getAsJsonArray("clusters").map{it.asString},p.getAsJsonArray("clusterWidthsPx").map{it.asFloat},style(p.getAsJsonObject("style")),p.int("chapterPosition"))
        ReaderMeasuredBlock.Paragraph(merge(base,p.deepCopy().apply{remove("alignment");add("style",gson.toJsonTree(style(getAsJsonObject("style"))))},ReaderMeasuredParagraph::class.java).copy(alignment=alignment(p,"alignment",ReaderTextAlignment.START)))
    }
    "inlineParagraph" -> {
        val base=ReaderMeasuredBlock.InlineParagraph(o.getAsJsonArray("items").map{item(it.asJsonObject)},o.int("indentCharacters"),alignment(o,"alignment",ReaderTextAlignment.START),o.float("lineHeightPx"),o.float("baselineOffsetPx"),o.float("baseTextSizePx"))
        val decorations=o.getAsJsonArray("decorations")?.map{d->val v=d.asJsonObject;ReaderParagraphDecoration(ReaderParagraphDecorationKind.valueOf(v.str("kind").uppercase()),v.get("colorArgb")?.takeUnless{it.isJsonNull}?.asInt,v.float("sizePx"),v.get("leadingOffsetPx")?.asFloat?:0f)}?:emptyList()
        base.copy(decorations=decorations,
            emphasized=o.get("emphasized")?.asBoolean?:false,
            titleSpacingScale=o.get("titleSpacingScale")?.asFloat?:1f,
            lineSpacingMultiplier=o.get("lineSpacingMultiplier")?.asFloat?:1f,
            letterSpacingPx=o.get("letterSpacingPx")?.takeUnless{it.isJsonNull}?.asFloat,
            indentWidthPx=o.get("indentWidthPx")?.takeUnless{it.isJsonNull}?.asFloat,
            restLineIndentWidthPx=o.get("restLineIndentWidthPx")?.asFloat?:0f,
            leadingIndentItems=o.get("leadingIndentItems")?.asInt?:0,
            justifyAtWordBoundaries=o.get("justifyAtWordBoundaries")?.asBoolean?:false)
    }
    "image" -> {
        val base=ReaderMeasuredBlock.Image(o.str("source"),o.float("intrinsicWidthPx"),o.float("intrinsicHeightPx"),o.int("chapterPosition"))
        val mode=o.get("scaleMode")?.asString?.replace(Regex("([a-z])([A-Z])"),"$1_$2")?.uppercase()?.let(ReaderImageScaleMode::valueOf)?:ReaderImageScaleMode.CONTAIN_NO_UPSCALE
        merge(base,o.deepCopy().apply{remove("horizontalAlignment");remove("scaleMode")},ReaderMeasuredBlock.Image::class.java).copy(horizontalAlignment=alignment(o,"horizontalAlignment",ReaderTextAlignment.CENTER),scaleMode=mode)
    }
    "blankLine" -> ReaderMeasuredBlock.BlankLine(o.int("chapterPosition"),o.float("lineHeightPx"),o.float("lineSpacingMultiplier"))
    "rule" -> merge(ReaderMeasuredBlock.Rule(o.int("colorArgb"),o.float("widthPx"),o.float("verticalPaddingPx")),o,ReaderMeasuredBlock.Rule::class.java)
    "pageBreak" -> ReaderMeasuredBlock.PageBreak
    else -> error("未知内容块")
}
private fun page(p: ReaderPage): JsonObject {
    val obj=gson.toJsonTree(p).asJsonObject
    // 动态搜索/朗读状态属于绘制输入，与布局无关。
    listOf("searchStart","searchEndInclusive","searchIsTitle","readAloudParagraphIndex","isPlaceholder").forEach(obj::remove)
    obj.add("elements",JsonArray().apply{p.elements.forEach{e->
        add(gson.toJsonTree(e).asJsonObject.apply{
            addProperty("type",e.javaClass.simpleName.replaceFirstChar{it.lowercase()})
        })
    }})
    return obj
}
fun main(args: Array<String>) {
    java.io.File(args[0]).forEachLine { line ->
        val input=JsonParser.parseString(line).asJsonObject
        val output=JsonObject()
        output.addProperty("name",input.str("name"))
        if(input.str("kind")=="break") {
            val v=input.getAsJsonObject("input")
            val b=ChineseLineBreaker(v.getAsJsonArray("clusters").map{it.asString},v.getAsJsonArray("widthsPx").map{it.asFloat},v.int("indentCharacters"),v.int("widthPx"),v.float("ideographWidthPx"),v.float("letterSpacingPx"),v.int("firstLineWidthPx"))
            output.add("expected",JsonObject().apply{
                add("lineStarts",gson.toJsonTree(b.lineStarts));add("lineClusterStarts",gson.toJsonTree(b.lineClusterStarts));add("lineWidthsPx",gson.toJsonTree(b.lineWidthsPx))
            })
        } else {
            val v=input.getAsJsonObject("input")
            output.add("expected",JsonArray().apply{ReaderPaginator.paginateBlocks(v.getAsJsonArray("blocks").map{block(it.asJsonObject)},config(v.getAsJsonObject("config"))).forEach{add(page(it))}})
        }
        println(gson.toJson(output))
    }
}
