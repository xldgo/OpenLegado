// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReadConfig {
  @JsonKey(name: 'reverseToc')
  bool get reverseToc;
  @JsonKey(name: 'pageAnim')
  int? get pageAnim;
  @JsonKey(name: 'reSegment')
  bool get reSegment;
  @JsonKey(name: 'imageStyle')
  String? get imageStyle;
  @JsonKey(name: 'useReplaceRule')
  bool? get useReplaceRule;
  @JsonKey(name: 'delTag')
  int get delTag;
  @JsonKey(name: 'ttsEngine')
  String? get ttsEngine;
  @JsonKey(name: 'splitLongChapter')
  bool get splitLongChapter;
  @JsonKey(name: 'readSimulating')
  bool get readSimulating;
  @JsonKey(name: 'startDate')
  String? get startDate;
  @JsonKey(name: 'startChapter')
  int? get startChapter;
  @JsonKey(name: 'dailyChapters')
  int get dailyChapters;
  @JsonKey(name: 'openCredits')
  int get openCredits;
  @JsonKey(name: 'closeCredits')
  int get closeCredits;
  @JsonKey(name: 'playMode')
  int get playMode;
  @JsonKey(name: 'playSpeed')
  double get playSpeed;

  /// [漫画设置作用域 2026-10-01] 书级翻页模式覆盖（null = 未覆盖，跟随
  /// 全局 [MangaConfigKeys.scrollMode]）。对齐参考版 `Book.ReadConfig.mangaScrollMode`
  /// 与 MangaReaderViewModel 有效值优先级 `book?.scrollMode ?: settings.scrollMode`。
  @JsonKey(name: 'mangaScrollMode')
  int? get mangaScrollMode;

  /// [漫画设置作用域 2026-10-01] 书级条漫侧边留白覆盖（null = 未覆盖，
  /// 跟随全局 [MangaConfigKeys.sidePadding]）。
  ///
  /// 键名对齐参考版 `Book.ReadConfig.webtoonSidePaddingDp`，但数值沿用
  /// Flutter 既有百分比口径 0..45（每侧留白 = 视口宽 × p/100），与参考版
  /// 字段仅做作用域对齐，**不做 dp/百分比换算**（无明确换算规则前禁止混用单位）。
  @JsonKey(name: 'webtoonSidePaddingDp')
  int? get webtoonSidePaddingDp;

  /// Create a copy of ReadConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReadConfigCopyWith<ReadConfig> get copyWith =>
      _$ReadConfigCopyWithImpl<ReadConfig>(this as ReadConfig, _$identity);

  /// Serializes this ReadConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as ReadConfig;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReadConfig &&
            (identical(other.reverseToc, _this.reverseToc) ||
                other.reverseToc == _this.reverseToc) &&
            (identical(other.pageAnim, _this.pageAnim) ||
                other.pageAnim == _this.pageAnim) &&
            (identical(other.reSegment, _this.reSegment) ||
                other.reSegment == _this.reSegment) &&
            (identical(other.imageStyle, _this.imageStyle) ||
                other.imageStyle == _this.imageStyle) &&
            (identical(other.useReplaceRule, _this.useReplaceRule) ||
                other.useReplaceRule == _this.useReplaceRule) &&
            (identical(other.delTag, _this.delTag) ||
                other.delTag == _this.delTag) &&
            (identical(other.ttsEngine, _this.ttsEngine) ||
                other.ttsEngine == _this.ttsEngine) &&
            (identical(other.splitLongChapter, _this.splitLongChapter) ||
                other.splitLongChapter == _this.splitLongChapter) &&
            (identical(other.readSimulating, _this.readSimulating) ||
                other.readSimulating == _this.readSimulating) &&
            (identical(other.startDate, _this.startDate) ||
                other.startDate == _this.startDate) &&
            (identical(other.startChapter, _this.startChapter) ||
                other.startChapter == _this.startChapter) &&
            (identical(other.dailyChapters, _this.dailyChapters) ||
                other.dailyChapters == _this.dailyChapters) &&
            (identical(other.openCredits, _this.openCredits) ||
                other.openCredits == _this.openCredits) &&
            (identical(other.closeCredits, _this.closeCredits) ||
                other.closeCredits == _this.closeCredits) &&
            (identical(other.playMode, _this.playMode) ||
                other.playMode == _this.playMode) &&
            (identical(other.playSpeed, _this.playSpeed) ||
                other.playSpeed == _this.playSpeed) &&
            (identical(other.mangaScrollMode, _this.mangaScrollMode) ||
                other.mangaScrollMode == _this.mangaScrollMode) &&
            (identical(
                  other.webtoonSidePaddingDp,
                  _this.webtoonSidePaddingDp,
                ) ||
                other.webtoonSidePaddingDp == _this.webtoonSidePaddingDp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as ReadConfig;
    return Object.hash(
      runtimeType,
      _this.reverseToc,
      _this.pageAnim,
      _this.reSegment,
      _this.imageStyle,
      _this.useReplaceRule,
      _this.delTag,
      _this.ttsEngine,
      _this.splitLongChapter,
      _this.readSimulating,
      _this.startDate,
      _this.startChapter,
      _this.dailyChapters,
      _this.openCredits,
      _this.closeCredits,
      _this.playMode,
      _this.playSpeed,
      _this.mangaScrollMode,
      _this.webtoonSidePaddingDp,
    );
  }

  @override
  String toString() {
    final _this = this as ReadConfig;
    return 'ReadConfig(reverseToc: ${_this.reverseToc}, pageAnim: ${_this.pageAnim}, reSegment: ${_this.reSegment}, imageStyle: ${_this.imageStyle}, useReplaceRule: ${_this.useReplaceRule}, delTag: ${_this.delTag}, ttsEngine: ${_this.ttsEngine}, splitLongChapter: ${_this.splitLongChapter}, readSimulating: ${_this.readSimulating}, startDate: ${_this.startDate}, startChapter: ${_this.startChapter}, dailyChapters: ${_this.dailyChapters}, openCredits: ${_this.openCredits}, closeCredits: ${_this.closeCredits}, playMode: ${_this.playMode}, playSpeed: ${_this.playSpeed}, mangaScrollMode: ${_this.mangaScrollMode}, webtoonSidePaddingDp: ${_this.webtoonSidePaddingDp})';
  }
}

/// @nodoc
abstract mixin class $ReadConfigCopyWith<$Res> {
  factory $ReadConfigCopyWith(
    ReadConfig value,
    $Res Function(ReadConfig) _then,
  ) = _$ReadConfigCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'reverseToc') bool reverseToc,
    @JsonKey(name: 'pageAnim') int? pageAnim,
    @JsonKey(name: 'reSegment') bool reSegment,
    @JsonKey(name: 'imageStyle') String? imageStyle,
    @JsonKey(name: 'useReplaceRule') bool? useReplaceRule,
    @JsonKey(name: 'delTag') int delTag,
    @JsonKey(name: 'ttsEngine') String? ttsEngine,
    @JsonKey(name: 'splitLongChapter') bool splitLongChapter,
    @JsonKey(name: 'readSimulating') bool readSimulating,
    @JsonKey(name: 'startDate') String? startDate,
    @JsonKey(name: 'startChapter') int? startChapter,
    @JsonKey(name: 'dailyChapters') int dailyChapters,
    @JsonKey(name: 'openCredits') int openCredits,
    @JsonKey(name: 'closeCredits') int closeCredits,
    @JsonKey(name: 'playMode') int playMode,
    @JsonKey(name: 'playSpeed') double playSpeed,
    @JsonKey(name: 'mangaScrollMode') int? mangaScrollMode,
    @JsonKey(name: 'webtoonSidePaddingDp') int? webtoonSidePaddingDp,
  });
}

/// @nodoc
class _$ReadConfigCopyWithImpl<$Res> implements $ReadConfigCopyWith<$Res> {
  _$ReadConfigCopyWithImpl(this._self, this._then);

  final ReadConfig _self;
  final $Res Function(ReadConfig) _then;

