// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bookshelf_manage_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookshelfManageState {
  /// 书架书籍列表
  List<Book> get books;

  /// 已勾选书籍的 bookUrl 集合
  Set<String> get selectedUrls;

  /// 正在加载
  bool get isLoading;

  /// 正在执行批量操作
  bool get isBusy;

  /// 错误信息
  String? get error;

  /// Create a copy of BookshelfManageState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookshelfManageStateCopyWith<BookshelfManageState> get copyWith =>
      _$BookshelfManageStateCopyWithImpl<BookshelfManageState>(
        this as BookshelfManageState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as BookshelfManageState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookshelfManageState &&
            const DeepCollectionEquality().equals(other.books, _this.books) &&
            const DeepCollectionEquality().equals(
              other.selectedUrls,
              _this.selectedUrls,
            ) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.isBusy, _this.isBusy) ||
                other.isBusy == _this.isBusy) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as BookshelfManageState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.books),
      const DeepCollectionEquality().hash(_this.selectedUrls),
      _this.isLoading,
      _this.isBusy,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as BookshelfManageState;
    return 'BookshelfManageState(books: ${_this.books}, selectedUrls: ${_this.selectedUrls}, isLoading: ${_this.isLoading}, isBusy: ${_this.isBusy}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $BookshelfManageStateCopyWith<$Res> {
  factory $BookshelfManageStateCopyWith(
    BookshelfManageState value,
    $Res Function(BookshelfManageState) _then,
  ) = _$BookshelfManageStateCopyWithImpl;
  @useResult
  $Res call({
    List<Book> books,
    Set<String> selectedUrls,
    bool isLoading,
    bool isBusy,
    String? error,
  });
}

/// @nodoc
class _$BookshelfManageStateCopyWithImpl<$Res>
    implements $BookshelfManageStateCopyWith<$Res> {
  _$BookshelfManageStateCopyWithImpl(this._self, this._then);

  final BookshelfManageState _self;
  final $Res Function(BookshelfManageState) _then;

  /// Create a copy of BookshelfManageState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? books = null,
    Object? selectedUrls = null,
    Object? isLoading = null,
    Object? isBusy = null,
    Object? error = freezed,
  }) {
    return _then(
      BookshelfManageState(
        books: null == books
            ? _self.books
            : books // ignore: cast_nullable_to_non_nullable
                  as List<Book>,
        selectedUrls: null == selectedUrls
            ? _self.selectedUrls
            : selectedUrls // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        isBusy: null == isBusy
            ? _self.isBusy
            : isBusy // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BookshelfManageState].
extension BookshelfManageStatePatterns on BookshelfManageState {
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
    TResult Function(_BookshelfManageState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookshelfManageState() when $default != null:
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
    TResult Function(_BookshelfManageState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookshelfManageState():
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
    TResult? Function(_BookshelfManageState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookshelfManageState() when $default != null:
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
      List<Book> books,
      Set<String> selectedUrls,
      bool isLoading,
      bool isBusy,
      String? error,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookshelfManageState() when $default != null:
        return $default(
          _that.books,
          _that.selectedUrls,
          _that.isLoading,
          _that.isBusy,
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
      List<Book> books,
      Set<String> selectedUrls,
      bool isLoading,
      bool isBusy,
      String? error,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookshelfManageState():
        return $default(
          _that.books,
          _that.selectedUrls,
          _that.isLoading,
          _that.isBusy,
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
      List<Book> books,
      Set<String> selectedUrls,
      bool isLoading,
      bool isBusy,
      String? error,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookshelfManageState() when $default != null:
        return $default(
          _that.books,
          _that.selectedUrls,
          _that.isLoading,
          _that.isBusy,
          _that.error,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _BookshelfManageState implements BookshelfManageState {
  const _BookshelfManageState({
    List<Book> books = const [],
    Set<String> selectedUrls = const {},
    this.isLoading = false,
    this.isBusy = false,
    this.error,
  }) : _books = books,
       _selectedUrls = selectedUrls;

  /// 书架书籍列表
  final List<Book> _books;

  /// 书架书籍列表
  @override
  @JsonKey()
  List<Book> get books {
    if (_books is EqualUnmodifiableListView) return _books;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_books);
  }

  /// 已勾选书籍的 bookUrl 集合
  final Set<String> _selectedUrls;

  /// 已勾选书籍的 bookUrl 集合
  @override
  @JsonKey()
  Set<String> get selectedUrls {
    if (_selectedUrls is EqualUnmodifiableSetView) return _selectedUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedUrls);
  }

  /// 正在加载
  @override
  @JsonKey()
  final bool isLoading;

  /// 正在执行批量操作
  @override
  @JsonKey()
  final bool isBusy;

  /// 错误信息
  @override
  final String? error;

  /// Create a copy of BookshelfManageState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookshelfManageStateCopyWith<_BookshelfManageState> get copyWith =>
      __$BookshelfManageStateCopyWithImpl<_BookshelfManageState>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookshelfManageState &&
            const DeepCollectionEquality().equals(other.books, _books) &&
            const DeepCollectionEquality().equals(
              other.selectedUrls,
              _selectedUrls,
            ) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isBusy, isBusy) || other.isBusy == isBusy) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_books),
      const DeepCollectionEquality().hash(_selectedUrls),
      isLoading,
      isBusy,
      error,
    );
  }

  @override
  String toString() {
    return 'BookshelfManageState(books: $books, selectedUrls: $selectedUrls, isLoading: $isLoading, isBusy: $isBusy, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$BookshelfManageStateCopyWith<$Res>
    implements $BookshelfManageStateCopyWith<$Res> {
  factory _$BookshelfManageStateCopyWith(
    _BookshelfManageState value,
    $Res Function(_BookshelfManageState) _then,
  ) = __$BookshelfManageStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    List<Book> books,
    Set<String> selectedUrls,
    bool isLoading,
    bool isBusy,
    String? error,
  });
}

/// @nodoc
class __$BookshelfManageStateCopyWithImpl<$Res>
    implements _$BookshelfManageStateCopyWith<$Res> {
  __$BookshelfManageStateCopyWithImpl(this._self, this._then);

  final _BookshelfManageState _self;
  final $Res Function(_BookshelfManageState) _then;

  /// Create a copy of BookshelfManageState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? books = null,
    Object? selectedUrls = null,
    Object? isLoading = null,
    Object? isBusy = null,
    Object? error = freezed,
  }) {
    return _then(
      _BookshelfManageState(
        books: null == books
            ? _self._books
            : books // ignore: cast_nullable_to_non_nullable
                  as List<Book>,
        selectedUrls: null == selectedUrls
            ? _self._selectedUrls
            : selectedUrls // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        isBusy: null == isBusy
            ? _self.isBusy
            : isBusy // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
