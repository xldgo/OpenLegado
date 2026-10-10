// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookSource {
  @JsonKey(name: 'bookSourceUrl')
  String get bookSourceUrl;
  @JsonKey(name: 'bookSourceName')
  String get bookSourceName;
  @JsonKey(name: 'bookSourceGroup')
  String? get bookSourceGroup;
  @JsonKey(name: 'bookSourceType')
  int get bookSourceType;
  @JsonKey(name: 'bookUrlPattern')
  String? get bookUrlPattern;
  @JsonKey(name: 'customOrder')
  int get customOrder;
  bool get enabled;
  @JsonKey(name: 'enabledExplore')
  bool get enabledExplore;
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
  @JsonKey(name: 'bookSourceComment')
  String? get bookSourceComment;
  @JsonKey(name: 'variableComment')
  String? get variableComment;
  String get variable;
  @JsonKey(name: 'lastUpdateTime')
  int get lastUpdateTime;
  @JsonKey(name: 'respondTime')
  int get respondTime;
  int get weight;
  @JsonKey(name: 'exploreUrl')
  String? get exploreUrl;
  @JsonKey(name: 'exploreScreen')
  String? get exploreScreen;
  @JsonKey(name: 'ruleExplore')
  ExploreRule? get ruleExplore;
  @JsonKey(name: 'searchUrl')
  String? get searchUrl;
  @JsonKey(name: 'ruleSearch')
  SearchRule? get ruleSearch;
  @JsonKey(name: 'ruleBookInfo')
  BookInfoRule? get ruleBookInfo;
  @JsonKey(name: 'ruleToc')
  TocRule? get ruleToc;
  @JsonKey(name: 'ruleContent')
  ContentRule? get ruleContent;
  @JsonKey(name: 'ruleReview')
  ReviewRule? get ruleReview;
  @JsonKey(name: 'mainJs')
  String? get mainJs;
  @JsonKey(name: 'eventListener')
  bool get eventListener;
  @JsonKey(name: 'customButton')
  bool get customButton;

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookSourceCopyWith<BookSource> get copyWith =>
      _$BookSourceCopyWithImpl<BookSource>(this as BookSource, _$identity);

  /// Serializes this BookSource to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as BookSource;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookSource &&
            (identical(other.bookSourceUrl, _this.bookSourceUrl) ||
                other.bookSourceUrl == _this.bookSourceUrl) &&
            (identical(other.bookSourceName, _this.bookSourceName) ||
                other.bookSourceName == _this.bookSourceName) &&
            (identical(other.bookSourceGroup, _this.bookSourceGroup) ||
                other.bookSourceGroup == _this.bookSourceGroup) &&
            (identical(other.bookSourceType, _this.bookSourceType) ||
                other.bookSourceType == _this.bookSourceType) &&
            (identical(other.bookUrlPattern, _this.bookUrlPattern) ||
                other.bookUrlPattern == _this.bookUrlPattern) &&
            (identical(other.customOrder, _this.customOrder) ||
                other.customOrder == _this.customOrder) &&
            (identical(other.enabled, _this.enabled) ||
                other.enabled == _this.enabled) &&
            (identical(other.enabledExplore, _this.enabledExplore) ||
                other.enabledExplore == _this.enabledExplore) &&
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
            (identical(other.bookSourceComment, _this.bookSourceComment) ||
                other.bookSourceComment == _this.bookSourceComment) &&
            (identical(other.variableComment, _this.variableComment) ||
                other.variableComment == _this.variableComment) &&
            (identical(other.variable, _this.variable) ||
                other.variable == _this.variable) &&
            (identical(other.lastUpdateTime, _this.lastUpdateTime) ||
                other.lastUpdateTime == _this.lastUpdateTime) &&
            (identical(other.respondTime, _this.respondTime) ||
                other.respondTime == _this.respondTime) &&
            (identical(other.weight, _this.weight) ||
                other.weight == _this.weight) &&
            (identical(other.exploreUrl, _this.exploreUrl) ||
                other.exploreUrl == _this.exploreUrl) &&
            (identical(other.exploreScreen, _this.exploreScreen) ||
                other.exploreScreen == _this.exploreScreen) &&
            (identical(other.ruleExplore, _this.ruleExplore) ||
                other.ruleExplore == _this.ruleExplore) &&
            (identical(other.searchUrl, _this.searchUrl) ||
                other.searchUrl == _this.searchUrl) &&
            (identical(other.ruleSearch, _this.ruleSearch) ||
                other.ruleSearch == _this.ruleSearch) &&
            (identical(other.ruleBookInfo, _this.ruleBookInfo) ||
                other.ruleBookInfo == _this.ruleBookInfo) &&
            (identical(other.ruleToc, _this.ruleToc) ||
                other.ruleToc == _this.ruleToc) &&
            (identical(other.ruleContent, _this.ruleContent) ||
                other.ruleContent == _this.ruleContent) &&
            (identical(other.ruleReview, _this.ruleReview) ||
                other.ruleReview == _this.ruleReview) &&
            (identical(other.mainJs, _this.mainJs) ||
                other.mainJs == _this.mainJs) &&
            (identical(other.eventListener, _this.eventListener) ||
                other.eventListener == _this.eventListener) &&
            (identical(other.customButton, _this.customButton) ||
                other.customButton == _this.customButton));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as BookSource;
    return Object.hashAll([
      runtimeType,
      _this.bookSourceUrl,
      _this.bookSourceName,
      _this.bookSourceGroup,
      _this.bookSourceType,
      _this.bookUrlPattern,
      _this.customOrder,
      _this.enabled,
      _this.enabledExplore,
      _this.jsLib,
      _this.enabledCookieJar,
      _this.concurrentRate,
      _this.header,
      _this.loginUrl,
      _this.loginUi,
      _this.loginCheckJs,
      _this.coverDecodeJs,
      _this.bookSourceComment,
      _this.variableComment,
      _this.variable,
      _this.lastUpdateTime,
      _this.respondTime,
      _this.weight,
      _this.exploreUrl,
      _this.exploreScreen,
      _this.ruleExplore,
      _this.searchUrl,
      _this.ruleSearch,
      _this.ruleBookInfo,
      _this.ruleToc,
      _this.ruleContent,
      _this.ruleReview,
      _this.mainJs,
      _this.eventListener,
      _this.customButton,
    ]);
  }

  @override
  String toString() {
    final _this = this as BookSource;
    return 'BookSource(bookSourceUrl: ${_this.bookSourceUrl}, bookSourceName: ${_this.bookSourceName}, bookSourceGroup: ${_this.bookSourceGroup}, bookSourceType: ${_this.bookSourceType}, bookUrlPattern: ${_this.bookUrlPattern}, customOrder: ${_this.customOrder}, enabled: ${_this.enabled}, enabledExplore: ${_this.enabledExplore}, jsLib: ${_this.jsLib}, enabledCookieJar: ${_this.enabledCookieJar}, concurrentRate: ${_this.concurrentRate}, header: ${_this.header}, loginUrl: ${_this.loginUrl}, loginUi: ${_this.loginUi}, loginCheckJs: ${_this.loginCheckJs}, coverDecodeJs: ${_this.coverDecodeJs}, bookSourceComment: ${_this.bookSourceComment}, variableComment: ${_this.variableComment}, variable: ${_this.variable}, lastUpdateTime: ${_this.lastUpdateTime}, respondTime: ${_this.respondTime}, weight: ${_this.weight}, exploreUrl: ${_this.exploreUrl}, exploreScreen: ${_this.exploreScreen}, ruleExplore: ${_this.ruleExplore}, searchUrl: ${_this.searchUrl}, ruleSearch: ${_this.ruleSearch}, ruleBookInfo: ${_this.ruleBookInfo}, ruleToc: ${_this.ruleToc}, ruleContent: ${_this.ruleContent}, ruleReview: ${_this.ruleReview}, mainJs: ${_this.mainJs}, eventListener: ${_this.eventListener}, customButton: ${_this.customButton})';
  }
}

