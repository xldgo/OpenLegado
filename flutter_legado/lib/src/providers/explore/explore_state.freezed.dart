// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'explore_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExploreState {
  /// 发现书源列表（已按 Android ExploreFragment 规则过滤：enabledExplore && exploreUrl 非空）
  List<BookSource> get bookSources;

  /// 是否正在加载书源列表
  bool get isLoading;

  /// 错误信息（null 表示无错误）
  String? get error;

  /// 展示层：实时搜索关键词
  String get searchKeyword;

  /// 展示层：选中分组（空字符串表示全部）
  String get selectedGroup;

  /// 分类缓存：sourceUrl → 解析出的分类列表（对齐 exploreParseUrl）
  Map<String, List<ExploreCategory>> get categoriesCache;

  /// 正在加载分类的书源 URL 集合
  Set<String> get loadingCategories;

  /// Create a copy of ExploreState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExploreStateCopyWith<ExploreState> get copyWith =>
      _$ExploreStateCopyWithImpl<ExploreState>(
        this as ExploreState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as ExploreState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExploreState &&
            const DeepCollectionEquality().equals(
              other.bookSources,
              _this.bookSources,
            ) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            (identical(other.searchKeyword, _this.searchKeyword) ||
                other.searchKeyword == _this.searchKeyword) &&
            (identical(other.selectedGroup, _this.selectedGroup) ||
                other.selectedGroup == _this.selectedGroup) &&
            const DeepCollectionEquality().equals(
              other.categoriesCache,
              _this.categoriesCache,
            ) &&
            const DeepCollectionEquality().equals(
              other.loadingCategories,
              _this.loadingCategories,
            ));
  }

  @override
  int get hashCode {
    final _this = this as ExploreState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.bookSources),
      _this.isLoading,
      _this.error,
      _this.searchKeyword,
      _this.selectedGroup,
      const DeepCollectionEquality().hash(_this.categoriesCache),
      const DeepCollectionEquality().hash(_this.loadingCategories),
    );
  }

  @override
  String toString() {
    final _this = this as ExploreState;
    return 'ExploreState(bookSources: ${_this.bookSources}, isLoading: ${_this.isLoading}, error: ${_this.error}, searchKeyword: ${_this.searchKeyword}, selectedGroup: ${_this.selectedGroup}, categoriesCache: ${_this.categoriesCache}, loadingCategories: ${_this.loadingCategories})';
  }
}

/// @nodoc
abstract mixin class $ExploreStateCopyWith<$Res> {
  factory $ExploreStateCopyWith(
    ExploreState value,
    $Res Function(ExploreState) _then,
  ) = _$ExploreStateCopyWithImpl;
  @useResult
  $Res call({
    List<BookSource> bookSources,
    bool isLoading,
    String? error,
    String searchKeyword,
    String selectedGroup,
    Map<String, List<ExploreCategory>> categoriesCache,
    Set<String> loadingCategories,
  });
}

/// @nodoc
class _$ExploreStateCopyWithImpl<$Res> implements $ExploreStateCopyWith<$Res> {
  _$ExploreStateCopyWithImpl(this._self, this._then);

  final ExploreState _self;
  final $Res Function(ExploreState) _then;

