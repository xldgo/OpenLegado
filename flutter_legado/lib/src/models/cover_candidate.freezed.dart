// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cover_candidate.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CoverCandidate {
  /// 封面图片 URL
  String get url;

  /// 图片宽度（像素，0 表示未知）
  int get width;

  /// 图片高度（像素，0 表示未知）
  int get height;

  /// Create a copy of CoverCandidate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CoverCandidateCopyWith<CoverCandidate> get copyWith =>
      _$CoverCandidateCopyWithImpl<CoverCandidate>(
        this as CoverCandidate,
        _$identity,
      );

  /// Serializes this CoverCandidate to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as CoverCandidate;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CoverCandidate &&
            (identical(other.url, _this.url) || other.url == _this.url) &&
            (identical(other.width, _this.width) ||
                other.width == _this.width) &&
            (identical(other.height, _this.height) ||
                other.height == _this.height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as CoverCandidate;
    return Object.hash(runtimeType, _this.url, _this.width, _this.height);
  }

  @override
  String toString() {
    final _this = this as CoverCandidate;
    return 'CoverCandidate(url: ${_this.url}, width: ${_this.width}, height: ${_this.height})';
  }
}

/// @nodoc
abstract mixin class $CoverCandidateCopyWith<$Res> {
  factory $CoverCandidateCopyWith(
    CoverCandidate value,
    $Res Function(CoverCandidate) _then,
  ) = _$CoverCandidateCopyWithImpl;
  @useResult
  $Res call({String url, int width, int height});
}

/// @nodoc
class _$CoverCandidateCopyWithImpl<$Res>
    implements $CoverCandidateCopyWith<$Res> {
  _$CoverCandidateCopyWithImpl(this._self, this._then);

  final CoverCandidate _self;
  final $Res Function(CoverCandidate) _then;

  /// Create a copy of CoverCandidate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? url = null, Object? width = null, Object? height = null}) {
    return _then(
      CoverCandidate(
        url: null == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        width: null == width
            ? _self.width
            : width // ignore: cast_nullable_to_non_nullable
                  as int,
        height: null == height
            ? _self.height
            : height // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [CoverCandidate].
extension CoverCandidatePatterns on CoverCandidate {
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
    TResult Function(_CoverCandidate value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CoverCandidate() when $default != null:
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
    TResult Function(_CoverCandidate value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CoverCandidate():
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
    TResult? Function(_CoverCandidate value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CoverCandidate() when $default != null:
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
    TResult Function(String url, int width, int height)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CoverCandidate() when $default != null:
        return $default(_that.url, _that.width, _that.height);
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
    TResult Function(String url, int width, int height) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CoverCandidate():
        return $default(_that.url, _that.width, _that.height);
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
    TResult? Function(String url, int width, int height)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CoverCandidate() when $default != null:
        return $default(_that.url, _that.width, _that.height);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CoverCandidate implements CoverCandidate {
  const _CoverCandidate({this.url = '', this.width = 0, this.height = 0});
  factory _CoverCandidate.fromJson(Map<String, dynamic> json) =>
      _$CoverCandidateFromJson(json);

  /// 封面图片 URL
  @override
  @JsonKey()
  final String url;

  /// 图片宽度（像素，0 表示未知）
  @override
  @JsonKey()
  final int width;

  /// 图片高度（像素，0 表示未知）
  @override
  @JsonKey()
  final int height;

  /// Create a copy of CoverCandidate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CoverCandidateCopyWith<_CoverCandidate> get copyWith =>
      __$CoverCandidateCopyWithImpl<_CoverCandidate>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CoverCandidateToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CoverCandidate &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, url, width, height);
  }

  @override
  String toString() {
    return 'CoverCandidate(url: $url, width: $width, height: $height)';
  }
}

/// @nodoc
abstract mixin class _$CoverCandidateCopyWith<$Res>
    implements $CoverCandidateCopyWith<$Res> {
  factory _$CoverCandidateCopyWith(
    _CoverCandidate value,
    $Res Function(_CoverCandidate) _then,
  ) = __$CoverCandidateCopyWithImpl;
  @override
  @useResult
  $Res call({String url, int width, int height});
}

/// @nodoc
class __$CoverCandidateCopyWithImpl<$Res>
    implements _$CoverCandidateCopyWith<$Res> {
  __$CoverCandidateCopyWithImpl(this._self, this._then);

  final _CoverCandidate _self;
  final $Res Function(_CoverCandidate) _then;

  /// Create a copy of CoverCandidate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? url = null, Object? width = null, Object? height = null}) {
    return _then(
      _CoverCandidate(
        url: null == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        width: null == width
            ? _self.width
            : width // ignore: cast_nullable_to_non_nullable
                  as int,
        height: null == height
            ? _self.height
            : height // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}
