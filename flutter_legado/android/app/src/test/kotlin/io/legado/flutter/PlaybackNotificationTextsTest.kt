package io.legado.flutter

import org.junit.Assert.assertEquals
import org.junit.Test

/** 书名与章节映射；定时使用独立辅助字段。— Codex + Bridge */
class PlaybackNotificationTextsTest {
    @Test
    fun `书名作为主标题章节作为次标题`() {
        val (title, text) = resolvePlaybackNotificationTexts("测试书", "第3章 风起")
        assertEquals("测试书", title)
        assertEquals("第3章 风起", text)
    }

    @Test
    fun `章节为空保留书名`() {
        assertEquals("测试书" to "", resolvePlaybackNotificationTexts("测试书", null))
    }

    @Test
    fun `书名缺失回退章节而不重复显示`() {
        assertEquals("第1章" to "", resolvePlaybackNotificationTexts("", "第1章"))
    }

    @Test
    fun `空元数据不会构造播放前缀`() {
        assertEquals("" to "", resolvePlaybackNotificationTexts(null, null))
    }
}
