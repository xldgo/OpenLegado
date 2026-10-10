// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dict_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DictState {
  /// 在线词典规则列表
  List<DictRule> get rules;

  /// 当前查询的单词（null 表示尚未查询）
  String? get queriedWord;

  /// 本地词典命中结果（null 表示未查询或未收录）
  DictEntry? get result;

  /// 正在加载规则
  bool get isLoading;

  /// 错误信息
  String? get error;

  /// Create a copy of DictState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DictStateCopyWith<DictState> get copyWith =>
      _$DictStateCopyWithImpl<DictState>(this as DictState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as DictState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DictState &&
            const DeepCollectionEquality().equals(other.rules, _this.rules) &&
            (identical(other.queriedWord, _this.queriedWord) ||
                other.queriedWord == _this.queriedWord) &&
            (identical(other.result, _this.result) ||
                other.result == _this.result) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as DictState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.rules),
      _this.queriedWord,
      _this.result,
      _this.isLoading,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as DictState;
    return 'DictState(rules: ${_this.rules}, queriedWord: ${_this.queriedWord}, result: ${_this.result}, isLoading: ${_this.isLoading}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $DictStateCopyWith<$Res> {
  factory $DictStateCopyWith(DictState value, $Res Function(DictState) _then) =
      _$DictStateCopyWithImpl;
  @useResult
  $Res call({
    List<DictRule> rules,
    String? queriedWord,
    DictEntry? result,
    bool isLoading,
    String? error,
  });

  $DictEntryCopyWith<$Res>? get result;
}

/// @nodoc
class _$DictStateCopyWithImpl<$Res> implements $DictStateCopyWith<$Res> {
  _$DictStateCopyWithImpl(this._self, this._then);

  final DictState _self;
  final $Res Function(DictState) _then;

  /// Create a copy of DictState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rules = null,
    Object? queriedWord = freezed,
    Object? result = freezed,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      DictState(
        rules: null == rules
            ? _self.rules
            : rules // ignore: cast_nullable_to_non_nullable
                  as List<DictRule>,
        queriedWord: freezed == queriedWord
            ? _self.queriedWord
            : queriedWord // ignore: cast_nullable_to_non_nullable
                  as String?,
        result: freezed == result
            ? _self.result
            : result // ignore: cast_nullable_to_non_nullable
                  as DictEntry?,
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

  /// Create a copy of DictState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DictEntryCopyWith<$Res>? get result {
    if (_self.result == null) {
      return null;
    }

    return $DictEntryCopyWith<$Res>(_self.result!, (value) {
      return _then(_self.copyWith(result: value));
    });
  }
}

/// Adds pattern-matching-related methods to [DictState].
extension DictStatePatterns on DictState {
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
    TResult Function(_DictState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DictState() when $default != null:
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
    TResult Function(_DictState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictState():
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
    TResult? Function(_DictState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictState() when $default != null:
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
      List<DictRule> rules,
      String? queriedWord,
      DictEntry? result,
      bool isLoading,
      String? error,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DictState() when $default != null:
        return $default(
          _that.rules,
          _that.queriedWord,
          _that.result,
          _that.isLoading,
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
      List<DictRule> rules,
      String? queriedWord,
      DictEntry? result,
      bool isLoading,
      String? error,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictState():
        return $default(
          _that.rules,
          _that.queriedWord,
          _that.result,
          _that.isLoading,
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
      List<DictRule> rules,
      String? queriedWord,
      DictEntry? result,
      bool isLoading,
      String? error,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictState() when $default != null:
        return $default(
          _that.rules,
          _that.queriedWord,
          _that.result,
          _that.isLoading,
          _that.error,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _DictState implements DictState {
  const _DictState({
    List<DictRule> rules = const [],
    this.queriedWord,
    this.result,
    this.isLoading = false,
    this.error,
  }) : _rules = rules;

  /// 在线词典规则列表
  final List<DictRule> _rules;

  /// 在线词典规则列表
  @override
  @JsonKey()
  List<DictRule> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  /// 当前查询的单词（null 表示尚未查询）
  @override
  final String? queriedWord;

  /// 本地词典命中结果（null 表示未查询或未收录）
  @override
  final DictEntry? result;

  /// 正在加载规则
  @override
  @JsonKey()
  final bool isLoading;

  /// 错误信息
  @override
  final String? error;

  /// Create a copy of DictState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DictStateCopyWith<_DictState> get copyWith =>
      __$DictStateCopyWithImpl<_DictState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DictState &&
            const DeepCollectionEquality().equals(other.rules, _rules) &&
            (identical(other.queriedWord, queriedWord) ||
                other.queriedWord == queriedWord) &&
            (identical(other.result, result) || other.result == result) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_rules),
      queriedWord,
      result,
      isLoading,
      error,
    );
  }

  @override
  String toString() {
    return 'DictState(rules: $rules, queriedWord: $queriedWord, result: $result, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$DictStateCopyWith<$Res>
    implements $DictStateCopyWith<$Res> {
  factory _$DictStateCopyWith(
    _DictState value,
    $Res Function(_DictState) _then,
  ) = __$DictStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    List<DictRule> rules,
    String? queriedWord,
    DictEntry? result,
    bool isLoading,
    String? error,
  });

  @override
  $DictEntryCopyWith<$Res>? get result;
}

/// @nodoc
class __$DictStateCopyWithImpl<$Res> implements _$DictStateCopyWith<$Res> {
  __$DictStateCopyWithImpl(this._self, this._then);

  final _DictState _self;
  final $Res Function(_DictState) _then;

  /// Create a copy of DictState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? rules = null,
    Object? queriedWord = freezed,
    Object? result = freezed,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _DictState(
        rules: null == rules
            ? _self._rules
            : rules // ignore: cast_nullable_to_non_nullable
                  as List<DictRule>,
        queriedWord: freezed == queriedWord
            ? _self.queriedWord
            : queriedWord // ignore: cast_nullable_to_non_nullable
                  as String?,
        result: freezed == result
            ? _self.result
            : result // ignore: cast_nullable_to_non_nullable
                  as DictEntry?,
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

  /// Create a copy of DictState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DictEntryCopyWith<$Res>? get result {
    if (_self.result == null) {
      return null;
    }

    return $DictEntryCopyWith<$Res>(_self.result!, (value) {
      return _then(_self.copyWith(result: value));
    });
  }
}
