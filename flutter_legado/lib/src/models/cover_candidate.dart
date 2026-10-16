import 'package:freezed_annotation/freezed_annotation.dart';

part 'cover_candidate.freezed.dart';
part 'cover_candidate.g.dart';

/// 网络封面候选项（对应Rust封面搜索结果）
///
/// 由CoverSearchService的数据适配器解码，页面不处理传输JSON。
/// 尺寸未知时为0，保持现有渲染语义。
@freezed
abstract class CoverCandidate with _$CoverCandidate {
  const factory CoverCandidate({
    /// 封面图片 URL
    @Default('') String url,

    /// 图片宽度（像素，0 表示未知）
    @Default(0) int width,

    /// 图片高度（像素，0 表示未知）
    @Default(0) int height,
  }) = _CoverCandidate;

  factory CoverCandidate.fromJson(Map<String, dynamic> json) =>
      _$CoverCandidateFromJson(json);
}
