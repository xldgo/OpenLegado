// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auto_task_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AutoTaskState {
  /// 定时任务列表
  List<AutoTask> get tasks;

  /// 是否正在加载任务列表
  bool get isLoading;

  /// 错误信息（null 表示无错误）
  String? get error;

  /// Create a copy of AutoTaskState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AutoTaskStateCopyWith<AutoTaskState> get copyWith =>
      _$AutoTaskStateCopyWithImpl<AutoTaskState>(
        this as AutoTaskState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as AutoTaskState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AutoTaskState &&
            const DeepCollectionEquality().equals(other.tasks, _this.tasks) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as AutoTaskState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.tasks),
      _this.isLoading,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as AutoTaskState;
    return 'AutoTaskState(tasks: ${_this.tasks}, isLoading: ${_this.isLoading}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $AutoTaskStateCopyWith<$Res> {
  factory $AutoTaskStateCopyWith(
    AutoTaskState value,
    $Res Function(AutoTaskState) _then,
  ) = _$AutoTaskStateCopyWithImpl;
  @useResult
  $Res call({List<AutoTask> tasks, bool isLoading, String? error});
}

/// @nodoc
class _$AutoTaskStateCopyWithImpl<$Res>
    implements $AutoTaskStateCopyWith<$Res> {
  _$AutoTaskStateCopyWithImpl(this._self, this._then);

  final AutoTaskState _self;
  final $Res Function(AutoTaskState) _then;

  /// Create a copy of AutoTaskState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tasks = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      AutoTaskState(
        tasks: null == tasks
            ? _self.tasks
            : tasks // ignore: cast_nullable_to_non_nullable
                  as List<AutoTask>,
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

/// Adds pattern-matching-related methods to [AutoTaskState].
extension AutoTaskStatePatterns on AutoTaskState {
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
    TResult Function(_AutoTaskState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AutoTaskState() when $default != null:
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
    TResult Function(_AutoTaskState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AutoTaskState():
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
    TResult? Function(_AutoTaskState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AutoTaskState() when $default != null:
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
    TResult Function(List<AutoTask> tasks, bool isLoading, String? error)?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AutoTaskState() when $default != null:
        return $default(_that.tasks, _that.isLoading, _that.error);
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
    TResult Function(List<AutoTask> tasks, bool isLoading, String? error)
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AutoTaskState():
        return $default(_that.tasks, _that.isLoading, _that.error);
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
    TResult? Function(List<AutoTask> tasks, bool isLoading, String? error)?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AutoTaskState() when $default != null:
        return $default(_that.tasks, _that.isLoading, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AutoTaskState implements AutoTaskState {
  const _AutoTaskState({
    List<AutoTask> tasks = const [],
    this.isLoading = false,
    this.error,
  }) : _tasks = tasks;

  /// 定时任务列表
  final List<AutoTask> _tasks;

  /// 定时任务列表
  @override
  @JsonKey()
  List<AutoTask> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
  }

  /// 是否正在加载任务列表
  @override
  @JsonKey()
  final bool isLoading;

  /// 错误信息（null 表示无错误）
  @override
  final String? error;

  /// Create a copy of AutoTaskState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AutoTaskStateCopyWith<_AutoTaskState> get copyWith =>
      __$AutoTaskStateCopyWithImpl<_AutoTaskState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AutoTaskState &&
            const DeepCollectionEquality().equals(other.tasks, _tasks) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_tasks),
      isLoading,
      error,
    );
  }

  @override
  String toString() {
    return 'AutoTaskState(tasks: $tasks, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$AutoTaskStateCopyWith<$Res>
    implements $AutoTaskStateCopyWith<$Res> {
  factory _$AutoTaskStateCopyWith(
    _AutoTaskState value,
    $Res Function(_AutoTaskState) _then,
  ) = __$AutoTaskStateCopyWithImpl;
  @override
  @useResult
  $Res call({List<AutoTask> tasks, bool isLoading, String? error});
}

/// @nodoc
class __$AutoTaskStateCopyWithImpl<$Res>
    implements _$AutoTaskStateCopyWith<$Res> {
  __$AutoTaskStateCopyWithImpl(this._self, this._then);

  final _AutoTaskState _self;
  final $Res Function(_AutoTaskState) _then;

  /// Create a copy of AutoTaskState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? tasks = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _AutoTaskState(
        tasks: null == tasks
            ? _self._tasks
            : tasks // ignore: cast_nullable_to_non_nullable
                  as List<AutoTask>,
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