  /// Create a copy of ReadConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? reverseToc = null,
    Object? pageAnim = freezed,
    Object? reSegment = null,
    Object? imageStyle = freezed,
    Object? useReplaceRule = freezed,
    Object? delTag = null,
    Object? ttsEngine = freezed,
    Object? splitLongChapter = null,
    Object? readSimulating = null,
    Object? startDate = freezed,
    Object? startChapter = freezed,
    Object? dailyChapters = null,
    Object? openCredits = null,
    Object? closeCredits = null,
    Object? playMode = null,
    Object? playSpeed = null,
    Object? mangaScrollMode = freezed,
    Object? webtoonSidePaddingDp = freezed,
  }) {
    return _then(
      ReadConfig(
        reverseToc: null == reverseToc
            ? _self.reverseToc
            : reverseToc // ignore: cast_nullable_to_non_nullable
                  as bool,
        pageAnim: freezed == pageAnim
            ? _self.pageAnim
            : pageAnim // ignore: cast_nullable_to_non_nullable
                  as int?,
        reSegment: null == reSegment
            ? _self.reSegment
            : reSegment // ignore: cast_nullable_to_non_nullable
                  as bool,
        imageStyle: freezed == imageStyle
            ? _self.imageStyle
            : imageStyle // ignore: cast_nullable_to_non_nullable
                  as String?,
        useReplaceRule: freezed == useReplaceRule
            ? _self.useReplaceRule
            : useReplaceRule // ignore: cast_nullable_to_non_nullable
                  as bool?,
        delTag: null == delTag
            ? _self.delTag
            : delTag // ignore: cast_nullable_to_non_nullable
                  as int,
        ttsEngine: freezed == ttsEngine
            ? _self.ttsEngine
            : ttsEngine // ignore: cast_nullable_to_non_nullable
                  as String?,
        splitLongChapter: null == splitLongChapter
            ? _self.splitLongChapter
            : splitLongChapter // ignore: cast_nullable_to_non_nullable
                  as bool,
        readSimulating: null == readSimulating
            ? _self.readSimulating
            : readSimulating // ignore: cast_nullable_to_non_nullable
                  as bool,
        startDate: freezed == startDate
            ? _self.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as String?,
        startChapter: freezed == startChapter
            ? _self.startChapter
            : startChapter // ignore: cast_nullable_to_non_nullable
                  as int?,
        dailyChapters: null == dailyChapters
            ? _self.dailyChapters
            : dailyChapters // ignore: cast_nullable_to_non_nullable
                  as int,
        openCredits: null == openCredits
            ? _self.openCredits
            : openCredits // ignore: cast_nullable_to_non_nullable
                  as int,
        closeCredits: null == closeCredits
            ? _self.closeCredits
            : closeCredits // ignore: cast_nullable_to_non_nullable
                  as int,
        playMode: null == playMode
            ? _self.playMode
            : playMode // ignore: cast_nullable_to_non_nullable
                  as int,
        playSpeed: null == playSpeed
            ? _self.playSpeed
            : playSpeed // ignore: cast_nullable_to_non_nullable
                  as double,
        mangaScrollMode: freezed == mangaScrollMode
            ? _self.mangaScrollMode
            : mangaScrollMode // ignore: cast_nullable_to_non_nullable
                  as int?,
        webtoonSidePaddingDp: freezed == webtoonSidePaddingDp
            ? _self.webtoonSidePaddingDp
            : webtoonSidePaddingDp // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ReadConfig].
extension ReadConfigPatterns on ReadConfig {
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
    TResult Function(_ReadConfig value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReadConfig() when $default != null:
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
    TResult Function(_ReadConfig value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadConfig():
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
    TResult? Function(_ReadConfig value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadConfig() when $default != null:
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
      @JsonKey(name: 'reverseToc') bool reverseToc,
      @JsonKey(name: 'pageAnim') int? pageAnim,
      @JsonKey(name: 'reSegment') bool reSegment,
      @JsonKey(name: 'imageStyle') String? imageStyle,
      @JsonKey(name: 'useReplaceRule') bool? useReplaceRule,
      @JsonKey(name: 'delTag') int delTag,
      @JsonKey(name: 'ttsEngine') String? ttsEngine,
      @JsonKey(name: 'splitLongChapter') bool splitLongChapter,
      @JsonKey(name: 'readSimulating') bool readSimulating,
      @JsonKey(name: 'startDate') String? startDate,
      @JsonKey(name: 'startChapter') int? startChapter,
      @JsonKey(name: 'dailyChapters') int dailyChapters,
      @JsonKey(name: 'openCredits') int openCredits,
      @JsonKey(name: 'closeCredits') int closeCredits,
      @JsonKey(name: 'playMode') int playMode,
      @JsonKey(name: 'playSpeed') double playSpeed,
      @JsonKey(name: 'mangaScrollMode') int? mangaScrollMode,
      @JsonKey(name: 'webtoonSidePaddingDp') int? webtoonSidePaddingDp,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReadConfig() when $default != null:
        return $default(
          _that.reverseToc,
          _that.pageAnim,
          _that.reSegment,
          _that.imageStyle,
          _that.useReplaceRule,
          _that.delTag,
          _that.ttsEngine,
          _that.splitLongChapter,
          _that.readSimulating,
          _that.startDate,
          _that.startChapter,
          _that.dailyChapters,
          _that.openCredits,
          _that.closeCredits,
          _that.playMode,
          _that.playSpeed,
          _that.mangaScrollMode,
          _that.webtoonSidePaddingDp,
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
      @JsonKey(name: 'reverseToc') bool reverseToc,
      @JsonKey(name: 'pageAnim') int? pageAnim,
      @JsonKey(name: 'reSegment') bool reSegment,
      @JsonKey(name: 'imageStyle') String? imageStyle,
      @JsonKey(name: 'useReplaceRule') bool? useReplaceRule,
      @JsonKey(name: 'delTag') int delTag,
      @JsonKey(name: 'ttsEngine') String? ttsEngine,
      @JsonKey(name: 'splitLongChapter') bool splitLongChapter,
      @JsonKey(name: 'readSimulating') bool readSimulating,
      @JsonKey(name: 'startDate') String? startDate,
      @JsonKey(name: 'startChapter') int? startChapter,
      @JsonKey(name: 'dailyChapters') int dailyChapters,
      @JsonKey(name: 'openCredits') int openCredits,
      @JsonKey(name: 'closeCredits') int closeCredits,
      @JsonKey(name: 'playMode') int playMode,
      @JsonKey(name: 'playSpeed') double playSpeed,
      @JsonKey(name: 'mangaScrollMode') int? mangaScrollMode,
      @JsonKey(name: 'webtoonSidePaddingDp') int? webtoonSidePaddingDp,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadConfig():
        return $default(
          _that.reverseToc,
          _that.pageAnim,
          _that.reSegment,
          _that.imageStyle,
          _that.useReplaceRule,
          _that.delTag,
          _that.ttsEngine,
          _that.splitLongChapter,
          _that.readSimulating,
          _that.startDate,
          _that.startChapter,
          _that.dailyChapters,
          _that.openCredits,
          _that.closeCredits,
          _that.playMode,
          _that.playSpeed,
          _that.mangaScrollMode,
          _that.webtoonSidePaddingDp,
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
      @JsonKey(name: 'reverseToc') bool reverseToc,
      @JsonKey(name: 'pageAnim') int? pageAnim,
      @JsonKey(name: 'reSegment') bool reSegment,
      @JsonKey(name: 'imageStyle') String? imageStyle,
      @JsonKey(name: 'useReplaceRule') bool? useReplaceRule,
      @JsonKey(name: 'delTag') int delTag,
      @JsonKey(name: 'ttsEngine') String? ttsEngine,
      @JsonKey(name: 'splitLongChapter') bool splitLongChapter,
      @JsonKey(name: 'readSimulating') bool readSimulating,
      @JsonKey(name: 'startDate') String? startDate,
      @JsonKey(name: 'startChapter') int? startChapter,
      @JsonKey(name: 'dailyChapters') int dailyChapters,
      @JsonKey(name: 'openCredits') int openCredits,
      @JsonKey(name: 'closeCredits') int closeCredits,
      @JsonKey(name: 'playMode') int playMode,
      @JsonKey(name: 'playSpeed') double playSpeed,
      @JsonKey(name: 'mangaScrollMode') int? mangaScrollMode,
      @JsonKey(name: 'webtoonSidePaddingDp') int? webtoonSidePaddingDp,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadConfig() when $default != null:
        return $default(
          _that.reverseToc,
          _that.pageAnim,
          _that.reSegment,
          _that.imageStyle,
          _that.useReplaceRule,
          _that.delTag,
          _that.ttsEngine,
          _that.splitLongChapter,
          _that.readSimulating,
          _that.startDate,
          _that.startChapter,
          _that.dailyChapters,
          _that.openCredits,
          _that.closeCredits,
          _that.playMode,
          _that.playSpeed,
          _that.mangaScrollMode,
          _that.webtoonSidePaddingDp,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ReadConfig implements ReadConfig {
  const _ReadConfig({
    @JsonKey(name: 'reverseToc') this.reverseToc = false,
    @JsonKey(name: 'pageAnim') this.pageAnim,
    @JsonKey(name: 'reSegment') this.reSegment = false,
    @JsonKey(name: 'imageStyle') this.imageStyle,
    @JsonKey(name: 'useReplaceRule') this.useReplaceRule,
    @JsonKey(name: 'delTag') this.delTag = 0,
    @JsonKey(name: 'ttsEngine') this.ttsEngine,
    @JsonKey(name: 'splitLongChapter') this.splitLongChapter = true,
    @JsonKey(name: 'readSimulating') this.readSimulating = false,
    @JsonKey(name: 'startDate') this.startDate,
    @JsonKey(name: 'startChapter') this.startChapter,
    @JsonKey(name: 'dailyChapters') this.dailyChapters = 3,
    @JsonKey(name: 'openCredits') this.openCredits = 0,
    @JsonKey(name: 'closeCredits') this.closeCredits = 0,
    @JsonKey(name: 'playMode') this.playMode = 0,
    @JsonKey(name: 'playSpeed') this.playSpeed = 1.0,
    @JsonKey(name: 'mangaScrollMode') this.mangaScrollMode,
    @JsonKey(name: 'webtoonSidePaddingDp') this.webtoonSidePaddingDp,
  });
  factory _ReadConfig.fromJson(Map<String, dynamic> json) =>
      _$ReadConfigFromJson(json);

  @override
  @JsonKey(name: 'reverseToc')
  final bool reverseToc;
  @override
  @JsonKey(name: 'pageAnim')
  final int? pageAnim;
  @override
  @JsonKey(name: 'reSegment')
  final bool reSegment;
  @override
  @JsonKey(name: 'imageStyle')
  final String? imageStyle;
  @override
  @JsonKey(name: 'useReplaceRule')
  final bool? useReplaceRule;
  @override
  @JsonKey(name: 'delTag')
  final int delTag;
  @override
  @JsonKey(name: 'ttsEngine')
  final String? ttsEngine;
  @override
  @JsonKey(name: 'splitLongChapter')
  final bool splitLongChapter;
  @override
  @JsonKey(name: 'readSimulating')
  final bool readSimulating;
  @override
  @JsonKey(name: 'startDate')
  final String? startDate;
  @override
  @JsonKey(name: 'startChapter')
  final int? startChapter;
  @override
  @JsonKey(name: 'dailyChapters')
  final int dailyChapters;
  @override
  @JsonKey(name: 'openCredits')
  final int openCredits;
  @override
  @JsonKey(name: 'closeCredits')
  final int closeCredits;
  @override
  @JsonKey(name: 'playMode')
  final int playMode;
  @override
  @JsonKey(name: 'playSpeed')
  final double playSpeed;

  /// [漫画设置作用域 2026-10-01] 书级翻页模式覆盖（null = 未覆盖，跟随
  /// 全局 [MangaConfigKeys.scrollMode]）。对齐参考版 `Book.ReadConfig.mangaScrollMode`
  /// 与 MangaReaderViewModel 有效值优先级 `book?.scrollMode ?: settings.scrollMode`。
  @override
  @JsonKey(name: 'mangaScrollMode')
  final int? mangaScrollMode;

  /// [漫画设置作用域 2026-10-01] 书级条漫侧边留白覆盖（null = 未覆盖，
  /// 跟随全局 [MangaConfigKeys.sidePadding]）。
  ///
  /// 键名对齐参考版 `Book.ReadConfig.webtoonSidePaddingDp`，但数值沿用
  /// Flutter 既有百分比口径 0..45（每侧留白 = 视口宽 × p/100），与参考版
  /// 字段仅做作用域对齐，**不做 dp/百分比换算**（无明确换算规则前禁止混用单位）。
  @override
  @JsonKey(name: 'webtoonSidePaddingDp')
  final int? webtoonSidePaddingDp;

  /// Create a copy of ReadConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReadConfigCopyWith<_ReadConfig> get copyWith =>
      __$ReadConfigCopyWithImpl<_ReadConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ReadConfigToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReadConfig &&
            (identical(other.reverseToc, reverseToc) ||
                other.reverseToc == reverseToc) &&
            (identical(other.pageAnim, pageAnim) ||
                other.pageAnim == pageAnim) &&
            (identical(other.reSegment, reSegment) ||
                other.reSegment == reSegment) &&
            (identical(other.imageStyle, imageStyle) ||
                other.imageStyle == imageStyle) &&
            (identical(other.useReplaceRule, useReplaceRule) ||
                other.useReplaceRule == useReplaceRule) &&
            (identical(other.delTag, delTag) || other.delTag == delTag) &&
            (identical(other.ttsEngine, ttsEngine) ||
                other.ttsEngine == ttsEngine) &&
            (identical(other.splitLongChapter, splitLongChapter) ||
                other.splitLongChapter == splitLongChapter) &&
            (identical(other.readSimulating, readSimulating) ||
                other.readSimulating == readSimulating) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.startChapter, startChapter) ||
                other.startChapter == startChapter) &&
            (identical(other.dailyChapters, dailyChapters) ||
                other.dailyChapters == dailyChapters) &&
            (identical(other.openCredits, openCredits) ||
                other.openCredits == openCredits) &&
            (identical(other.closeCredits, closeCredits) ||
                other.closeCredits == closeCredits) &&
            (identical(other.playMode, playMode) ||
                other.playMode == playMode) &&
            (identical(other.playSpeed, playSpeed) ||
                other.playSpeed == playSpeed) &&
            (identical(other.mangaScrollMode, mangaScrollMode) ||
                other.mangaScrollMode == mangaScrollMode) &&
            (identical(other.webtoonSidePaddingDp, webtoonSidePaddingDp) ||
                other.webtoonSidePaddingDp == webtoonSidePaddingDp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      reverseToc,
      pageAnim,
      reSegment,
      imageStyle,
      useReplaceRule,
      delTag,
      ttsEngine,
      splitLongChapter,
      readSimulating,
      startDate,
      startChapter,
      dailyChapters,
      openCredits,
      closeCredits,
      playMode,
      playSpeed,
      mangaScrollMode,
      webtoonSidePaddingDp,
    );
  }

  @override
  String toString() {
    return 'ReadConfig(reverseToc: $reverseToc, pageAnim: $pageAnim, reSegment: $reSegment, imageStyle: $imageStyle, useReplaceRule: $useReplaceRule, delTag: $delTag, ttsEngine: $ttsEngine, splitLongChapter: $splitLongChapter, readSimulating: $readSimulating, startDate: $startDate, startChapter: $startChapter, dailyChapters: $dailyChapters, openCredits: $openCredits, closeCredits: $closeCredits, playMode: $playMode, playSpeed: $playSpeed, mangaScrollMode: $mangaScrollMode, webtoonSidePaddingDp: $webtoonSidePaddingDp)';
  }
}

/// @nodoc
abstract mixin class _$ReadConfigCopyWith<$Res>
    implements $ReadConfigCopyWith<$Res> {
  factory _$ReadConfigCopyWith(
    _ReadConfig value,
    $Res Function(_ReadConfig) _then,
  ) = __$ReadConfigCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'reverseToc') bool reverseToc,
    @JsonKey(name: 'pageAnim') int? pageAnim,
    @JsonKey(name: 'reSegment') bool reSegment,
    @JsonKey(name: 'imageStyle') String? imageStyle,
    @JsonKey(name: 'useReplaceRule') bool? useReplaceRule,
    @JsonKey(name: 'delTag') int delTag,
    @JsonKey(name: 'ttsEngine') String? ttsEngine,
    @JsonKey(name: 'splitLongChapter') bool splitLongChapter,
    @JsonKey(name: 'readSimulating') bool readSimulating,
    @JsonKey(name: 'startDate') String? startDate,
    @JsonKey(name: 'startChapter') int? startChapter,
    @JsonKey(name: 'dailyChapters') int dailyChapters,
    @JsonKey(name: 'openCredits') int openCredits,
    @JsonKey(name: 'closeCredits') int closeCredits,
    @JsonKey(name: 'playMode') int playMode,
    @JsonKey(name: 'playSpeed') double playSpeed,
    @JsonKey(name: 'mangaScrollMode') int? mangaScrollMode,
    @JsonKey(name: 'webtoonSidePaddingDp') int? webtoonSidePaddingDp,
  });
}

/// @nodoc
class __$ReadConfigCopyWithImpl<$Res> implements _$ReadConfigCopyWith<$Res> {
  __$ReadConfigCopyWithImpl(this._self, this._then);

  final _ReadConfig _self;
  final $Res Function(_ReadConfig) _then;

  /// Create a copy of ReadConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? reverseToc = null,
    Object? pageAnim = freezed,
    Object? reSegment = null,
    Object? imageStyle = freezed,
    Object? useReplaceRule = freezed,
    Object? delTag = null,
    Object? ttsEngine = freezed,
    Object? splitLongChapter = null,
    Object? readSimulating = null,
    Object? startDate = freezed,
    Object? startChapter = freezed,
    Object? dailyChapters = null,
    Object? openCredits = null,
    Object? closeCredits = null,
    Object? playMode = null,
    Object? playSpeed = null,
    Object? mangaScrollMode = freezed,
    Object? webtoonSidePaddingDp = freezed,
  }) {
    return _then(
      _ReadConfig(
        reverseToc: null == reverseToc
            ? _self.reverseToc
            : reverseToc // ignore: cast_nullable_to_non_nullable
                  as bool,
        pageAnim: freezed == pageAnim
            ? _self.pageAnim
            : pageAnim // ignore: cast_nullable_to_non_nullable
                  as int?,
        reSegment: null == reSegment
            ? _self.reSegment
            : reSegment // ignore: cast_nullable_to_non_nullable
                  as bool,
        imageStyle: freezed == imageStyle
            ? _self.imageStyle
            : imageStyle // ignore: cast_nullable_to_non_nullable
                  as String?,
        useReplaceRule: freezed == useReplaceRule
            ? _self.useReplaceRule
            : useReplaceRule // ignore: cast_nullable_to_non_nullable
                  as bool?,
        delTag: null == delTag
            ? _self.delTag
            : delTag // ignore: cast_nullable_to_non_nullable
                  as int,
        ttsEngine: freezed == ttsEngine
            ? _self.ttsEngine
            : ttsEngine // ignore: cast_nullable_to_non_nullable
                  as String?,
        splitLongChapter: null == splitLongChapter
            ? _self.splitLongChapter
            : splitLongChapter // ignore: cast_nullable_to_non_nullable
                  as bool,
        readSimulating: null == readSimulating
            ? _self.readSimulating
            : readSimulating // ignore: cast_nullable_to_non_nullable
                  as bool,
        startDate: freezed == startDate
            ? _self.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as String?,
        startChapter: freezed == startChapter
            ? _self.startChapter
            : startChapter // ignore: cast_nullable_to_non_nullable
                  as int?,
        dailyChapters: null == dailyChapters
            ? _self.dailyChapters
            : dailyChapters // ignore: cast_nullable_to_non_nullable
                  as int,
        openCredits: null == openCredits
            ? _self.openCredits
            : openCredits // ignore: cast_nullable_to_non_nullable
                  as int,
        closeCredits: null == closeCredits
            ? _self.closeCredits
            : closeCredits // ignore: cast_nullable_to_non_nullable
                  as int,
        playMode: null == playMode
            ? _self.playMode
            : playMode // ignore: cast_nullable_to_non_nullable
                  as int,
        playSpeed: null == playSpeed
            ? _self.playSpeed
            : playSpeed // ignore: cast_nullable_to_non_nullable
                  as double,
        mangaScrollMode: freezed == mangaScrollMode
            ? _self.mangaScrollMode
            : mangaScrollMode // ignore: cast_nullable_to_non_nullable
                  as int?,
        webtoonSidePaddingDp: freezed == webtoonSidePaddingDp
            ? _self.webtoonSidePaddingDp
            : webtoonSidePaddingDp // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
mixin _$Book {
  @JsonKey(name: 'bookUrl')
  String get bookUrl;
  bool get isPrivate;
  @JsonKey(name: 'tocUrl')
  String get tocUrl;
  String get origin;
  @JsonKey(name: 'originName')
  String get originName;
  String get name;
  String get author;
  String? get kind;
  @JsonKey(name: 'customTag')
  String? get customTag;
  @JsonKey(name: 'coverUrl')
  String? get coverUrl;
  @JsonKey(name: 'customCoverUrl')
  String? get customCoverUrl;
  String? get intro;
  @JsonKey(name: 'customIntro')
  String? get customIntro;
  String? get charset;
  @JsonKey(name: 'type')
  int get bookType;
  int get group;
  @JsonKey(name: 'latestChapterTitle')
  String? get latestChapterTitle;
  @JsonKey(name: 'latestChapterTime')
  int get latestChapterTime;
  @JsonKey(name: 'lastCheckTime')
  int get lastCheckTime;
  @JsonKey(name: 'lastCheckCount')
  int get lastCheckCount;
  @JsonKey(name: 'totalChapterNum')
  int get totalChapterNum;
  @JsonKey(name: 'durChapterTitle')
  String? get durChapterTitle;
  @JsonKey(name: 'durChapterIndex')
  int get durChapterIndex;
  @JsonKey(name: 'durVolumeIndex')
  int get durVolumeIndex;
  @JsonKey(name: 'chapterInVolumeIndex')
  int get chapterInVolumeIndex;
  @JsonKey(name: 'durChapterPos')
  int get durChapterPos;
  @JsonKey(name: 'durChapterTime')
  int get durChapterTime;
  @JsonKey(name: 'wordCount')
  String? get wordCount;
  @JsonKey(name: 'canUpdate')
  bool get canUpdate;
  int get order;
  @JsonKey(name: 'originOrder')
  int get originOrder;
  String? get variable;
  @JsonKey(name: 'readConfig')
  ReadConfig? get readConfig;
  @JsonKey(name: 'syncTime')
  int get syncTime;

  /// [P2-8] 当前书源下该书的详情页地址（换源事务写入；bookUrl 保持
  /// 稳定主键不变，换源后可能仍是旧源地址）。为空时「抓取书籍页」
  /// 路径回退 bookUrl（未换源书籍与存量库行为不变，向后兼容）。
  @JsonKey(name: 'originBookUrl')
  String get originBookUrl;

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookCopyWith<Book> get copyWith =>
      _$BookCopyWithImpl<Book>(this as Book, _$identity);

  /// Serializes this Book to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as Book;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Book &&
            (identical(other.bookUrl, _this.bookUrl) ||
                other.bookUrl == _this.bookUrl) &&
            (identical(other.isPrivate, _this.isPrivate) ||
                other.isPrivate == _this.isPrivate) &&
            (identical(other.tocUrl, _this.tocUrl) ||
                other.tocUrl == _this.tocUrl) &&
            (identical(other.origin, _this.origin) ||
                other.origin == _this.origin) &&
            (identical(other.originName, _this.originName) ||
                other.originName == _this.originName) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.author, _this.author) ||
                other.author == _this.author) &&
            (identical(other.kind, _this.kind) || other.kind == _this.kind) &&
            (identical(other.customTag, _this.customTag) ||
                other.customTag == _this.customTag) &&
            (identical(other.coverUrl, _this.coverUrl) ||
                other.coverUrl == _this.coverUrl) &&
            (identical(other.customCoverUrl, _this.customCoverUrl) ||
                other.customCoverUrl == _this.customCoverUrl) &&
            (identical(other.intro, _this.intro) ||
                other.intro == _this.intro) &&
            (identical(other.customIntro, _this.customIntro) ||
                other.customIntro == _this.customIntro) &&
            (identical(other.charset, _this.charset) ||
                other.charset == _this.charset) &&
            (identical(other.bookType, _this.bookType) ||
                other.bookType == _this.bookType) &&
            (identical(other.group, _this.group) ||
                other.group == _this.group) &&
            (identical(other.latestChapterTitle, _this.latestChapterTitle) ||
                other.latestChapterTitle == _this.latestChapterTitle) &&
            (identical(other.latestChapterTime, _this.latestChapterTime) ||
                other.latestChapterTime == _this.latestChapterTime) &&
            (identical(other.lastCheckTime, _this.lastCheckTime) ||
                other.lastCheckTime == _this.lastCheckTime) &&
            (identical(other.lastCheckCount, _this.lastCheckCount) ||
                other.lastCheckCount == _this.lastCheckCount) &&
            (identical(other.totalChapterNum, _this.totalChapterNum) ||
                other.totalChapterNum == _this.totalChapterNum) &&
            (identical(other.durChapterTitle, _this.durChapterTitle) ||
                other.durChapterTitle == _this.durChapterTitle) &&
            (identical(other.durChapterIndex, _this.durChapterIndex) ||
                other.durChapterIndex == _this.durChapterIndex) &&
            (identical(other.durVolumeIndex, _this.durVolumeIndex) ||
                other.durVolumeIndex == _this.durVolumeIndex) &&
            (identical(
                  other.chapterInVolumeIndex,
                  _this.chapterInVolumeIndex,
                ) ||
                other.chapterInVolumeIndex == _this.chapterInVolumeIndex) &&
            (identical(other.durChapterPos, _this.durChapterPos) ||
                other.durChapterPos == _this.durChapterPos) &&
            (identical(other.durChapterTime, _this.durChapterTime) ||
                other.durChapterTime == _this.durChapterTime) &&
            (identical(other.wordCount, _this.wordCount) ||
                other.wordCount == _this.wordCount) &&
            (identical(other.canUpdate, _this.canUpdate) ||
                other.canUpdate == _this.canUpdate) &&
            (identical(other.order, _this.order) ||
                other.order == _this.order) &&
            (identical(other.originOrder, _this.originOrder) ||
                other.originOrder == _this.originOrder) &&
            (identical(other.variable, _this.variable) ||
                other.variable == _this.variable) &&
            (identical(other.readConfig, _this.readConfig) ||
                other.readConfig == _this.readConfig) &&
            (identical(other.syncTime, _this.syncTime) ||
                other.syncTime == _this.syncTime) &&
            (identical(other.originBookUrl, _this.originBookUrl) ||
                other.originBookUrl == _this.originBookUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as Book;
    return Object.hashAll([
      runtimeType,
      _this.bookUrl,
      _this.isPrivate,
      _this.tocUrl,
      _this.origin,
      _this.originName,
      _this.name,
      _this.author,
      _this.kind,
      _this.customTag,
      _this.coverUrl,
      _this.customCoverUrl,
      _this.intro,
      _this.customIntro,
      _this.charset,
      _this.bookType,
      _this.group,
      _this.latestChapterTitle,
      _this.latestChapterTime,
      _this.lastCheckTime,
      _this.lastCheckCount,
      _this.totalChapterNum,
      _this.durChapterTitle,
      _this.durChapterIndex,
      _this.durVolumeIndex,
      _this.chapterInVolumeIndex,
      _this.durChapterPos,
      _this.durChapterTime,
      _this.wordCount,
      _this.canUpdate,
      _this.order,
      _this.originOrder,
      _this.variable,
      _this.readConfig,
      _this.syncTime,
      _this.originBookUrl,
    ]);
  }

  @override
  String toString() {
    final _this = this as Book;
    return 'Book(bookUrl: ${_this.bookUrl}, isPrivate: ${_this.isPrivate}, tocUrl: ${_this.tocUrl}, origin: ${_this.origin}, originName: ${_this.originName}, name: ${_this.name}, author: ${_this.author}, kind: ${_this.kind}, customTag: ${_this.customTag}, coverUrl: ${_this.coverUrl}, customCoverUrl: ${_this.customCoverUrl}, intro: ${_this.intro}, customIntro: ${_this.customIntro}, charset: ${_this.charset}, bookType: ${_this.bookType}, group: ${_this.group}, latestChapterTitle: ${_this.latestChapterTitle}, latestChapterTime: ${_this.latestChapterTime}, lastCheckTime: ${_this.lastCheckTime}, lastCheckCount: ${_this.lastCheckCount}, totalChapterNum: ${_this.totalChapterNum}, durChapterTitle: ${_this.durChapterTitle}, durChapterIndex: ${_this.durChapterIndex}, durVolumeIndex: ${_this.durVolumeIndex}, chapterInVolumeIndex: ${_this.chapterInVolumeIndex}, durChapterPos: ${_this.durChapterPos}, durChapterTime: ${_this.durChapterTime}, wordCount: ${_this.wordCount}, canUpdate: ${_this.canUpdate}, order: ${_this.order}, originOrder: ${_this.originOrder}, variable: ${_this.variable}, readConfig: ${_this.readConfig}, syncTime: ${_this.syncTime}, originBookUrl: ${_this.originBookUrl})';
  }
}

/// @nodoc
abstract mixin class $BookCopyWith<$Res> {
  factory $BookCopyWith(Book value, $Res Function(Book) _then) =
      _$BookCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'bookUrl') String bookUrl,
    bool isPrivate,
    @JsonKey(name: 'tocUrl') String tocUrl,
    String origin,
    @JsonKey(name: 'originName') String originName,
    String name,
    String author,
    String? kind,
    @JsonKey(name: 'customTag') String? customTag,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    @JsonKey(name: 'customCoverUrl') String? customCoverUrl,
    String? intro,
    @JsonKey(name: 'customIntro') String? customIntro,
    String? charset,
    @JsonKey(name: 'type') int bookType,
    int group,
    @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
    @JsonKey(name: 'latestChapterTime') int latestChapterTime,
    @JsonKey(name: 'lastCheckTime') int lastCheckTime,
    @JsonKey(name: 'lastCheckCount') int lastCheckCount,
    @JsonKey(name: 'totalChapterNum') int totalChapterNum,
    @JsonKey(name: 'durChapterTitle') String? durChapterTitle,
    @JsonKey(name: 'durChapterIndex') int durChapterIndex,
    @JsonKey(name: 'durVolumeIndex') int durVolumeIndex,
    @JsonKey(name: 'chapterInVolumeIndex') int chapterInVolumeIndex,
    @JsonKey(name: 'durChapterPos') int durChapterPos,
    @JsonKey(name: 'durChapterTime') int durChapterTime,
    @JsonKey(name: 'wordCount') String? wordCount,
    @JsonKey(name: 'canUpdate') bool canUpdate,
    int order,
    @JsonKey(name: 'originOrder') int originOrder,
    String? variable,
    @JsonKey(name: 'readConfig') ReadConfig? readConfig,
    @JsonKey(name: 'syncTime') int syncTime,
    @JsonKey(name: 'originBookUrl') String originBookUrl,
  });

  $ReadConfigCopyWith<$Res>? get readConfig;
}

/// @nodoc
class _$BookCopyWithImpl<$Res> implements $BookCopyWith<$Res> {
  _$BookCopyWithImpl(this._self, this._then);

  final Book _self;
  final $Res Function(Book) _then;

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookUrl = null,
    Object? isPrivate = null,
    Object? tocUrl = null,
    Object? origin = null,
    Object? originName = null,
    Object? name = null,
    Object? author = null,
    Object? kind = freezed,
    Object? customTag = freezed,
    Object? coverUrl = freezed,
    Object? customCoverUrl = freezed,
    Object? intro = freezed,
    Object? customIntro = freezed,
    Object? charset = freezed,
    Object? bookType = null,
    Object? group = null,
    Object? latestChapterTitle = freezed,
    Object? latestChapterTime = null,
    Object? lastCheckTime = null,
    Object? lastCheckCount = null,
    Object? totalChapterNum = null,
    Object? durChapterTitle = freezed,
    Object? durChapterIndex = null,
    Object? durVolumeIndex = null,
    Object? chapterInVolumeIndex = null,
    Object? durChapterPos = null,
    Object? durChapterTime = null,
    Object? wordCount = freezed,
    Object? canUpdate = null,
    Object? order = null,
    Object? originOrder = null,
    Object? variable = freezed,
    Object? readConfig = freezed,
    Object? syncTime = null,
    Object? originBookUrl = null,
  }) {
    return _then(
      Book(
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        isPrivate: null == isPrivate
            ? _self.isPrivate
            : isPrivate // ignore: cast_nullable_to_non_nullable
                  as bool,
        tocUrl: null == tocUrl
            ? _self.tocUrl
            : tocUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        originName: null == originName
            ? _self.originName
            : originName // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        kind: freezed == kind
            ? _self.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String?,
        customTag: freezed == customTag
            ? _self.customTag
            : customTag // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        customCoverUrl: freezed == customCoverUrl
            ? _self.customCoverUrl
            : customCoverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        customIntro: freezed == customIntro
            ? _self.customIntro
            : customIntro // ignore: cast_nullable_to_non_nullable
                  as String?,
        charset: freezed == charset
            ? _self.charset
            : charset // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookType: null == bookType
            ? _self.bookType
            : bookType // ignore: cast_nullable_to_non_nullable
                  as int,
        group: null == group
            ? _self.group
            : group // ignore: cast_nullable_to_non_nullable
                  as int,
        latestChapterTitle: freezed == latestChapterTitle
            ? _self.latestChapterTitle
            : latestChapterTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        latestChapterTime: null == latestChapterTime
            ? _self.latestChapterTime
            : latestChapterTime // ignore: cast_nullable_to_non_nullable
                  as int,
        lastCheckTime: null == lastCheckTime
            ? _self.lastCheckTime
            : lastCheckTime // ignore: cast_nullable_to_non_nullable
                  as int,
        lastCheckCount: null == lastCheckCount
            ? _self.lastCheckCount
            : lastCheckCount // ignore: cast_nullable_to_non_nullable
                  as int,
        totalChapterNum: null == totalChapterNum
            ? _self.totalChapterNum
            : totalChapterNum // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterTitle: freezed == durChapterTitle
            ? _self.durChapterTitle
            : durChapterTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        durChapterIndex: null == durChapterIndex
            ? _self.durChapterIndex
            : durChapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        durVolumeIndex: null == durVolumeIndex
            ? _self.durVolumeIndex
            : durVolumeIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterInVolumeIndex: null == chapterInVolumeIndex
            ? _self.chapterInVolumeIndex
            : chapterInVolumeIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterPos: null == durChapterPos
            ? _self.durChapterPos
            : durChapterPos // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterTime: null == durChapterTime
            ? _self.durChapterTime
            : durChapterTime // ignore: cast_nullable_to_non_nullable
                  as int,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        canUpdate: null == canUpdate
            ? _self.canUpdate
            : canUpdate // ignore: cast_nullable_to_non_nullable
                  as bool,
        order: null == order
            ? _self.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        originOrder: null == originOrder
            ? _self.originOrder
            : originOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        variable: freezed == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String?,
        readConfig: freezed == readConfig
            ? _self.readConfig
            : readConfig // ignore: cast_nullable_to_non_nullable
                  as ReadConfig?,
        syncTime: null == syncTime
            ? _self.syncTime
            : syncTime // ignore: cast_nullable_to_non_nullable
                  as int,
        originBookUrl: null == originBookUrl
            ? _self.originBookUrl
            : originBookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ReadConfigCopyWith<$Res>? get readConfig {
    if (_self.readConfig == null) {
      return null;
    }

    return $ReadConfigCopyWith<$Res>(_self.readConfig!, (value) {
      return _then(_self.copyWith(readConfig: value));
    });
  }
}

/// Adds pattern-matching-related methods to [Book].
extension BookPatterns on Book {
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
    TResult Function(_Book value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Book() when $default != null:
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
  TResult map<TResult extends Object?>(TResult Function(_Book value) $default) {
    final _that = this;
    switch (_that) {
      case _Book():
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
    TResult? Function(_Book value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Book() when $default != null:
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
      @JsonKey(name: 'bookUrl') String bookUrl,
      bool isPrivate,
      @JsonKey(name: 'tocUrl') String tocUrl,
      String origin,
      @JsonKey(name: 'originName') String originName,
      String name,
      String author,
      String? kind,
      @JsonKey(name: 'customTag') String? customTag,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'customCoverUrl') String? customCoverUrl,
      String? intro,
      @JsonKey(name: 'customIntro') String? customIntro,
      String? charset,
      @JsonKey(name: 'type') int bookType,
      int group,
      @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
      @JsonKey(name: 'latestChapterTime') int latestChapterTime,
      @JsonKey(name: 'lastCheckTime') int lastCheckTime,
      @JsonKey(name: 'lastCheckCount') int lastCheckCount,
      @JsonKey(name: 'totalChapterNum') int totalChapterNum,
      @JsonKey(name: 'durChapterTitle') String? durChapterTitle,
      @JsonKey(name: 'durChapterIndex') int durChapterIndex,
      @JsonKey(name: 'durVolumeIndex') int durVolumeIndex,
      @JsonKey(name: 'chapterInVolumeIndex') int chapterInVolumeIndex,
      @JsonKey(name: 'durChapterPos') int durChapterPos,
      @JsonKey(name: 'durChapterTime') int durChapterTime,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'canUpdate') bool canUpdate,
      int order,
      @JsonKey(name: 'originOrder') int originOrder,
      String? variable,
      @JsonKey(name: 'readConfig') ReadConfig? readConfig,
      @JsonKey(name: 'syncTime') int syncTime,
      @JsonKey(name: 'originBookUrl') String originBookUrl,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Book() when $default != null:
        return $default(
          _that.bookUrl,
          _that.isPrivate,
          _that.tocUrl,
          _that.origin,
          _that.originName,
          _that.name,
          _that.author,
          _that.kind,
          _that.customTag,
          _that.coverUrl,
          _that.customCoverUrl,
          _that.intro,
          _that.customIntro,
          _that.charset,
          _that.bookType,
          _that.group,
          _that.latestChapterTitle,
          _that.latestChapterTime,
          _that.lastCheckTime,
          _that.lastCheckCount,
          _that.totalChapterNum,
          _that.durChapterTitle,
          _that.durChapterIndex,
          _that.durVolumeIndex,
          _that.chapterInVolumeIndex,
          _that.durChapterPos,
          _that.durChapterTime,
          _that.wordCount,
          _that.canUpdate,
          _that.order,
          _that.originOrder,
          _that.variable,
          _that.readConfig,
          _that.syncTime,
          _that.originBookUrl,
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
      @JsonKey(name: 'bookUrl') String bookUrl,
      bool isPrivate,
      @JsonKey(name: 'tocUrl') String tocUrl,
      String origin,
      @JsonKey(name: 'originName') String originName,
      String name,
      String author,
      String? kind,
      @JsonKey(name: 'customTag') String? customTag,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'customCoverUrl') String? customCoverUrl,
      String? intro,
      @JsonKey(name: 'customIntro') String? customIntro,
      String? charset,
      @JsonKey(name: 'type') int bookType,
      int group,
      @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
      @JsonKey(name: 'latestChapterTime') int latestChapterTime,
      @JsonKey(name: 'lastCheckTime') int lastCheckTime,
      @JsonKey(name: 'lastCheckCount') int lastCheckCount,
      @JsonKey(name: 'totalChapterNum') int totalChapterNum,
      @JsonKey(name: 'durChapterTitle') String? durChapterTitle,
      @JsonKey(name: 'durChapterIndex') int durChapterIndex,
      @JsonKey(name: 'durVolumeIndex') int durVolumeIndex,
      @JsonKey(name: 'chapterInVolumeIndex') int chapterInVolumeIndex,
      @JsonKey(name: 'durChapterPos') int durChapterPos,
      @JsonKey(name: 'durChapterTime') int durChapterTime,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'canUpdate') bool canUpdate,
      int order,
      @JsonKey(name: 'originOrder') int originOrder,
      String? variable,
      @JsonKey(name: 'readConfig') ReadConfig? readConfig,
      @JsonKey(name: 'syncTime') int syncTime,
      @JsonKey(name: 'originBookUrl') String originBookUrl,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Book():
        return $default(
          _that.bookUrl,
          _that.isPrivate,
          _that.tocUrl,
          _that.origin,
          _that.originName,
          _that.name,
          _that.author,
          _that.kind,
          _that.customTag,
          _that.coverUrl,
          _that.customCoverUrl,
          _that.intro,
          _that.customIntro,
          _that.charset,
          _that.bookType,
          _that.group,
          _that.latestChapterTitle,
          _that.latestChapterTime,
          _that.lastCheckTime,
          _that.lastCheckCount,
          _that.totalChapterNum,
          _that.durChapterTitle,
          _that.durChapterIndex,
          _that.durVolumeIndex,
          _that.chapterInVolumeIndex,
          _that.durChapterPos,
          _that.durChapterTime,
          _that.wordCount,
          _that.canUpdate,
          _that.order,
          _that.originOrder,
          _that.variable,
          _that.readConfig,
          _that.syncTime,
          _that.originBookUrl,
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
      @JsonKey(name: 'bookUrl') String bookUrl,
      bool isPrivate,
      @JsonKey(name: 'tocUrl') String tocUrl,
      String origin,
      @JsonKey(name: 'originName') String originName,
      String name,
      String author,
      String? kind,
      @JsonKey(name: 'customTag') String? customTag,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'customCoverUrl') String? customCoverUrl,
      String? intro,
      @JsonKey(name: 'customIntro') String? customIntro,
      String? charset,
      @JsonKey(name: 'type') int bookType,
      int group,
      @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
      @JsonKey(name: 'latestChapterTime') int latestChapterTime,
      @JsonKey(name: 'lastCheckTime') int lastCheckTime,
      @JsonKey(name: 'lastCheckCount') int lastCheckCount,
      @JsonKey(name: 'totalChapterNum') int totalChapterNum,
      @JsonKey(name: 'durChapterTitle') String? durChapterTitle,
      @JsonKey(name: 'durChapterIndex') int durChapterIndex,
      @JsonKey(name: 'durVolumeIndex') int durVolumeIndex,
      @JsonKey(name: 'chapterInVolumeIndex') int chapterInVolumeIndex,
      @JsonKey(name: 'durChapterPos') int durChapterPos,
      @JsonKey(name: 'durChapterTime') int durChapterTime,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'canUpdate') bool canUpdate,
      int order,
      @JsonKey(name: 'originOrder') int originOrder,
      String? variable,
      @JsonKey(name: 'readConfig') ReadConfig? readConfig,
      @JsonKey(name: 'syncTime') int syncTime,
      @JsonKey(name: 'originBookUrl') String originBookUrl,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Book() when $default != null:
        return $default(
          _that.bookUrl,
          _that.isPrivate,
          _that.tocUrl,
          _that.origin,
          _that.originName,
          _that.name,
          _that.author,
          _that.kind,
          _that.customTag,
          _that.coverUrl,
          _that.customCoverUrl,
          _that.intro,
          _that.customIntro,
          _that.charset,
          _that.bookType,
          _that.group,
          _that.latestChapterTitle,
          _that.latestChapterTime,
          _that.lastCheckTime,
          _that.lastCheckCount,
          _that.totalChapterNum,
          _that.durChapterTitle,
          _that.durChapterIndex,
          _that.durVolumeIndex,
          _that.chapterInVolumeIndex,
          _that.durChapterPos,
          _that.durChapterTime,
          _that.wordCount,
          _that.canUpdate,
          _that.order,
          _that.originOrder,
          _that.variable,
          _that.readConfig,
          _that.syncTime,
          _that.originBookUrl,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Book implements Book {
  const _Book({
    @JsonKey(name: 'bookUrl') this.bookUrl = '',
    this.isPrivate = false,
    @JsonKey(name: 'tocUrl') this.tocUrl = '',
    this.origin = 'loc_book',
    @JsonKey(name: 'originName') this.originName = '',
    this.name = '',
    this.author = '',
    this.kind,
    @JsonKey(name: 'customTag') this.customTag,
    @JsonKey(name: 'coverUrl') this.coverUrl,
    @JsonKey(name: 'customCoverUrl') this.customCoverUrl,
    this.intro,
    @JsonKey(name: 'customIntro') this.customIntro,
    this.charset,
    @JsonKey(name: 'type') this.bookType = 0,
    this.group = 0,
    @JsonKey(name: 'latestChapterTitle') this.latestChapterTitle,
    @JsonKey(name: 'latestChapterTime') this.latestChapterTime = 0,
    @JsonKey(name: 'lastCheckTime') this.lastCheckTime = 0,
    @JsonKey(name: 'lastCheckCount') this.lastCheckCount = 0,
    @JsonKey(name: 'totalChapterNum') this.totalChapterNum = 0,
    @JsonKey(name: 'durChapterTitle') this.durChapterTitle,
    @JsonKey(name: 'durChapterIndex') this.durChapterIndex = 0,
    @JsonKey(name: 'durVolumeIndex') this.durVolumeIndex = 0,
    @JsonKey(name: 'chapterInVolumeIndex') this.chapterInVolumeIndex = 0,
    @JsonKey(name: 'durChapterPos') this.durChapterPos = 0,
    @JsonKey(name: 'durChapterTime') this.durChapterTime = 0,
    @JsonKey(name: 'wordCount') this.wordCount,
    @JsonKey(name: 'canUpdate') this.canUpdate = true,
    this.order = 0,
    @JsonKey(name: 'originOrder') this.originOrder = 0,
    this.variable,
    @JsonKey(name: 'readConfig') this.readConfig,
    @JsonKey(name: 'syncTime') this.syncTime = 0,
    @JsonKey(name: 'originBookUrl') this.originBookUrl = '',
  });
  factory _Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);

  @override
  @JsonKey(name: 'bookUrl')
  final String bookUrl;
  @override
  @JsonKey()
  final bool isPrivate;
  @override
  @JsonKey(name: 'tocUrl')
  final String tocUrl;
  @override
  @JsonKey()
  final String origin;
  @override
  @JsonKey(name: 'originName')
  final String originName;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String author;
  @override
  final String? kind;
  @override
  @JsonKey(name: 'customTag')
  final String? customTag;
  @override
  @JsonKey(name: 'coverUrl')
  final String? coverUrl;
  @override
  @JsonKey(name: 'customCoverUrl')
  final String? customCoverUrl;
  @override
  final String? intro;
  @override
  @JsonKey(name: 'customIntro')
  final String? customIntro;
  @override
  final String? charset;
  @override
  @JsonKey(name: 'type')
  final int bookType;
  @override
  @JsonKey()
  final int group;
  @override
  @JsonKey(name: 'latestChapterTitle')
  final String? latestChapterTitle;
  @override
  @JsonKey(name: 'latestChapterTime')
  final int latestChapterTime;
  @override
  @JsonKey(name: 'lastCheckTime')
  final int lastCheckTime;
  @override
  @JsonKey(name: 'lastCheckCount')
  final int lastCheckCount;
  @override
  @JsonKey(name: 'totalChapterNum')
  final int totalChapterNum;
  @override
  @JsonKey(name: 'durChapterTitle')
  final String? durChapterTitle;
  @override
  @JsonKey(name: 'durChapterIndex')
  final int durChapterIndex;
  @override
  @JsonKey(name: 'durVolumeIndex')
  final int durVolumeIndex;
  @override
  @JsonKey(name: 'chapterInVolumeIndex')
  final int chapterInVolumeIndex;
  @override
  @JsonKey(name: 'durChapterPos')
  final int durChapterPos;
  @override
  @JsonKey(name: 'durChapterTime')
  final int durChapterTime;
  @override
  @JsonKey(name: 'wordCount')
  final String? wordCount;
  @override
  @JsonKey(name: 'canUpdate')
  final bool canUpdate;
  @override
  @JsonKey()
  final int order;
  @override
  @JsonKey(name: 'originOrder')
  final int originOrder;
  @override
  final String? variable;
  @override
  @JsonKey(name: 'readConfig')
  final ReadConfig? readConfig;
  @override
  @JsonKey(name: 'syncTime')
  final int syncTime;

  /// [P2-8] 当前书源下该书的详情页地址（换源事务写入；bookUrl 保持
  /// 稳定主键不变，换源后可能仍是旧源地址）。为空时「抓取书籍页」
  /// 路径回退 bookUrl（未换源书籍与存量库行为不变，向后兼容）。
  @override
  @JsonKey(name: 'originBookUrl')
  final String originBookUrl;

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookCopyWith<_Book> get copyWith =>
      __$BookCopyWithImpl<_Book>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BookToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Book &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl) &&
            (identical(other.isPrivate, isPrivate) ||
                other.isPrivate == isPrivate) &&
            (identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.originName, originName) ||
                other.originName == originName) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.customTag, customTag) ||
                other.customTag == customTag) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.customCoverUrl, customCoverUrl) ||
                other.customCoverUrl == customCoverUrl) &&
            (identical(other.intro, intro) || other.intro == intro) &&
            (identical(other.customIntro, customIntro) ||
                other.customIntro == customIntro) &&
            (identical(other.charset, charset) || other.charset == charset) &&
            (identical(other.bookType, bookType) ||
                other.bookType == bookType) &&
            (identical(other.group, group) || other.group == group) &&
            (identical(other.latestChapterTitle, latestChapterTitle) ||
                other.latestChapterTitle == latestChapterTitle) &&
            (identical(other.latestChapterTime, latestChapterTime) ||
                other.latestChapterTime == latestChapterTime) &&
            (identical(other.lastCheckTime, lastCheckTime) ||
                other.lastCheckTime == lastCheckTime) &&
            (identical(other.lastCheckCount, lastCheckCount) ||
                other.lastCheckCount == lastCheckCount) &&
            (identical(other.totalChapterNum, totalChapterNum) ||
                other.totalChapterNum == totalChapterNum) &&
            (identical(other.durChapterTitle, durChapterTitle) ||
                other.durChapterTitle == durChapterTitle) &&
            (identical(other.durChapterIndex, durChapterIndex) ||
                other.durChapterIndex == durChapterIndex) &&
            (identical(other.durVolumeIndex, durVolumeIndex) ||
                other.durVolumeIndex == durVolumeIndex) &&
            (identical(other.chapterInVolumeIndex, chapterInVolumeIndex) ||
                other.chapterInVolumeIndex == chapterInVolumeIndex) &&
            (identical(other.durChapterPos, durChapterPos) ||
                other.durChapterPos == durChapterPos) &&
            (identical(other.durChapterTime, durChapterTime) ||
                other.durChapterTime == durChapterTime) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.canUpdate, canUpdate) ||
                other.canUpdate == canUpdate) &&
            (identical(other.order, order) || other.order == order) &&
            (identical(other.originOrder, originOrder) ||
                other.originOrder == originOrder) &&
            (identical(other.variable, variable) ||
                other.variable == variable) &&
            (identical(other.readConfig, readConfig) ||
                other.readConfig == readConfig) &&
            (identical(other.syncTime, syncTime) ||
                other.syncTime == syncTime) &&
            (identical(other.originBookUrl, originBookUrl) ||
                other.originBookUrl == originBookUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hashAll([
      runtimeType,
      bookUrl,
      isPrivate,
      tocUrl,
      origin,
      originName,
      name,
      author,
      kind,
      customTag,
      coverUrl,
      customCoverUrl,
      intro,
      customIntro,
      charset,
      bookType,
      group,
      latestChapterTitle,
      latestChapterTime,
      lastCheckTime,
      lastCheckCount,
      totalChapterNum,
      durChapterTitle,
      durChapterIndex,
      durVolumeIndex,
      chapterInVolumeIndex,
      durChapterPos,
      durChapterTime,
      wordCount,
      canUpdate,
      order,
      originOrder,
      variable,
      readConfig,
      syncTime,
      originBookUrl,
    ]);
  }

  @override
  String toString() {
    return 'Book(bookUrl: $bookUrl, isPrivate: $isPrivate, tocUrl: $tocUrl, origin: $origin, originName: $originName, name: $name, author: $author, kind: $kind, customTag: $customTag, coverUrl: $coverUrl, customCoverUrl: $customCoverUrl, intro: $intro, customIntro: $customIntro, charset: $charset, bookType: $bookType, group: $group, latestChapterTitle: $latestChapterTitle, latestChapterTime: $latestChapterTime, lastCheckTime: $lastCheckTime, lastCheckCount: $lastCheckCount, totalChapterNum: $totalChapterNum, durChapterTitle: $durChapterTitle, durChapterIndex: $durChapterIndex, durVolumeIndex: $durVolumeIndex, chapterInVolumeIndex: $chapterInVolumeIndex, durChapterPos: $durChapterPos, durChapterTime: $durChapterTime, wordCount: $wordCount, canUpdate: $canUpdate, order: $order, originOrder: $originOrder, variable: $variable, readConfig: $readConfig, syncTime: $syncTime, originBookUrl: $originBookUrl)';
  }
}

