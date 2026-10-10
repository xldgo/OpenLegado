// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rss_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RssSource {
  @JsonKey(name: 'sourceUrl')
  String get sourceUrl;
  @JsonKey(name: 'sourceName')
  String get sourceName;
  @JsonKey(name: 'sourceIcon')
  String get sourceIcon;
  @JsonKey(name: 'sourceGroup')
  String? get sourceGroup;
  @JsonKey(name: 'sourceComment')
  String? get sourceComment;
  bool get enabled;
  @JsonKey(name: 'variableComment')
  String? get variableComment;
  @JsonKey(name: 'jsLib')
  String? get jsLib;
  @JsonKey(name: 'enabledCookieJar')
  bool? get enabledCookieJar;
  @JsonKey(name: 'concurrentRate')
  String? get concurrentRate;
  String? get header;
  @JsonKey(name: 'loginUrl')
  String? get loginUrl;
  @JsonKey(name: 'loginUi')
  String? get loginUi;
  @JsonKey(name: 'loginCheckJs')
  String? get loginCheckJs;
  @JsonKey(name: 'coverDecodeJs')
  String? get coverDecodeJs;
  @JsonKey(name: 'sortUrl')
  String? get sortUrl;
  @JsonKey(name: 'singleUrl')
  bool get singleUrl;
  @JsonKey(name: 'articleStyle')
  int get articleStyle;
  @JsonKey(name: 'ruleArticles')
  String? get ruleArticles;
  @JsonKey(name: 'ruleNextPage')
  String? get ruleNextPage;
  @JsonKey(name: 'ruleTitle')
  String? get ruleTitle;
  @JsonKey(name: 'rulePubDate')
  String? get rulePubDate;
  @JsonKey(name: 'ruleDescription')
  String? get ruleDescription;
  @JsonKey(name: 'ruleImage')
  String? get ruleImage;
  @JsonKey(name: 'ruleLink')
  String? get ruleLink;
  @JsonKey(name: 'ruleContent')
  String? get ruleContent;
  @JsonKey(name: 'contentWhitelist')
  String? get contentWhitelist;
  @JsonKey(name: 'contentBlacklist')
  String? get contentBlacklist;
  @JsonKey(name: 'shouldOverrideUrlLoading')
  String? get shouldOverrideUrlLoading;
  String? get style;
  @JsonKey(name: 'enableJs')
  bool get enableJs;
  @JsonKey(name: 'loadWithBaseUrl')
  bool get loadWithBaseUrl;
  @JsonKey(name: 'injectJs')
  String? get injectJs;
  @JsonKey(name: 'preloadJs')
  String? get preloadJs;
  @JsonKey(name: 'startHtml')
  String? get startHtml;
  @JsonKey(name: 'startStyle')
  String? get startStyle;
  @JsonKey(name: 'startJs')
  String? get startJs;
  @JsonKey(name: 'showWebLog')
  bool get showWebLog;
  @JsonKey(name: 'lastUpdateTime')
  int get lastUpdateTime;
  @JsonKey(name: 'customOrder')
  int get customOrder;
  @JsonKey(name: 'type')
  int get rssType;
  bool get preload;
  @JsonKey(name: 'cacheFirst')
  bool get cacheFirst;
  @JsonKey(name: 'searchUrl')
  String? get searchUrl;

  /// Create a copy of RssSource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RssSourceCopyWith<RssSource> get copyWith =>
      _$RssSourceCopyWithImpl<RssSource>(this as RssSource, _$identity);

  /// Serializes this RssSource to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as RssSource;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RssSource &&
            (identical(other.sourceUrl, _this.sourceUrl) ||
                other.sourceUrl == _this.sourceUrl) &&
            (identical(other.sourceName, _this.sourceName) ||
                other.sourceName == _this.sourceName) &&
            (identical(other.sourceIcon, _this.sourceIcon) ||
                other.sourceIcon == _this.sourceIcon) &&
            (identical(other.sourceGroup, _this.sourceGroup) ||
                other.sourceGroup == _this.sourceGroup) &&
            (identical(other.sourceComment, _this.sourceComment) ||
                other.sourceComment == _this.sourceComment) &&
            (identical(other.enabled, _this.enabled) ||
                other.enabled == _this.enabled) &&
            (identical(other.variableComment, _this.variableComment) ||
                other.variableComment == _this.variableComment) &&
            (identical(other.jsLib, _this.jsLib) ||
                other.jsLib == _this.jsLib) &&
            (identical(other.enabledCookieJar, _this.enabledCookieJar) ||
                other.enabledCookieJar == _this.enabledCookieJar) &&
            (identical(other.concurrentRate, _this.concurrentRate) ||
                other.concurrentRate == _this.concurrentRate) &&
            (identical(other.header, _this.header) ||
                other.header == _this.header) &&
            (identical(other.loginUrl, _this.loginUrl) ||
                other.loginUrl == _this.loginUrl) &&
            (identical(other.loginUi, _this.loginUi) ||
                other.loginUi == _this.loginUi) &&
            (identical(other.loginCheckJs, _this.loginCheckJs) ||
                other.loginCheckJs == _this.loginCheckJs) &&
            (identical(other.coverDecodeJs, _this.coverDecodeJs) ||
                other.coverDecodeJs == _this.coverDecodeJs) &&
            (identical(other.sortUrl, _this.sortUrl) ||
                other.sortUrl == _this.sortUrl) &&
            (identical(other.singleUrl, _this.singleUrl) ||
                other.singleUrl == _this.singleUrl) &&
            (identical(other.articleStyle, _this.articleStyle) ||
                other.articleStyle == _this.articleStyle) &&
            (identical(other.ruleArticles, _this.ruleArticles) ||
                other.ruleArticles == _this.ruleArticles) &&
            (identical(other.ruleNextPage, _this.ruleNextPage) ||
                other.ruleNextPage == _this.ruleNextPage) &&
            (identical(other.ruleTitle, _this.ruleTitle) ||
                other.ruleTitle == _this.ruleTitle) &&
            (identical(other.rulePubDate, _this.rulePubDate) ||
                other.rulePubDate == _this.rulePubDate) &&
            (identical(other.ruleDescription, _this.ruleDescription) ||
                other.ruleDescription == _this.ruleDescription) &&
            (identical(other.ruleImage, _this.ruleImage) ||
                other.ruleImage == _this.ruleImage) &&
            (identical(other.ruleLink, _this.ruleLink) ||
                other.ruleLink == _this.ruleLink) &&
            (identical(other.ruleContent, _this.ruleContent) ||
                other.ruleContent == _this.ruleContent) &&
            (identical(other.contentWhitelist, _this.contentWhitelist) ||
                other.contentWhitelist == _this.contentWhitelist) &&
            (identical(other.contentBlacklist, _this.contentBlacklist) ||
                other.contentBlacklist == _this.contentBlacklist) &&
            (identical(
                  other.shouldOverrideUrlLoading,
                  _this.shouldOverrideUrlLoading,
                ) ||
                other.shouldOverrideUrlLoading ==
                    _this.shouldOverrideUrlLoading) &&
            (identical(other.style, _this.style) ||
                other.style == _this.style) &&
            (identical(other.enableJs, _this.enableJs) ||
                other.enableJs == _this.enableJs) &&
            (identical(other.loadWithBaseUrl, _this.loadWithBaseUrl) ||
                other.loadWithBaseUrl == _this.loadWithBaseUrl) &&
            (identical(other.injectJs, _this.injectJs) ||
                other.injectJs == _this.injectJs) &&
            (identical(other.preloadJs, _this.preloadJs) ||
                other.preloadJs == _this.preloadJs) &&
            (identical(other.startHtml, _this.startHtml) ||
                other.startHtml == _this.startHtml) &&
            (identical(other.startStyle, _this.startStyle) ||
                other.startStyle == _this.startStyle) &&
            (identical(other.startJs, _this.startJs) ||
                other.startJs == _this.startJs) &&
            (identical(other.showWebLog, _this.showWebLog) ||
                other.showWebLog == _this.showWebLog) &&
            (identical(other.lastUpdateTime, _this.lastUpdateTime) ||
                other.lastUpdateTime == _this.lastUpdateTime) &&
            (identical(other.customOrder, _this.customOrder) ||
                other.customOrder == _this.customOrder) &&
            (identical(other.rssType, _this.rssType) ||
                other.rssType == _this.rssType) &&
            (identical(other.preload, _this.preload) ||
                other.preload == _this.preload) &&
            (identical(other.cacheFirst, _this.cacheFirst) ||
                other.cacheFirst == _this.cacheFirst) &&
            (identical(other.searchUrl, _this.searchUrl) ||
                other.searchUrl == _this.searchUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as RssSource;
    return Object.hashAll([
      runtimeType,
      _this.sourceUrl,
      _this.sourceName,
      _this.sourceIcon,
      _this.sourceGroup,
      _this.sourceComment,
      _this.enabled,
      _this.variableComment,
      _this.jsLib,
      _this.enabledCookieJar,
      _this.concurrentRate,
      _this.header,
      _this.loginUrl,
      _this.loginUi,
      _this.loginCheckJs,
      _this.coverDecodeJs,
      _this.sortUrl,
      _this.singleUrl,
      _this.articleStyle,
      _this.ruleArticles,
      _this.ruleNextPage,
      _this.ruleTitle,
      _this.rulePubDate,
      _this.ruleDescription,
      _this.ruleImage,
      _this.ruleLink,
      _this.ruleContent,
      _this.contentWhitelist,
      _this.contentBlacklist,
      _this.shouldOverrideUrlLoading,
      _this.style,
      _this.enableJs,
      _this.loadWithBaseUrl,
      _this.injectJs,
      _this.preloadJs,
      _this.startHtml,
      _this.startStyle,
      _this.startJs,
      _this.showWebLog,
      _this.lastUpdateTime,
      _this.customOrder,
      _this.rssType,
      _this.preload,
      _this.cacheFirst,
      _this.searchUrl,
    ]);
  }

  @override
  String toString() {
    final _this = this as RssSource;
    return 'RssSource(sourceUrl: ${_this.sourceUrl}, sourceName: ${_this.sourceName}, sourceIcon: ${_this.sourceIcon}, sourceGroup: ${_this.sourceGroup}, sourceComment: ${_this.sourceComment}, enabled: ${_this.enabled}, variableComment: ${_this.variableComment}, jsLib: ${_this.jsLib}, enabledCookieJar: ${_this.enabledCookieJar}, concurrentRate: ${_this.concurrentRate}, header: ${_this.header}, loginUrl: ${_this.loginUrl}, loginUi: ${_this.loginUi}, loginCheckJs: ${_this.loginCheckJs}, coverDecodeJs: ${_this.coverDecodeJs}, sortUrl: ${_this.sortUrl}, singleUrl: ${_this.singleUrl}, articleStyle: ${_this.articleStyle}, ruleArticles: ${_this.ruleArticles}, ruleNextPage: ${_this.ruleNextPage}, ruleTitle: ${_this.ruleTitle}, rulePubDate: ${_this.rulePubDate}, ruleDescription: ${_this.ruleDescription}, ruleImage: ${_this.ruleImage}, ruleLink: ${_this.ruleLink}, ruleContent: ${_this.ruleContent}, contentWhitelist: ${_this.contentWhitelist}, contentBlacklist: ${_this.contentBlacklist}, shouldOverrideUrlLoading: ${_this.shouldOverrideUrlLoading}, style: ${_this.style}, enableJs: ${_this.enableJs}, loadWithBaseUrl: ${_this.loadWithBaseUrl}, injectJs: ${_this.injectJs}, preloadJs: ${_this.preloadJs}, startHtml: ${_this.startHtml}, startStyle: ${_this.startStyle}, startJs: ${_this.startJs}, showWebLog: ${_this.showWebLog}, lastUpdateTime: ${_this.lastUpdateTime}, customOrder: ${_this.customOrder}, rssType: ${_this.rssType}, preload: ${_this.preload}, cacheFirst: ${_this.cacheFirst}, searchUrl: ${_this.searchUrl})';
  }
}

