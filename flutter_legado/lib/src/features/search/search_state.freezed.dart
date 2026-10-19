// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SearchState {
  /// 当前搜索关键词
  String get keyword;

  /// 搜索结果列表（已按书名+作者聚合，对齐原版 mergeItems）
  List<SearchResult> get results;

  /// 是否正在搜索
  bool get isLoading;

  /// 渐进搜索：已完成书源数（对齐原版 onSearchProgress searched）
  int get searchedCount;

  /// 渐进搜索：书源总数（对齐原版 onSearchProgress total）
  int get totalCount;

  /// 错误信息
  String? get error;

  /// 失败书源列表（队列④ P1-B：单源搜索失败原仅 AppLog 留痕、UI 不可见，
  /// 现累积于此并在搜索结果页顶部以非阻断横幅呈现；新关键词搜索 / 清空 /
  /// 页面重开时清空，同关键词续页按源名去重（最新错误优先））
  List<SearchSourceFailure> get failedSources;

  /// 精准搜索：选中的书源 URL
  Set<String> get selectedSourceUrls;

  /// 精准搜索：选中的分组
  Set<String> get selectedGroups;

  /// 搜索历史（最近 20 条，经 SearchHistoryRepository 持久化至 Rust search_keywords 表）
  /// [审计修复 §4.5] 清理陈旧注释（实际已不走 SharedPreferences） — Qoder
  List<String> get searchHistory;

  /// 输入框实时文本（用于联想过滤，区别于已提交的 [keyword]）
  String get inputText;

  /// 活动搜索会话的当前页码（批次B G-B-01：新关键词 → 重置为 1；
  /// 同关键词续页 → searchPage++，对齐原版 SearchModel.searchPage）
  int get searchPage;

  /// 是否有下一页（批次B G-B-02：当前页非空批次的 OR，Rust 侧 has_more
  /// 累积字段；新搜索开始时乐观置 true，每批事件覆写）
  bool get hasMore;

  /// 软挂起态（批次B G-B-04：仅门控未派发书源，已派发任务继续；
  /// 对齐原版 repeatOnLifecycle(RESUMED) → viewModel.pause/resume）
  bool get isPaused;

  /// 用户手动停止了本次搜索（对齐原版 SearchActivity.isManualStopSearch）：
  /// 抑制 play FAB 与滚动自动加载，直至新关键词搜索重置
  bool get isManualStop;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SearchStateCopyWith<SearchState> get copyWith =>
      _$SearchStateCopyWithImpl<SearchState>(this as SearchState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as SearchState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SearchState &&
            (identical(other.keyword, _this.keyword) ||
                other.keyword == _this.keyword) &&
            const DeepCollectionEquality().equals(
              other.results,
              _this.results,
            ) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.searchedCount, _this.searchedCount) ||
                other.searchedCount == _this.searchedCount) &&
            (identical(other.totalCount, _this.totalCount) ||
                other.totalCount == _this.totalCount) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            const DeepCollectionEquality().equals(
              other.failedSources,
              _this.failedSources,
            ) &&
            const DeepCollectionEquality().equals(
              other.selectedSourceUrls,
              _this.selectedSourceUrls,
            ) &&
            const DeepCollectionEquality().equals(
              other.selectedGroups,
              _this.selectedGroups,
            ) &&
            const DeepCollectionEquality().equals(
              other.searchHistory,
              _this.searchHistory,
            ) &&
            (identical(other.inputText, _this.inputText) ||
                other.inputText == _this.inputText) &&
            (identical(other.searchPage, _this.searchPage) ||
                other.searchPage == _this.searchPage) &&
            (identical(other.hasMore, _this.hasMore) ||
                other.hasMore == _this.hasMore) &&
            (identical(other.isPaused, _this.isPaused) ||
                other.isPaused == _this.isPaused) &&
            (identical(other.isManualStop, _this.isManualStop) ||
                other.isManualStop == _this.isManualStop));
  }

  @override
  int get hashCode {
    final _this = this as SearchState;
    return Object.hash(
      runtimeType,
      _this.keyword,
      const DeepCollectionEquality().hash(_this.results),
      _this.isLoading,
      _this.searchedCount,
      _this.totalCount,
      _this.error,
      const DeepCollectionEquality().hash(_this.failedSources),
      const DeepCollectionEquality().hash(_this.selectedSourceUrls),
      const DeepCollectionEquality().hash(_this.selectedGroups),
      const DeepCollectionEquality().hash(_this.searchHistory),
      _this.inputText,
      _this.searchPage,
      _this.hasMore,
      _this.isPaused,
      _this.isManualStop,
    );
  }

  @override
  String toString() {
    final _this = this as SearchState;
    return 'SearchState(keyword: ${_this.keyword}, results: ${_this.results}, isLoading: ${_this.isLoading}, searchedCount: ${_this.searchedCount}, totalCount: ${_this.totalCount}, error: ${_this.error}, failedSources: ${_this.failedSources}, selectedSourceUrls: ${_this.selectedSourceUrls}, selectedGroups: ${_this.selectedGroups}, searchHistory: ${_this.searchHistory}, inputText: ${_this.inputText}, searchPage: ${_this.searchPage}, hasMore: ${_this.hasMore}, isPaused: ${_this.isPaused}, isManualStop: ${_this.isManualStop})';
  }
}

