// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rss_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RssState {
  /// 全部 RSS 源列表
  List<RssSource> get sources;

  /// 当前选中源的文章列表
  List<RssFeedArticle> get articles;

  /// 当前选中的源（null 表示未选中）
  RssSource? get selectedSource;

  /// 是否正在加载源列表
  bool get isLoadingSources;

  /// 是否正在加载文章列表
  bool get isLoadingArticles;

  /// 错误信息（null 表示无错误）
  String? get error;

  /// 当前选中的分组筛选；null 表示「全部」
  String? get selectedGroup;

  /// Create a copy of RssState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RssStateCopyWith<RssState> get copyWith =>
      _$RssStateCopyWithImpl<RssState>(this as RssState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as RssState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RssState &&
            const DeepCollectionEquality().equals(
              other.sources,
              _this.sources,
            ) &&
            const DeepCollectionEquality().equals(
              other.articles,
              _this.articles,
            ) &&
            (identical(other.selectedSource, _this.selectedSource) ||
                other.selectedSource == _this.selectedSource) &&
            (identical(other.isLoadingSources, _this.isLoadingSources) ||
                other.isLoadingSources == _this.isLoadingSources) &&
            (identical(other.isLoadingArticles, _this.isLoadingArticles) ||
                other.isLoadingArticles == _this.isLoadingArticles) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            (identical(other.selectedGroup, _this.selectedGroup) ||
                other.selectedGroup == _this.selectedGroup));
  }

  @override
  int get hashCode {
    final _this = this as RssState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.sources),
      const DeepCollectionEquality().hash(_this.articles),
      _this.selectedSource,
      _this.isLoadingSources,
      _this.isLoadingArticles,
      _this.error,
      _this.selectedGroup,
    );
  }

  @override
  String toString() {
    final _this = this as RssState;
    return 'RssState(sources: ${_this.sources}, articles: ${_this.articles}, selectedSource: ${_this.selectedSource}, isLoadingSources: ${_this.isLoadingSources}, isLoadingArticles: ${_this.isLoadingArticles}, error: ${_this.error}, selectedGroup: ${_this.selectedGroup})';
  }
}

/// @nodoc
abstract mixin class $RssStateCopyWith<$Res> {
  factory $RssStateCopyWith(RssState value, $Res Function(RssState) _then) =
      _$RssStateCopyWithImpl;
  @useResult
  $Res call({
    List<RssSource> sources,
    List<RssFeedArticle> articles,
    RssSource? selectedSource,
    bool isLoadingSources,
    bool isLoadingArticles,
    String? error,
    String? selectedGroup,
  });

  $RssSourceCopyWith<$Res>? get selectedSource;
}

/// @nodoc
class _$RssStateCopyWithImpl<$Res> implements $RssStateCopyWith<$Res> {
  _$RssStateCopyWithImpl(this._self, this._then);

  final RssState _self;
  final $Res Function(RssState) _then;

