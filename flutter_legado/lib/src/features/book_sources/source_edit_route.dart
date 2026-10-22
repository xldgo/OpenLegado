import 'package:material_ui/material_ui.dart';

import '../../models/book_source.dart';
import 'source_edit_screen.dart';

/// 书源编辑页的统一路由入口。
///
/// 关闭转场快照（[MaterialPageRoute.allowSnapshotting] = false）：编辑页在首帧
/// 即回填全部字段（构造传入 [BookSource] 时在 initState 同步回填，走 sourceUrl
/// 时在 post-frame 回填），而浮动标签的上浮动画只有 167ms，短于平台默认转场
/// 时长（Android FadeForwards 450ms / 桌面 Zoom 300ms）。开启快照时转场期间
/// 进入页被栅格化成静态图，标签动画整段被冻结，转场结束才一帧跳到最终位置，
/// 看起来就是「无动画地从无输入变成有输入」。关闭后转场期间实时绘制，动画
/// 恢复可见，其余页面仍保留快照的性能收益。
///
/// 所有书源编辑页入口（go_router 的 sourceEdit 及书源列表、阅读器、听书页的
/// Navigator.push）统一走本工厂，避免新增入口漏配。
/// — DeepSeek Harness + UI（2026-10-22）
MaterialPageRoute<T> sourceEditRoute<T>({
  String? sourceUrl,
  BookSource? source,
  WidgetBuilder? builder,
  RouteSettings? settings,
}) => MaterialPageRoute<T>(
  settings: settings,
  allowSnapshotting: false,
  builder:
      builder ?? (_) => SourceEditScreen(sourceUrl: sourceUrl, source: source),
);