/// @nodoc
abstract mixin class $SearchStateCopyWith<$Res> {
  factory $SearchStateCopyWith(
    SearchState value,
    $Res Function(SearchState) _then,
  ) = _$SearchStateCopyWithImpl;
  @useResult
  $Res call({
    String keyword,
    List<SearchResult> results,
    bool isLoading,
    int searchedCount,
    int totalCount,
    String? error,
    List<SearchSourceFailure> failedSources,
    Set<String> selectedSourceUrls,
    Set<String> selectedGroups,
    List<String> searchHistory,
    String inputText,
    int searchPage,
    bool hasMore,
    bool isPaused,
    bool isManualStop,
  });
}

/// @nodoc
class _$SearchStateCopyWithImpl<$Res> implements $SearchStateCopyWith<$Res> {
  _$SearchStateCopyWithImpl(this._self, this._then);

  final SearchState _self;
  final $Res Function(SearchState) _then;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? keyword = null,
    Object? results = null,
    Object? isLoading = null,
    Object? searchedCount = null,
    Object? totalCount = null,
    Object? error = freezed,
    Object? failedSources = null,
    Object? selectedSourceUrls = null,
    Object? selectedGroups = null,
    Object? searchHistory = null,
    Object? inputText = null,
    Object? searchPage = null,
    Object? hasMore = null,
    Object? isPaused = null,
    Object? isManualStop = null,
  }) {
    return _then(
      SearchState(
        keyword: null == keyword
            ? _self.keyword
            : keyword // ignore: cast_nullable_to_non_nullable
                  as String,
        results: null == results
            ? _self.results
            : results // ignore: cast_nullable_to_non_nullable
                  as List<SearchResult>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        searchedCount: null == searchedCount
            ? _self.searchedCount
            : searchedCount // ignore: cast_nullable_to_non_nullable
                  as int,
        totalCount: null == totalCount
            ? _self.totalCount
            : totalCount // ignore: cast_nullable_to_non_nullable
                  as int,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        failedSources: null == failedSources
            ? _self.failedSources
            : failedSources // ignore: cast_nullable_to_non_nullable
                  as List<SearchSourceFailure>,
        selectedSourceUrls: null == selectedSourceUrls
            ? _self.selectedSourceUrls
            : selectedSourceUrls // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        selectedGroups: null == selectedGroups
            ? _self.selectedGroups
            : selectedGroups // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        searchHistory: null == searchHistory
            ? _self.searchHistory
            : searchHistory // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        inputText: null == inputText
            ? _self.inputText
            : inputText // ignore: cast_nullable_to_non_nullable
                  as String,
        searchPage: null == searchPage
            ? _self.searchPage
            : searchPage // ignore: cast_nullable_to_non_nullable
                  as int,
        hasMore: null == hasMore
            ? _self.hasMore
            : hasMore // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPaused: null == isPaused
            ? _self.isPaused
            : isPaused // ignore: cast_nullable_to_non_nullable
                  as bool,
        isManualStop: null == isManualStop
            ? _self.isManualStop
            : isManualStop // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [SearchState].
extension SearchStatePatterns on SearchState {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_SearchState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchState() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_SearchState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchState():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_SearchState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchState() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
      String keyword,
      List<SearchResult> results,
      bool isLoading,
      int searchedCount,
      int totalCount,
      String? error,
      List<SearchSourceFailure> failedSources,
      Set<String> selectedSourceUrls,
      Set<String> selectedGroups,
      List<String> searchHistory,
      String inputText,
      int searchPage,
      bool hasMore,
      bool isPaused,
      bool isManualStop,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchState() when $default != null:
        return $default(
          _that.keyword,
          _that.results,
          _that.isLoading,
          _that.searchedCount,
          _that.totalCount,
          _that.error,
          _that.failedSources,
          _that.selectedSourceUrls,
          _that.selectedGroups,
          _that.searchHistory,
          _that.inputText,
          _that.searchPage,
          _that.hasMore,
          _that.isPaused,
          _that.isManualStop,
        );
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
      String keyword,
      List<SearchResult> results,
      bool isLoading,
      int searchedCount,
      int totalCount,
      String? error,
      List<SearchSourceFailure> failedSources,
      Set<String> selectedSourceUrls,
      Set<String> selectedGroups,
      List<String> searchHistory,
      String inputText,
      int searchPage,
      bool hasMore,
      bool isPaused,
      bool isManualStop,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchState():
        return $default(
          _that.keyword,
          _that.results,
          _that.isLoading,
          _that.searchedCount,
          _that.totalCount,
          _that.error,
          _that.failedSources,
          _that.selectedSourceUrls,
          _that.selectedGroups,
          _that.searchHistory,
          _that.inputText,
          _that.searchPage,
          _that.hasMore,
          _that.isPaused,
          _that.isManualStop,
        );
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
      String keyword,
      List<SearchResult> results,
      bool isLoading,
      int searchedCount,
      int totalCount,
      String? error,
      List<SearchSourceFailure> failedSources,
      Set<String> selectedSourceUrls,
      Set<String> selectedGroups,
      List<String> searchHistory,
      String inputText,
      int searchPage,
      bool hasMore,
      bool isPaused,
      bool isManualStop,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchState() when $default != null:
        return $default(
          _that.keyword,
          _that.results,
          _that.isLoading,
          _that.searchedCount,
          _that.totalCount,
          _that.error,
          _that.failedSources,
          _that.selectedSourceUrls,
          _that.selectedGroups,
          _that.searchHistory,
          _that.inputText,
          _that.searchPage,
          _that.hasMore,
          _that.isPaused,
          _that.isManualStop,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SearchState implements SearchState {
  const _SearchState({
    this.keyword = '',
    List<SearchResult> results = const [],
    this.isLoading = false,
    this.searchedCount = 0,
    this.totalCount = 0,
    this.error,
    List<SearchSourceFailure> failedSources = const <SearchSourceFailure>[],
    Set<String> selectedSourceUrls = const <String>{},
    Set<String> selectedGroups = const <String>{},
    List<String> searchHistory = const [],
    this.inputText = '',
    this.searchPage = 1,
    this.hasMore = false,
    this.isPaused = false,
    this.isManualStop = false,
  }) : _results = results,
       _failedSources = failedSources,
       _selectedSourceUrls = selectedSourceUrls,
       _selectedGroups = selectedGroups,
       _searchHistory = searchHistory;

  /// 当前搜索关键词
  @override
  @JsonKey()
  final String keyword;

  /// 搜索结果列表（已按书名+作者聚合，对齐原版 mergeItems）
  final List<SearchResult> _results;

  /// 搜索结果列表（已按书名+作者聚合，对齐原版 mergeItems）
  @override
  @JsonKey()
  List<SearchResult> get results {
    if (_results is EqualUnmodifiableListView) return _results;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_results);
  }

  /// 是否正在搜索
  @override
  @JsonKey()
  final bool isLoading;

  /// 渐进搜索：已完成书源数（对齐原版 onSearchProgress searched）
  @override
  @JsonKey()
  final int searchedCount;

  /// 渐进搜索：书源总数（对齐原版 onSearchProgress total）
  @override
  @JsonKey()
  final int totalCount;

  /// 错误信息
  @override
  final String? error;

  /// 失败书源列表（队列④ P1-B：单源搜索失败原仅 AppLog 留痕、UI 不可见，
  /// 现累积于此并在搜索结果页顶部以非阻断横幅呈现；新关键词搜索 / 清空 /
  /// 页面重开时清空，同关键词续页按源名去重（最新错误优先））
  final List<SearchSourceFailure> _failedSources;

  /// 失败书源列表（队列④ P1-B：单源搜索失败原仅 AppLog 留痕、UI 不可见，
  /// 现累积于此并在搜索结果页顶部以非阻断横幅呈现；新关键词搜索 / 清空 /
  /// 页面重开时清空，同关键词续页按源名去重（最新错误优先））
  @override
  @JsonKey()
  List<SearchSourceFailure> get failedSources {
    if (_failedSources is EqualUnmodifiableListView) return _failedSources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_failedSources);
  }

  /// 精准搜索：选中的书源 URL
  final Set<String> _selectedSourceUrls;

  /// 精准搜索：选中的书源 URL
  @override
  @JsonKey()
  Set<String> get selectedSourceUrls {
    if (_selectedSourceUrls is EqualUnmodifiableSetView)
      return _selectedSourceUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedSourceUrls);
  }

  /// 精准搜索：选中的分组
  final Set<String> _selectedGroups;

  /// 精准搜索：选中的分组
  @override
  @JsonKey()
  Set<String> get selectedGroups {
    if (_selectedGroups is EqualUnmodifiableSetView) return _selectedGroups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedGroups);
  }

  /// 搜索历史（最近 20 条，经 SearchHistoryRepository 持久化至 Rust search_keywords 表）
  /// [审计修复 §4.5] 清理陈旧注释（实际已不走 SharedPreferences） — Qoder
  final List<String> _searchHistory;

  /// 搜索历史（最近 20 条，经 SearchHistoryRepository 持久化至 Rust search_keywords 表）
  /// [审计修复 §4.5] 清理陈旧注释（实际已不走 SharedPreferences） — Qoder
  @override
  @JsonKey()
  List<String> get searchHistory {
    if (_searchHistory is EqualUnmodifiableListView) return _searchHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_searchHistory);
  }

  /// 输入框实时文本（用于联想过滤，区别于已提交的 [keyword]）
  @override
  @JsonKey()
  final String inputText;

  /// 活动搜索会话的当前页码（批次B G-B-01：新关键词 → 重置为 1；
  /// 同关键词续页 → searchPage++，对齐原版 SearchModel.searchPage）
  @override
  @JsonKey()
  final int searchPage;

  /// 是否有下一页（批次B G-B-02：当前页非空批次的 OR，Rust 侧 has_more
  /// 累积字段；新搜索开始时乐观置 true，每批事件覆写）
  @override
  @JsonKey()
  final bool hasMore;

  /// 软挂起态（批次B G-B-04：仅门控未派发书源，已派发任务继续；
  /// 对齐原版 repeatOnLifecycle(RESUMED) → viewModel.pause/resume）
  @override
  @JsonKey()
  final bool isPaused;

  /// 用户手动停止了本次搜索（对齐原版 SearchActivity.isManualStopSearch）：
  /// 抑制 play FAB 与滚动自动加载，直至新关键词搜索重置
  @override
  @JsonKey()
  final bool isManualStop;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SearchStateCopyWith<_SearchState> get copyWith =>
      __$SearchStateCopyWithImpl<_SearchState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SearchState &&
            (identical(other.keyword, keyword) || other.keyword == keyword) &&
            const DeepCollectionEquality().equals(other.results, _results) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.searchedCount, searchedCount) ||
                other.searchedCount == searchedCount) &&
            (identical(other.totalCount, totalCount) ||
                other.totalCount == totalCount) &&
            (identical(other.error, error) || other.error == error) &&
            const DeepCollectionEquality().equals(
              other.failedSources,
              _failedSources,
            ) &&
            const DeepCollectionEquality().equals(
              other.selectedSourceUrls,
              _selectedSourceUrls,
            ) &&
            const DeepCollectionEquality().equals(
              other.selectedGroups,
              _selectedGroups,
            ) &&
            const DeepCollectionEquality().equals(
              other.searchHistory,
              _searchHistory,
            ) &&
            (identical(other.inputText, inputText) ||
                other.inputText == inputText) &&
            (identical(other.searchPage, searchPage) ||
                other.searchPage == searchPage) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.isPaused, isPaused) ||
                other.isPaused == isPaused) &&
            (identical(other.isManualStop, isManualStop) ||
                other.isManualStop == isManualStop));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      keyword,
      const DeepCollectionEquality().hash(_results),
      isLoading,
      searchedCount,
      totalCount,
      error,
      const DeepCollectionEquality().hash(_failedSources),
      const DeepCollectionEquality().hash(_selectedSourceUrls),
      const DeepCollectionEquality().hash(_selectedGroups),
      const DeepCollectionEquality().hash(_searchHistory),
      inputText,
      searchPage,
      hasMore,
      isPaused,
      isManualStop,
    );
  }

  @override
  String toString() {
    return 'SearchState(keyword: $keyword, results: $results, isLoading: $isLoading, searchedCount: $searchedCount, totalCount: $totalCount, error: $error, failedSources: $failedSources, selectedSourceUrls: $selectedSourceUrls, selectedGroups: $selectedGroups, searchHistory: $searchHistory, inputText: $inputText, searchPage: $searchPage, hasMore: $hasMore, isPaused: $isPaused, isManualStop: $isManualStop)';
  }
}

