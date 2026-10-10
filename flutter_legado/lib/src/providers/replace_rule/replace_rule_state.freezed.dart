// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'replace_rule_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReplaceRuleState {
  /// 替换规则列表
  List<ReplaceRule> get rules;

  /// 是否正在加载规则列表
  bool get loading;

  /// 错误信息（null 表示无错误）
  String? get error;

  /// Create a copy of ReplaceRuleState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReplaceRuleStateCopyWith<ReplaceRuleState> get copyWith =>
      _$ReplaceRuleStateCopyWithImpl<ReplaceRuleState>(
        this as ReplaceRuleState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as ReplaceRuleState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReplaceRuleState &&
            const DeepCollectionEquality().equals(other.rules, _this.rules) &&
            (identical(other.loading, _this.loading) ||
                other.loading == _this.loading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as ReplaceRuleState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.rules),
      _this.loading,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as ReplaceRuleState;
    return 'ReplaceRuleState(rules: ${_this.rules}, loading: ${_this.loading}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $ReplaceRuleStateCopyWith<$Res> {
  factory $ReplaceRuleStateCopyWith(
    ReplaceRuleState value,
    $Res Function(ReplaceRuleState) _then,
  ) = _$ReplaceRuleStateCopyWithImpl;
  @useResult
  $Res call({List<ReplaceRule> rules, bool loading, String? error});
}

/// @nodoc
class _$ReplaceRuleStateCopyWithImpl<$Res>
    implements $ReplaceRuleStateCopyWith<$Res> {
  _$ReplaceRuleStateCopyWithImpl(this._self, this._then);

  final ReplaceRuleState _self;
  final $Res Function(ReplaceRuleState) _then;

  /// Create a copy of ReplaceRuleState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rules = null,
    Object? loading = null,
    Object? error = freezed,
  }) {
    return _then(
      ReplaceRuleState(
        rules: null == rules
            ? _self.rules
            : rules // ignore: cast_nullable_to_non_nullable
                  as List<ReplaceRule>,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ReplaceRuleState].
extension ReplaceRuleStatePatterns on ReplaceRuleState {
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
    TResult Function(_ReplaceRuleState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReplaceRuleState() when $default != null:
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
    TResult Function(_ReplaceRuleState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceRuleState():
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
    TResult? Function(_ReplaceRuleState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceRuleState() when $default != null:
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
    TResult Function(List<ReplaceRule> rules, bool loading, String? error)?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReplaceRuleState() when $default != null:
        return $default(_that.rules, _that.loading, _that.error);
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
    TResult Function(List<ReplaceRule> rules, bool loading, String? error)
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceRuleState():
        return $default(_that.rules, _that.loading, _that.error);
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
    TResult? Function(List<ReplaceRule> rules, bool loading, String? error)?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceRuleState() when $default != null:
        return $default(_that.rules, _that.loading, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ReplaceRuleState implements ReplaceRuleState {
  const _ReplaceRuleState({
    List<ReplaceRule> rules = const [],
    this.loading = false,
    this.error,
  }) : _rules = rules;

  /// 替换规则列表
  final List<ReplaceRule> _rules;

  /// 替换规则列表
  @override
  @JsonKey()
  List<ReplaceRule> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  /// 是否正在加载规则列表
  @override
  @JsonKey()
  final bool loading;

  /// 错误信息（null 表示无错误）
  @override
  final String? error;

  /// Create a copy of ReplaceRuleState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReplaceRuleStateCopyWith<_ReplaceRuleState> get copyWith =>
      __$ReplaceRuleStateCopyWithImpl<_ReplaceRuleState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReplaceRuleState &&
            const DeepCollectionEquality().equals(other.rules, _rules) &&
            (identical(other.loading, loading) || other.loading == loading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_rules),
      loading,
      error,
    );
  }

  @override
  String toString() {
    return 'ReplaceRuleState(rules: $rules, loading: $loading, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$ReplaceRuleStateCopyWith<$Res>
    implements $ReplaceRuleStateCopyWith<$Res> {
  factory _$ReplaceRuleStateCopyWith(
    _ReplaceRuleState value,
    $Res Function(_ReplaceRuleState) _then,
  ) = __$ReplaceRuleStateCopyWithImpl;
  @override
  @useResult
  $Res call({List<ReplaceRule> rules, bool loading, String? error});
}

/// @nodoc
class __$ReplaceRuleStateCopyWithImpl<$Res>
    implements _$ReplaceRuleStateCopyWith<$Res> {
  __$ReplaceRuleStateCopyWithImpl(this._self, this._then);

  final _ReplaceRuleState _self;
  final $Res Function(_ReplaceRuleState) _then;

  /// Create a copy of ReplaceRuleState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? rules = null,
    Object? loading = null,
    Object? error = freezed,
  }) {
    return _then(
      _ReplaceRuleState(
        rules: null == rules
            ? _self._rules
            : rules // ignore: cast_nullable_to_non_nullable
                  as List<ReplaceRule>,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
