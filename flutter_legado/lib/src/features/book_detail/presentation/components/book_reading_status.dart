import 'package:material_ui/material_ui.dart';

import '../../../../models/models.dart';
import '../../../../utils/meaningful_text_guard.dart';

/// 详情独立表现组件，只消费输入和事件。— Codex + UI
class BookReadingStatus extends StatelessWidget {
  const BookReadingStatus({
    super.key,
    required this.book,
    required this.chapters,
  });
  final Book book;
  final List<BookChapter> chapters;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    // [F1 | 台账 0917 08 批] 在读/最新行 onSurfaceVariant（wcag 2.79-2.92）
    // 改 onSurface 高对比；[H2/H3 | 台账 0917 反馈批七] ref 08 量化：
    // 在读行墨高 46px/字宽 45px≈16sp 且字框 fill 0.30-0.52 为粗体 →
    // 16sp w700；最新行墨高 40px/字宽 38px≈13sp 常规字重 → 13sp
    Widget line(String text, {double fontSize = 13, FontWeight? weight}) =>
        Padding(
          // [08 左缘对齐 | 台账 0922 遗留闭环 2026-09-26] 参考
          // BookInfoSummary start=16dp（ref x=48），我方 13dp（x=39）差 3dp
          padding: const EdgeInsets.only(left: 16, top: 6),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ts.bodyMedium?.copyWith(
              fontSize: fontSize,
              fontWeight: weight,
              color: cs.onSurface,
            ),
          ),
        );
    final lines = <Widget>[];
    // 在读行（[P2-21] 标题取值 ① 存储值 → ② 目录回落 → ③ 不渲染；
    // durChapterIndex 为 0 基，原版 resolveBookInfoTocTitle 同口径
    // chapters.getOrNull(currentIndex)）
    final durIdx = book.durChapterIndex;
    final storedTitle = (book.durChapterTitle ?? '').trim();
    String? readTitle = isMeaningfulText(storedTitle) ? storedTitle : null;
    if (readTitle == null && durIdx >= 0 && durIdx < chapters.length) {
      final tocTitle = chapters[durIdx].title.trim();
      if (isMeaningfulText(tocTitle)) {
        readTitle = tocTitle;
      }
    }
    if (readTitle != null) {
      // [H2 | 台账 0917 反馈批七] 在读行 16sp w700（ref 墨高 46px 粗体）；
      // [P2-21] 形态对齐参考 toc_s「在读 · %s」：标题原文直出，无「第N章」
      // 前缀（原「在读·第N章」前缀 + 1 基取 chapters[durIdx-1] 双错）
      lines.add(line('在读 · $readTitle', fontSize: 16, weight: FontWeight.w700));
    }
    // 最新行（info：latestChapterTitle）
    // [E5 | 台账 0917 反馈批四] 部分书源的 latestChapterTitle 字段返回的是完结
    // 状态词（如「已完结」而非章节标题，参考版实测「最新·第51章 已完结」缺
    // 章节名），此时回落目录末章真实标题（与在读行同源 chapters 列表）；
    // 数据缺（字段为空）保持现状不渲染（D4 单行口径，不造占位），
    // 状态词且目录无标题数据时保持原值（不丢行）。
    // [P2-21] 形态对齐参考 lasted_show「最新 · %s」：去「第N章」前缀与
    // 代码追加的「（全书完）」后缀（参考 dump 中该后缀为站点标题自带，
    // 回落目录末章时同样不加后缀）
    final latestStatusRe = RegExp(r'^(已完结|完本|已完本|连载中|暂停更新|停更|断更)$');
    final latestRaw = (book.latestChapterTitle ?? '').trim();
    var latestTitle = latestRaw;
    if (latestStatusRe.hasMatch(latestTitle)) {
      final tocTotal = book.totalChapterNum > 0
          ? book.totalChapterNum
          : chapters.length;
      final tocIdx = tocTotal > 0 ? tocTotal - 1 : chapters.length - 1;
      if (tocIdx >= 0 && tocIdx < chapters.length) {
        final tocTitle = chapters[tocIdx].title.trim();
        if (isMeaningfulText(tocTitle)) {
          latestTitle = tocTitle;
        }
      }
    }
    if (isMeaningfulText(latestTitle)) {
      // [H3 | 台账 0917 反馈批七] 最新行 13sp 常规字重（ref 墨高 40px）
      lines.add(line('最新 · $latestTitle', fontSize: 13));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...lines,
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 16, 0),
          child: _buildChapterStatLine(context, book, chapters),
        ),
      ],
    );
  }

  Widget _buildChapterStatLine(
    BuildContext context,
    Book book,
    List<BookChapter> chapters,
  ) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final chapterTotal = book.totalChapterNum > 0
        ? book.totalChapterNum
        : chapters.length;
    if (chapterTotal <= 0) {
      return Text(
        '暂无章节',
        style: ts.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
      );
    }
    final dci = book.durChapterIndex;
    final String readState;
    if (dci == 0 && book.durChapterPos == 0) {
      readState = '未读';
    } else if (dci + 1 == chapterTotal && chapterTotal > 0) {
      readState = '已读完';
    } else {
      readState = '已读 ${dci + 1} 章';
    }
    // [H4 | 台账 0917 反馈批七] ref 08 共N章行墨高 35px/字宽 33px≈
    // 12sp → 13sp 偏大，显式定 12sp
    final base = ts.bodyLarge?.copyWith(fontSize: 12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '共 $chapterTotal 章',
          style: base?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Text('|', style: base?.copyWith(color: cs.secondary)),
        const SizedBox(width: 8),
        Text(readState, style: base?.copyWith(color: cs.secondary)),
      ],
    );
  }
}
