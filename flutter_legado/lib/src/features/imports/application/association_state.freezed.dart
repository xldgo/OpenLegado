// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'association_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AssociationState {
  /// 导入类型（由内容自动识别或深度链接指定）
  ImportType get type;

  /// 内容地址输入
  String get urlInput;

  /// 正在加载
  bool get isLoading;

  /// 错误消息（null = 无错误）
  String? get error;

  /// 解析出的导入条目
  List<AssociationItem> get items;

  /// 最近一次导入结果
  ImportResult? get lastResult;

  /// Create a copy of AssociationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AssociationStateCopyWith<AssociationState> get copyWith =>
      _$AssociationStateCopyWithImpl<AssociationState>(
        this as AssociationState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as AssociationState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AssociationState &&
            (identical(other.type, _this.type) || other.type == _this.type) &&
            (identical(other.urlInput, _this.urlInput) ||
                other.urlInput == _this.urlInput) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            const DeepCollectionEquality().equals(other.items, _this.items) &&
            (identical(other.lastResult, _this.lastResult) ||
                other.lastResult == _this.lastResult));
  }

  @override
  int get hashCode {
    final _this = this as AssociationState;
    return Object.hash(
      runtimeType,
      _this.type,
      _this.urlInput,
      _this.isLoading,
      _this.error,
      const DeepCollectionEquality().hash(_this.items),
      _this.lastResult,
    );
  }

  @override
  String toString() {
    final _this = this as AssociationState;
    return 'AssociationState(type: ${_this.type}, urlInput: ${_this.urlInput}, isLoading: ${_this.isLoading}, error: ${_this.error}, items: ${_this.items}, lastResult: ${_this.lastResult})';
  }
}

/// @nodoc
abstract mixin class $AssociationStateCopyWith<$Res> {
  factory $AssociationStateCopyWith(
    AssociationState value,
    $Res Function(AssociationState) _then,
  ) = _$AssociationStateCopyWithImpl;
  @useResult
  $Res call({
    ImportType type,
    String urlInput,
    bool isLoading,
    String? error,
    List<AssociationItem> items,
    ImportResult? lastResult,
  });
}

/// @nodoc
class _$AssociationStateCopyWithImpl<$Res>
    implements $AssociationStateCopyWith<$Res> {
  _$AssociationStateCopyWithImpl(this._self, this._then);

  final AssociationState _self;
  final $Res Function(AssociationState) _then;

  /// Create a copy of AssociationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? urlInput = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? items = null,
    Object? lastResult = freezed,
  }) {
    return _then(
      AssociationState(
        type: null == type
            ? _self.type
            : type // ignore: cast_nullable_to_non_nullable
                  as ImportType,
        urlInput: null == urlInput
            ? _self.urlInput
            : urlInput // ignore: cast_nullable_to_non_nullable
                  as String,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        items: null == items
            ? _self.items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<AssociationItem>,
        lastResult: freezed == lastResult
            ? _self.lastResult
            : lastResult // ignore: cast_nullable_to_non_nullable
                  as ImportResult?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [AssociationState].
extension AssociationStatePatterns on AssociationState {
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
    TResult Function(_AssociationState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AssociationState() when $default != null:
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
    TResult Function(_AssociationState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssociationState():
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
    TResult? Function(_AssociationState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssociationState() when $default != null:
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
      ImportType type,
      String urlInput,
      bool isLoading,
      String? error,
      List<AssociationItem> items,
      ImportResult? lastResult,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AssociationState() when $default != null:
        return $default(
          _that.type,
          _that.urlInput,
          _that.isLoading,
          _that.error,
          _that.items,
          _that.lastResult,
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
      ImportType type,
      String urlInput,
      bool isLoading,
      String? error,
      List<AssociationItem> items,
      ImportResult? lastResult,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssociationState():
        return $default(
          _that.type,
          _that.urlInput,
          _that.isLoading,
          _that.error,
          _that.items,
          _that.lastResult,
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
      ImportType type,
      String urlInput,
      bool isLoading,
      String? error,
      List<AssociationItem> items,
      ImportResult? lastResult,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssociationState() when $default != null:
        return $default(
          _that.type,
          _that.urlInput,
          _that.isLoading,
          _that.error,
          _that.items,
          _that.lastResult,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AssociationState implements AssociationState {
  const _AssociationState({
    this.type = ImportType.bookSource,
    this.urlInput = '',
    this.isLoading = false,
    this.error,
    List<AssociationItem> items = const [],
    this.lastResult,
  }) : _items = items;

  /// 导入类型（由内容自动识别或深度链接指定）
  @override
  @JsonKey()
  final ImportType type;

  /// 内容地址输入
  @override
  @JsonKey()
  final String urlInput;

  /// 正在加载
  @override
  @JsonKey()
  final bool isLoading;

  /// 错误消息（null = 无错误）
  @override
  final String? error;

  /// 解析出的导入条目
  final List<AssociationItem> _items;

  /// 解析出的导入条目
  @override
  @JsonKey()
  List<AssociationItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  /// 最近一次导入结果
  @override
  final ImportResult? lastResult;

  /// Create a copy of AssociationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AssociationStateCopyWith<_AssociationState> get copyWith =>
      __$AssociationStateCopyWithImpl<_AssociationState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AssociationState &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.urlInput, urlInput) ||
                other.urlInput == urlInput) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error) &&
            const DeepCollectionEquality().equals(other.items, _items) &&
            (identical(other.lastResult, lastResult) ||
                other.lastResult == lastResult));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      type,
      urlInput,
      isLoading,
      error,
      const DeepCollectionEquality().hash(_items),
      lastResult,
    );
  }

  @override
  String toString() {
    return 'AssociationState(type: $type, urlInput: $urlInput, isLoading: $isLoading, error: $error, items: $items, lastResult: $lastResult)';
  }
}

/// @nodoc
abstract mixin class _$AssociationStateCopyWith<$Res>
    implements $AssociationStateCopyWith<$Res> {
  factory _$AssociationStateCopyWith(
    _AssociationState value,
    $Res Function(_AssociationState) _then,
  ) = __$AssociationStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    ImportType type,
    String urlInput,
    bool isLoading,
    String? error,
    List<AssociationItem> items,
    ImportResult? lastResult,
  });
}

/// @nodoc
class __$AssociationStateCopyWithImpl<$Res>
    implements _$AssociationStateCopyWith<$Res> {
  __$AssociationStateCopyWithImpl(this._self, this._then);

  final _AssociationState _self;
  final $Res Function(_AssociationState) _then;

  /// Create a copy of AssociationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? type = null,
    Object? urlInput = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? items = null,
    Object? lastResult = freezed,
  }) {
    return _then(
      _AssociationState(
        type: null == type
            ? _self.type
            : type // ignore: cast_nullable_to_non_nullable
                  as ImportType,
        urlInput: null == urlInput
            ? _self.urlInput
            : urlInput // ignore: cast_nullable_to_non_nullable
                  as String,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        items: null == items
            ? _self._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<AssociationItem>,
        lastResult: freezed == lastResult
            ? _self.lastResult
            : lastResult // ignore: cast_nullable_to_non_nullable
                  as ImportResult?,
      ),
    );
  }
}