/// @nodoc
abstract mixin class $RssSourceCopyWith<$Res> {
  factory $RssSourceCopyWith(RssSource value, $Res Function(RssSource) _then) =
      _$RssSourceCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'sourceUrl') String sourceUrl,
    @JsonKey(name: 'sourceName') String sourceName,
    @JsonKey(name: 'sourceIcon') String sourceIcon,
    @JsonKey(name: 'sourceGroup') String? sourceGroup,
    @JsonKey(name: 'sourceComment') String? sourceComment,
    bool enabled,
    @JsonKey(name: 'variableComment') String? variableComment,
    @JsonKey(name: 'jsLib') String? jsLib,
    @JsonKey(name: 'enabledCookieJar') bool? enabledCookieJar,
    @JsonKey(name: 'concurrentRate') String? concurrentRate,
    String? header,
    @JsonKey(name: 'loginUrl') String? loginUrl,
    @JsonKey(name: 'loginUi') String? loginUi,
    @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
    @JsonKey(name: 'coverDecodeJs') String? coverDecodeJs,
    @JsonKey(name: 'sortUrl') String? sortUrl,
    @JsonKey(name: 'singleUrl') bool singleUrl,
    @JsonKey(name: 'articleStyle') int articleStyle,
    @JsonKey(name: 'ruleArticles') String? ruleArticles,
    @JsonKey(name: 'ruleNextPage') String? ruleNextPage,
    @JsonKey(name: 'ruleTitle') String? ruleTitle,
    @JsonKey(name: 'rulePubDate') String? rulePubDate,
    @JsonKey(name: 'ruleDescription') String? ruleDescription,
    @JsonKey(name: 'ruleImage') String? ruleImage,
    @JsonKey(name: 'ruleLink') String? ruleLink,
    @JsonKey(name: 'ruleContent') String? ruleContent,
    @JsonKey(name: 'contentWhitelist') String? contentWhitelist,
    @JsonKey(name: 'contentBlacklist') String? contentBlacklist,
    @JsonKey(name: 'shouldOverrideUrlLoading') String? shouldOverrideUrlLoading,
    String? style,
    @JsonKey(name: 'enableJs') bool enableJs,
    @JsonKey(name: 'loadWithBaseUrl') bool loadWithBaseUrl,
    @JsonKey(name: 'injectJs') String? injectJs,
    @JsonKey(name: 'preloadJs') String? preloadJs,
    @JsonKey(name: 'startHtml') String? startHtml,
    @JsonKey(name: 'startStyle') String? startStyle,
    @JsonKey(name: 'startJs') String? startJs,
    @JsonKey(name: 'showWebLog') bool showWebLog,
    @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
    @JsonKey(name: 'customOrder') int customOrder,
    @JsonKey(name: 'type') int rssType,
    bool preload,
    @JsonKey(name: 'cacheFirst') bool cacheFirst,
    @JsonKey(name: 'searchUrl') String? searchUrl,
  });
}