/// @nodoc
abstract mixin class _$BookCopyWith<$Res> implements $BookCopyWith<$Res> {
  factory _$BookCopyWith(_Book value, $Res Function(_Book) _then) =
      __$BookCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'bookUrl') String bookUrl,
    bool isPrivate,
    @JsonKey(name: 'tocUrl') String tocUrl,
    String origin,
    @JsonKey(name: 'originName') String originName,
    String name,
    String author,
    String? kind,
    @JsonKey(name: 'customTag') String? customTag,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    @JsonKey(name: 'customCoverUrl') String? customCoverUrl,
    String? intro,
    @JsonKey(name: 'customIntro') String? customIntro,
    String? charset,
    @JsonKey(name: 'type') int bookType,
    int group,
    @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
    @JsonKey(name: 'latestChapterTime') int latestChapterTime,
    @JsonKey(name: 'lastCheckTime') int lastCheckTime,
    @JsonKey(name: 'lastCheckCount') int lastCheckCount,
    @JsonKey(name: 'totalChapterNum') int totalChapterNum,
    @JsonKey(name: 'durChapterTitle') String? durChapterTitle,
    @JsonKey(name: 'durChapterIndex') int durChapterIndex,
    @JsonKey(name: 'durVolumeIndex') int durVolumeIndex,
    @JsonKey(name: 'chapterInVolumeIndex') int chapterInVolumeIndex,
    @JsonKey(name: 'durChapterPos') int durChapterPos,
    @JsonKey(name: 'durChapterTime') int durChapterTime,
    @JsonKey(name: 'wordCount') String? wordCount,
    @JsonKey(name: 'canUpdate') bool canUpdate,
    int order,
    @JsonKey(name: 'originOrder') int originOrder,
    String? variable,
    @JsonKey(name: 'readConfig') ReadConfig? readConfig,
    @JsonKey(name: 'syncTime') int syncTime,
    @JsonKey(name: 'originBookUrl') String originBookUrl,
  });

  @override
  $ReadConfigCopyWith<$Res>? get readConfig;
}

