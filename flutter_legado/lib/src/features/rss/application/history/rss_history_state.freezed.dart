// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rss_history_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RssHistoryState {
  /// 已读记录列表（按阅读时间降序）
  List<RssReadRecordRow> get records;

  /// 正在加载
  bool get isLoading;

  /// 正在清空
  bool get isClearing;

  /// 错误信息
  String? get error;

  /// Create a copy of RssHistoryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RssHistoryStateCopyWith<RssHistoryState> get copyWith =>
      _$RssHistoryStateCopyWithImpl<RssHistoryState>(
        this as RssHistoryState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as RssHistoryState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RssHistoryState &&
            const DeepCollectionEquality().equals(
              other.records,
              _this.records,
            ) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.isClearing, _this.isClearing) ||
                other.isClearing == _this.isClearing) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as RssHistoryState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.records),
      _this.isLoading,
      _this.isClearing,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as RssHistoryState;
    return 'RssHistoryState(records: ${_this.records}, isLoading: ${_this.isLoading}, isClearing: ${_this.isClearing}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $RssHistoryStateCopyWith<$Res> {
  factory $RssHistoryStateCopyWith(
    RssHistoryState value,
    $Res Function(RssHistoryState) _then,
  ) = _$RssHistoryStateCopyWithImpl;
  @useResult
  $Res call({
    List<RssReadRecordRow> records,
    bool isLoading,
    bool isClearing,
    String? error,
  });
}

/// @nodoc
class _$RssHistoryStateCopyWithImpl<$Res>
    implements $RssHistoryStateCopyWith<$Res> {
  _$RssHistoryStateCopyWithImpl(this._self, this._then);

  final RssHistoryState _self;
  final $Res Function(RssHistoryState) _then;

  /// Create a copy of RssHistoryState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? records = null,
    Object? isLoading = null,
    Object? isClearing = null,
    Object? error = freezed,
  }) {
    return _then(
      RssHistoryState(
        records: null == records
            ? _self.records
            : records // ignore: cast_nullable_to_non_nullable
                  as List<RssReadRecordRow>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        isClearing: null == isClearing
            ? _self.isClearing
            : isClearing // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [RssHistoryState].
extension RssHistoryStatePatterns on RssHistoryState {
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
    TResult Function(_RssHistoryState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssHistoryState() when $default != null:
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
    TResult Function(_RssHistoryState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssHistoryState():
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
    TResult? Function(_RssHistoryState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssHistoryState() when $default != null:
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
      List<RssReadRecordRow> records,
      bool isLoading,
      bool isClearing,
      String? error,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssHistoryState() when $default != null:
        return $default(
          _that.records,
          _that.isLoading,
          _that.isClearing,
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
      List<RssReadRecordRow> records,
      bool isLoading,
      bool isClearing,
      String? error,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssHistoryState():
        return $default(
          _that.records,
          _that.isLoading,
          _that.isClearing,
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
      List<RssReadRecordRow> records,
      bool isLoading,
      bool isClearing,
      String? error,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssHistoryState() when $default != null:
        return $default(
          _that.records,
          _that.isLoading,
          _that.isClearing,
          _that.error,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _RssHistoryState implements RssHistoryState {
  const _RssHistoryState({
    List<RssReadRecordRow> records = const [],
    this.isLoading = false,
    this.isClearing = false,
    this.error,
  }) : _records = records;

  /// 已读记录列表（按阅读时间降序）
  final List<RssReadRecordRow> _records;

  /// 已读记录列表（按阅读时间降序）
  @override
  @JsonKey()
  List<RssReadRecordRow> get records {
    if (_records is EqualUnmodifiableListView) return _records;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_records);
  }

  /// 正在加载
  @override
  @JsonKey()
  final bool isLoading;

  /// 正在清空
  @override
  @JsonKey()
  final bool isClearing;

  /// 错误信息
  @override
  final String? error;

  /// Create a copy of RssHistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RssHistoryStateCopyWith<_RssHistoryState> get copyWith =>
      __$RssHistoryStateCopyWithImpl<_RssHistoryState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RssHistoryState &&
            const DeepCollectionEquality().equals(other.records, _records) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isClearing, isClearing) ||
                other.isClearing == isClearing) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_records),
      isLoading,
      isClearing,
      error,
    );
  }

  @override
  String toString() {
    return 'RssHistoryState(records: $records, isLoading: $isLoading, isClearing: $isClearing, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$RssHistoryStateCopyWith<$Res>
    implements $RssHistoryStateCopyWith<$Res> {
  factory _$RssHistoryStateCopyWith(
    _RssHistoryState value,
    $Res Function(_RssHistoryState) _then,
  ) = __$RssHistoryStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    List<RssReadRecordRow> records,
    bool isLoading,
    bool isClearing,
    String? error,
  });
}

/// @nodoc
class __$RssHistoryStateCopyWithImpl<$Res>
    implements _$RssHistoryStateCopyWith<$Res> {
  __$RssHistoryStateCopyWithImpl(this._self, this._then);

  final _RssHistoryState _self;
  final $Res Function(_RssHistoryState) _then;

  /// Create a copy of RssHistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? records = null,
    Object? isLoading = null,
    Object? isClearing = null,
    Object? error = freezed,
  }) {
    return _then(
      _RssHistoryState(
        records: null == records
            ? _self._records
            : records // ignore: cast_nullable_to_non_nullable
                  as List<RssReadRecordRow>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        isClearing: null == isClearing
            ? _self.isClearing
            : isClearing // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