/// @nodoc
abstract mixin class $BookSourceCopyWith<$Res> {
  factory $BookSourceCopyWith(
    BookSource value,
    $Res Function(BookSource) _then,
  ) = _$BookSourceCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'bookSourceUrl') String bookSourceUrl,
    @JsonKey(name: 'bookSourceName') String bookSourceName,
    @JsonKey(name: 'bookSourceGroup') String? bookSourceGroup,
    @JsonKey(name: 'bookSourceType') int bookSourceType,
    @JsonKey(name: 'bookUrlPattern') String? bookUrlPattern,
    @JsonKey(name: 'customOrder') int customOrder,
    bool enabled,
    @JsonKey(name: 'enabledExplore') bool enabledExplore,
    @JsonKey(name: 'jsLib') String? jsLib,
    @JsonKey(name: 'enabledCookieJar') bool? enabledCookieJar,
    @JsonKey(name: 'concurrentRate') String? concurrentRate,
    String? header,
    @JsonKey(name: 'loginUrl') String? loginUrl,
    @JsonKey(name: 'loginUi') String? loginUi,
    @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
    @JsonKey(name: 'coverDecodeJs') String? coverDecodeJs,
    @JsonKey(name: 'bookSourceComment') String? bookSourceComment,
    @JsonKey(name: 'variableComment') String? variableComment,
    String variable,
    @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
    @JsonKey(name: 'respondTime') int respondTime,
    int weight,
    @JsonKey(name: 'exploreUrl') String? exploreUrl,
    @JsonKey(name: 'exploreScreen') String? exploreScreen,
    @JsonKey(name: 'ruleExplore') ExploreRule? ruleExplore,
    @JsonKey(name: 'searchUrl') String? searchUrl,
    @JsonKey(name: 'ruleSearch') SearchRule? ruleSearch,
    @JsonKey(name: 'ruleBookInfo') BookInfoRule? ruleBookInfo,
    @JsonKey(name: 'ruleToc') TocRule? ruleToc,
    @JsonKey(name: 'ruleContent') ContentRule? ruleContent,
    @JsonKey(name: 'ruleReview') ReviewRule? ruleReview,
    @JsonKey(name: 'mainJs') String? mainJs,
    @JsonKey(name: 'eventListener') bool eventListener,
    @JsonKey(name: 'customButton') bool customButton,
  });

  $ExploreRuleCopyWith<$Res>? get ruleExplore;
  $SearchRuleCopyWith<$Res>? get ruleSearch;
  $BookInfoRuleCopyWith<$Res>? get ruleBookInfo;
  $TocRuleCopyWith<$Res>? get ruleToc;
  $ContentRuleCopyWith<$Res>? get ruleContent;
  $ReviewRuleCopyWith<$Res>? get ruleReview;
}

/// @nodoc
class _$BookSourceCopyWithImpl<$Res> implements $BookSourceCopyWith<$Res> {
  _$BookSourceCopyWithImpl(this._self, this._then);