/// @nodoc
abstract mixin class _$SearchStateCopyWith<$Res>
    implements $SearchStateCopyWith<$Res> {
  factory _$SearchStateCopyWith(
    _SearchState value,
    $Res Function(_SearchState) _then,
  ) = __$SearchStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    String keyword,
    List<SearchResult> results,
    bool isLoading,
    int searchedCount,
    int totalCount,
    String? error,
    List<SearchSourceFailure> failedSources,
    Set<String> selectedSourceUrls,
    Set<String> selectedGroups,
    List<String> searchHistory,
    String inputText,
    int searchPage,
    bool hasMore,
    bool isPaused,
    bool isManualStop,
  });
}

/// @nodoc
class __$SearchStateCopyWithImpl<$Res> implements _$SearchStateCopyWith<$Res> {
  __$SearchStateCopyWithImpl(this._self, this._then);

  final _SearchState _self;
  final $Res Function(_SearchState) _then;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? keyword = null,
    Object? results = null,
    Object? isLoading = null,
    Object? searchedCount = null,
    Object? totalCount = null,
    Object? error = freezed,
    Object? failedSources = null,
    Object? selectedSourceUrls = null,
    Object? selectedGroups = null,
    Object? searchHistory = null,
    Object? inputText = null,
    Object? searchPage = null,
    Object? hasMore = null,
    Object? isPaused = null,
    Object? isManualStop = null,
  }) {
    return _then(
      _SearchState(
        keyword: null == keyword
            ? _self.keyword
            : keyword // ignore: cast_nullable_to_non_nullable
                  as String,
        results: null == results
            ? _self._results
            : results // ignore: cast_nullable_to_non_nullable
                  as List<SearchResult>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        searchedCount: null == searchedCount
            ? _self.searchedCount
            : searchedCount // ignore: cast_nullable_to_non_nullable
                  as int,
        totalCount: null == totalCount
            ? _self.totalCount
            : totalCount // ignore: cast_nullable_to_non_nullable
                  as int,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        failedSources: null == failedSources
            ? _self._failedSources
            : failedSources // ignore: cast_nullable_to_non_nullable
                  as List<SearchSourceFailure>,
        selectedSourceUrls: null == selectedSourceUrls
            ? _self._selectedSourceUrls
            : selectedSourceUrls // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        selectedGroups: null == selectedGroups
            ? _self._selectedGroups
            : selectedGroups // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        searchHistory: null == searchHistory
            ? _self._searchHistory
            : searchHistory // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        inputText: null == inputText
            ? _self.inputText
            : inputText // ignore: cast_nullable_to_non_nullable
                  as String,
        searchPage: null == searchPage
            ? _self.searchPage
            : searchPage // ignore: cast_nullable_to_non_nullable
                  as int,
        hasMore: null == hasMore
            ? _self.hasMore
            : hasMore // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPaused: null == isPaused
            ? _self.isPaused
            : isPaused // ignore: cast_nullable_to_non_nullable
                  as bool,
        isManualStop: null == isManualStop
            ? _self.isManualStop
            : isManualStop // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}
