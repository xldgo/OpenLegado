// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bookmark_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookmarkState {
  /// 书签列表
  List<Bookmark> get bookmarks;

  /// 是否正在加载
  bool get isLoading;

  /// 错误信息（null 表示无错误）
  String? get error;

  /// Create a copy of BookmarkState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookmarkStateCopyWith<BookmarkState> get copyWith =>
      _$BookmarkStateCopyWithImpl<BookmarkState>(
        this as BookmarkState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as BookmarkState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookmarkState &&
            const DeepCollectionEquality().equals(
              other.bookmarks,
              _this.bookmarks,
            ) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as BookmarkState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.bookmarks),
      _this.isLoading,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as BookmarkState;
    return 'BookmarkState(bookmarks: ${_this.bookmarks}, isLoading: ${_this.isLoading}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $BookmarkStateCopyWith<$Res> {
  factory $BookmarkStateCopyWith(
    BookmarkState value,
    $Res Function(BookmarkState) _then,
  ) = _$BookmarkStateCopyWithImpl;
  @useResult
  $Res call({List<Bookmark> bookmarks, bool isLoading, String? error});
}

/// @nodoc
class _$BookmarkStateCopyWithImpl<$Res>
    implements $BookmarkStateCopyWith<$Res> {
  _$BookmarkStateCopyWithImpl(this._self, this._then);

  final BookmarkState _self;
  final $Res Function(BookmarkState) _then;

  /// Create a copy of BookmarkState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookmarks = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      BookmarkState(
        bookmarks: null == bookmarks
            ? _self.bookmarks
            : bookmarks // ignore: cast_nullable_to_non_nullable
                  as List<Bookmark>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BookmarkState].
extension BookmarkStatePatterns on BookmarkState {
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
    TResult Function(_BookmarkState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookmarkState() when $default != null:
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
    TResult Function(_BookmarkState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookmarkState():
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
    TResult? Function(_BookmarkState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookmarkState() when $default != null:
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
    TResult Function(List<Bookmark> bookmarks, bool isLoading, String? error)?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookmarkState() when $default != null:
        return $default(_that.bookmarks, _that.isLoading, _that.error);
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
    TResult Function(List<Bookmark> bookmarks, bool isLoading, String? error)
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookmarkState():
        return $default(_that.bookmarks, _that.isLoading, _that.error);
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
    TResult? Function(List<Bookmark> bookmarks, bool isLoading, String? error)?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookmarkState() when $default != null:
        return $default(_that.bookmarks, _that.isLoading, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _BookmarkState implements BookmarkState {
  const _BookmarkState({
    List<Bookmark> bookmarks = const [],
    this.isLoading = false,
    this.error,
  }) : _bookmarks = bookmarks;

  /// 书签列表
  final List<Bookmark> _bookmarks;

  /// 书签列表
  @override
  @JsonKey()
  List<Bookmark> get bookmarks {
    if (_bookmarks is EqualUnmodifiableListView) return _bookmarks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_bookmarks);
  }

  /// 是否正在加载
  @override
  @JsonKey()
  final bool isLoading;

  /// 错误信息（null 表示无错误）
  @override
  final String? error;

  /// Create a copy of BookmarkState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookmarkStateCopyWith<_BookmarkState> get copyWith =>
      __$BookmarkStateCopyWithImpl<_BookmarkState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookmarkState &&
            const DeepCollectionEquality().equals(
              other.bookmarks,
              _bookmarks,
            ) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_bookmarks),
      isLoading,
      error,
    );
  }

  @override
  String toString() {
    return 'BookmarkState(bookmarks: $bookmarks, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$BookmarkStateCopyWith<$Res>
    implements $BookmarkStateCopyWith<$Res> {
  factory _$BookmarkStateCopyWith(
    _BookmarkState value,
    $Res Function(_BookmarkState) _then,
  ) = __$BookmarkStateCopyWithImpl;
  @override
  @useResult
  $Res call({List<Bookmark> bookmarks, bool isLoading, String? error});
}

/// @nodoc
class __$BookmarkStateCopyWithImpl<$Res>
    implements _$BookmarkStateCopyWith<$Res> {
  __$BookmarkStateCopyWithImpl(this._self, this._then);

  final _BookmarkState _self;
  final $Res Function(_BookmarkState) _then;

  /// Create a copy of BookmarkState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookmarks = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _BookmarkState(
        bookmarks: null == bookmarks
            ? _self._bookmarks
            : bookmarks // ignore: cast_nullable_to_non_nullable
                  as List<Bookmark>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
