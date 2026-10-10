// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'change_cover_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChangeCoverState {
  /// 网络封面候选列表
  List<CoverCandidate> get candidates;

  /// 正在搜索封面
  bool get isSearching;

  /// 错误信息
  String? get error;

  /// Create a copy of ChangeCoverState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChangeCoverStateCopyWith<ChangeCoverState> get copyWith =>
      _$ChangeCoverStateCopyWithImpl<ChangeCoverState>(
        this as ChangeCoverState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as ChangeCoverState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChangeCoverState &&
            const DeepCollectionEquality().equals(
              other.candidates,
              _this.candidates,
            ) &&
            (identical(other.isSearching, _this.isSearching) ||
                other.isSearching == _this.isSearching) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as ChangeCoverState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.candidates),
      _this.isSearching,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as ChangeCoverState;
    return 'ChangeCoverState(candidates: ${_this.candidates}, isSearching: ${_this.isSearching}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $ChangeCoverStateCopyWith<$Res> {
  factory $ChangeCoverStateCopyWith(
    ChangeCoverState value,
    $Res Function(ChangeCoverState) _then,
  ) = _$ChangeCoverStateCopyWithImpl;
  @useResult
  $Res call({List<CoverCandidate> candidates, bool isSearching, String? error});
}

/// @nodoc
class _$ChangeCoverStateCopyWithImpl<$Res>
    implements $ChangeCoverStateCopyWith<$Res> {
  _$ChangeCoverStateCopyWithImpl(this._self, this._then);

  final ChangeCoverState _self;
  final $Res Function(ChangeCoverState) _then;

  /// Create a copy of ChangeCoverState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? candidates = null,
    Object? isSearching = null,
    Object? error = freezed,
  }) {
    return _then(
      ChangeCoverState(
        candidates: null == candidates
            ? _self.candidates
            : candidates // ignore: cast_nullable_to_non_nullable
                  as List<CoverCandidate>,
        isSearching: null == isSearching
            ? _self.isSearching
            : isSearching // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ChangeCoverState].
extension ChangeCoverStatePatterns on ChangeCoverState {
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
    TResult Function(_ChangeCoverState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChangeCoverState() when $default != null:
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
    TResult Function(_ChangeCoverState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeCoverState():
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
    TResult? Function(_ChangeCoverState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeCoverState() when $default != null:
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
      List<CoverCandidate> candidates,
      bool isSearching,
      String? error,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChangeCoverState() when $default != null:
        return $default(_that.candidates, _that.isSearching, _that.error);
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
      List<CoverCandidate> candidates,
      bool isSearching,
      String? error,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeCoverState():
        return $default(_that.candidates, _that.isSearching, _that.error);
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
      List<CoverCandidate> candidates,
      bool isSearching,
      String? error,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeCoverState() when $default != null:
        return $default(_that.candidates, _that.isSearching, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ChangeCoverState implements ChangeCoverState {
  const _ChangeCoverState({
    List<CoverCandidate> candidates = const [],
    this.isSearching = false,
    this.error,
  }) : _candidates = candidates;

  /// 网络封面候选列表
  final List<CoverCandidate> _candidates;

  /// 网络封面候选列表
  @override
  @JsonKey()
  List<CoverCandidate> get candidates {
    if (_candidates is EqualUnmodifiableListView) return _candidates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_candidates);
  }

  /// 正在搜索封面
  @override
  @JsonKey()
  final bool isSearching;

  /// 错误信息
  @override
  final String? error;

  /// Create a copy of ChangeCoverState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChangeCoverStateCopyWith<_ChangeCoverState> get copyWith =>
      __$ChangeCoverStateCopyWithImpl<_ChangeCoverState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChangeCoverState &&
            const DeepCollectionEquality().equals(
              other.candidates,
              _candidates,
            ) &&
            (identical(other.isSearching, isSearching) ||
                other.isSearching == isSearching) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_candidates),
      isSearching,
      error,
    );
  }

  @override
  String toString() {
    return 'ChangeCoverState(candidates: $candidates, isSearching: $isSearching, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$ChangeCoverStateCopyWith<$Res>
    implements $ChangeCoverStateCopyWith<$Res> {
  factory _$ChangeCoverStateCopyWith(
    _ChangeCoverState value,
    $Res Function(_ChangeCoverState) _then,
  ) = __$ChangeCoverStateCopyWithImpl;
  @override
  @useResult
  $Res call({List<CoverCandidate> candidates, bool isSearching, String? error});
}

/// @nodoc
class __$ChangeCoverStateCopyWithImpl<$Res>
    implements _$ChangeCoverStateCopyWith<$Res> {
  __$ChangeCoverStateCopyWithImpl(this._self, this._then);

  final _ChangeCoverState _self;
  final $Res Function(_ChangeCoverState) _then;

  /// Create a copy of ChangeCoverState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? candidates = null,
    Object? isSearching = null,
    Object? error = freezed,
  }) {
    return _then(
      _ChangeCoverState(
        candidates: null == candidates
            ? _self._candidates
            : candidates // ignore: cast_nullable_to_non_nullable
                  as List<CoverCandidate>,
        isSearching: null == isSearching
            ? _self.isSearching
            : isSearching // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
