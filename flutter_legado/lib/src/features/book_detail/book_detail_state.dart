import '../../domain/models/book_detail_data.dart';

/// 首屏、后台补全与目录加载只在详情展示层表达。— Codex + UI
class BookDetailState {
  const BookDetailState({
    required this.data,
    this.pageLoading = false,
    this.tocLoading = false,
    this.networkLoading = false,
    this.error,
  });

  final BookDetailData data;
  final bool pageLoading, tocLoading, networkLoading;
  final String? error;

  BookDetailState copyWith({
    BookDetailData? data,
    bool? pageLoading,
    bool? tocLoading,
    bool? networkLoading,
    String? error,
    bool clearError = false,
  }) => BookDetailState(
    data: data ?? this.data,
    pageLoading: pageLoading ?? this.pageLoading,
    tocLoading: tocLoading ?? this.tocLoading,
    networkLoading: networkLoading ?? this.networkLoading,
    error: clearError ? null : error ?? this.error,
  );
}