/// @nodoc
class _$RssSourceCopyWithImpl<$Res> implements $RssSourceCopyWith<$Res> {
  _$RssSourceCopyWithImpl(this._self, this._then);

  final RssSource _self;
  final $Res Function(RssSource) _then;

  /// Create a copy of RssSource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sourceUrl = null,
    Object? sourceName = null,
    Object? sourceIcon = null,
    Object? sourceGroup = freezed,
    Object? sourceComment = freezed,
    Object? enabled = null,
    Object? variableComment = freezed,
    Object? jsLib = freezed,
    Object? enabledCookieJar = freezed,
    Object? concurrentRate = freezed,
    Object? header = freezed,
    Object? loginUrl = freezed,
    Object? loginUi = freezed,
    Object? loginCheckJs = freezed,
    Object? coverDecodeJs = freezed,
    Object? sortUrl = freezed,
    Object? singleUrl = null,
    Object? articleStyle = null,
    Object? ruleArticles = freezed,
    Object? ruleNextPage = freezed,
    Object? ruleTitle = freezed,
    Object? rulePubDate = freezed,
    Object? ruleDescription = freezed,
    Object? ruleImage = freezed,
    Object? ruleLink = freezed,
    Object? ruleContent = freezed,
    Object? contentWhitelist = freezed,
    Object? contentBlacklist = freezed,
    Object? shouldOverrideUrlLoading = freezed,
    Object? style = freezed,
    Object? enableJs = null,
    Object? loadWithBaseUrl = null,
    Object? injectJs = freezed,
    Object? preloadJs = freezed,
    Object? startHtml = freezed,
    Object? startStyle = freezed,
    Object? startJs = freezed,
    Object? showWebLog = null,
    Object? lastUpdateTime = null,
    Object? customOrder = null,
    Object? rssType = null,
    Object? preload = null,
    Object? cacheFirst = null,
    Object? searchUrl = freezed,
  }) {
    return _then(
      RssSource(
        sourceUrl: null == sourceUrl
            ? _self.sourceUrl
            : sourceUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceName: null == sourceName
            ? _self.sourceName
            : sourceName // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceIcon: null == sourceIcon
            ? _self.sourceIcon
            : sourceIcon // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceGroup: freezed == sourceGroup
            ? _self.sourceGroup
            : sourceGroup // ignore: cast_nullable_to_non_nullable
                  as String?,
        sourceComment: freezed == sourceComment
            ? _self.sourceComment
            : sourceComment // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabled: null == enabled
            ? _self.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        variableComment: freezed == variableComment
            ? _self.variableComment
            : variableComment // ignore: cast_nullable_to_non_nullable
                  as String?,
        jsLib: freezed == jsLib
            ? _self.jsLib
            : jsLib // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabledCookieJar: freezed == enabledCookieJar
            ? _self.enabledCookieJar
            : enabledCookieJar // ignore: cast_nullable_to_non_nullable
                  as bool?,
        concurrentRate: freezed == concurrentRate
            ? _self.concurrentRate
            : concurrentRate // ignore: cast_nullable_to_non_nullable
                  as String?,
        header: freezed == header
            ? _self.header
            : header // ignore: cast_nullable_to_non_nullable
                  as String?,
        loginUrl: freezed == loginUrl
            ? _self.loginUrl
            : loginUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        loginUi: freezed == loginUi
            ? _self.loginUi
            : loginUi // ignore: cast_nullable_to_non_nullable
                  as String?,
        loginCheckJs: freezed == loginCheckJs
            ? _self.loginCheckJs
            : loginCheckJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverDecodeJs: freezed == coverDecodeJs
            ? _self.coverDecodeJs
            : coverDecodeJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        sortUrl: freezed == sortUrl
            ? _self.sortUrl
            : sortUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        singleUrl: null == singleUrl
            ? _self.singleUrl
            : singleUrl // ignore: cast_nullable_to_non_nullable
                  as bool,
        articleStyle: null == articleStyle
            ? _self.articleStyle
            : articleStyle // ignore: cast_nullable_to_non_nullable
                  as int,
        ruleArticles: freezed == ruleArticles
            ? _self.ruleArticles
            : ruleArticles // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleNextPage: freezed == ruleNextPage
            ? _self.ruleNextPage
            : ruleNextPage // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleTitle: freezed == ruleTitle
            ? _self.ruleTitle
            : ruleTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        rulePubDate: freezed == rulePubDate
            ? _self.rulePubDate
            : rulePubDate // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleDescription: freezed == ruleDescription
            ? _self.ruleDescription
            : ruleDescription // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleImage: freezed == ruleImage
            ? _self.ruleImage
            : ruleImage // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleLink: freezed == ruleLink
            ? _self.ruleLink
            : ruleLink // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleContent: freezed == ruleContent
            ? _self.ruleContent
            : ruleContent // ignore: cast_nullable_to_non_nullable
                  as String?,
        contentWhitelist: freezed == contentWhitelist
            ? _self.contentWhitelist
            : contentWhitelist // ignore: cast_nullable_to_non_nullable
                  as String?,
        contentBlacklist: freezed == contentBlacklist
            ? _self.contentBlacklist
            : contentBlacklist // ignore: cast_nullable_to_non_nullable
                  as String?,
        shouldOverrideUrlLoading: freezed == shouldOverrideUrlLoading
            ? _self.shouldOverrideUrlLoading
            : shouldOverrideUrlLoading // ignore: cast_nullable_to_non_nullable
                  as String?,
        style: freezed == style
            ? _self.style
            : style // ignore: cast_nullable_to_non_nullable
                  as String?,
        enableJs: null == enableJs
            ? _self.enableJs
            : enableJs // ignore: cast_nullable_to_non_nullable
                  as bool,
        loadWithBaseUrl: null == loadWithBaseUrl
            ? _self.loadWithBaseUrl
            : loadWithBaseUrl // ignore: cast_nullable_to_non_nullable
                  as bool,
        injectJs: freezed == injectJs
            ? _self.injectJs
            : injectJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        preloadJs: freezed == preloadJs
            ? _self.preloadJs
            : preloadJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        startHtml: freezed == startHtml
            ? _self.startHtml
            : startHtml // ignore: cast_nullable_to_non_nullable
                  as String?,
        startStyle: freezed == startStyle
            ? _self.startStyle
            : startStyle // ignore: cast_nullable_to_non_nullable
                  as String?,
        startJs: freezed == startJs
            ? _self.startJs
            : startJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        showWebLog: null == showWebLog
            ? _self.showWebLog
            : showWebLog // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastUpdateTime: null == lastUpdateTime
            ? _self.lastUpdateTime
            : lastUpdateTime // ignore: cast_nullable_to_non_nullable
                  as int,
        customOrder: null == customOrder
            ? _self.customOrder
            : customOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        rssType: null == rssType
            ? _self.rssType
            : rssType // ignore: cast_nullable_to_non_nullable
                  as int,
        preload: null == preload
            ? _self.preload
            : preload // ignore: cast_nullable_to_non_nullable
                  as bool,
        cacheFirst: null == cacheFirst
            ? _self.cacheFirst
            : cacheFirst // ignore: cast_nullable_to_non_nullable
                  as bool,
        searchUrl: freezed == searchUrl
            ? _self.searchUrl
            : searchUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [RssSource].
extension RssSourcePatterns on RssSource {
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
    TResult Function(_RssSource value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssSource() when $default != null:
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
    TResult Function(_RssSource value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssSource():
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
    TResult? Function(_RssSource value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssSource() when $default != null:
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
      @JsonKey(name: 'sourceUrl') String sourceUrl,
      @JsonKey(name: 'sourceName') String sourceName,
      @JsonKey(name: 'sourceIcon') String sourceIcon,
      @JsonKey(name: 'sourceGroup') String? sourceGroup,
      @JsonKey(name: 'sourceComment') String? sourceComment,
      bool enabled,
      @JsonKey(name: 'variableComment') String? variableComment,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'enabledCookieJar') bool? enabledCookieJar,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      String? header,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi') String? loginUi,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      @JsonKey(name: 'coverDecodeJs') String? coverDecodeJs,
      @JsonKey(name: 'sortUrl') String? sortUrl,
      @JsonKey(name: 'singleUrl') bool singleUrl,
      @JsonKey(name: 'articleStyle') int articleStyle,
      @JsonKey(name: 'ruleArticles') String? ruleArticles,
      @JsonKey(name: 'ruleNextPage') String? ruleNextPage,
      @JsonKey(name: 'ruleTitle') String? ruleTitle,
      @JsonKey(name: 'rulePubDate') String? rulePubDate,
      @JsonKey(name: 'ruleDescription') String? ruleDescription,
      @JsonKey(name: 'ruleImage') String? ruleImage,
      @JsonKey(name: 'ruleLink') String? ruleLink,
      @JsonKey(name: 'ruleContent') String? ruleContent,
      @JsonKey(name: 'contentWhitelist') String? contentWhitelist,
      @JsonKey(name: 'contentBlacklist') String? contentBlacklist,
      @JsonKey(name: 'shouldOverrideUrlLoading')
      String? shouldOverrideUrlLoading,
      String? style,
      @JsonKey(name: 'enableJs') bool enableJs,
      @JsonKey(name: 'loadWithBaseUrl') bool loadWithBaseUrl,
      @JsonKey(name: 'injectJs') String? injectJs,
      @JsonKey(name: 'preloadJs') String? preloadJs,
      @JsonKey(name: 'startHtml') String? startHtml,
      @JsonKey(name: 'startStyle') String? startStyle,
      @JsonKey(name: 'startJs') String? startJs,
      @JsonKey(name: 'showWebLog') bool showWebLog,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'customOrder') int customOrder,
      @JsonKey(name: 'type') int rssType,
      bool preload,
      @JsonKey(name: 'cacheFirst') bool cacheFirst,
      @JsonKey(name: 'searchUrl') String? searchUrl,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssSource() when $default != null:
        return $default(
          _that.sourceUrl,
          _that.sourceName,
          _that.sourceIcon,
          _that.sourceGroup,
          _that.sourceComment,
          _that.enabled,
          _that.variableComment,
          _that.jsLib,
          _that.enabledCookieJar,
          _that.concurrentRate,
          _that.header,
          _that.loginUrl,
          _that.loginUi,
          _that.loginCheckJs,
          _that.coverDecodeJs,
          _that.sortUrl,
          _that.singleUrl,
          _that.articleStyle,
          _that.ruleArticles,
          _that.ruleNextPage,
          _that.ruleTitle,
          _that.rulePubDate,
          _that.ruleDescription,
          _that.ruleImage,
          _that.ruleLink,
          _that.ruleContent,
          _that.contentWhitelist,
          _that.contentBlacklist,
          _that.shouldOverrideUrlLoading,
          _that.style,
          _that.enableJs,
          _that.loadWithBaseUrl,
          _that.injectJs,
          _that.preloadJs,
          _that.startHtml,
          _that.startStyle,
          _that.startJs,
          _that.showWebLog,
          _that.lastUpdateTime,
          _that.customOrder,
          _that.rssType,
          _that.preload,
          _that.cacheFirst,
          _that.searchUrl,
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
      @JsonKey(name: 'sourceUrl') String sourceUrl,
      @JsonKey(name: 'sourceName') String sourceName,
      @JsonKey(name: 'sourceIcon') String sourceIcon,
      @JsonKey(name: 'sourceGroup') String? sourceGroup,
      @JsonKey(name: 'sourceComment') String? sourceComment,
      bool enabled,
      @JsonKey(name: 'variableComment') String? variableComment,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'enabledCookieJar') bool? enabledCookieJar,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      String? header,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi') String? loginUi,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      @JsonKey(name: 'coverDecodeJs') String? coverDecodeJs,
      @JsonKey(name: 'sortUrl') String? sortUrl,
      @JsonKey(name: 'singleUrl') bool singleUrl,
      @JsonKey(name: 'articleStyle') int articleStyle,
      @JsonKey(name: 'ruleArticles') String? ruleArticles,
      @JsonKey(name: 'ruleNextPage') String? ruleNextPage,
      @JsonKey(name: 'ruleTitle') String? ruleTitle,
      @JsonKey(name: 'rulePubDate') String? rulePubDate,
      @JsonKey(name: 'ruleDescription') String? ruleDescription,
      @JsonKey(name: 'ruleImage') String? ruleImage,
      @JsonKey(name: 'ruleLink') String? ruleLink,
      @JsonKey(name: 'ruleContent') String? ruleContent,
      @JsonKey(name: 'contentWhitelist') String? contentWhitelist,
      @JsonKey(name: 'contentBlacklist') String? contentBlacklist,
      @JsonKey(name: 'shouldOverrideUrlLoading')
      String? shouldOverrideUrlLoading,
      String? style,
      @JsonKey(name: 'enableJs') bool enableJs,
      @JsonKey(name: 'loadWithBaseUrl') bool loadWithBaseUrl,
      @JsonKey(name: 'injectJs') String? injectJs,
      @JsonKey(name: 'preloadJs') String? preloadJs,
      @JsonKey(name: 'startHtml') String? startHtml,
      @JsonKey(name: 'startStyle') String? startStyle,
      @JsonKey(name: 'startJs') String? startJs,
      @JsonKey(name: 'showWebLog') bool showWebLog,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'customOrder') int customOrder,
      @JsonKey(name: 'type') int rssType,
      bool preload,
      @JsonKey(name: 'cacheFirst') bool cacheFirst,
      @JsonKey(name: 'searchUrl') String? searchUrl,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssSource():
        return $default(
          _that.sourceUrl,
          _that.sourceName,
          _that.sourceIcon,
          _that.sourceGroup,
          _that.sourceComment,
          _that.enabled,
          _that.variableComment,
          _that.jsLib,
          _that.enabledCookieJar,
          _that.concurrentRate,
          _that.header,
          _that.loginUrl,
          _that.loginUi,
          _that.loginCheckJs,
          _that.coverDecodeJs,
          _that.sortUrl,
          _that.singleUrl,
          _that.articleStyle,
          _that.ruleArticles,
          _that.ruleNextPage,
          _that.ruleTitle,
          _that.rulePubDate,
          _that.ruleDescription,
          _that.ruleImage,
          _that.ruleLink,
          _that.ruleContent,
          _that.contentWhitelist,
          _that.contentBlacklist,
          _that.shouldOverrideUrlLoading,
          _that.style,
          _that.enableJs,
          _that.loadWithBaseUrl,
          _that.injectJs,
          _that.preloadJs,
          _that.startHtml,
          _that.startStyle,
          _that.startJs,
          _that.showWebLog,
          _that.lastUpdateTime,
          _that.customOrder,
          _that.rssType,
          _that.preload,
          _that.cacheFirst,
          _that.searchUrl,
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
      @JsonKey(name: 'sourceUrl') String sourceUrl,
      @JsonKey(name: 'sourceName') String sourceName,
      @JsonKey(name: 'sourceIcon') String sourceIcon,
      @JsonKey(name: 'sourceGroup') String? sourceGroup,
      @JsonKey(name: 'sourceComment') String? sourceComment,
      bool enabled,
      @JsonKey(name: 'variableComment') String? variableComment,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'enabledCookieJar') bool? enabledCookieJar,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      String? header,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi') String? loginUi,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      @JsonKey(name: 'coverDecodeJs') String? coverDecodeJs,
      @JsonKey(name: 'sortUrl') String? sortUrl,
      @JsonKey(name: 'singleUrl') bool singleUrl,
      @JsonKey(name: 'articleStyle') int articleStyle,
      @JsonKey(name: 'ruleArticles') String? ruleArticles,
      @JsonKey(name: 'ruleNextPage') String? ruleNextPage,
      @JsonKey(name: 'ruleTitle') String? ruleTitle,
      @JsonKey(name: 'rulePubDate') String? rulePubDate,
      @JsonKey(name: 'ruleDescription') String? ruleDescription,
      @JsonKey(name: 'ruleImage') String? ruleImage,
      @JsonKey(name: 'ruleLink') String? ruleLink,
      @JsonKey(name: 'ruleContent') String? ruleContent,
      @JsonKey(name: 'contentWhitelist') String? contentWhitelist,
      @JsonKey(name: 'contentBlacklist') String? contentBlacklist,
      @JsonKey(name: 'shouldOverrideUrlLoading')
      String? shouldOverrideUrlLoading,
      String? style,
      @JsonKey(name: 'enableJs') bool enableJs,
      @JsonKey(name: 'loadWithBaseUrl') bool loadWithBaseUrl,
      @JsonKey(name: 'injectJs') String? injectJs,
      @JsonKey(name: 'preloadJs') String? preloadJs,
      @JsonKey(name: 'startHtml') String? startHtml,
      @JsonKey(name: 'startStyle') String? startStyle,
      @JsonKey(name: 'startJs') String? startJs,
      @JsonKey(name: 'showWebLog') bool showWebLog,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'customOrder') int customOrder,
      @JsonKey(name: 'type') int rssType,
      bool preload,
      @JsonKey(name: 'cacheFirst') bool cacheFirst,
      @JsonKey(name: 'searchUrl') String? searchUrl,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssSource() when $default != null:
        return $default(
          _that.sourceUrl,
          _that.sourceName,
          _that.sourceIcon,
          _that.sourceGroup,
          _that.sourceComment,
          _that.enabled,
          _that.variableComment,
          _that.jsLib,
          _that.enabledCookieJar,
          _that.concurrentRate,
          _that.header,
          _that.loginUrl,
          _that.loginUi,
          _that.loginCheckJs,
          _that.coverDecodeJs,
          _that.sortUrl,
          _that.singleUrl,
          _that.articleStyle,
          _that.ruleArticles,
          _that.ruleNextPage,
          _that.ruleTitle,
          _that.rulePubDate,
          _that.ruleDescription,
          _that.ruleImage,
          _that.ruleLink,
          _that.ruleContent,
          _that.contentWhitelist,
          _that.contentBlacklist,
          _that.shouldOverrideUrlLoading,
          _that.style,
          _that.enableJs,
          _that.loadWithBaseUrl,
          _that.injectJs,
          _that.preloadJs,
          _that.startHtml,
          _that.startStyle,
          _that.startJs,
          _that.showWebLog,
          _that.lastUpdateTime,
          _that.customOrder,
          _that.rssType,
          _that.preload,
          _that.cacheFirst,
          _that.searchUrl,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RssSource implements RssSource {
  const _RssSource({
    @JsonKey(name: 'sourceUrl') this.sourceUrl = '',
    @JsonKey(name: 'sourceName') this.sourceName = '',
    @JsonKey(name: 'sourceIcon') this.sourceIcon = '',
    @JsonKey(name: 'sourceGroup') this.sourceGroup,
    @JsonKey(name: 'sourceComment') this.sourceComment,
    this.enabled = true,
    @JsonKey(name: 'variableComment') this.variableComment,
    @JsonKey(name: 'jsLib') this.jsLib,
    @JsonKey(name: 'enabledCookieJar') this.enabledCookieJar,
    @JsonKey(name: 'concurrentRate') this.concurrentRate,
    this.header,
    @JsonKey(name: 'loginUrl') this.loginUrl,
    @JsonKey(name: 'loginUi') this.loginUi,
    @JsonKey(name: 'loginCheckJs') this.loginCheckJs,
    @JsonKey(name: 'coverDecodeJs') this.coverDecodeJs,
    @JsonKey(name: 'sortUrl') this.sortUrl,
    @JsonKey(name: 'singleUrl') this.singleUrl = false,
    @JsonKey(name: 'articleStyle') this.articleStyle = 0,
    @JsonKey(name: 'ruleArticles') this.ruleArticles,
    @JsonKey(name: 'ruleNextPage') this.ruleNextPage,
    @JsonKey(name: 'ruleTitle') this.ruleTitle,
    @JsonKey(name: 'rulePubDate') this.rulePubDate,
    @JsonKey(name: 'ruleDescription') this.ruleDescription,
    @JsonKey(name: 'ruleImage') this.ruleImage,
    @JsonKey(name: 'ruleLink') this.ruleLink,
    @JsonKey(name: 'ruleContent') this.ruleContent,
    @JsonKey(name: 'contentWhitelist') this.contentWhitelist,
    @JsonKey(name: 'contentBlacklist') this.contentBlacklist,
    @JsonKey(name: 'shouldOverrideUrlLoading') this.shouldOverrideUrlLoading,
    this.style,
    @JsonKey(name: 'enableJs') this.enableJs = true,
    @JsonKey(name: 'loadWithBaseUrl') this.loadWithBaseUrl = true,
    @JsonKey(name: 'injectJs') this.injectJs,
    @JsonKey(name: 'preloadJs') this.preloadJs,
    @JsonKey(name: 'startHtml') this.startHtml,
    @JsonKey(name: 'startStyle') this.startStyle,
    @JsonKey(name: 'startJs') this.startJs,
    @JsonKey(name: 'showWebLog') this.showWebLog = false,
    @JsonKey(name: 'lastUpdateTime') this.lastUpdateTime = 0,
    @JsonKey(name: 'customOrder') this.customOrder = 0,
    @JsonKey(name: 'type') this.rssType = 0,
    this.preload = false,
    @JsonKey(name: 'cacheFirst') this.cacheFirst = false,
    @JsonKey(name: 'searchUrl') this.searchUrl,
  });
  factory _RssSource.fromJson(Map<String, dynamic> json) =>
      _$RssSourceFromJson(json);

  @override
  @JsonKey(name: 'sourceUrl')
  final String sourceUrl;
  @override
  @JsonKey(name: 'sourceName')
  final String sourceName;
  @override
  @JsonKey(name: 'sourceIcon')
  final String sourceIcon;
  @override
  @JsonKey(name: 'sourceGroup')
  final String? sourceGroup;
  @override
  @JsonKey(name: 'sourceComment')
  final String? sourceComment;
  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey(name: 'variableComment')
  final String? variableComment;
  @override
  @JsonKey(name: 'jsLib')
  final String? jsLib;
  @override
  @JsonKey(name: 'enabledCookieJar')
  final bool? enabledCookieJar;
  @override
  @JsonKey(name: 'concurrentRate')
  final String? concurrentRate;
  @override
  final String? header;
  @override
  @JsonKey(name: 'loginUrl')
  final String? loginUrl;
  @override
  @JsonKey(name: 'loginUi')
  final String? loginUi;
  @override
  @JsonKey(name: 'loginCheckJs')
  final String? loginCheckJs;
  @override
  @JsonKey(name: 'coverDecodeJs')
  final String? coverDecodeJs;
  @override
  @JsonKey(name: 'sortUrl')
  final String? sortUrl;
  @override
  @JsonKey(name: 'singleUrl')
  final bool singleUrl;
  @override
  @JsonKey(name: 'articleStyle')
  final int articleStyle;
  @override
  @JsonKey(name: 'ruleArticles')
  final String? ruleArticles;
  @override
  @JsonKey(name: 'ruleNextPage')
  final String? ruleNextPage;
  @override
  @JsonKey(name: 'ruleTitle')
  final String? ruleTitle;
  @override
  @JsonKey(name: 'rulePubDate')
  final String? rulePubDate;
  @override
  @JsonKey(name: 'ruleDescription')
  final String? ruleDescription;
  @override
  @JsonKey(name: 'ruleImage')
  final String? ruleImage;
  @override
  @JsonKey(name: 'ruleLink')
  final String? ruleLink;
  @override
  @JsonKey(name: 'ruleContent')
  final String? ruleContent;
  @override
  @JsonKey(name: 'contentWhitelist')
  final String? contentWhitelist;
  @override
  @JsonKey(name: 'contentBlacklist')
  final String? contentBlacklist;
  @override
  @JsonKey(name: 'shouldOverrideUrlLoading')
  final String? shouldOverrideUrlLoading;
  @override
  final String? style;
  @override
  @JsonKey(name: 'enableJs')
  final bool enableJs;
  @override
  @JsonKey(name: 'loadWithBaseUrl')
  final bool loadWithBaseUrl;
  @override
  @JsonKey(name: 'injectJs')
  final String? injectJs;
  @override
  @JsonKey(name: 'preloadJs')
  final String? preloadJs;
  @override
  @JsonKey(name: 'startHtml')
  final String? startHtml;
  @override
  @JsonKey(name: 'startStyle')
  final String? startStyle;
  @override
  @JsonKey(name: 'startJs')
  final String? startJs;
  @override
  @JsonKey(name: 'showWebLog')
  final bool showWebLog;
  @override
  @JsonKey(name: 'lastUpdateTime')
  final int lastUpdateTime;
  @override
  @JsonKey(name: 'customOrder')
  final int customOrder;
  @override
  @JsonKey(name: 'type')
  final int rssType;
  @override
  @JsonKey()
  final bool preload;
  @override
  @JsonKey(name: 'cacheFirst')
  final bool cacheFirst;
  @override
  @JsonKey(name: 'searchUrl')
  final String? searchUrl;

  /// Create a copy of RssSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RssSourceCopyWith<_RssSource> get copyWith =>
      __$RssSourceCopyWithImpl<_RssSource>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RssSourceToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RssSource &&
            (identical(other.sourceUrl, sourceUrl) ||
                other.sourceUrl == sourceUrl) &&
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            (identical(other.sourceIcon, sourceIcon) ||
                other.sourceIcon == sourceIcon) &&
            (identical(other.sourceGroup, sourceGroup) ||
                other.sourceGroup == sourceGroup) &&
            (identical(other.sourceComment, sourceComment) ||
                other.sourceComment == sourceComment) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.variableComment, variableComment) ||
                other.variableComment == variableComment) &&
            (identical(other.jsLib, jsLib) || other.jsLib == jsLib) &&
            (identical(other.enabledCookieJar, enabledCookieJar) ||
                other.enabledCookieJar == enabledCookieJar) &&
            (identical(other.concurrentRate, concurrentRate) ||
                other.concurrentRate == concurrentRate) &&
            (identical(other.header, header) || other.header == header) &&
            (identical(other.loginUrl, loginUrl) ||
                other.loginUrl == loginUrl) &&
            (identical(other.loginUi, loginUi) || other.loginUi == loginUi) &&
            (identical(other.loginCheckJs, loginCheckJs) ||
                other.loginCheckJs == loginCheckJs) &&
            (identical(other.coverDecodeJs, coverDecodeJs) ||
                other.coverDecodeJs == coverDecodeJs) &&
            (identical(other.sortUrl, sortUrl) || other.sortUrl == sortUrl) &&
            (identical(other.singleUrl, singleUrl) ||
                other.singleUrl == singleUrl) &&
            (identical(other.articleStyle, articleStyle) ||
                other.articleStyle == articleStyle) &&
            (identical(other.ruleArticles, ruleArticles) ||
                other.ruleArticles == ruleArticles) &&
            (identical(other.ruleNextPage, ruleNextPage) ||
                other.ruleNextPage == ruleNextPage) &&
            (identical(other.ruleTitle, ruleTitle) ||
                other.ruleTitle == ruleTitle) &&
            (identical(other.rulePubDate, rulePubDate) ||
                other.rulePubDate == rulePubDate) &&
            (identical(other.ruleDescription, ruleDescription) ||
                other.ruleDescription == ruleDescription) &&
            (identical(other.ruleImage, ruleImage) ||
                other.ruleImage == ruleImage) &&
            (identical(other.ruleLink, ruleLink) ||
                other.ruleLink == ruleLink) &&
            (identical(other.ruleContent, ruleContent) ||
                other.ruleContent == ruleContent) &&
            (identical(other.contentWhitelist, contentWhitelist) ||
                other.contentWhitelist == contentWhitelist) &&
            (identical(other.contentBlacklist, contentBlacklist) ||
                other.contentBlacklist == contentBlacklist) &&
            (identical(
                  other.shouldOverrideUrlLoading,
                  shouldOverrideUrlLoading,
                ) ||
                other.shouldOverrideUrlLoading == shouldOverrideUrlLoading) &&
            (identical(other.style, style) || other.style == style) &&
            (identical(other.enableJs, enableJs) ||
                other.enableJs == enableJs) &&
            (identical(other.loadWithBaseUrl, loadWithBaseUrl) ||
                other.loadWithBaseUrl == loadWithBaseUrl) &&
            (identical(other.injectJs, injectJs) ||
                other.injectJs == injectJs) &&
            (identical(other.preloadJs, preloadJs) ||
                other.preloadJs == preloadJs) &&
            (identical(other.startHtml, startHtml) ||
                other.startHtml == startHtml) &&
            (identical(other.startStyle, startStyle) ||
                other.startStyle == startStyle) &&
            (identical(other.startJs, startJs) || other.startJs == startJs) &&
            (identical(other.showWebLog, showWebLog) ||
                other.showWebLog == showWebLog) &&
            (identical(other.lastUpdateTime, lastUpdateTime) ||
                other.lastUpdateTime == lastUpdateTime) &&
            (identical(other.customOrder, customOrder) ||
                other.customOrder == customOrder) &&
            (identical(other.rssType, rssType) || other.rssType == rssType) &&
            (identical(other.preload, preload) || other.preload == preload) &&
            (identical(other.cacheFirst, cacheFirst) ||
                other.cacheFirst == cacheFirst) &&
            (identical(other.searchUrl, searchUrl) ||
                other.searchUrl == searchUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hashAll([
      runtimeType,
      sourceUrl,
      sourceName,
      sourceIcon,
      sourceGroup,
      sourceComment,
      enabled,
      variableComment,
      jsLib,
      enabledCookieJar,
      concurrentRate,
      header,
      loginUrl,
      loginUi,
      loginCheckJs,
      coverDecodeJs,
      sortUrl,
      singleUrl,
      articleStyle,
      ruleArticles,
      ruleNextPage,
      ruleTitle,
      rulePubDate,
      ruleDescription,
      ruleImage,
      ruleLink,
      ruleContent,
      contentWhitelist,
      contentBlacklist,
      shouldOverrideUrlLoading,
      style,
      enableJs,
      loadWithBaseUrl,
      injectJs,
      preloadJs,
      startHtml,
      startStyle,
      startJs,
      showWebLog,
      lastUpdateTime,
      customOrder,
      rssType,
      preload,
      cacheFirst,
      searchUrl,
    ]);
  }

  @override
  String toString() {
    return 'RssSource(sourceUrl: $sourceUrl, sourceName: $sourceName, sourceIcon: $sourceIcon, sourceGroup: $sourceGroup, sourceComment: $sourceComment, enabled: $enabled, variableComment: $variableComment, jsLib: $jsLib, enabledCookieJar: $enabledCookieJar, concurrentRate: $concurrentRate, header: $header, loginUrl: $loginUrl, loginUi: $loginUi, loginCheckJs: $loginCheckJs, coverDecodeJs: $coverDecodeJs, sortUrl: $sortUrl, singleUrl: $singleUrl, articleStyle: $articleStyle, ruleArticles: $ruleArticles, ruleNextPage: $ruleNextPage, ruleTitle: $ruleTitle, rulePubDate: $rulePubDate, ruleDescription: $ruleDescription, ruleImage: $ruleImage, ruleLink: $ruleLink, ruleContent: $ruleContent, contentWhitelist: $contentWhitelist, contentBlacklist: $contentBlacklist, shouldOverrideUrlLoading: $shouldOverrideUrlLoading, style: $style, enableJs: $enableJs, loadWithBaseUrl: $loadWithBaseUrl, injectJs: $injectJs, preloadJs: $preloadJs, startHtml: $startHtml, startStyle: $startStyle, startJs: $startJs, showWebLog: $showWebLog, lastUpdateTime: $lastUpdateTime, customOrder: $customOrder, rssType: $rssType, preload: $preload, cacheFirst: $cacheFirst, searchUrl: $searchUrl)';
  }
}

/// @nodoc
abstract mixin class _$RssSourceCopyWith<$Res>
    implements $RssSourceCopyWith<$Res> {
  factory _$RssSourceCopyWith(
    _RssSource value,
    $Res Function(_RssSource) _then,
  ) = __$RssSourceCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'sourceUrl') String sourceUrl,
    @JsonKey(name: 'sourceName') String sourceName,
    @JsonKey(name: 'sourceIcon') String sourceIcon,
    @JsonKey(name: 'sourceGroup') String? sourceGroup,
    @JsonKey(name: 'sourceComment') String? sourceComment,
    bool enabled,
    @JsonKey(name: 'variableComment') String? variableComment,
    @JsonKey(name: 'jsLib') String? jsLib,
    @JsonKey(name: 'enabledCookieJar') bool? enabledCookieJar,
    @JsonKey(name: 'concurrentRate') String? concurrentRate,
    String? header,
    @JsonKey(name: 'loginUrl') String? loginUrl,
    @JsonKey(name: 'loginUi') String? loginUi,
    @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
    @JsonKey(name: 'coverDecodeJs') String? coverDecodeJs,
    @JsonKey(name: 'sortUrl') String? sortUrl,
    @JsonKey(name: 'singleUrl') bool singleUrl,
    @JsonKey(name: 'articleStyle') int articleStyle,
    @JsonKey(name: 'ruleArticles') String? ruleArticles,
    @JsonKey(name: 'ruleNextPage') String? ruleNextPage,
    @JsonKey(name: 'ruleTitle') String? ruleTitle,
    @JsonKey(name: 'rulePubDate') String? rulePubDate,
    @JsonKey(name: 'ruleDescription') String? ruleDescription,
    @JsonKey(name: 'ruleImage') String? ruleImage,
    @JsonKey(name: 'ruleLink') String? ruleLink,
    @JsonKey(name: 'ruleContent') String? ruleContent,
    @JsonKey(name: 'contentWhitelist') String? contentWhitelist,
    @JsonKey(name: 'contentBlacklist') String? contentBlacklist,
    @JsonKey(name: 'shouldOverrideUrlLoading') String? shouldOverrideUrlLoading,
    String? style,
    @JsonKey(name: 'enableJs') bool enableJs,
    @JsonKey(name: 'loadWithBaseUrl') bool loadWithBaseUrl,
    @JsonKey(name: 'injectJs') String? injectJs,
    @JsonKey(name: 'preloadJs') String? preloadJs,
    @JsonKey(name: 'startHtml') String? startHtml,
    @JsonKey(name: 'startStyle') String? startStyle,
    @JsonKey(name: 'startJs') String? startJs,
    @JsonKey(name: 'showWebLog') bool showWebLog,
    @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
    @JsonKey(name: 'customOrder') int customOrder,
    @JsonKey(name: 'type') int rssType,
    bool preload,
    @JsonKey(name: 'cacheFirst') bool cacheFirst,
    @JsonKey(name: 'searchUrl') String? searchUrl,
  });
}

