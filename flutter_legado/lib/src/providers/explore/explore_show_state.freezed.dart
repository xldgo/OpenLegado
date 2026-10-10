// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'explore_show_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExploreShowState {
  /// 当前书源
  BookSource? get source;

  /// 分类名称（用于标题显示）
  String get categoryName;

  /// 分类 URL
  String get categoryUrl;

  /// 已加载的书籍列表（累积去重）
  List<SearchBook> get books;

  /// 下一待抓取页码（对标 Android ExplorePaginationState.nextPage）
  int get page;

  /// 当前展示页码（对标 Android pageLiveData，0 表示尚未完成首次加载）
  int get displayPage;

  /// 是否正在加载
  bool get isLoading;

  /// 是否还有更多数据
  bool get hasMore;

  /// 错误信息
  String? get error;

  /// Create a copy of ExploreShowState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExploreShowStateCopyWith<ExploreShowState> get copyWith =>
      _$ExploreShowStateCopyWithImpl<ExploreShowState>(
        this as ExploreShowState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as ExploreShowState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExploreShowState &&
            (identical(other.source, _this.source) ||
                other.source == _this.source) &&
            (identical(other.categoryName, _this.categoryName) ||
                other.categoryName == _this.categoryName) &&
            (identical(other.categoryUrl, _this.categoryUrl) ||
                other.categoryUrl == _this.categoryUrl) &&
            const DeepCollectionEquality().equals(other.books, _this.books) &&
            (identical(other.page, _this.page) || other.page == _this.page) &&
            (identical(other.displayPage, _this.displayPage) ||
                other.displayPage == _this.displayPage) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.hasMore, _this.hasMore) ||
                other.hasMore == _this.hasMore) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as ExploreShowState;
    return Object.hash(
      runtimeType,
      _this.source,
      _this.categoryName,
      _this.categoryUrl,
      const DeepCollectionEquality().hash(_this.books),
      _this.page,
      _this.displayPage,
      _this.isLoading,
      _this.hasMore,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as ExploreShowState;
    return 'ExploreShowState(source: ${_this.source}, categoryName: ${_this.categoryName}, categoryUrl: ${_this.categoryUrl}, books: ${_this.books}, page: ${_this.page}, displayPage: ${_this.displayPage}, isLoading: ${_this.isLoading}, hasMore: ${_this.hasMore}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $ExploreShowStateCopyWith<$Res> {
  factory $ExploreShowStateCopyWith(
    ExploreShowState value,
    $Res Function(ExploreShowState) _then,
  ) = _$ExploreShowStateCopyWithImpl;
  @useResult
  $Res call({
    BookSource? source,
    String categoryName,
    String categoryUrl,
    List<SearchBook> books,
    int page,
    int displayPage,
    bool isLoading,
    bool hasMore,
    String? error,
  });

  $BookSourceCopyWith<$Res>? get source;
}

