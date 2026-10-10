// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'theme_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ThemeState {
  /// 主题模式（亮/暗/跟随系统）
  ThemeMode get themeMode;

  /// 字体缩放原始值（0 = 跟随系统；8~16 → 0.8x~1.6x）
  int get fontScaleRaw;

  /// 内置 MD3 调色板 id（Md3Palettes.byId 消费；未知值回退默认 def）
  String get paletteId;

  /// Create a copy of ThemeState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ThemeStateCopyWith<ThemeState> get copyWith =>
      _$ThemeStateCopyWithImpl<ThemeState>(this as ThemeState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as ThemeState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ThemeState &&
            (identical(other.themeMode, _this.themeMode) ||
                other.themeMode == _this.themeMode) &&
            (identical(other.fontScaleRaw, _this.fontScaleRaw) ||
                other.fontScaleRaw == _this.fontScaleRaw) &&
            (identical(other.paletteId, _this.paletteId) ||
                other.paletteId == _this.paletteId));
  }

  @override
  int get hashCode {
    final _this = this as ThemeState;
    return Object.hash(
      runtimeType,
      _this.themeMode,
      _this.fontScaleRaw,
      _this.paletteId,
    );
  }

  @override
  String toString() {
    final _this = this as ThemeState;
    return 'ThemeState(themeMode: ${_this.themeMode}, fontScaleRaw: ${_this.fontScaleRaw}, paletteId: ${_this.paletteId})';
  }
}

/// @nodoc
abstract mixin class $ThemeStateCopyWith<$Res> {
  factory $ThemeStateCopyWith(
    ThemeState value,
    $Res Function(ThemeState) _then,
  ) = _$ThemeStateCopyWithImpl;
  @useResult
  $Res call({ThemeMode themeMode, int fontScaleRaw, String paletteId});
}

/// @nodoc
class _$ThemeStateCopyWithImpl<$Res> implements $ThemeStateCopyWith<$Res> {
  _$ThemeStateCopyWithImpl(this._self, this._then);

  final ThemeState _self;
  final $Res Function(ThemeState) _then;

  /// Create a copy of ThemeState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? themeMode = null,
    Object? fontScaleRaw = null,
    Object? paletteId = null,
  }) {
    return _then(
      ThemeState(
        themeMode: null == themeMode
            ? _self.themeMode
            : themeMode // ignore: cast_nullable_to_non_nullable
                  as ThemeMode,
        fontScaleRaw: null == fontScaleRaw
            ? _self.fontScaleRaw
            : fontScaleRaw // ignore: cast_nullable_to_non_nullable
                  as int,
        paletteId: null == paletteId
            ? _self.paletteId
            : paletteId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ThemeState].
extension ThemeStatePatterns on ThemeState {
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
    TResult Function(_ThemeState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ThemeState() when $default != null:
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
    TResult Function(_ThemeState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemeState():
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
    TResult? Function(_ThemeState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemeState() when $default != null:
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
    TResult Function(ThemeMode themeMode, int fontScaleRaw, String paletteId)?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ThemeState() when $default != null:
        return $default(_that.themeMode, _that.fontScaleRaw, _that.paletteId);
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
    TResult Function(ThemeMode themeMode, int fontScaleRaw, String paletteId)
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemeState():
        return $default(_that.themeMode, _that.fontScaleRaw, _that.paletteId);
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
    TResult? Function(ThemeMode themeMode, int fontScaleRaw, String paletteId)?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemeState() when $default != null:
        return $default(_that.themeMode, _that.fontScaleRaw, _that.paletteId);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ThemeState implements ThemeState {
  const _ThemeState({
    this.themeMode = ThemeMode.system,
    this.fontScaleRaw = 0,
    this.paletteId = 'def',
  });

  /// 主题模式（亮/暗/跟随系统）
  @override
  @JsonKey()
  final ThemeMode themeMode;

  /// 字体缩放原始值（0 = 跟随系统；8~16 → 0.8x~1.6x）
  @override
  @JsonKey()
  final int fontScaleRaw;

  /// 内置 MD3 调色板 id（Md3Palettes.byId 消费；未知值回退默认 def）
  @override
  @JsonKey()
  final String paletteId;

  /// Create a copy of ThemeState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ThemeStateCopyWith<_ThemeState> get copyWith =>
      __$ThemeStateCopyWithImpl<_ThemeState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ThemeState &&
            (identical(other.themeMode, themeMode) ||
                other.themeMode == themeMode) &&
            (identical(other.fontScaleRaw, fontScaleRaw) ||
                other.fontScaleRaw == fontScaleRaw) &&
            (identical(other.paletteId, paletteId) ||
                other.paletteId == paletteId));
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, themeMode, fontScaleRaw, paletteId);
  }

  @override
  String toString() {
    return 'ThemeState(themeMode: $themeMode, fontScaleRaw: $fontScaleRaw, paletteId: $paletteId)';
  }
}

/// @nodoc
abstract mixin class _$ThemeStateCopyWith<$Res>
    implements $ThemeStateCopyWith<$Res> {
  factory _$ThemeStateCopyWith(
    _ThemeState value,
    $Res Function(_ThemeState) _then,
  ) = __$ThemeStateCopyWithImpl;
  @override
  @useResult
  $Res call({ThemeMode themeMode, int fontScaleRaw, String paletteId});
}

/// @nodoc
class __$ThemeStateCopyWithImpl<$Res> implements _$ThemeStateCopyWith<$Res> {
  __$ThemeStateCopyWithImpl(this._self, this._then);

  final _ThemeState _self;
  final $Res Function(_ThemeState) _then;

  /// Create a copy of ThemeState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? themeMode = null,
    Object? fontScaleRaw = null,
    Object? paletteId = null,
  }) {
    return _then(
      _ThemeState(
        themeMode: null == themeMode
            ? _self.themeMode
            : themeMode // ignore: cast_nullable_to_non_nullable
                  as ThemeMode,
        fontScaleRaw: null == fontScaleRaw
            ? _self.fontScaleRaw
            : fontScaleRaw // ignore: cast_nullable_to_non_nullable
                  as int,
        paletteId: null == paletteId
            ? _self.paletteId
            : paletteId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}
