// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_login_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SourceLoginState {
  /// Bearer Token / API Key（可选）
  String get token;

  /// Cookie 键值对列表
  List<LoginKeyValue> get cookies;

  /// Header 键值对列表
  List<LoginKeyValue> get headers;

  /// 正在加载已保存的登录信息
  bool get isLoading;

  /// 正在保存
  bool get isSaving;

  /// 错误信息
  String? get error;

  /// Create a copy of SourceLoginState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SourceLoginStateCopyWith<SourceLoginState> get copyWith =>
      _$SourceLoginStateCopyWithImpl<SourceLoginState>(
        this as SourceLoginState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as SourceLoginState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SourceLoginState &&
            (identical(other.token, _this.token) ||
                other.token == _this.token) &&
            const DeepCollectionEquality().equals(
              other.cookies,
              _this.cookies,
            ) &&
            const DeepCollectionEquality().equals(
              other.headers,
              _this.headers,
            ) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.isSaving, _this.isSaving) ||
                other.isSaving == _this.isSaving) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error));
  }

  @override
  int get hashCode {
    final _this = this as SourceLoginState;
    return Object.hash(
      runtimeType,
      _this.token,
      const DeepCollectionEquality().hash(_this.cookies),
      const DeepCollectionEquality().hash(_this.headers),
      _this.isLoading,
      _this.isSaving,
      _this.error,
    );
  }

  @override
  String toString() {
    final _this = this as SourceLoginState;
    return 'SourceLoginState(token: ${_this.token}, cookies: ${_this.cookies}, headers: ${_this.headers}, isLoading: ${_this.isLoading}, isSaving: ${_this.isSaving}, error: ${_this.error})';
  }
}

/// @nodoc
abstract mixin class $SourceLoginStateCopyWith<$Res> {
  factory $SourceLoginStateCopyWith(
    SourceLoginState value,
    $Res Function(SourceLoginState) _then,
  ) = _$SourceLoginStateCopyWithImpl;
  @useResult
  $Res call({
    String token,
    List<LoginKeyValue> cookies,
    List<LoginKeyValue> headers,
    bool isLoading,
    bool isSaving,
    String? error,
  });
}

/// @nodoc
class _$SourceLoginStateCopyWithImpl<$Res>
    implements $SourceLoginStateCopyWith<$Res> {
  _$SourceLoginStateCopyWithImpl(this._self, this._then);

  final SourceLoginState _self;
  final $Res Function(SourceLoginState) _then;

  /// Create a copy of SourceLoginState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? token = null,
    Object? cookies = null,
    Object? headers = null,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? error = freezed,
  }) {
    return _then(
      SourceLoginState(
        token: null == token
            ? _self.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String,
        cookies: null == cookies
            ? _self.cookies
            : cookies // ignore: cast_nullable_to_non_nullable
                  as List<LoginKeyValue>,
        headers: null == headers
            ? _self.headers
            : headers // ignore: cast_nullable_to_non_nullable
                  as List<LoginKeyValue>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        isSaving: null == isSaving
            ? _self.isSaving
            : isSaving // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [SourceLoginState].
extension SourceLoginStatePatterns on SourceLoginState {
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
    TResult Function(_SourceLoginState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SourceLoginState() when $default != null:
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
    TResult Function(_SourceLoginState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceLoginState():
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
    TResult? Function(_SourceLoginState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceLoginState() when $default != null:
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
      String token,
      List<LoginKeyValue> cookies,
      List<LoginKeyValue> headers,
      bool isLoading,
      bool isSaving,
      String? error,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SourceLoginState() when $default != null:
        return $default(
          _that.token,
          _that.cookies,
          _that.headers,
          _that.isLoading,
          _that.isSaving,
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
      String token,
      List<LoginKeyValue> cookies,
      List<LoginKeyValue> headers,
      bool isLoading,
      bool isSaving,
      String? error,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceLoginState():
        return $default(
          _that.token,
          _that.cookies,
          _that.headers,
          _that.isLoading,
          _that.isSaving,
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
      String token,
      List<LoginKeyValue> cookies,
      List<LoginKeyValue> headers,
      bool isLoading,
      bool isSaving,
      String? error,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceLoginState() when $default != null:
        return $default(
          _that.token,
          _that.cookies,
          _that.headers,
          _that.isLoading,
          _that.isSaving,
          _that.error,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SourceLoginState implements SourceLoginState {
  const _SourceLoginState({
    this.token = '',
    List<LoginKeyValue> cookies = const [],
    List<LoginKeyValue> headers = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  }) : _cookies = cookies,
       _headers = headers;

  /// Bearer Token / API Key（可选）
  @override
  @JsonKey()
  final String token;

  /// Cookie 键值对列表
  final List<LoginKeyValue> _cookies;

  /// Cookie 键值对列表
  @override
  @JsonKey()
  List<LoginKeyValue> get cookies {
    if (_cookies is EqualUnmodifiableListView) return _cookies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_cookies);
  }

  /// Header 键值对列表
  final List<LoginKeyValue> _headers;

  /// Header 键值对列表
  @override
  @JsonKey()
  List<LoginKeyValue> get headers {
    if (_headers is EqualUnmodifiableListView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_headers);
  }

  /// 正在加载已保存的登录信息
  @override
  @JsonKey()
  final bool isLoading;

  /// 正在保存
  @override
  @JsonKey()
  final bool isSaving;

  /// 错误信息
  @override
  final String? error;

  /// Create a copy of SourceLoginState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SourceLoginStateCopyWith<_SourceLoginState> get copyWith =>
      __$SourceLoginStateCopyWithImpl<_SourceLoginState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SourceLoginState &&
            (identical(other.token, token) || other.token == token) &&
            const DeepCollectionEquality().equals(other.cookies, _cookies) &&
            const DeepCollectionEquality().equals(other.headers, _headers) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isSaving, isSaving) ||
                other.isSaving == isSaving) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      token,
      const DeepCollectionEquality().hash(_cookies),
      const DeepCollectionEquality().hash(_headers),
      isLoading,
      isSaving,
      error,
    );
  }

  @override
  String toString() {
    return 'SourceLoginState(token: $token, cookies: $cookies, headers: $headers, isLoading: $isLoading, isSaving: $isSaving, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$SourceLoginStateCopyWith<$Res>
    implements $SourceLoginStateCopyWith<$Res> {
  factory _$SourceLoginStateCopyWith(
    _SourceLoginState value,
    $Res Function(_SourceLoginState) _then,
  ) = __$SourceLoginStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    String token,
    List<LoginKeyValue> cookies,
    List<LoginKeyValue> headers,
    bool isLoading,
    bool isSaving,
    String? error,
  });
}

/// @nodoc
class __$SourceLoginStateCopyWithImpl<$Res>
    implements _$SourceLoginStateCopyWith<$Res> {
  __$SourceLoginStateCopyWithImpl(this._self, this._then);

  final _SourceLoginState _self;
  final $Res Function(_SourceLoginState) _then;

  /// Create a copy of SourceLoginState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? token = null,
    Object? cookies = null,
    Object? headers = null,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? error = freezed,
  }) {
    return _then(
      _SourceLoginState(
        token: null == token
            ? _self.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String,
        cookies: null == cookies
            ? _self._cookies
            : cookies // ignore: cast_nullable_to_non_nullable
                  as List<LoginKeyValue>,
        headers: null == headers
            ? _self._headers
            : headers // ignore: cast_nullable_to_non_nullable
                  as List<LoginKeyValue>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        isSaving: null == isSaving
            ? _self.isSaving
            : isSaving // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