  final BookSource _self;
  final $Res Function(BookSource) _then;

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookSourceUrl = null,
    Object? bookSourceName = null,
    Object? bookSourceGroup = freezed,
    Object? bookSourceType = null,
    Object? bookUrlPattern = freezed,
    Object? customOrder = null,
    Object? enabled = null,
    Object? enabledExplore = null,
    Object? jsLib = freezed,
    Object? enabledCookieJar = freezed,
    Object? concurrentRate = freezed,
    Object? header = freezed,
    Object? loginUrl = freezed,
    Object? loginUi = freezed,
    Object? loginCheckJs = freezed,
    Object? coverDecodeJs = freezed,
    Object? bookSourceComment = freezed,
    Object? variableComment = freezed,
    Object? variable = null,
    Object? lastUpdateTime = null,
    Object? respondTime = null,
    Object? weight = null,
    Object? exploreUrl = freezed,
    Object? exploreScreen = freezed,
    Object? ruleExplore = freezed,
    Object? searchUrl = freezed,
    Object? ruleSearch = freezed,
    Object? ruleBookInfo = freezed,
    Object? ruleToc = freezed,
    Object? ruleContent = freezed,
    Object? ruleReview = freezed,
    Object? mainJs = freezed,
    Object? eventListener = null,
    Object? customButton = null,
  }) {
    return _then(
      BookSource(
        bookSourceUrl: null == bookSourceUrl
            ? _self.bookSourceUrl
            : bookSourceUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        bookSourceName: null == bookSourceName
            ? _self.bookSourceName
            : bookSourceName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookSourceGroup: freezed == bookSourceGroup
            ? _self.bookSourceGroup
            : bookSourceGroup // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookSourceType: null == bookSourceType
            ? _self.bookSourceType
            : bookSourceType // ignore: cast_nullable_to_non_nullable
                  as int,
        bookUrlPattern: freezed == bookUrlPattern
            ? _self.bookUrlPattern
            : bookUrlPattern // ignore: cast_nullable_to_non_nullable
                  as String?,
        customOrder: null == customOrder
            ? _self.customOrder
            : customOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        enabled: null == enabled
            ? _self.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        enabledExplore: null == enabledExplore
            ? _self.enabledExplore
            : enabledExplore // ignore: cast_nullable_to_non_nullable
                  as bool,
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
        bookSourceComment: freezed == bookSourceComment
            ? _self.bookSourceComment
            : bookSourceComment // ignore: cast_nullable_to_non_nullable
                  as String?,
        variableComment: freezed == variableComment
            ? _self.variableComment
            : variableComment // ignore: cast_nullable_to_non_nullable
                  as String?,
        variable: null == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String,
        lastUpdateTime: null == lastUpdateTime
            ? _self.lastUpdateTime
            : lastUpdateTime // ignore: cast_nullable_to_non_nullable
                  as int,
        respondTime: null == respondTime
            ? _self.respondTime
            : respondTime // ignore: cast_nullable_to_non_nullable
                  as int,
        weight: null == weight
            ? _self.weight
            : weight // ignore: cast_nullable_to_non_nullable
                  as int,
        exploreUrl: freezed == exploreUrl
            ? _self.exploreUrl
            : exploreUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        exploreScreen: freezed == exploreScreen
            ? _self.exploreScreen
            : exploreScreen // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleExplore: freezed == ruleExplore
            ? _self.ruleExplore
            : ruleExplore // ignore: cast_nullable_to_non_nullable
                  as ExploreRule?,
        searchUrl: freezed == searchUrl
            ? _self.searchUrl
            : searchUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleSearch: freezed == ruleSearch
            ? _self.ruleSearch
            : ruleSearch // ignore: cast_nullable_to_non_nullable
                  as SearchRule?,
        ruleBookInfo: freezed == ruleBookInfo
            ? _self.ruleBookInfo
            : ruleBookInfo // ignore: cast_nullable_to_non_nullable
                  as BookInfoRule?,
        ruleToc: freezed == ruleToc
            ? _self.ruleToc
            : ruleToc // ignore: cast_nullable_to_non_nullable
                  as TocRule?,
        ruleContent: freezed == ruleContent
            ? _self.ruleContent
            : ruleContent // ignore: cast_nullable_to_non_nullable
                  as ContentRule?,
        ruleReview: freezed == ruleReview
            ? _self.ruleReview
            : ruleReview // ignore: cast_nullable_to_non_nullable
                  as ReviewRule?,
        mainJs: freezed == mainJs
            ? _self.mainJs
            : mainJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        eventListener: null == eventListener
            ? _self.eventListener
            : eventListener // ignore: cast_nullable_to_non_nullable
                  as bool,
        customButton: null == customButton
            ? _self.customButton
            : customButton // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ExploreRuleCopyWith<$Res>? get ruleExplore {
    if (_self.ruleExplore == null) {
      return null;
    }

    return $ExploreRuleCopyWith<$Res>(_self.ruleExplore!, (value) {
      return _then(_self.copyWith(ruleExplore: value));
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SearchRuleCopyWith<$Res>? get ruleSearch {
    if (_self.ruleSearch == null) {
      return null;
    }

    return $SearchRuleCopyWith<$Res>(_self.ruleSearch!, (value) {
      return _then(_self.copyWith(ruleSearch: value));
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BookInfoRuleCopyWith<$Res>? get ruleBookInfo {
    if (_self.ruleBookInfo == null) {
      return null;
    }

    return $BookInfoRuleCopyWith<$Res>(_self.ruleBookInfo!, (value) {
      return _then(_self.copyWith(ruleBookInfo: value));
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TocRuleCopyWith<$Res>? get ruleToc {
    if (_self.ruleToc == null) {
      return null;
    }

    return $TocRuleCopyWith<$Res>(_self.ruleToc!, (value) {
      return _then(_self.copyWith(ruleToc: value));
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ContentRuleCopyWith<$Res>? get ruleContent {
    if (_self.ruleContent == null) {
      return null;
    }

    return $ContentRuleCopyWith<$Res>(_self.ruleContent!, (value) {
      return _then(_self.copyWith(ruleContent: value));
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ReviewRuleCopyWith<$Res>? get ruleReview {
    if (_self.ruleReview == null) {
      return null;
    }

    return $ReviewRuleCopyWith<$Res>(_self.ruleReview!, (value) {
      return _then(_self.copyWith(ruleReview: value));
    });
  }
}

/// Adds pattern-matching-related methods to [BookSource].
extension BookSourcePatterns on BookSource {
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
    TResult Function(_BookSource value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookSource() when $default != null:
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
    TResult Function(_BookSource value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookSource():
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
    TResult? Function(_BookSource value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookSource() when $default != null:
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
      @JsonKey(name: 'bookSourceUrl') String bookSourceUrl,
      @JsonKey(name: 'bookSourceName') String bookSourceName,
      @JsonKey(name: 'bookSourceGroup') String? bookSourceGroup,
      @JsonKey(name: 'bookSourceType') int bookSourceType,
      @JsonKey(name: 'bookUrlPattern') String? bookUrlPattern,
      @JsonKey(name: 'customOrder') int customOrder,
      bool enabled,
      @JsonKey(name: 'enabledExplore') bool enabledExplore,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'enabledCookieJar') bool? enabledCookieJar,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      String? header,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi') String? loginUi,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      @JsonKey(name: 'coverDecodeJs') String? coverDecodeJs,
      @JsonKey(name: 'bookSourceComment') String? bookSourceComment,
      @JsonKey(name: 'variableComment') String? variableComment,
      String variable,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'respondTime') int respondTime,
      int weight,
      @JsonKey(name: 'exploreUrl') String? exploreUrl,
      @JsonKey(name: 'exploreScreen') String? exploreScreen,
      @JsonKey(name: 'ruleExplore') ExploreRule? ruleExplore,
      @JsonKey(name: 'searchUrl') String? searchUrl,
      @JsonKey(name: 'ruleSearch') SearchRule? ruleSearch,
      @JsonKey(name: 'ruleBookInfo') BookInfoRule? ruleBookInfo,
      @JsonKey(name: 'ruleToc') TocRule? ruleToc,
      @JsonKey(name: 'ruleContent') ContentRule? ruleContent,
      @JsonKey(name: 'ruleReview') ReviewRule? ruleReview,
      @JsonKey(name: 'mainJs') String? mainJs,
      @JsonKey(name: 'eventListener') bool eventListener,
      @JsonKey(name: 'customButton') bool customButton,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookSource() when $default != null:
        return $default(
          _that.bookSourceUrl,
          _that.bookSourceName,
          _that.bookSourceGroup,
          _that.bookSourceType,
          _that.bookUrlPattern,
          _that.customOrder,
          _that.enabled,
          _that.enabledExplore,
          _that.jsLib,
          _that.enabledCookieJar,
          _that.concurrentRate,
          _that.header,
          _that.loginUrl,
          _that.loginUi,
          _that.loginCheckJs,
          _that.coverDecodeJs,
          _that.bookSourceComment,
          _that.variableComment,
          _that.variable,
          _that.lastUpdateTime,
          _that.respondTime,
          _that.weight,
          _that.exploreUrl,
          _that.exploreScreen,
          _that.ruleExplore,
          _that.searchUrl,
          _that.ruleSearch,
          _that.ruleBookInfo,
          _that.ruleToc,
          _that.ruleContent,
          _that.ruleReview,
          _that.mainJs,
          _that.eventListener,
          _that.customButton,
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
      @JsonKey(name: 'bookSourceUrl') String bookSourceUrl,
      @JsonKey(name: 'bookSourceName') String bookSourceName,
      @JsonKey(name: 'bookSourceGroup') String? bookSourceGroup,
      @JsonKey(name: 'bookSourceType') int bookSourceType,
      @JsonKey(name: 'bookUrlPattern') String? bookUrlPattern,
      @JsonKey(name: 'customOrder') int customOrder,
      bool enabled,
      @JsonKey(name: 'enabledExplore') bool enabledExplore,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'enabledCookieJar') bool? enabledCookieJar,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      String? header,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi') String? loginUi,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      @JsonKey(name: 'coverDecodeJs') String? coverDecodeJs,
      @JsonKey(name: 'bookSourceComment') String? bookSourceComment,
      @JsonKey(name: 'variableComment') String? variableComment,
      String variable,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'respondTime') int respondTime,
      int weight,
      @JsonKey(name: 'exploreUrl') String? exploreUrl,
      @JsonKey(name: 'exploreScreen') String? exploreScreen,
      @JsonKey(name: 'ruleExplore') ExploreRule? ruleExplore,
      @JsonKey(name: 'searchUrl') String? searchUrl,
      @JsonKey(name: 'ruleSearch') SearchRule? ruleSearch,
      @JsonKey(name: 'ruleBookInfo') BookInfoRule? ruleBookInfo,
      @JsonKey(name: 'ruleToc') TocRule? ruleToc,
      @JsonKey(name: 'ruleContent') ContentRule? ruleContent,
      @JsonKey(name: 'ruleReview') ReviewRule? ruleReview,
      @JsonKey(name: 'mainJs') String? mainJs,
      @JsonKey(name: 'eventListener') bool eventListener,
      @JsonKey(name: 'customButton') bool customButton,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookSource():
        return $default(
          _that.bookSourceUrl,
          _that.bookSourceName,
          _that.bookSourceGroup,
          _that.bookSourceType,
          _that.bookUrlPattern,
          _that.customOrder,
          _that.enabled,
          _that.enabledExplore,
          _that.jsLib,
          _that.enabledCookieJar,
          _that.concurrentRate,
          _that.header,
          _that.loginUrl,
          _that.loginUi,
          _that.loginCheckJs,
          _that.coverDecodeJs,
          _that.bookSourceComment,
          _that.variableComment,
          _that.variable,
          _that.lastUpdateTime,
          _that.respondTime,
          _that.weight,
          _that.exploreUrl,
          _that.exploreScreen,
          _that.ruleExplore,
          _that.searchUrl,
          _that.ruleSearch,
          _that.ruleBookInfo,
          _that.ruleToc,
          _that.ruleContent,
          _that.ruleReview,
          _that.mainJs,
          _that.eventListener,
          _that.customButton,
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
      @JsonKey(name: 'bookSourceUrl') String bookSourceUrl,
      @JsonKey(name: 'bookSourceName') String bookSourceName,
      @JsonKey(name: 'bookSourceGroup') String? bookSourceGroup,
      @JsonKey(name: 'bookSourceType') int bookSourceType,
      @JsonKey(name: 'bookUrlPattern') String? bookUrlPattern,
      @JsonKey(name: 'customOrder') int customOrder,
      bool enabled,
      @JsonKey(name: 'enabledExplore') bool enabledExplore,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'enabledCookieJar') bool? enabledCookieJar,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      String? header,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi') String? loginUi,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      @JsonKey(name: 'coverDecodeJs') String? coverDecodeJs,
      @JsonKey(name: 'bookSourceComment') String? bookSourceComment,
      @JsonKey(name: 'variableComment') String? variableComment,
      String variable,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'respondTime') int respondTime,
      int weight,
      @JsonKey(name: 'exploreUrl') String? exploreUrl,
      @JsonKey(name: 'exploreScreen') String? exploreScreen,
      @JsonKey(name: 'ruleExplore') ExploreRule? ruleExplore,
      @JsonKey(name: 'searchUrl') String? searchUrl,
      @JsonKey(name: 'ruleSearch') SearchRule? ruleSearch,
      @JsonKey(name: 'ruleBookInfo') BookInfoRule? ruleBookInfo,
      @JsonKey(name: 'ruleToc') TocRule? ruleToc,
      @JsonKey(name: 'ruleContent') ContentRule? ruleContent,
      @JsonKey(name: 'ruleReview') ReviewRule? ruleReview,
      @JsonKey(name: 'mainJs') String? mainJs,
      @JsonKey(name: 'eventListener') bool eventListener,
      @JsonKey(name: 'customButton') bool customButton,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookSource() when $default != null:
        return $default(
          _that.bookSourceUrl,
          _that.bookSourceName,
          _that.bookSourceGroup,
          _that.bookSourceType,
          _that.bookUrlPattern,
          _that.customOrder,
          _that.enabled,
          _that.enabledExplore,
          _that.jsLib,
          _that.enabledCookieJar,
          _that.concurrentRate,
          _that.header,
          _that.loginUrl,
          _that.loginUi,
          _that.loginCheckJs,
          _that.coverDecodeJs,
          _that.bookSourceComment,
          _that.variableComment,
          _that.variable,
          _that.lastUpdateTime,
          _that.respondTime,
          _that.weight,
          _that.exploreUrl,
          _that.exploreScreen,
          _that.ruleExplore,
          _that.searchUrl,
          _that.ruleSearch,
          _that.ruleBookInfo,
          _that.ruleToc,
          _that.ruleContent,
          _that.ruleReview,
          _that.mainJs,
          _that.eventListener,
          _that.customButton,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BookSource implements BookSource {
  const _BookSource({
    @JsonKey(name: 'bookSourceUrl') this.bookSourceUrl = '',
    @JsonKey(name: 'bookSourceName') this.bookSourceName = '',
    @JsonKey(name: 'bookSourceGroup') this.bookSourceGroup,
    @JsonKey(name: 'bookSourceType') this.bookSourceType = 0,
    @JsonKey(name: 'bookUrlPattern') this.bookUrlPattern,
    @JsonKey(name: 'customOrder') this.customOrder = 0,
    this.enabled = true,
    @JsonKey(name: 'enabledExplore') this.enabledExplore = true,
    @JsonKey(name: 'jsLib') this.jsLib,
    @JsonKey(name: 'enabledCookieJar') this.enabledCookieJar,
    @JsonKey(name: 'concurrentRate') this.concurrentRate,
    this.header,
    @JsonKey(name: 'loginUrl') this.loginUrl,
    @JsonKey(name: 'loginUi') this.loginUi,
    @JsonKey(name: 'loginCheckJs') this.loginCheckJs,
    @JsonKey(name: 'coverDecodeJs') this.coverDecodeJs,
    @JsonKey(name: 'bookSourceComment') this.bookSourceComment,
    @JsonKey(name: 'variableComment') this.variableComment,
    this.variable = '',
    @JsonKey(name: 'lastUpdateTime') this.lastUpdateTime = 0,
    @JsonKey(name: 'respondTime') this.respondTime = 180000,
    this.weight = 0,
    @JsonKey(name: 'exploreUrl') this.exploreUrl,
    @JsonKey(name: 'exploreScreen') this.exploreScreen,
    @JsonKey(name: 'ruleExplore') this.ruleExplore,
    @JsonKey(name: 'searchUrl') this.searchUrl,
    @JsonKey(name: 'ruleSearch') this.ruleSearch,
    @JsonKey(name: 'ruleBookInfo') this.ruleBookInfo,
    @JsonKey(name: 'ruleToc') this.ruleToc,
    @JsonKey(name: 'ruleContent') this.ruleContent,
    @JsonKey(name: 'ruleReview') this.ruleReview,
    @JsonKey(name: 'mainJs') this.mainJs,
    @JsonKey(name: 'eventListener') this.eventListener = false,
    @JsonKey(name: 'customButton') this.customButton = false,
  });
  factory _BookSource.fromJson(Map<String, dynamic> json) =>
      _$BookSourceFromJson(json);

  @override
  @JsonKey(name: 'bookSourceUrl')
  final String bookSourceUrl;
  @override
  @JsonKey(name: 'bookSourceName')
  final String bookSourceName;
  @override
  @JsonKey(name: 'bookSourceGroup')
  final String? bookSourceGroup;
  @override
  @JsonKey(name: 'bookSourceType')
  final int bookSourceType;
  @override
  @JsonKey(name: 'bookUrlPattern')
  final String? bookUrlPattern;
  @override
  @JsonKey(name: 'customOrder')
  final int customOrder;
  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey(name: 'enabledExplore')
  final bool enabledExplore;
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
  @JsonKey(name: 'bookSourceComment')
  final String? bookSourceComment;
  @override
  @JsonKey(name: 'variableComment')
  final String? variableComment;
  @override
  @JsonKey()
  final String variable;
  @override
  @JsonKey(name: 'lastUpdateTime')
  final int lastUpdateTime;
  @override
  @JsonKey(name: 'respondTime')
  final int respondTime;
  @override
  @JsonKey()
  final int weight;
  @override
  @JsonKey(name: 'exploreUrl')
  final String? exploreUrl;
  @override
  @JsonKey(name: 'exploreScreen')
  final String? exploreScreen;
  @override
  @JsonKey(name: 'ruleExplore')
  final ExploreRule? ruleExplore;
  @override
  @JsonKey(name: 'searchUrl')
  final String? searchUrl;
  @override
  @JsonKey(name: 'ruleSearch')
  final SearchRule? ruleSearch;
  @override
  @JsonKey(name: 'ruleBookInfo')
  final BookInfoRule? ruleBookInfo;
  @override
  @JsonKey(name: 'ruleToc')
  final TocRule? ruleToc;
  @override
  @JsonKey(name: 'ruleContent')
  final ContentRule? ruleContent;
  @override
  @JsonKey(name: 'ruleReview')
  final ReviewRule? ruleReview;
  @override
  @JsonKey(name: 'mainJs')
  final String? mainJs;
  @override
  @JsonKey(name: 'eventListener')
  final bool eventListener;
  @override
  @JsonKey(name: 'customButton')
  final bool customButton;

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookSourceCopyWith<_BookSource> get copyWith =>
      __$BookSourceCopyWithImpl<_BookSource>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BookSourceToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookSource &&
            (identical(other.bookSourceUrl, bookSourceUrl) ||
                other.bookSourceUrl == bookSourceUrl) &&
            (identical(other.bookSourceName, bookSourceName) ||
                other.bookSourceName == bookSourceName) &&
            (identical(other.bookSourceGroup, bookSourceGroup) ||
                other.bookSourceGroup == bookSourceGroup) &&
            (identical(other.bookSourceType, bookSourceType) ||
                other.bookSourceType == bookSourceType) &&
            (identical(other.bookUrlPattern, bookUrlPattern) ||
                other.bookUrlPattern == bookUrlPattern) &&
            (identical(other.customOrder, customOrder) ||
                other.customOrder == customOrder) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.enabledExplore, enabledExplore) ||
                other.enabledExplore == enabledExplore) &&
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
            (identical(other.bookSourceComment, bookSourceComment) ||
                other.bookSourceComment == bookSourceComment) &&
            (identical(other.variableComment, variableComment) ||
                other.variableComment == variableComment) &&
            (identical(other.variable, variable) ||
                other.variable == variable) &&
            (identical(other.lastUpdateTime, lastUpdateTime) ||
                other.lastUpdateTime == lastUpdateTime) &&
            (identical(other.respondTime, respondTime) ||
                other.respondTime == respondTime) &&
            (identical(other.weight, weight) || other.weight == weight) &&
            (identical(other.exploreUrl, exploreUrl) ||
                other.exploreUrl == exploreUrl) &&
            (identical(other.exploreScreen, exploreScreen) ||
                other.exploreScreen == exploreScreen) &&
            (identical(other.ruleExplore, ruleExplore) ||
                other.ruleExplore == ruleExplore) &&
            (identical(other.searchUrl, searchUrl) ||
                other.searchUrl == searchUrl) &&
            (identical(other.ruleSearch, ruleSearch) ||
                other.ruleSearch == ruleSearch) &&
            (identical(other.ruleBookInfo, ruleBookInfo) ||
                other.ruleBookInfo == ruleBookInfo) &&
            (identical(other.ruleToc, ruleToc) || other.ruleToc == ruleToc) &&
            (identical(other.ruleContent, ruleContent) ||
                other.ruleContent == ruleContent) &&
            (identical(other.ruleReview, ruleReview) ||
                other.ruleReview == ruleReview) &&
            (identical(other.mainJs, mainJs) || other.mainJs == mainJs) &&
            (identical(other.eventListener, eventListener) ||
                other.eventListener == eventListener) &&
            (identical(other.customButton, customButton) ||
                other.customButton == customButton));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hashAll([
      runtimeType,
      bookSourceUrl,
      bookSourceName,
      bookSourceGroup,
      bookSourceType,
      bookUrlPattern,
      customOrder,
      enabled,
      enabledExplore,
      jsLib,
      enabledCookieJar,
      concurrentRate,
      header,
      loginUrl,
      loginUi,
      loginCheckJs,
      coverDecodeJs,
      bookSourceComment,
      variableComment,
      variable,
      lastUpdateTime,
      respondTime,
      weight,
      exploreUrl,
      exploreScreen,
      ruleExplore,
      searchUrl,
      ruleSearch,
      ruleBookInfo,
      ruleToc,
      ruleContent,
      ruleReview,
      mainJs,
      eventListener,
      customButton,
    ]);
  }

  @override
  String toString() {
    return 'BookSource(bookSourceUrl: $bookSourceUrl, bookSourceName: $bookSourceName, bookSourceGroup: $bookSourceGroup, bookSourceType: $bookSourceType, bookUrlPattern: $bookUrlPattern, customOrder: $customOrder, enabled: $enabled, enabledExplore: $enabledExplore, jsLib: $jsLib, enabledCookieJar: $enabledCookieJar, concurrentRate: $concurrentRate, header: $header, loginUrl: $loginUrl, loginUi: $loginUi, loginCheckJs: $loginCheckJs, coverDecodeJs: $coverDecodeJs, bookSourceComment: $bookSourceComment, variableComment: $variableComment, variable: $variable, lastUpdateTime: $lastUpdateTime, respondTime: $respondTime, weight: $weight, exploreUrl: $exploreUrl, exploreScreen: $exploreScreen, ruleExplore: $ruleExplore, searchUrl: $searchUrl, ruleSearch: $ruleSearch, ruleBookInfo: $ruleBookInfo, ruleToc: $ruleToc, ruleContent: $ruleContent, ruleReview: $ruleReview, mainJs: $mainJs, eventListener: $eventListener, customButton: $customButton)';
  }
}

/// @nodoc
abstract mixin class _$BookSourceCopyWith<$Res>
    implements $BookSourceCopyWith<$Res> {
  factory _$BookSourceCopyWith(
    _BookSource value,
    $Res Function(_BookSource) _then,
  ) = __$BookSourceCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'bookSourceUrl') String bookSourceUrl,
    @JsonKey(name: 'bookSourceName') String bookSourceName,
    @JsonKey(name: 'bookSourceGroup') String? bookSourceGroup,
    @JsonKey(name: 'bookSourceType') int bookSourceType,
    @JsonKey(name: 'bookUrlPattern') String? bookUrlPattern,
    @JsonKey(name: 'customOrder') int customOrder,
    bool enabled,
    @JsonKey(name: 'enabledExplore') bool enabledExplore,
    @JsonKey(name: 'jsLib') String? jsLib,
    @JsonKey(name: 'enabledCookieJar') bool? enabledCookieJar,
    @JsonKey(name: 'concurrentRate') String? concurrentRate,
    String? header,
    @JsonKey(name: 'loginUrl') String? loginUrl,
    @JsonKey(name: 'loginUi') String? loginUi,
    @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
    @JsonKey(name: 'coverDecodeJs') String? coverDecodeJs,
    @JsonKey(name: 'bookSourceComment') String? bookSourceComment,
    @JsonKey(name: 'variableComment') String? variableComment,
    String variable,
    @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
    @JsonKey(name: 'respondTime') int respondTime,
    int weight,
    @JsonKey(name: 'exploreUrl') String? exploreUrl,
    @JsonKey(name: 'exploreScreen') String? exploreScreen,
    @JsonKey(name: 'ruleExplore') ExploreRule? ruleExplore,
    @JsonKey(name: 'searchUrl') String? searchUrl,
    @JsonKey(name: 'ruleSearch') SearchRule? ruleSearch,
    @JsonKey(name: 'ruleBookInfo') BookInfoRule? ruleBookInfo,
    @JsonKey(name: 'ruleToc') TocRule? ruleToc,
    @JsonKey(name: 'ruleContent') ContentRule? ruleContent,
    @JsonKey(name: 'ruleReview') ReviewRule? ruleReview,
    @JsonKey(name: 'mainJs') String? mainJs,
    @JsonKey(name: 'eventListener') bool eventListener,
    @JsonKey(name: 'customButton') bool customButton,
  });

  @override
  $ExploreRuleCopyWith<$Res>? get ruleExplore;
  @override
  $SearchRuleCopyWith<$Res>? get ruleSearch;
  @override
  $BookInfoRuleCopyWith<$Res>? get ruleBookInfo;
  @override
  $TocRuleCopyWith<$Res>? get ruleToc;
  @override
  $ContentRuleCopyWith<$Res>? get ruleContent;
  @override
  $ReviewRuleCopyWith<$Res>? get ruleReview;
}

/// @nodoc
class __$BookSourceCopyWithImpl<$Res> implements _$BookSourceCopyWith<$Res> {
  __$BookSourceCopyWithImpl(this._self, this._then);

  final _BookSource _self;
  final $Res Function(_BookSource) _then;

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookSourceUrl = null,
    Object? bookSourceName = null,
    Object? bookSourceGroup = freezed,
    Object? bookSourceType = null,
    Object? bookUrlPattern = freezed,
    Object? customOrder = null,
    Object? enabled = null,
    Object? enabledExplore = null,
    Object? jsLib = freezed,
    Object? enabledCookieJar = freezed,
    Object? concurrentRate = freezed,
    Object? header = freezed,
    Object? loginUrl = freezed,
    Object? loginUi = freezed,
    Object? loginCheckJs = freezed,
    Object? coverDecodeJs = freezed,
    Object? bookSourceComment = freezed,
    Object? variableComment = freezed,
    Object? variable = null,
    Object? lastUpdateTime = null,
    Object? respondTime = null,
    Object? weight = null,
    Object? exploreUrl = freezed,
    Object? exploreScreen = freezed,
    Object? ruleExplore = freezed,
    Object? searchUrl = freezed,
    Object? ruleSearch = freezed,
    Object? ruleBookInfo = freezed,
    Object? ruleToc = freezed,
    Object? ruleContent = freezed,
    Object? ruleReview = freezed,
    Object? mainJs = freezed,
    Object? eventListener = null,
    Object? customButton = null,
  }) {
    return _then(
      _BookSource(
        bookSourceUrl: null == bookSourceUrl
            ? _self.bookSourceUrl
            : bookSourceUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        bookSourceName: null == bookSourceName
            ? _self.bookSourceName
            : bookSourceName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookSourceGroup: freezed == bookSourceGroup
            ? _self.bookSourceGroup
            : bookSourceGroup // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookSourceType: null == bookSourceType
            ? _self.bookSourceType
            : bookSourceType // ignore: cast_nullable_to_non_nullable
                  as int,
        bookUrlPattern: freezed == bookUrlPattern
            ? _self.bookUrlPattern
            : bookUrlPattern // ignore: cast_nullable_to_non_nullable
                  as String?,
        customOrder: null == customOrder
            ? _self.customOrder
            : customOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        enabled: null == enabled
            ? _self.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        enabledExplore: null == enabledExplore
            ? _self.enabledExplore
            : enabledExplore // ignore: cast_nullable_to_non_nullable
                  as bool,
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
        bookSourceComment: freezed == bookSourceComment
            ? _self.bookSourceComment
            : bookSourceComment // ignore: cast_nullable_to_non_nullable
                  as String?,
        variableComment: freezed == variableComment
            ? _self.variableComment
            : variableComment // ignore: cast_nullable_to_non_nullable
                  as String?,
        variable: null == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String,
        lastUpdateTime: null == lastUpdateTime
            ? _self.lastUpdateTime
            : lastUpdateTime // ignore: cast_nullable_to_non_nullable
                  as int,
        respondTime: null == respondTime
            ? _self.respondTime
            : respondTime // ignore: cast_nullable_to_non_nullable
                  as int,
        weight: null == weight
            ? _self.weight
            : weight // ignore: cast_nullable_to_non_nullable
                  as int,
        exploreUrl: freezed == exploreUrl
            ? _self.exploreUrl
            : exploreUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        exploreScreen: freezed == exploreScreen
            ? _self.exploreScreen
            : exploreScreen // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleExplore: freezed == ruleExplore
            ? _self.ruleExplore
            : ruleExplore // ignore: cast_nullable_to_non_nullable
                  as ExploreRule?,
        searchUrl: freezed == searchUrl
            ? _self.searchUrl
            : searchUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        ruleSearch: freezed == ruleSearch
            ? _self.ruleSearch
            : ruleSearch // ignore: cast_nullable_to_non_nullable
                  as SearchRule?,
        ruleBookInfo: freezed == ruleBookInfo
            ? _self.ruleBookInfo
            : ruleBookInfo // ignore: cast_nullable_to_non_nullable
                  as BookInfoRule?,
        ruleToc: freezed == ruleToc
            ? _self.ruleToc
            : ruleToc // ignore: cast_nullable_to_non_nullable
                  as TocRule?,
        ruleContent: freezed == ruleContent
            ? _self.ruleContent
            : ruleContent // ignore: cast_nullable_to_non_nullable
                  as ContentRule?,
        ruleReview: freezed == ruleReview
            ? _self.ruleReview
            : ruleReview // ignore: cast_nullable_to_non_nullable
                  as ReviewRule?,
        mainJs: freezed == mainJs
            ? _self.mainJs
            : mainJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        eventListener: null == eventListener
            ? _self.eventListener
            : eventListener // ignore: cast_nullable_to_non_nullable
                  as bool,
        customButton: null == customButton
            ? _self.customButton
            : customButton // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ExploreRuleCopyWith<$Res>? get ruleExplore {
    if (_self.ruleExplore == null) {
      return null;
    }

    return $ExploreRuleCopyWith<$Res>(_self.ruleExplore!, (value) {
      return _then(_self.copyWith(ruleExplore: value));
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SearchRuleCopyWith<$Res>? get ruleSearch {
    if (_self.ruleSearch == null) {
      return null;
    }

    return $SearchRuleCopyWith<$Res>(_self.ruleSearch!, (value) {
      return _then(_self.copyWith(ruleSearch: value));
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BookInfoRuleCopyWith<$Res>? get ruleBookInfo {
    if (_self.ruleBookInfo == null) {
      return null;
    }

    return $BookInfoRuleCopyWith<$Res>(_self.ruleBookInfo!, (value) {
      return _then(_self.copyWith(ruleBookInfo: value));
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TocRuleCopyWith<$Res>? get ruleToc {
    if (_self.ruleToc == null) {
      return null;
    }

    return $TocRuleCopyWith<$Res>(_self.ruleToc!, (value) {
      return _then(_self.copyWith(ruleToc: value));
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ContentRuleCopyWith<$Res>? get ruleContent {
    if (_self.ruleContent == null) {
      return null;
    }

    return $ContentRuleCopyWith<$Res>(_self.ruleContent!, (value) {
      return _then(_self.copyWith(ruleContent: value));
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ReviewRuleCopyWith<$Res>? get ruleReview {
    if (_self.ruleReview == null) {
      return null;
    }

    return $ReviewRuleCopyWith<$Res>(_self.ruleReview!, (value) {
      return _then(_self.copyWith(ruleReview: value));
    });
  }
}