  /// Create a copy of RssState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sources = null,
    Object? articles = null,
    Object? selectedSource = freezed,
    Object? isLoadingSources = null,
    Object? isLoadingArticles = null,
    Object? error = freezed,
    Object? selectedGroup = freezed,
  }) {
    return _then(
      RssState(
        sources: null == sources
            ? _self.sources
            : sources // ignore: cast_nullable_to_non_nullable
                  as List<RssSource>,
        articles: null == articles
            ? _self.articles
            : articles // ignore: cast_nullable_to_non_nullable
                  as List<RssFeedArticle>,
        selectedSource: freezed == selectedSource
            ? _self.selectedSource
            : selectedSource // ignore: cast_nullable_to_non_nullable
                  as RssSource?,
        isLoadingSources: null == isLoadingSources
            ? _self.isLoadingSources
            : isLoadingSources // ignore: cast_nullable_to_non_nullable
                  as bool,
        isLoadingArticles: null == isLoadingArticles
            ? _self.isLoadingArticles
            : isLoadingArticles // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        selectedGroup: freezed == selectedGroup
            ? _self.selectedGroup
            : selectedGroup // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }

  /// Create a copy of RssState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RssSourceCopyWith<$Res>? get selectedSource {
    if (_self.selectedSource == null) {
      return null;
    }

    return $RssSourceCopyWith<$Res>(_self.selectedSource!, (value) {
      return _then(_self.copyWith(selectedSource: value));
    });
  }
}

/// Adds pattern-matching-related methods to [RssState].
extension RssStatePatterns on RssState {
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
    TResult Function(_RssState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssState() when $default != null:
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
    TResult Function(_RssState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssState():
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
    TResult? Function(_RssState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssState() when $default != null:
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
      List<RssSource> sources,
      List<RssFeedArticle> articles,
      RssSource? selectedSource,
      bool isLoadingSources,
      bool isLoadingArticles,
      String? error,
      String? selectedGroup,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssState() when $default != null:
        return $default(
          _that.sources,
          _that.articles,
          _that.selectedSource,
          _that.isLoadingSources,
          _that.isLoadingArticles,
          _that.error,
          _that.selectedGroup,
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
      List<RssSource> sources,
      List<RssFeedArticle> articles,
      RssSource? selectedSource,
      bool isLoadingSources,
      bool isLoadingArticles,
      String? error,
      String? selectedGroup,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssState():
        return $default(
          _that.sources,
          _that.articles,
          _that.selectedSource,
          _that.isLoadingSources,
          _that.isLoadingArticles,
          _that.error,
          _that.selectedGroup,
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
      List<RssSource> sources,
      List<RssFeedArticle> articles,
      RssSource? selectedSource,
      bool isLoadingSources,
      bool isLoadingArticles,
      String? error,
      String? selectedGroup,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssState() when $default != null:
        return $default(
          _that.sources,
          _that.articles,
          _that.selectedSource,
          _that.isLoadingSources,
          _that.isLoadingArticles,
          _that.error,
          _that.selectedGroup,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _RssState implements RssState {
  const _RssState({
    List<RssSource> sources = const [],
    List<RssFeedArticle> articles = const [],
    this.selectedSource,
    this.isLoadingSources = false,
    this.isLoadingArticles = false,
    this.error,
    this.selectedGroup,
  }) : _sources = sources,
       _articles = articles;

  /// 全部 RSS 源列表
  final List<RssSource> _sources;

  /// 全部 RSS 源列表
  @override
  @JsonKey()
  List<RssSource> get sources {
    if (_sources is EqualUnmodifiableListView) return _sources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sources);
  }

  /// 当前选中源的文章列表
  final List<RssFeedArticle> _articles;

  /// 当前选中源的文章列表
  @override
  @JsonKey()
  List<RssFeedArticle> get articles {
    if (_articles is EqualUnmodifiableListView) return _articles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_articles);
  }

  /// 当前选中的源（null 表示未选中）
  @override
  final RssSource? selectedSource;

  /// 是否正在加载源列表
  @override
  @JsonKey()
  final bool isLoadingSources;

  /// 是否正在加载文章列表
  @override
  @JsonKey()
  final bool isLoadingArticles;

  /// 错误信息（null 表示无错误）
  @override
  final String? error;

  /// 当前选中的分组筛选；null 表示「全部」
  @override
  final String? selectedGroup;

  /// Create a copy of RssState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RssStateCopyWith<_RssState> get copyWith =>
      __$RssStateCopyWithImpl<_RssState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RssState &&
            const DeepCollectionEquality().equals(other.sources, _sources) &&
            const DeepCollectionEquality().equals(other.articles, _articles) &&
            (identical(other.selectedSource, selectedSource) ||
                other.selectedSource == selectedSource) &&
            (identical(other.isLoadingSources, isLoadingSources) ||
                other.isLoadingSources == isLoadingSources) &&
            (identical(other.isLoadingArticles, isLoadingArticles) ||
                other.isLoadingArticles == isLoadingArticles) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.selectedGroup, selectedGroup) ||
                other.selectedGroup == selectedGroup));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_sources),
      const DeepCollectionEquality().hash(_articles),
      selectedSource,
      isLoadingSources,
      isLoadingArticles,
      error,
      selectedGroup,
    );
  }

  @override
  String toString() {
    return 'RssState(sources: $sources, articles: $articles, selectedSource: $selectedSource, isLoadingSources: $isLoadingSources, isLoadingArticles: $isLoadingArticles, error: $error, selectedGroup: $selectedGroup)';
  }
}

/// @nodoc
abstract mixin class _$RssStateCopyWith<$Res>
    implements $RssStateCopyWith<$Res> {
  factory _$RssStateCopyWith(_RssState value, $Res Function(_RssState) _then) =
      __$RssStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    List<RssSource> sources,
    List<RssFeedArticle> articles,
    RssSource? selectedSource,
    bool isLoadingSources,
    bool isLoadingArticles,
    String? error,
    String? selectedGroup,
  });

  @override
  $RssSourceCopyWith<$Res>? get selectedSource;
}

/// @nodoc
class __$RssStateCopyWithImpl<$Res> implements _$RssStateCopyWith<$Res> {
  __$RssStateCopyWithImpl(this._self, this._then);

  final _RssState _self;
  final $Res Function(_RssState) _then;

  /// Create a copy of RssState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sources = null,
    Object? articles = null,
    Object? selectedSource = freezed,
    Object? isLoadingSources = null,
    Object? isLoadingArticles = null,
    Object? error = freezed,
    Object? selectedGroup = freezed,
  }) {
    return _then(
      _RssState(
        sources: null == sources
            ? _self._sources
            : sources // ignore: cast_nullable_to_non_nullable
                  as List<RssSource>,
        articles: null == articles
            ? _self._articles
            : articles // ignore: cast_nullable_to_non_nullable
                  as List<RssFeedArticle>,
        selectedSource: freezed == selectedSource
            ? _self.selectedSource
            : selectedSource // ignore: cast_nullable_to_non_nullable
                  as RssSource?,
        isLoadingSources: null == isLoadingSources
            ? _self.isLoadingSources
            : isLoadingSources // ignore: cast_nullable_to_non_nullable
                  as bool,
        isLoadingArticles: null == isLoadingArticles
            ? _self.isLoadingArticles
            : isLoadingArticles // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        selectedGroup: freezed == selectedGroup
            ? _self.selectedGroup
            : selectedGroup // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }

  /// Create a copy of RssState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RssSourceCopyWith<$Res>? get selectedSource {
    if (_self.selectedSource == null) {
      return null;
    }

    return $RssSourceCopyWith<$Res>(_self.selectedSource!, (value) {
      return _then(_self.copyWith(selectedSource: value));
    });
  }
}