/// @nodoc
class __$BookCopyWithImpl<$Res> implements _$BookCopyWith<$Res> {
  __$BookCopyWithImpl(this._self, this._then);

  final _Book _self;
  final $Res Function(_Book) _then;

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookUrl = null,
    Object? isPrivate = null,
    Object? tocUrl = null,
    Object? origin = null,
    Object? originName = null,
    Object? name = null,
    Object? author = null,
    Object? kind = freezed,
    Object? customTag = freezed,
    Object? coverUrl = freezed,
    Object? customCoverUrl = freezed,
    Object? intro = freezed,
    Object? customIntro = freezed,
    Object? charset = freezed,
    Object? bookType = null,
    Object? group = null,
    Object? latestChapterTitle = freezed,
    Object? latestChapterTime = null,
    Object? lastCheckTime = null,
    Object? lastCheckCount = null,
    Object? totalChapterNum = null,
    Object? durChapterTitle = freezed,
    Object? durChapterIndex = null,
    Object? durVolumeIndex = null,
    Object? chapterInVolumeIndex = null,
    Object? durChapterPos = null,
    Object? durChapterTime = null,
    Object? wordCount = freezed,
    Object? canUpdate = null,
    Object? order = null,
    Object? originOrder = null,
    Object? variable = freezed,
    Object? readConfig = freezed,
    Object? syncTime = null,
    Object? originBookUrl = null,
  }) {
    return _then(
      _Book(
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        isPrivate: null == isPrivate
            ? _self.isPrivate
            : isPrivate // ignore: cast_nullable_to_non_nullable
                  as bool,
        tocUrl: null == tocUrl
            ? _self.tocUrl
            : tocUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        originName: null == originName
            ? _self.originName
            : originName // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        kind: freezed == kind
            ? _self.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String?,
        customTag: freezed == customTag
            ? _self.customTag
            : customTag // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        customCoverUrl: freezed == customCoverUrl
            ? _self.customCoverUrl
            : customCoverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        customIntro: freezed == customIntro
            ? _self.customIntro
            : customIntro // ignore: cast_nullable_to_non_nullable
                  as String?,
        charset: freezed == charset
            ? _self.charset
            : charset // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookType: null == bookType
            ? _self.bookType
            : bookType // ignore: cast_nullable_to_non_nullable
                  as int,
        group: null == group
            ? _self.group
            : group // ignore: cast_nullable_to_non_nullable
                  as int,
        latestChapterTitle: freezed == latestChapterTitle
            ? _self.latestChapterTitle
            : latestChapterTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        latestChapterTime: null == latestChapterTime
            ? _self.latestChapterTime
            : latestChapterTime // ignore: cast_nullable_to_non_nullable
                  as int,
        lastCheckTime: null == lastCheckTime
            ? _self.lastCheckTime
            : lastCheckTime // ignore: cast_nullable_to_non_nullable
                  as int,
        lastCheckCount: null == lastCheckCount
            ? _self.lastCheckCount
            : lastCheckCount // ignore: cast_nullable_to_non_nullable
                  as int,
        totalChapterNum: null == totalChapterNum
            ? _self.totalChapterNum
            : totalChapterNum // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterTitle: freezed == durChapterTitle
            ? _self.durChapterTitle
            : durChapterTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        durChapterIndex: null == durChapterIndex
            ? _self.durChapterIndex
            : durChapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        durVolumeIndex: null == durVolumeIndex
            ? _self.durVolumeIndex
            : durVolumeIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterInVolumeIndex: null == chapterInVolumeIndex
            ? _self.chapterInVolumeIndex
            : chapterInVolumeIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterPos: null == durChapterPos
            ? _self.durChapterPos
            : durChapterPos // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterTime: null == durChapterTime
            ? _self.durChapterTime
            : durChapterTime // ignore: cast_nullable_to_non_nullable
                  as int,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        canUpdate: null == canUpdate
            ? _self.canUpdate
            : canUpdate // ignore: cast_nullable_to_non_nullable
                  as bool,
        order: null == order
            ? _self.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        originOrder: null == originOrder
            ? _self.originOrder
            : originOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        variable: freezed == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String?,
        readConfig: freezed == readConfig
            ? _self.readConfig
            : readConfig // ignore: cast_nullable_to_non_nullable
                  as ReadConfig?,
        syncTime: null == syncTime
            ? _self.syncTime
            : syncTime // ignore: cast_nullable_to_non_nullable
                  as int,
        originBookUrl: null == originBookUrl
            ? _self.originBookUrl
            : originBookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ReadConfigCopyWith<$Res>? get readConfig {
    if (_self.readConfig == null) {
      return null;
    }

    return $ReadConfigCopyWith<$Res>(_self.readConfig!, (value) {
      return _then(_self.copyWith(readConfig: value));
    });
  }
}