  /// Create a copy of ExploreState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookSources = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? searchKeyword = null,
    Object? selectedGroup = null,
    Object? categoriesCache = null,
    Object? loadingCategories = null,
  }) {
    return _then(
      ExploreState(
        bookSources: null == bookSources
            ? _self.bookSources
            : bookSources // ignore: cast_nullable_to_non_nullable
                  as List<BookSource>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        searchKeyword: null == searchKeyword
            ? _self.searchKeyword
            : searchKeyword // ignore: cast_nullable_to_non_nullable
                  as String,
        selectedGroup: null == selectedGroup
            ? _self.selectedGroup
            : selectedGroup // ignore: cast_nullable_to_non_nullable
                  as String,
        categoriesCache: null == categoriesCache
            ? _self.categoriesCache
            : categoriesCache // ignore: cast_nullable_to_non_nullable
                  as Map<String, List<ExploreCategory>>,
        loadingCategories: null == loadingCategories
            ? _self.loadingCategories
            : loadingCategories // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ExploreState].
extension ExploreStatePatterns on ExploreState {
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
    TResult Function(_ExploreState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExploreState() when $default != null:
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
    TResult Function(_ExploreState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreState():
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
    TResult? Function(_ExploreState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreState() when $default != null:
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
      List<BookSource> bookSources,
      bool isLoading,
      String? error,
      String searchKeyword,
      String selectedGroup,
      Map<String, List<ExploreCategory>> categoriesCache,
      Set<String> loadingCategories,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExploreState() when $default != null:
        return $default(
          _that.bookSources,
          _that.isLoading,
          _that.error,
          _that.searchKeyword,
          _that.selectedGroup,
          _that.categoriesCache,
          _that.loadingCategories,
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
      List<BookSource> bookSources,
      bool isLoading,
      String? error,
      String searchKeyword,
      String selectedGroup,
      Map<String, List<ExploreCategory>> categoriesCache,
      Set<String> loadingCategories,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreState():
        return $default(
          _that.bookSources,
          _that.isLoading,
          _that.error,
          _that.searchKeyword,
          _that.selectedGroup,
          _that.categoriesCache,
          _that.loadingCategories,
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
      List<BookSource> bookSources,
      bool isLoading,
      String? error,
      String searchKeyword,
      String selectedGroup,
      Map<String, List<ExploreCategory>> categoriesCache,
      Set<String> loadingCategories,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreState() when $default != null:
        return $default(
          _that.bookSources,
          _that.isLoading,
          _that.error,
          _that.searchKeyword,
          _that.selectedGroup,
          _that.categoriesCache,
          _that.loadingCategories,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ExploreState implements ExploreState {
  const _ExploreState({
    List<BookSource> bookSources = const [],
    this.isLoading = false,
    this.error,
    this.searchKeyword = '',
    this.selectedGroup = '',
    Map<String, List<ExploreCategory>> categoriesCache =
        const <String, List<ExploreCategory>>{},
    Set<String> loadingCategories = const <String>{},
  }) : _bookSources = bookSources,
       _categoriesCache = categoriesCache,
       _loadingCategories = loadingCategories;

  /// 发现书源列表（已按 Android ExploreFragment 规则过滤：enabledExplore && exploreUrl 非空）
  final List<BookSource> _bookSources;

  /// 发现书源列表（已按 Android ExploreFragment 规则过滤：enabledExplore && exploreUrl 非空）
  @override
  @JsonKey()
  List<BookSource> get bookSources {
    if (_bookSources is EqualUnmodifiableListView) return _bookSources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_bookSources);
  }

  /// 是否正在加载书源列表
  @override
  @JsonKey()
  final bool isLoading;

  /// 错误信息（null 表示无错误）
  @override
  final String? error;

  /// 展示层：实时搜索关键词
  @override
  @JsonKey()
  final String searchKeyword;

  /// 展示层：选中分组（空字符串表示全部）
  @override
  @JsonKey()
  final String selectedGroup;

  /// 分类缓存：sourceUrl → 解析出的分类列表（对齐 exploreParseUrl）
  final Map<String, List<ExploreCategory>> _categoriesCache;

  /// 分类缓存：sourceUrl → 解析出的分类列表（对齐 exploreParseUrl）
  @override
  @JsonKey()
  Map<String, List<ExploreCategory>> get categoriesCache {
    if (_categoriesCache is EqualUnmodifiableMapView) return _categoriesCache;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_categoriesCache);
  }

  /// 正在加载分类的书源 URL 集合
  final Set<String> _loadingCategories;

  /// 正在加载分类的书源 URL 集合
  @override
  @JsonKey()
  Set<String> get loadingCategories {
    if (_loadingCategories is EqualUnmodifiableSetView)
      return _loadingCategories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_loadingCategories);
  }

  /// Create a copy of ExploreState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExploreStateCopyWith<_ExploreState> get copyWith =>
      __$ExploreStateCopyWithImpl<_ExploreState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExploreState &&
            const DeepCollectionEquality().equals(
              other.bookSources,
              _bookSources,
            ) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.searchKeyword, searchKeyword) ||
                other.searchKeyword == searchKeyword) &&
            (identical(other.selectedGroup, selectedGroup) ||
                other.selectedGroup == selectedGroup) &&
            const DeepCollectionEquality().equals(
              other.categoriesCache,
              _categoriesCache,
            ) &&
            const DeepCollectionEquality().equals(
              other.loadingCategories,
              _loadingCategories,
            ));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_bookSources),
      isLoading,
      error,
      searchKeyword,
      selectedGroup,
      const DeepCollectionEquality().hash(_categoriesCache),
      const DeepCollectionEquality().hash(_loadingCategories),
    );
  }

  @override
  String toString() {
    return 'ExploreState(bookSources: $bookSources, isLoading: $isLoading, error: $error, searchKeyword: $searchKeyword, selectedGroup: $selectedGroup, categoriesCache: $categoriesCache, loadingCategories: $loadingCategories)';
  }
}

/// @nodoc
abstract mixin class _$ExploreStateCopyWith<$Res>
    implements $ExploreStateCopyWith<$Res> {
  factory _$ExploreStateCopyWith(
    _ExploreState value,
    $Res Function(_ExploreState) _then,
  ) = __$ExploreStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    List<BookSource> bookSources,
    bool isLoading,
    String? error,
    String searchKeyword,
    String selectedGroup,
    Map<String, List<ExploreCategory>> categoriesCache,
    Set<String> loadingCategories,
  });
}

/// @nodoc
class __$ExploreStateCopyWithImpl<$Res>
    implements _$ExploreStateCopyWith<$Res> {
  __$ExploreStateCopyWithImpl(this._self, this._then);

  final _ExploreState _self;
  final $Res Function(_ExploreState) _then;

  /// Create a copy of ExploreState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookSources = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? searchKeyword = null,
    Object? selectedGroup = null,
    Object? categoriesCache = null,
    Object? loadingCategories = null,
  }) {
    return _then(
      _ExploreState(
        bookSources: null == bookSources
            ? _self._bookSources
            : bookSources // ignore: cast_nullable_to_non_nullable
                  as List<BookSource>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        searchKeyword: null == searchKeyword
            ? _self.searchKeyword
            : searchKeyword // ignore: cast_nullable_to_non_nullable
                  as String,
        selectedGroup: null == selectedGroup
            ? _self.selectedGroup
            : selectedGroup // ignore: cast_nullable_to_non_nullable
                  as String,
        categoriesCache: null == categoriesCache
            ? _self._categoriesCache
            : categoriesCache // ignore: cast_nullable_to_non_nullable
                  as Map<String, List<ExploreCategory>>,
        loadingCategories: null == loadingCategories
            ? _self._loadingCategories
            : loadingCategories // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
      ),
    );
  }
}
