import 'package:material_ui/material_ui.dart';

import '../../../../models/models.dart';

import 'package:material_symbols_icons/symbols.dart';

import '../../../../widgets/book_cover.dart';

/// 详情独立表现组件，只消费输入和事件。— Codex + UI
class BookMetaCard extends StatelessWidget {
  const BookMetaCard({
    super.key,
    required this.book,
    required this.onChangeCover,
    required this.onPreviewCover,
    required this.onNameTap,
    required this.onNameLongPress,
    required this.onAuthorTap,
    required this.onAuthorLongPress,
    required this.onChangeSource,
    required this.onSourceTap,
  });
  final Book book;
  final VoidCallback onChangeCover;
  final VoidCallback onPreviewCover;
  final VoidCallback onNameTap;
  final VoidCallback onNameLongPress;
  final VoidCallback onAuthorTap;
  final VoidCallback onAuthorLongPress;
  final VoidCallback onChangeSource;
  final VoidCallback? onSourceTap;
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    // [U6 | 台账 0917 批二] 双（深+浅）柔阴影：去掉信息列浅底卡后，书名/作者/
    // 书源直排于 hero（参考 08 无卡底），此阴影保证任意（亮/暗）封面 hero 下
    // 深色文字对比可读（深色阴影压亮底、浅色光晕托暗底）
    // [F1 | 台账 0917 08 批] 强化为「深色文字 + 白色柔光」保底组合（历史）
    // [G3 | 台账 0917 批六] 改「深色为主」：三行文字保持完全不透明 onSurface
    // （亮态 hero 上即纯黑书名，对齐 ref 08 PIL 实测墨 L≤17）；深阴影升为
    // 主保障 α0.60/blur6/offset(0,1.5) 压亮底；白色柔光降权至 α0.25/blur12
    // 仅作暗 hero / 暗色主题保险，避免强白晕冲淡深色高对比观感
    final heroTextShadows = const [
      Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1.5)),
      Shadow(color: Color(0x40FFFFFF), blurRadius: 12),
    ];
    // [U10 | 台账 0917 批三] 版块重排后头部以两栏收尾，底距 12→4：
    // 与 ① 聚合行 top 8 合成 12dp 间隙（原 12dp 底距随移出的版块移除）
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 4),
      child: Column(
        // [PARITY C1 D6] 信息流左对齐（参考 08：各信息行随封面左缘起排）；
        // Column 默认 center 会使收缩行居中 → start。
        // [U10-U12] 标签行/在读最新块/聚合行已移出头部（见 _buildBody 版块序）
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 两栏：封面左置 + 右侧信息列
          // [U2 | 台账 0917] 封面回缩至原版 XML 尺寸 110×160dp（ref 08 PIL
          // 实测 337×469px≈112×156dp，圆角 2-3dp）；左距 13dp、与右侧
          // 信息列间隙 17dp（PIL 实测 39-40px/52px），信息列垂直居中
          // （参考版书名顶距封面顶 44.7dp≈160dp 封面内居中，对齐参考位置）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // [G4 | 台账 0917 批六] 封面卡浮起观感：阴影保留（elevation 8），
                // 补 1px 浅描边（outlineVariant 槽位；ref 08 PIL 实测卡缘 ~1-2px
                // 浅灰线 L≈150-154）。G1 渐隐后卡下缘落在纯 surface 底色区，
                // 描边+阴影的浮起感清晰，对齐参考
                Material(
                  elevation: 8,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: GestureDetector(
                      // 对齐原版 ivCover 点击换封面 / 长按预览大图 — Cursor UI
                      onTap: onChangeCover,
                      onLongPress: onPreviewCover,
                      // 共用封面飞行与状态保留，内层不再设置 heroTag。
                      child: BookCoverHero(
                        tag: 'book-cover:${book.bookUrl}',
                        child: BookCover(
                          coverUrl: book.customCoverUrl ?? book.coverUrl,
                          // [U2 | 台账 0917] 110×160dp 圆角 3（原版
                          // activity_book_info.xml iv_cover 精确值 + ref PIL
                          // 实测 112×156dp；2.0.276 的 120×260 偏大，回缩）
                          width: 110,
                          height: 160,
                          borderRadius: 3,
                          sourceOrigin: book.origin,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 17),
                Expanded(
                  child: Container(
                    // [U6 | 台账 0917 批二] 去掉淡色护底卡：信息列（书名/作者/
                    // 书源）透明直排于 hero（对齐参考 08，其标题块无卡底，PIL
                    // 实测标题区背景=hero 透传 117-176 渐变，非浅底卡）。对比度
                    // 改由文字双（深+浅）柔阴影 heroTextShadows 保证，任意封面
                    // （亮/暗）hero 下均可读
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 书名（对齐原版 tvName 点击/长按 → SearchActivity）
                        GestureDetector(
                          onTap: onNameTap,
                          onLongPress: onNameLongPress,
                          child: Text(
                            book.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            // [U3 | 台账 0917] 大字深色：ref 08 PIL 实测
                            // 墨高 65px≈22sp（任务估 28sp 为缩略预览误估，
                            // 以 PIL 量化为准）；主题 titleLarge=18sp 偏小，
                            // 此处显式定 22sp w700 onSurface 高对比
                            // [F2 | 台账 0917 08 批] 复测 ref 08 书名墨高
                            // 70px≈23.3sp → 24sp（22sp 偏小一档）
                            style: ts.titleLarge?.copyWith(
                              fontSize: 24,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                              shadows: heroTextShadows,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // 作者（点击 → 搜索作者；长按 → JS 回调，行为不变）
                        GestureDetector(
                          onTap: onAuthorTap,
                          onLongPress: onAuthorLongPress,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            book.author.isNotEmpty ? book.author : '未知作者',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // [U3 | 台账 0917] 中等可读灰（ref PIL 实测
                            // 14-16sp）；[U6] 去护底卡后对比度由
                            // heroTextShadows 双柔阴影保证
                            // [F1 | 台账 0917 08 批] 过淡灰 onSurfaceVariant
                            // （wcag 2.08-3.36 <4.5）改完全不透明 onSurface +
                            // 强化白柔光阴影，任意 hero 下可读
                            style: ts.bodyMedium?.copyWith(
                              color: cs.onSurface,
                              shadows: heroTextShadows,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 来源=书源名（点击 → 编辑书源；「换源」小按钮，行为不变）
                        Row(
                          children: [
                            // [F1 | 台账 0917 08 批] 图标随文字改 onSurface 高对比
                            Icon(
                              Symbols.language_rounded,
                              size: 14,
                              color: cs.onSurface,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                onTap: onSourceTap,
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  '来源：${book.originName.isNotEmpty ? book.originName : book.origin}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  // [F1 | 台账 0917 08 批] onSurfaceVariant
                                  // → onSurface 高对比 + 白柔光阴影；
                                  // [F2] ref 08 来源行墨高 32px≈10.7sp → 11sp
                                  // （原 14sp 偏大一档）
                                  style: ts.bodyMedium?.copyWith(
                                    fontSize: 11,
                                    color: cs.onSurface,
                                    shadows: heroTextShadows,
                                  ),
                                ),
                              ),
                            ),
                            _smallAction(context, '换源', onChangeSource),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallAction(BuildContext context, String text, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, color: cs.onPrimary)),
      ),
    );
  }
}
