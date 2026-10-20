// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'txt_toc_rules_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TxtTocRulesState {
  /// 规则列表（按 serialNumber 语义排序）
  List<TxtTocRule> get rules;

  /// 正在加载
  bool get isLoading;

  /// 错误信息
  String? get error;

  /// Create a copy of TxtTocRulesState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TxtTocRulesStateCopyWith<TxtTocRulesState> get copyWith =>
      _$TxtTocRulesStateCopyWithImpl<TxtTocRulesState>(
        this as TxtTocRulesState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as TxtTocRulesState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TxtTocRulesState &&
            const DeepCollectionEquality().equals(other.rules, _this.rules) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as TxtTocRulesState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.rules),
      _this.isLoading,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as TxtTocRulesState;
    return 'TxtTocRulesState(rules: ${_this.rules}, isLoading: ${_this.isLoading}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $TxtTocRulesStateCopyWith<$Res> {
  factory $TxtTocRulesStateCopyWith(
    TxtTocRulesState value,
    $Res Function(TxtTocRulesState) _then,
  ) = _$TxtTocRulesStateCopyWithImpl;
  @useResult
  $Res call({List<TxtTocRule> rules, bool isLoading, String? error});
}

/// @nodoc
class _$TxtTocRulesStateCopyWithImpl<$Res>
    implements $TxtTocRulesStateCopyWith<$Res> {
  _$TxtTocRulesStateCopyWithImpl(this._self, this._then);

  final TxtTocRulesState _self;
  final $Res Function(TxtTocRulesState) _then;

  /// Create a copy of TxtTocRulesState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rules = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      TxtTocRulesState(
        rules: null == rules
            ? _self.rules
            : rules // ignore: cast_nullable_to_non_nullable
                  as List<TxtTocRule>,
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

/// Adds pattern-matching-related methods to [TxtTocRulesState].
extension TxtTocRulesStatePatterns on TxtTocRulesState {
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
    TResult Function(_TxtTocRulesState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TxtTocRulesState() when $default != null:
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
    TResult Function(_TxtTocRulesState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TxtTocRulesState():
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
    TResult? Function(_TxtTocRulesState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TxtTocRulesState() when $default != null:
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
    TResult Function(List<TxtTocRule> rules, bool isLoading, String? error)?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TxtTocRulesState() when $default != null:
        return $default(_that.rules, _that.isLoading, _that.error);
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
    TResult Function(List<TxtTocRule> rules, bool isLoading, String? error)
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TxtTocRulesState():
        return $default(_that.rules, _that.isLoading, _that.error);
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
    TResult? Function(List<TxtTocRule> rules, bool isLoading, String? error)?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TxtTocRulesState() when $default != null:
        return $default(_that.rules, _that.isLoading, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TxtTocRulesState implements TxtTocRulesState {
  const _TxtTocRulesState({
    List<TxtTocRule> rules = const [],
    this.isLoading = false,
    this.error,
  }) : _rules = rules;

  /// 规则列表（按 serialNumber 语义排序）
  final List<TxtTocRule> _rules;

  /// 规则列表（按 serialNumber 语义排序）
  @override
  @JsonKey()
  List<TxtTocRule> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  /// 正在加载
  @override
  @JsonKey()
  final bool isLoading;

  /// 错误信息
  @override
  final String? error;

  /// Create a copy of TxtTocRulesState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TxtTocRulesStateCopyWith<_TxtTocRulesState> get copyWith =>
      __$TxtTocRulesStateCopyWithImpl<_TxtTocRulesState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TxtTocRulesState &&
            const DeepCollectionEquality().equals(other.rules, _rules) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_rules),
      isLoading,
      error,
    );
  }

  @override
  String toString() {
    return 'TxtTocRulesState(rules: $rules, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$TxtTocRulesStateCopyWith<$Res>
    implements $TxtTocRulesStateCopyWith<$Res> {
  factory _$TxtTocRulesStateCopyWith(
    _TxtTocRulesState value,
    $Res Function(_TxtTocRulesState) _then,
  ) = __$TxtTocRulesStateCopyWithImpl;
  @override
  @useResult
  $Res call({List<TxtTocRule> rules, bool isLoading, String? error});
}

/// @nodoc
class __$TxtTocRulesStateCopyWithImpl<$Res>
    implements _$TxtTocRulesStateCopyWith<$Res> {
  __$TxtTocRulesStateCopyWithImpl(this._self, this._then);

  final _TxtTocRulesState _self;
  final $Res Function(_TxtTocRulesState) _then;

  /// Create a copy of TxtTocRulesState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? rules = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _TxtTocRulesState(
        rules: null == rules
            ? _self._rules
            : rules // ignore: cast_nullable_to_non_nullable
                  as List<TxtTocRule>,
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
