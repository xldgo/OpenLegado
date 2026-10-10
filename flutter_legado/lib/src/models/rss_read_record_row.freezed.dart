// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rss_read_record_row.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RssReadRecordRow {
  /// 来源 URL
  String get origin;

  /// 文章标题
  String get title;

  /// 文章链接
  String? get link;

  /// 阅读时间（Unix 毫秒）
  @JsonKey(name: 'read_time')
  int get readTime;

  /// Create a copy of RssReadRecordRow
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RssReadRecordRowCopyWith<RssReadRecordRow> get copyWith =>
      _$RssReadRecordRowCopyWithImpl<RssReadRecordRow>(
        this as RssReadRecordRow,
        _$identity,
      );

  /// Serializes this RssReadRecordRow to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as RssReadRecordRow;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RssReadRecordRow &&
            (identical(other.origin, _this.origin) ||
                other.origin == _this.origin) &&
            (identical(other.title, _this.title) ||
                other.title == _this.title) &&
            (identical(other.link, _this.link) || other.link == _this.link) &&
            (identical(other.readTime, _this.readTime) ||
                other.readTime == _this.readTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as RssReadRecordRow;
    return Object.hash(
      runtimeType,
      _this.origin,
      _this.title,
      _this.link,
      _this.readTime,
    );
  }

  @override
  String toString() {
    final _this = this as RssReadRecordRow;
    return 'RssReadRecordRow(origin: ${_this.origin}, title: ${_this.title}, link: ${_this.link}, readTime: ${_this.readTime})';
  }
}

/// @nodoc
abstract mixin class $RssReadRecordRowCopyWith<$Res> {
  factory $RssReadRecordRowCopyWith(
    RssReadRecordRow value,
    $Res Function(RssReadRecordRow) _then,
  ) = _$RssReadRecordRowCopyWithImpl;
  @useResult
  $Res call({
    String origin,
    String title,
    String? link,
    @JsonKey(name: 'read_time') int readTime,
  });
}

/// @nodoc
class _$RssReadRecordRowCopyWithImpl<$Res>
    implements $RssReadRecordRowCopyWith<$Res> {
  _$RssReadRecordRowCopyWithImpl(this._self, this._then);

  final RssReadRecordRow _self;
  final $Res Function(RssReadRecordRow) _then;

  /// Create a copy of RssReadRecordRow
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? origin = null,
    Object? title = null,
    Object? link = freezed,
    Object? readTime = null,
  }) {
    return _then(
      RssReadRecordRow(
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        link: freezed == link
            ? _self.link
            : link // ignore: cast_nullable_to_non_nullable
                  as String?,
        readTime: null == readTime
            ? _self.readTime
            : readTime // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [RssReadRecordRow].
extension RssReadRecordRowPatterns on RssReadRecordRow {
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
    TResult Function(_RssReadRecordRow value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssReadRecordRow() when $default != null:
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
    TResult Function(_RssReadRecordRow value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssReadRecordRow():
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
    TResult? Function(_RssReadRecordRow value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssReadRecordRow() when $default != null:
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
      String origin,
      String title,
      String? link,
      @JsonKey(name: 'read_time') int readTime,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssReadRecordRow() when $default != null:
        return $default(_that.origin, _that.title, _that.link, _that.readTime);
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
      String origin,
      String title,
      String? link,
      @JsonKey(name: 'read_time') int readTime,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssReadRecordRow():
        return $default(_that.origin, _that.title, _that.link, _that.readTime);
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
      String origin,
      String title,
      String? link,
      @JsonKey(name: 'read_time') int readTime,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssReadRecordRow() when $default != null:
        return $default(_that.origin, _that.title, _that.link, _that.readTime);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RssReadRecordRow implements RssReadRecordRow {
  const _RssReadRecordRow({
    this.origin = '',
    this.title = '',
    this.link,
    @JsonKey(name: 'read_time') this.readTime = 0,
  });
  factory _RssReadRecordRow.fromJson(Map<String, dynamic> json) =>
      _$RssReadRecordRowFromJson(json);

  /// 来源 URL
  @override
  @JsonKey()
  final String origin;

  /// 文章标题
  @override
  @JsonKey()
  final String title;

  /// 文章链接
  @override
  final String? link;

  /// 阅读时间（Unix 毫秒）
  @override
  @JsonKey(name: 'read_time')
  final int readTime;

  /// Create a copy of RssReadRecordRow
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RssReadRecordRowCopyWith<_RssReadRecordRow> get copyWith =>
      __$RssReadRecordRowCopyWithImpl<_RssReadRecordRow>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RssReadRecordRowToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RssReadRecordRow &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.link, link) || other.link == link) &&
            (identical(other.readTime, readTime) ||
                other.readTime == readTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, origin, title, link, readTime);
  }

  @override
  String toString() {
    return 'RssReadRecordRow(origin: $origin, title: $title, link: $link, readTime: $readTime)';
  }
}

/// @nodoc
abstract mixin class _$RssReadRecordRowCopyWith<$Res>
    implements $RssReadRecordRowCopyWith<$Res> {
  factory _$RssReadRecordRowCopyWith(
    _RssReadRecordRow value,
    $Res Function(_RssReadRecordRow) _then,
  ) = __$RssReadRecordRowCopyWithImpl;
  @override
  @useResult
  $Res call({
    String origin,
    String title,
    String? link,
    @JsonKey(name: 'read_time') int readTime,
  });
}

/// @nodoc
class __$RssReadRecordRowCopyWithImpl<$Res>
    implements _$RssReadRecordRowCopyWith<$Res> {
  __$RssReadRecordRowCopyWithImpl(this._self, this._then);

  final _RssReadRecordRow _self;
  final $Res Function(_RssReadRecordRow) _then;

  /// Create a copy of RssReadRecordRow
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? origin = null,
    Object? title = null,
    Object? link = freezed,
    Object? readTime = null,
  }) {
    return _then(
      _RssReadRecordRow(
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        link: freezed == link
            ? _self.link
            : link // ignore: cast_nullable_to_non_nullable
                  as String?,
        readTime: null == readTime
            ? _self.readTime
            : readTime // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}