/// @nodoc
class __$RssSourceCopyWithImpl<$Res> implements _$RssSourceCopyWith<$Res> {
  __$RssSourceCopyWithImpl(this._self, this._then);

  final _RssSource _self;
  final $Res Function(_RssSource) _then;

  /// Create a copy of RssSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sourceUrl = null,
    Object? sourceName = null,
    Object? sourceIcon = null,
    Object? sourceGroup = freezed,
    Object? sourceComment = freezed,
    Object? enabled = null,
    Object? variableComment = freezed,
    Object? jsLib = freezed,
    Object? enabledCookieJar = freezed,
    Object? concurrentRate = freezed,
    Object? header = freezed,
    Object? loginUrl = freezed,
    Object? loginUi = freezed,
    Object? loginCheckJs = freezed,
    Object? coverDecodeJs = freezed,
    Object? sortUrl = freezed,
    Object? singleUrl = null,
    Object? articleStyle = null,
    Object? ruleArticles = freezed,
    Object? ruleNextPage = freezed,
    Object? ruleTitle = freezed,
    Object? rulePubDate = freezed,
    Object? ruleDescription = freezed,
    Object? ruleImage = freezed,
    Object? ruleLink = freezed,
    Object? ruleContent = freezed,
    Object? contentWhitelist = freezed,
    Object? contentBlacklist = freezed,
    Object? shouldOverrideUrlLoading = freezed,
    Object? style = freezed,
    Object? enableJs = null,
    Object? loadWithBaseUrl = null,
    Object? injectJs = freezed,
    Object? preloadJs = freezed,
    Object? startHtml = freezed,
    Object? startStyle = freezed,
    Object? startJs = freezed,
    Object? showWebLog = null,
    Object? lastUpdateTime = null,
    Object? customOrder = null,
    Object? rssType = null,
    Object? preload = null,
    Object? cacheFirst = null,
    Object? searchUrl = freezed,
  }) {
    return _then(
      _RssSource(
        sourceUrl: null == sourceUrl
            ? _self.sourceUrl
            : sourceUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceName: null == sourceName
            ? _self.sourceName
            : sourceName // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceIcon: null == sourceIcon
            ? _self.sourceIcon
            : sourceIcon // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceGroup: freezed == sourceGroup
            ? _self.sourceGroup
            : sourceGroup // ignore: cast_nullable_to_non_nullable
                  as String?,
        sourceComment: freezed == sourceComment
            ? _self.sourceComment
            : sourceComment // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabled: null == enabled
            ? _self.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        variableComment: freezed == variableComment
            ? _self.variableComment
            : variableComment // ignore: cast_nullable_to_non_nullable
                  as String?,
        jsLib: freezed == jsLib
            ? _self.jsLib
            : jsLib // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabledCookieJar: freezed == enabledCookieJar
            ? _self.enabledCookieJar
            : enabledCookieJar // ignore: cast_nullable_to_non_nullable
                  as bool?,
        concurrentRate: freezed == concurrentRate
            ? _self.concurrentRate
            : concurrentRate // ignore: cast_nullable_to_non_nullable
                  as String?,
        header: freezed == header
            ? _self.header
            : header // ignore: cast_nullable_to_non_nullable
                  as String?,
        loginUrl: freezed == loginUrl
            ? _self.loginUrl
            : loginUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        loginUi: freezed == loginUi
            ? _self.loginUi
            : loginUi // ignore: cast_nullable_to_non_nullable
                  as String?,
        loginCheckJs: freezed == loginCheckJs
            ? _self.loginCheckJs
            : loginCheckJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverDecodeJs: freezed == coverDecodeJs
            ? _self.coverDecodeJs
            : coverDecodeJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        sortUrl: freezed == sortUrl
            ? _self.sortUrl
            : sortUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        singleUrl: null == singleUrl
            ? _self.singleUrl
            : singleUrl // ignore: cast_nullable_to_non_nullable
                  as bool,
        articleStyle: null == articleStyle
            ? _self.articleStyle
            : articleStyle // ignore: cast_nullable_to_non_nullable
                  as int,
        ruleArticles: freezed == ruleArticles
            ? _self.ruleArticles
            : ruleArticles // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleNextPage: freezed == ruleNextPage
            ? _self.ruleNextPage
            : ruleNextPage // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleTitle: freezed == ruleTitle
            ? _self.ruleTitle
            : ruleTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        rulePubDate: freezed == rulePubDate
            ? _self.rulePubDate
            : rulePubDate // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleDescription: freezed == ruleDescription
            ? _self.ruleDescription
            : ruleDescription // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleImage: freezed == ruleImage
            ? _self.ruleImage
            : ruleImage // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleLink: freezed == ruleLink
            ? _self.ruleLink
            : ruleLink // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleContent: freezed == ruleContent
            ? _self.ruleContent
            : ruleContent // ignore: cast_nullable_to_non_nullable
                  as String?,
        contentWhitelist: freezed == contentWhitelist
            ? _self.contentWhitelist
            : contentWhitelist // ignore: cast_nullable_to_non_nullable
                  as String?,
        contentBlacklist: freezed == contentBlacklist
            ? _self.contentBlacklist
            : contentBlacklist // ignore: cast_nullable_to_non_nullable
                  as String?,
        shouldOverrideUrlLoading: freezed == shouldOverrideUrlLoading
            ? _self.shouldOverrideUrlLoading
            : shouldOverrideUrlLoading // ignore: cast_nullable_to_non_nullable
                  as String?,
        style: freezed == style
            ? _self.style
            : style // ignore: cast_nullable_to_non_nullable
                  as String?,
        enableJs: null == enableJs
            ? _self.enableJs
            : enableJs // ignore: cast_nullable_to_non_nullable
                  as bool,
        loadWithBaseUrl: null == loadWithBaseUrl
            ? _self.loadWithBaseUrl
            : loadWithBaseUrl // ignore: cast_nullable_to_non_nullable
                  as bool,
        injectJs: freezed == injectJs
            ? _self.injectJs
            : injectJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        preloadJs: freezed == preloadJs
            ? _self.preloadJs
            : preloadJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        startHtml: freezed == startHtml
            ? _self.startHtml
            : startHtml // ignore: cast_nullable_to_non_nullable
                  as String?,
        startStyle: freezed == startStyle
            ? _self.startStyle
            : startStyle // ignore: cast_nullable_to_non_nullable
                  as String?,
        startJs: freezed == startJs
            ? _self.startJs
            : startJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        showWebLog: null == showWebLog
            ? _self.showWebLog
            : showWebLog // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastUpdateTime: null == lastUpdateTime
            ? _self.lastUpdateTime
            : lastUpdateTime // ignore: cast_nullable_to_non_nullable
                  as int,
        customOrder: null == customOrder
            ? _self.customOrder
            : customOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        rssType: null == rssType
            ? _self.rssType
            : rssType // ignore: cast_nullable_to_non_nullable
                  as int,
        preload: null == preload
            ? _self.preload
            : preload // ignore: cast_nullable_to_non_nullable
                  as bool,
        cacheFirst: null == cacheFirst
            ? _self.cacheFirst
            : cacheFirst // ignore: cast_nullable_to_non_nullable
                  as bool,
        searchUrl: freezed == searchUrl
            ? _self.searchUrl
            : searchUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
