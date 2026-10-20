import 'package:material_ui/material_ui.dart';

import '../../../../models/book_chapter.dart';

/// 章节状态只负责表现；选择、下载与重试由页面提供。— Codex + UI
class TocItemTile extends StatelessWidget {
  const TocItemTile({
    super.key,
    required this.chapter,
    required this.isCurrent,
    required this.isLocal,
    required this.isCached,
    required this.isDownloading,
    required this.isError,
    required this.loadWordCount,
    required this.wordCount,
    required this.onSelect,
    required this.onDownload,
    required this.onRetry,
  });
  final BookChapter chapter;
  final bool isCurrent,
      isLocal,
      isCached,
      isDownloading,
      isError,
      loadWordCount;
  final String? wordCount;
  final VoidCallback onSelect, onDownload, onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // [P2-29b] 字数胶囊条件对齐参考版 showCount（:1039-1041）：
    // 开关开 && wordCount 非空 && (本地书 || 网络书已缓存)；
    // [P2-29c] && !isError（ERROR 态优先于 SUCCESS/字数）
    final showCount =
        loadWordCount &&
        (wordCount?.isNotEmpty ?? false) &&
        (isLocal || isCached) &&
        !isError;
    // [P2-29b] 状态元素互斥分支（对齐参考版单 when 链，①~⑥ 至多渲染一个；
    // size 16 沿用 P2-28 行高适配；内容带取整行 48 保证图标居中可命中，见
    // 下方 contentPadding 注释）
    final Widget? statusTrailing;
    if (showCount) {
      // ① 字数胶囊（isDur 分色；短路全部状态图标——当前章不再与定位图标并存）
      statusTrailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          // 参考版 :1045-1049：当前章 = primaryContainer 底，
          // 普通章 = surfaceContainer 底（灰底）
          color: isCurrent ? cs.primaryContainer : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        // [P2-28b] 原样展示（Rust 回填值已带「字/万字」后缀；showCount 守卫
        // 已保证非空）
        child: Text(
          wordCount!,
          style: textTheme.labelSmall?.copyWith(
            fontSize: 8,
            // 8sp labelSmallEmphasized（参考版 :1054）
            fontWeight: FontWeight.w500,
            // 参考版 :1055-1059：当前章 = onPrimaryContainer，
            // 普通章 = onSurfaceVariant
            color: isCurrent ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      );
    } else if (isCurrent) {
      // ② 当前章且无胶囊（被 ① 短路）：定位图标（参考版 DUR 态，
      // ReaderSheetStatusIcon tint=secondary，非红色）
      statusTrailing = Icon(Icons.location_on, size: 16, color: cs.secondary);
    } else if (isDownloading) {
      // ③ 下载中：16px 加载指示（对齐参考版 LOADING 态 16dp 转圈形态）
      statusTrailing = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      );
    } else if (isError) {
      // ④ 失败（[P2-29c] 优先级先于已缓存，对齐参考版 rawDataFlow
      // :510-514 running > error > cached 判定序）：红色重试图标可点击 →
      // 单章重下复用 cacheDownloadStart(bookUrl, idx, idx)（契约 §2.43.3
      // 闭区间单章语义）；shrinkWrap 保持 16px 图标几何（P2-28/29 行高
      // 适配口径），不改变行内状态元素对齐
      statusTrailing = IconButton(
        icon: Icon(Icons.refresh, size: 16, color: cs.error),
        iconSize: 16,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        // 命中区 24×24 对齐参考版（视觉仍 16；16×16 仅参考版面积的
        // 44%。不上 48：参考版未做，且占满行高有 P2-29 中心裁切回归风险）
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        tooltip: '重新下载本章',
        onPressed: onRetry,
      );
    } else if (isCached) {
      // ⑤ 已缓存且无胶囊（字数开关关或 wordCount 空）：对勾图标
      // （参考版 SUCCESS 态 :1069-1071 CheckCircle，secondary 色）；
      // [B1-TOC] 音频书的已缓存判定来自音频缓存下标集合（契约 §2.47）
      statusTrailing = Icon(Icons.check_circle, size: 16, color: cs.secondary);
    } else if (!isLocal && !isCached) {
      // ⑥ 未缓存网络章：离线下载图标 ⬇（参考版 NONE 态 outline 色）；
      // [P2-29c] 可点击单章下载（对齐参考版 canDownload = NONE || ERROR
      // :879-881 + :958-965 状态图标挂 onDownloadClick → downloadChapter
      // :863-869），复用 cacheDownloadStart(bookUrl, idx, idx)（契约
      // §2.43.3 闭区间单章语义）；shrinkWrap 保持 16px 图标几何
      statusTrailing = IconButton(
        icon: Icon(
          Icons.download_for_offline_outlined,
          size: 16,
          color: cs.outline.withValues(alpha: 0.5),
        ),
        iconSize: 16,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        // 命中区 24×24 对齐参考版（视觉仍 16；同上不上 48 的理由）
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        tooltip: '下载本章',
        onPressed: onDownload,
      );
    } else {
      // ⑦ 本地书章节（无胶囊且非当前章）：无显示（参考版 LOCAL 态渲染空，
      // 本地书恒视为已缓存但不显示对勾图标，对齐原版 isLocalBook 语义）
      statusTrailing = null;
    }
    return ListTile(
      dense: true,
      shape: const RoundedRectangleBorder(),
      // [P2-29b] 当前章行级高亮对齐参考版 ReaderSheetChapterItem :965-974：
      // isDur → 行背景 secondaryContainer + 标题 onSecondaryContainer（蓝色
      // 主调下即此前量化的淡蓝底 ≈(238,243,253)，替代 primary 10% 铺底）
      tileColor: isCurrent ? cs.secondaryContainer : null,
      // [P2-29b] 行级文字色：M3 ListTile 以 effectiveColor 覆写标题样式色，
      // 经 textColor 参数注入（普通行回退 listTileTheme 的 onSurface 不变）
      textColor: isCurrent ? cs.onSecondaryContainer : null,
      // [LAYOUT_MOTION_AUDIT L3] 章节行内边距 horizontal8；vertical 取 0 而非 12：
      // M3 ListTile trailing 的 _yOffsetFor 按整 tile 高 48 居中后再叠加
      // contentPadding.vertical，v12 会把 16px 状态图标下移 12px（底边超出 24px
      // 内容带），中心点被裁切，ERROR 重试图标 tester.tap 命中不到。vertical 0
      // 使内容带=整行 48，图标居中（16..32）可命中；dense 自然行高 48 与 itemExtent
      // 48 一致，标题仍垂直居中，视觉与 P2-28 不变。
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(chapter.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      // [P2-29b] 右侧状态元素：互斥分支——字数胶囊与状态图标不再并存
      // （对齐参考版单 when 链），两者皆无时为 null
      trailing: statusTrailing,
      // 返回选中章节 index，由调用方走现有阅读跳转链路（对齐原版 openChapter setResult）
      onTap: onSelect,
    );
  }
}