/// @nodoc
class _$ExploreShowStateCopyWithImpl<$Res>
    implements $ExploreShowStateCopyWith<$Res> {
  _$ExploreShowStateCopyWithImpl(this._self, this._then);

  final ExploreShowState _self;
  final $Res Function(ExploreShowState) _then;

  /// Create a copy of ExploreShowState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? source = freezed,
    Object? categoryName = null,
    Object? categoryUrl = null,
    Object? books = null,
    Object? page = null,
    Object? displayPage = null,
    Object? isLoading = null,
    Object? hasMore = null,
    Object? error = freezed,
  }) {
    return _then(
      ExploreShowState(
        source: freezed == source
            ? _self.source
            : source // ignore: cast_nullable_to_non_nullable
                  as BookSource?,
        categoryName: null == categoryName
            ? _self.categoryName
            : categoryName // ignore: cast_nullable_to_non_nullable
                  as String,
        categoryUrl: null == categoryUrl
            ? _self.categoryUrl
            : categoryUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        books: null == books
            ? _self.books
            : books // ignore: cast_nullable_to_non_nullable
                  as List<SearchBook>,
        page: null == page
            ? _self.page
            : page // ignore: cast_nullable_to_non_nullable
                  as int,
        displayPage: null == displayPage
            ? _self.displayPage
            : displayPage // ignore: cast_nullable_to_non_nullable
                  as int,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasMore: null == hasMore
            ? _self.hasMore
            : hasMore // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }

  /// Create a copy of ExploreShowState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BookSourceCopyWith<$Res>? get source {
    if (_self.source == null) {
      return null;
    }

    return $BookSourceCopyWith<$Res>(_self.source!, (value) {
      return _then(_self.copyWith(source: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ExploreShowState].
extension ExploreShowStatePatterns on ExploreShowState {
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
    TResult Function(_ExploreShowState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExploreShowState() when $default != null:
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
    TResult Function(_ExploreShowState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreShowState():
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
    TResult? Function(_ExploreShowState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreShowState() when $default != null:
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
      BookSource? source,
      String categoryName,
      String categoryUrl,
      List<SearchBook> books,
      int page,
      int displayPage,
      bool isLoading,
      bool hasMore,
      String? error,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExploreShowState() when $default != null:
        return $default(
          _that.source,
          _that.categoryName,
          _that.categoryUrl,
          _that.books,
          _that.page,
          _that.displayPage,
          _that.isLoading,
          _that.hasMore,
          _that.error,
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
      BookSource? source,
      String categoryName,
      String categoryUrl,
      List<SearchBook> books,
      int page,
      int displayPage,
      bool isLoading,
      bool hasMore,
      String? error,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreShowState():
        return $default(
          _that.source,
          _that.categoryName,
          _that.categoryUrl,
          _that.books,
          _that.page,
          _that.displayPage,
          _that.isLoading,
          _that.hasMore,
          _that.error,
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
      BookSource? source,
      String categoryName,
      String categoryUrl,
      List<SearchBook> books,
      int page,
      int displayPage,
      bool isLoading,
      bool hasMore,
      String? error,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreShowState() when $default != null:
        return $default(
          _that.source,
          _that.categoryName,
          _that.categoryUrl,
          _that.books,
          _that.page,
          _that.displayPage,
          _that.isLoading,
          _that.hasMore,
          _that.error,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ExploreShowState implements ExploreShowState {
  const _ExploreShowState({
    this.source,
    this.categoryName = '',
    this.categoryUrl = '',
    List<SearchBook> books = const [],
    this.page = 1,
    this.displayPage = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  }) : _books = books;

  /// 当前书源
  @override
  final BookSource? source;

  /// 分类名称（用于标题显示）
  @override
  @JsonKey()
  final String categoryName;

  /// 分类 URL
  @override
  @JsonKey()
  final String categoryUrl;

  /// 已加载的书籍列表（累积去重）
  final List<SearchBook> _books;

  /// 已加载的书籍列表（累积去重）
  @override
  @JsonKey()
  List<SearchBook> get books {
    if (_books is EqualUnmodifiableListView) return _books;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_books);
  }

  /// 下一待抓取页码（对标 Android ExplorePaginationState.nextPage）
  @override
  @JsonKey()
  final int page;

  /// 当前展示页码（对标 Android pageLiveData，0 表示尚未完成首次加载）
  @override
  @JsonKey()
  final int displayPage;

  /// 是否正在加载
  @override
  @JsonKey()
  final bool isLoading;

  /// 是否还有更多数据
  @override
  @JsonKey()
  final bool hasMore;

  /// 错误信息
  @override
  final String? error;

  /// Create a copy of ExploreShowState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExploreShowStateCopyWith<_ExploreShowState> get copyWith =>
      __$ExploreShowStateCopyWithImpl<_ExploreShowState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExploreShowState &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.categoryUrl, categoryUrl) ||
                other.categoryUrl == categoryUrl) &&
            const DeepCollectionEquality().equals(other.books, _books) &&
            (identical(other.page, page) || other.page == page) &&
            (identical(other.displayPage, displayPage) ||
                other.displayPage == displayPage) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      source,
      categoryName,
      categoryUrl,
      const DeepCollectionEquality().hash(_books),
      page,
      displayPage,
      isLoading,
      hasMore,
      error,
    );
  }

  @override
  String toString() {
    return 'ExploreShowState(source: $source, categoryName: $categoryName, categoryUrl: $categoryUrl, books: $books, page: $page, displayPage: $displayPage, isLoading: $isLoading, hasMore: $hasMore, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$ExploreShowStateCopyWith<$Res>
    implements $ExploreShowStateCopyWith<$Res> {
  factory _$ExploreShowStateCopyWith(
    _ExploreShowState value,
    $Res Function(_ExploreShowState) _then,
  ) = __$ExploreShowStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    BookSource? source,
    String categoryName,
    String categoryUrl,
    List<SearchBook> books,
    int page,
    int displayPage,
    bool isLoading,
    bool hasMore,
    String? error,
  });

  @override
  $BookSourceCopyWith<$Res>? get source;
}

/// @nodoc
class __$ExploreShowStateCopyWithImpl<$Res>
    implements _$ExploreShowStateCopyWith<$Res> {
  __$ExploreShowStateCopyWithImpl(this._self, this._then);

  final _ExploreShowState _self;
  final $Res Function(_ExploreShowState) _then;

  /// Create a copy of ExploreShowState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? source = freezed,
    Object? categoryName = null,
    Object? categoryUrl = null,
    Object? books = null,
    Object? page = null,
    Object? displayPage = null,
    Object? isLoading = null,
    Object? hasMore = null,
    Object? error = freezed,
  }) {
    return _then(
      _ExploreShowState(
        source: freezed == source
            ? _self.source
            : source // ignore: cast_nullable_to_non_nullable
                  as BookSource?,
        categoryName: null == categoryName
            ? _self.categoryName
            : categoryName // ignore: cast_nullable_to_non_nullable
                  as String,
        categoryUrl: null == categoryUrl
            ? _self.categoryUrl
            : categoryUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        books: null == books
            ? _self._books
            : books // ignore: cast_nullable_to_non_nullable
                  as List<SearchBook>,
        page: null == page
            ? _self.page
            : page // ignore: cast_nullable_to_non_nullable
                  as int,
        displayPage: null == displayPage
            ? _self.displayPage
            : displayPage // ignore: cast_nullable_to_non_nullable
                  as int,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasMore: null == hasMore
            ? _self.hasMore
            : hasMore // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }

  /// Create a copy of ExploreShowState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BookSourceCopyWith<$Res>? get source {
    if (_self.source == null) {
      return null;
    }

    return $BookSourceCopyWith<$Res>(_self.source!, (value) {
      return _then(_self.copyWith(source: value));
    });
  }
}
