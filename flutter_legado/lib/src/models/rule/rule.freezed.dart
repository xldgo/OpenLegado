// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookInfoRule {
  String? get init;
  String? get name;
  String? get author;
  String? get intro;
  String? get kind;
  @JsonKey(name: 'lastChapter')
  String? get lastChapter;
  @JsonKey(name: 'updateTime')
  String? get updateTime;
  @JsonKey(name: 'coverUrl')
  String? get coverUrl;
  @JsonKey(name: 'tocUrl')
  String? get tocUrl;
  @JsonKey(name: 'wordCount')
  String? get wordCount;
  @JsonKey(name: 'canReName')
  String? get canReName;
  @JsonKey(name: 'downloadUrls')
  String? get downloadUrls;

  /// Create a copy of BookInfoRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookInfoRuleCopyWith<BookInfoRule> get copyWith =>
      _$BookInfoRuleCopyWithImpl<BookInfoRule>(
        this as BookInfoRule,
        _$identity,
      );

  /// Serializes this BookInfoRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as BookInfoRule;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookInfoRule &&
            (identical(other.init, _this.init) || other.init == _this.init) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.author, _this.author) ||
                other.author == _this.author) &&
            (identical(other.intro, _this.intro) ||
                other.intro == _this.intro) &&
            (identical(other.kind, _this.kind) || other.kind == _this.kind) &&
            (identical(other.lastChapter, _this.lastChapter) ||
                other.lastChapter == _this.lastChapter) &&
            (identical(other.updateTime, _this.updateTime) ||
                other.updateTime == _this.updateTime) &&
            (identical(other.coverUrl, _this.coverUrl) ||
                other.coverUrl == _this.coverUrl) &&
            (identical(other.tocUrl, _this.tocUrl) ||
                other.tocUrl == _this.tocUrl) &&
            (identical(other.wordCount, _this.wordCount) ||
                other.wordCount == _this.wordCount) &&
            (identical(other.canReName, _this.canReName) ||
                other.canReName == _this.canReName) &&
            (identical(other.downloadUrls, _this.downloadUrls) ||
                other.downloadUrls == _this.downloadUrls));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as BookInfoRule;
    return Object.hash(
      runtimeType,
      _this.init,
      _this.name,
      _this.author,
      _this.intro,
      _this.kind,
      _this.lastChapter,
      _this.updateTime,
      _this.coverUrl,
      _this.tocUrl,
      _this.wordCount,
      _this.canReName,
      _this.downloadUrls,
    );
  }

  @override
  String toString() {
    final _this = this as BookInfoRule;
    return 'BookInfoRule(init: ${_this.init}, name: ${_this.name}, author: ${_this.author}, intro: ${_this.intro}, kind: ${_this.kind}, lastChapter: ${_this.lastChapter}, updateTime: ${_this.updateTime}, coverUrl: ${_this.coverUrl}, tocUrl: ${_this.tocUrl}, wordCount: ${_this.wordCount}, canReName: ${_this.canReName}, downloadUrls: ${_this.downloadUrls})';
  }
}

/// @nodoc
abstract mixin class $BookInfoRuleCopyWith<$Res> {
  factory $BookInfoRuleCopyWith(
    BookInfoRule value,
    $Res Function(BookInfoRule) _then,
  ) = _$BookInfoRuleCopyWithImpl;
  @useResult
  $Res call({
    String? init,
    String? name,
    String? author,
    String? intro,
    String? kind,
    @JsonKey(name: 'lastChapter') String? lastChapter,
    @JsonKey(name: 'updateTime') String? updateTime,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    @JsonKey(name: 'tocUrl') String? tocUrl,
    @JsonKey(name: 'wordCount') String? wordCount,
    @JsonKey(name: 'canReName') String? canReName,
    @JsonKey(name: 'downloadUrls') String? downloadUrls,
  });
}

/// @nodoc
class _$BookInfoRuleCopyWithImpl<$Res> implements $BookInfoRuleCopyWith<$Res> {
  _$BookInfoRuleCopyWithImpl(this._self, this._then);

  final BookInfoRule _self;
  final $Res Function(BookInfoRule) _then;

  /// Create a copy of BookInfoRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? init = freezed,
    Object? name = freezed,
    Object? author = freezed,
    Object? intro = freezed,
    Object? kind = freezed,
    Object? lastChapter = freezed,
    Object? updateTime = freezed,
    Object? coverUrl = freezed,
    Object? tocUrl = freezed,
    Object? wordCount = freezed,
    Object? canReName = freezed,
    Object? downloadUrls = freezed,
  }) {
    return _then(
      BookInfoRule(
        init: freezed == init
            ? _self.init
            : init // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: freezed == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        author: freezed == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        kind: freezed == kind
            ? _self.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastChapter: freezed == lastChapter
            ? _self.lastChapter
            : lastChapter // ignore: cast_nullable_to_non_nullable
                  as String?,
        updateTime: freezed == updateTime
            ? _self.updateTime
            : updateTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        tocUrl: freezed == tocUrl
            ? _self.tocUrl
            : tocUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        canReName: freezed == canReName
            ? _self.canReName
            : canReName // ignore: cast_nullable_to_non_nullable
                  as String?,
        downloadUrls: freezed == downloadUrls
            ? _self.downloadUrls
            : downloadUrls // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BookInfoRule].
extension BookInfoRulePatterns on BookInfoRule {
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
    TResult Function(_BookInfoRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookInfoRule() when $default != null:
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
    TResult Function(_BookInfoRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookInfoRule():
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
    TResult? Function(_BookInfoRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookInfoRule() when $default != null:
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
      String? init,
      String? name,
      String? author,
      String? intro,
      String? kind,
      @JsonKey(name: 'lastChapter') String? lastChapter,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'tocUrl') String? tocUrl,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'canReName') String? canReName,
      @JsonKey(name: 'downloadUrls') String? downloadUrls,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookInfoRule() when $default != null:
        return $default(
          _that.init,
          _that.name,
          _that.author,
          _that.intro,
          _that.kind,
          _that.lastChapter,
          _that.updateTime,
          _that.coverUrl,
          _that.tocUrl,
          _that.wordCount,
          _that.canReName,
          _that.downloadUrls,
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
      String? init,
      String? name,
      String? author,
      String? intro,
      String? kind,
      @JsonKey(name: 'lastChapter') String? lastChapter,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'tocUrl') String? tocUrl,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'canReName') String? canReName,
      @JsonKey(name: 'downloadUrls') String? downloadUrls,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookInfoRule():
        return $default(
          _that.init,
          _that.name,
          _that.author,
          _that.intro,
          _that.kind,
          _that.lastChapter,
          _that.updateTime,
          _that.coverUrl,
          _that.tocUrl,
          _that.wordCount,
          _that.canReName,
          _that.downloadUrls,
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
      String? init,
      String? name,
      String? author,
      String? intro,
      String? kind,
      @JsonKey(name: 'lastChapter') String? lastChapter,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'tocUrl') String? tocUrl,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'canReName') String? canReName,
      @JsonKey(name: 'downloadUrls') String? downloadUrls,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookInfoRule() when $default != null:
        return $default(
          _that.init,
          _that.name,
          _that.author,
          _that.intro,
          _that.kind,
          _that.lastChapter,
          _that.updateTime,
          _that.coverUrl,
          _that.tocUrl,
          _that.wordCount,
          _that.canReName,
          _that.downloadUrls,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BookInfoRule implements BookInfoRule {
  const _BookInfoRule({
    this.init,
    this.name,
    this.author,
    this.intro,
    this.kind,
    @JsonKey(name: 'lastChapter') this.lastChapter,
    @JsonKey(name: 'updateTime') this.updateTime,
    @JsonKey(name: 'coverUrl') this.coverUrl,
    @JsonKey(name: 'tocUrl') this.tocUrl,
    @JsonKey(name: 'wordCount') this.wordCount,
    @JsonKey(name: 'canReName') this.canReName,
    @JsonKey(name: 'downloadUrls') this.downloadUrls,
  });
  factory _BookInfoRule.fromJson(Map<String, dynamic> json) =>
      _$BookInfoRuleFromJson(json);

  @override
  final String? init;
  @override
  final String? name;
  @override
  final String? author;
  @override
  final String? intro;
  @override
  final String? kind;
  @override
  @JsonKey(name: 'lastChapter')
  final String? lastChapter;
  @override
  @JsonKey(name: 'updateTime')
  final String? updateTime;
  @override
  @JsonKey(name: 'coverUrl')
  final String? coverUrl;
  @override
  @JsonKey(name: 'tocUrl')
  final String? tocUrl;
  @override
  @JsonKey(name: 'wordCount')
  final String? wordCount;
  @override
  @JsonKey(name: 'canReName')
  final String? canReName;
  @override
  @JsonKey(name: 'downloadUrls')
  final String? downloadUrls;

  /// Create a copy of BookInfoRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookInfoRuleCopyWith<_BookInfoRule> get copyWith =>
      __$BookInfoRuleCopyWithImpl<_BookInfoRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BookInfoRuleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookInfoRule &&
            (identical(other.init, init) || other.init == init) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.intro, intro) || other.intro == intro) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.lastChapter, lastChapter) ||
                other.lastChapter == lastChapter) &&
            (identical(other.updateTime, updateTime) ||
                other.updateTime == updateTime) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.canReName, canReName) ||
                other.canReName == canReName) &&
            (identical(other.downloadUrls, downloadUrls) ||
                other.downloadUrls == downloadUrls));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      init,
      name,
      author,
      intro,
      kind,
      lastChapter,
      updateTime,
      coverUrl,
      tocUrl,
      wordCount,
      canReName,
      downloadUrls,
    );
  }

  @override
  String toString() {
    return 'BookInfoRule(init: $init, name: $name, author: $author, intro: $intro, kind: $kind, lastChapter: $lastChapter, updateTime: $updateTime, coverUrl: $coverUrl, tocUrl: $tocUrl, wordCount: $wordCount, canReName: $canReName, downloadUrls: $downloadUrls)';
  }
}

/// @nodoc
abstract mixin class _$BookInfoRuleCopyWith<$Res>
    implements $BookInfoRuleCopyWith<$Res> {
  factory _$BookInfoRuleCopyWith(
    _BookInfoRule value,
    $Res Function(_BookInfoRule) _then,
  ) = __$BookInfoRuleCopyWithImpl;
  @override
  @useResult
  $Res call({
    String? init,
    String? name,
    String? author,
    String? intro,
    String? kind,
    @JsonKey(name: 'lastChapter') String? lastChapter,
    @JsonKey(name: 'updateTime') String? updateTime,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    @JsonKey(name: 'tocUrl') String? tocUrl,
    @JsonKey(name: 'wordCount') String? wordCount,
    @JsonKey(name: 'canReName') String? canReName,
    @JsonKey(name: 'downloadUrls') String? downloadUrls,
  });
}

/// @nodoc
class __$BookInfoRuleCopyWithImpl<$Res>
    implements _$BookInfoRuleCopyWith<$Res> {
  __$BookInfoRuleCopyWithImpl(this._self, this._then);

  final _BookInfoRule _self;
  final $Res Function(_BookInfoRule) _then;

  /// Create a copy of BookInfoRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? init = freezed,
    Object? name = freezed,
    Object? author = freezed,
    Object? intro = freezed,
    Object? kind = freezed,
    Object? lastChapter = freezed,
    Object? updateTime = freezed,
    Object? coverUrl = freezed,
    Object? tocUrl = freezed,
    Object? wordCount = freezed,
    Object? canReName = freezed,
    Object? downloadUrls = freezed,
  }) {
    return _then(
      _BookInfoRule(
        init: freezed == init
            ? _self.init
            : init // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: freezed == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        author: freezed == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        kind: freezed == kind
            ? _self.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastChapter: freezed == lastChapter
            ? _self.lastChapter
            : lastChapter // ignore: cast_nullable_to_non_nullable
                  as String?,
        updateTime: freezed == updateTime
            ? _self.updateTime
            : updateTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        tocUrl: freezed == tocUrl
            ? _self.tocUrl
            : tocUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        canReName: freezed == canReName
            ? _self.canReName
            : canReName // ignore: cast_nullable_to_non_nullable
                  as String?,
        downloadUrls: freezed == downloadUrls
            ? _self.downloadUrls
            : downloadUrls // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
mixin _$SearchRule {
  @JsonKey(name: 'checkKeyWord')
  String? get checkKeyWord;
  @JsonKey(name: 'bookList')
  String? get bookList;
  String? get name;
  String? get author;
  String? get intro;
  String? get kind;
  @JsonKey(name: 'lastChapter')
  String? get lastChapter;
  @JsonKey(name: 'updateTime')
  String? get updateTime;
  @JsonKey(name: 'bookUrl')
  String? get bookUrl;
  @JsonKey(name: 'coverUrl')
  String? get coverUrl;
  @JsonKey(name: 'wordCount')
  String? get wordCount;

  /// Create a copy of SearchRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SearchRuleCopyWith<SearchRule> get copyWith =>
      _$SearchRuleCopyWithImpl<SearchRule>(this as SearchRule, _$identity);

  /// Serializes this SearchRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as SearchRule;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SearchRule &&
            (identical(other.checkKeyWord, _this.checkKeyWord) ||
                other.checkKeyWord == _this.checkKeyWord) &&
            (identical(other.bookList, _this.bookList) ||
                other.bookList == _this.bookList) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.author, _this.author) ||
                other.author == _this.author) &&
            (identical(other.intro, _this.intro) ||
                other.intro == _this.intro) &&
            (identical(other.kind, _this.kind) || other.kind == _this.kind) &&
            (identical(other.lastChapter, _this.lastChapter) ||
                other.lastChapter == _this.lastChapter) &&
            (identical(other.updateTime, _this.updateTime) ||
                other.updateTime == _this.updateTime) &&
            (identical(other.bookUrl, _this.bookUrl) ||
                other.bookUrl == _this.bookUrl) &&
            (identical(other.coverUrl, _this.coverUrl) ||
                other.coverUrl == _this.coverUrl) &&
            (identical(other.wordCount, _this.wordCount) ||
                other.wordCount == _this.wordCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as SearchRule;
    return Object.hash(
      runtimeType,
      _this.checkKeyWord,
      _this.bookList,
      _this.name,
      _this.author,
      _this.intro,
      _this.kind,
      _this.lastChapter,
      _this.updateTime,
      _this.bookUrl,
      _this.coverUrl,
      _this.wordCount,
    );
  }

  @override
  String toString() {
    final _this = this as SearchRule;
    return 'SearchRule(checkKeyWord: ${_this.checkKeyWord}, bookList: ${_this.bookList}, name: ${_this.name}, author: ${_this.author}, intro: ${_this.intro}, kind: ${_this.kind}, lastChapter: ${_this.lastChapter}, updateTime: ${_this.updateTime}, bookUrl: ${_this.bookUrl}, coverUrl: ${_this.coverUrl}, wordCount: ${_this.wordCount})';
  }
}

/// @nodoc
abstract mixin class $SearchRuleCopyWith<$Res> {
  factory $SearchRuleCopyWith(
    SearchRule value,
    $Res Function(SearchRule) _then,
  ) = _$SearchRuleCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'checkKeyWord') String? checkKeyWord,
    @JsonKey(name: 'bookList') String? bookList,
    String? name,
    String? author,
    String? intro,
    String? kind,
    @JsonKey(name: 'lastChapter') String? lastChapter,
    @JsonKey(name: 'updateTime') String? updateTime,
    @JsonKey(name: 'bookUrl') String? bookUrl,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    @JsonKey(name: 'wordCount') String? wordCount,
  });
}

/// @nodoc
class _$SearchRuleCopyWithImpl<$Res> implements $SearchRuleCopyWith<$Res> {
  _$SearchRuleCopyWithImpl(this._self, this._then);

  final SearchRule _self;
  final $Res Function(SearchRule) _then;

  /// Create a copy of SearchRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checkKeyWord = freezed,
    Object? bookList = freezed,
    Object? name = freezed,
    Object? author = freezed,
    Object? intro = freezed,
    Object? kind = freezed,
    Object? lastChapter = freezed,
    Object? updateTime = freezed,
    Object? bookUrl = freezed,
    Object? coverUrl = freezed,
    Object? wordCount = freezed,
  }) {
    return _then(
      SearchRule(
        checkKeyWord: freezed == checkKeyWord
            ? _self.checkKeyWord
            : checkKeyWord // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookList: freezed == bookList
            ? _self.bookList
            : bookList // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: freezed == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        author: freezed == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        kind: freezed == kind
            ? _self.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastChapter: freezed == lastChapter
            ? _self.lastChapter
            : lastChapter // ignore: cast_nullable_to_non_nullable
                  as String?,
        updateTime: freezed == updateTime
            ? _self.updateTime
            : updateTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookUrl: freezed == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [SearchRule].
extension SearchRulePatterns on SearchRule {
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
    TResult Function(_SearchRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchRule() when $default != null:
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
    TResult Function(_SearchRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchRule():
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
    TResult? Function(_SearchRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchRule() when $default != null:
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
      @JsonKey(name: 'checkKeyWord') String? checkKeyWord,
      @JsonKey(name: 'bookList') String? bookList,
      String? name,
      String? author,
      String? intro,
      String? kind,
      @JsonKey(name: 'lastChapter') String? lastChapter,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'bookUrl') String? bookUrl,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'wordCount') String? wordCount,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchRule() when $default != null:
        return $default(
          _that.checkKeyWord,
          _that.bookList,
          _that.name,
          _that.author,
          _that.intro,
          _that.kind,
          _that.lastChapter,
          _that.updateTime,
          _that.bookUrl,
          _that.coverUrl,
          _that.wordCount,
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
      @JsonKey(name: 'checkKeyWord') String? checkKeyWord,
      @JsonKey(name: 'bookList') String? bookList,
      String? name,
      String? author,
      String? intro,
      String? kind,
      @JsonKey(name: 'lastChapter') String? lastChapter,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'bookUrl') String? bookUrl,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'wordCount') String? wordCount,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchRule():
        return $default(
          _that.checkKeyWord,
          _that.bookList,
          _that.name,
          _that.author,
          _that.intro,
          _that.kind,
          _that.lastChapter,
          _that.updateTime,
          _that.bookUrl,
          _that.coverUrl,
          _that.wordCount,
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
      @JsonKey(name: 'checkKeyWord') String? checkKeyWord,
      @JsonKey(name: 'bookList') String? bookList,
      String? name,
      String? author,
      String? intro,
      String? kind,
      @JsonKey(name: 'lastChapter') String? lastChapter,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'bookUrl') String? bookUrl,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'wordCount') String? wordCount,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchRule() when $default != null:
        return $default(
          _that.checkKeyWord,
          _that.bookList,
          _that.name,
          _that.author,
          _that.intro,
          _that.kind,
          _that.lastChapter,
          _that.updateTime,
          _that.bookUrl,
          _that.coverUrl,
          _that.wordCount,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SearchRule implements SearchRule {
  const _SearchRule({
    @JsonKey(name: 'checkKeyWord') this.checkKeyWord,
    @JsonKey(name: 'bookList') this.bookList,
    this.name,
    this.author,
    this.intro,
    this.kind,
    @JsonKey(name: 'lastChapter') this.lastChapter,
    @JsonKey(name: 'updateTime') this.updateTime,
    @JsonKey(name: 'bookUrl') this.bookUrl,
    @JsonKey(name: 'coverUrl') this.coverUrl,
    @JsonKey(name: 'wordCount') this.wordCount,
  });
  factory _SearchRule.fromJson(Map<String, dynamic> json) =>
      _$SearchRuleFromJson(json);

  @override
  @JsonKey(name: 'checkKeyWord')
  final String? checkKeyWord;
  @override
  @JsonKey(name: 'bookList')
  final String? bookList;
  @override
  final String? name;
  @override
  final String? author;
  @override
  final String? intro;
  @override
  final String? kind;
  @override
  @JsonKey(name: 'lastChapter')
  final String? lastChapter;
  @override
  @JsonKey(name: 'updateTime')
  final String? updateTime;
  @override
  @JsonKey(name: 'bookUrl')
  final String? bookUrl;
  @override
  @JsonKey(name: 'coverUrl')
  final String? coverUrl;
  @override
  @JsonKey(name: 'wordCount')
  final String? wordCount;

  /// Create a copy of SearchRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SearchRuleCopyWith<_SearchRule> get copyWith =>
      __$SearchRuleCopyWithImpl<_SearchRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SearchRuleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SearchRule &&
            (identical(other.checkKeyWord, checkKeyWord) ||
                other.checkKeyWord == checkKeyWord) &&
            (identical(other.bookList, bookList) ||
                other.bookList == bookList) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.intro, intro) || other.intro == intro) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.lastChapter, lastChapter) ||
                other.lastChapter == lastChapter) &&
            (identical(other.updateTime, updateTime) ||
                other.updateTime == updateTime) &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      checkKeyWord,
      bookList,
      name,
      author,
      intro,
      kind,
      lastChapter,
      updateTime,
      bookUrl,
      coverUrl,
      wordCount,
    );
  }

  @override
  String toString() {
    return 'SearchRule(checkKeyWord: $checkKeyWord, bookList: $bookList, name: $name, author: $author, intro: $intro, kind: $kind, lastChapter: $lastChapter, updateTime: $updateTime, bookUrl: $bookUrl, coverUrl: $coverUrl, wordCount: $wordCount)';
  }
}

/// @nodoc
abstract mixin class _$SearchRuleCopyWith<$Res>
    implements $SearchRuleCopyWith<$Res> {
  factory _$SearchRuleCopyWith(
    _SearchRule value,
    $Res Function(_SearchRule) _then,
  ) = __$SearchRuleCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'checkKeyWord') String? checkKeyWord,
    @JsonKey(name: 'bookList') String? bookList,
    String? name,
    String? author,
    String? intro,
    String? kind,
    @JsonKey(name: 'lastChapter') String? lastChapter,
    @JsonKey(name: 'updateTime') String? updateTime,
    @JsonKey(name: 'bookUrl') String? bookUrl,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    @JsonKey(name: 'wordCount') String? wordCount,
  });
}

/// @nodoc
class __$SearchRuleCopyWithImpl<$Res> implements _$SearchRuleCopyWith<$Res> {
  __$SearchRuleCopyWithImpl(this._self, this._then);

  final _SearchRule _self;
  final $Res Function(_SearchRule) _then;

  /// Create a copy of SearchRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? checkKeyWord = freezed,
    Object? bookList = freezed,
    Object? name = freezed,
    Object? author = freezed,
    Object? intro = freezed,
    Object? kind = freezed,
    Object? lastChapter = freezed,
    Object? updateTime = freezed,
    Object? bookUrl = freezed,
    Object? coverUrl = freezed,
    Object? wordCount = freezed,
  }) {
    return _then(
      _SearchRule(
        checkKeyWord: freezed == checkKeyWord
            ? _self.checkKeyWord
            : checkKeyWord // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookList: freezed == bookList
            ? _self.bookList
            : bookList // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: freezed == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        author: freezed == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        kind: freezed == kind
            ? _self.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastChapter: freezed == lastChapter
            ? _self.lastChapter
            : lastChapter // ignore: cast_nullable_to_non_nullable
                  as String?,
        updateTime: freezed == updateTime
            ? _self.updateTime
            : updateTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookUrl: freezed == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
mixin _$TocRule {
  @JsonKey(name: 'preUpdateJs')
  String? get preUpdateJs;
  @JsonKey(name: 'chapterList')
  String? get chapterList;
  @JsonKey(name: 'chapterName')
  String? get chapterName;
  @JsonKey(name: 'chapterUrl')
  String? get chapterUrl;
  @JsonKey(name: 'formatJs')
  String? get formatJs;
  @JsonKey(name: 'isVolume')
  String? get isVolume;
  @JsonKey(name: 'isVip')
  String? get isVip;
  @JsonKey(name: 'isPay')
  String? get isPay;
  @JsonKey(name: 'updateTime')
  String? get updateTime;
  @JsonKey(name: 'nextTocUrl')
  String? get nextTocUrl;

  /// Create a copy of TocRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TocRuleCopyWith<TocRule> get copyWith =>
      _$TocRuleCopyWithImpl<TocRule>(this as TocRule, _$identity);

  /// Serializes this TocRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as TocRule;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TocRule &&
            (identical(other.preUpdateJs, _this.preUpdateJs) ||
                other.preUpdateJs == _this.preUpdateJs) &&
            (identical(other.chapterList, _this.chapterList) ||
                other.chapterList == _this.chapterList) &&
            (identical(other.chapterName, _this.chapterName) ||
                other.chapterName == _this.chapterName) &&
            (identical(other.chapterUrl, _this.chapterUrl) ||
                other.chapterUrl == _this.chapterUrl) &&
            (identical(other.formatJs, _this.formatJs) ||
                other.formatJs == _this.formatJs) &&
            (identical(other.isVolume, _this.isVolume) ||
                other.isVolume == _this.isVolume) &&
            (identical(other.isVip, _this.isVip) ||
                other.isVip == _this.isVip) &&
            (identical(other.isPay, _this.isPay) ||
                other.isPay == _this.isPay) &&
            (identical(other.updateTime, _this.updateTime) ||
                other.updateTime == _this.updateTime) &&
            (identical(other.nextTocUrl, _this.nextTocUrl) ||
                other.nextTocUrl == _this.nextTocUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as TocRule;
    return Object.hash(
      runtimeType,
      _this.preUpdateJs,
      _this.chapterList,
      _this.chapterName,
      _this.chapterUrl,
      _this.formatJs,
      _this.isVolume,
      _this.isVip,
      _this.isPay,
      _this.updateTime,
      _this.nextTocUrl,
    );
  }

  @override
  String toString() {
    final _this = this as TocRule;
    return 'TocRule(preUpdateJs: ${_this.preUpdateJs}, chapterList: ${_this.chapterList}, chapterName: ${_this.chapterName}, chapterUrl: ${_this.chapterUrl}, formatJs: ${_this.formatJs}, isVolume: ${_this.isVolume}, isVip: ${_this.isVip}, isPay: ${_this.isPay}, updateTime: ${_this.updateTime}, nextTocUrl: ${_this.nextTocUrl})';
  }
}

/// @nodoc
abstract mixin class $TocRuleCopyWith<$Res> {
  factory $TocRuleCopyWith(TocRule value, $Res Function(TocRule) _then) =
      _$TocRuleCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'preUpdateJs') String? preUpdateJs,
    @JsonKey(name: 'chapterList') String? chapterList,
    @JsonKey(name: 'chapterName') String? chapterName,
    @JsonKey(name: 'chapterUrl') String? chapterUrl,
    @JsonKey(name: 'formatJs') String? formatJs,
    @JsonKey(name: 'isVolume') String? isVolume,
    @JsonKey(name: 'isVip') String? isVip,
    @JsonKey(name: 'isPay') String? isPay,
    @JsonKey(name: 'updateTime') String? updateTime,
    @JsonKey(name: 'nextTocUrl') String? nextTocUrl,
  });
}

/// @nodoc
class _$TocRuleCopyWithImpl<$Res> implements $TocRuleCopyWith<$Res> {
  _$TocRuleCopyWithImpl(this._self, this._then);

  final TocRule _self;
  final $Res Function(TocRule) _then;

  /// Create a copy of TocRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? preUpdateJs = freezed,
    Object? chapterList = freezed,
    Object? chapterName = freezed,
    Object? chapterUrl = freezed,
    Object? formatJs = freezed,
    Object? isVolume = freezed,
    Object? isVip = freezed,
    Object? isPay = freezed,
    Object? updateTime = freezed,
    Object? nextTocUrl = freezed,
  }) {
    return _then(
      TocRule(
        preUpdateJs: freezed == preUpdateJs
            ? _self.preUpdateJs
            : preUpdateJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        chapterList: freezed == chapterList
            ? _self.chapterList
            : chapterList // ignore: cast_nullable_to_non_nullable
                  as String?,
        chapterName: freezed == chapterName
            ? _self.chapterName
            : chapterName // ignore: cast_nullable_to_non_nullable
                  as String?,
        chapterUrl: freezed == chapterUrl
            ? _self.chapterUrl
            : chapterUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        formatJs: freezed == formatJs
            ? _self.formatJs
            : formatJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        isVolume: freezed == isVolume
            ? _self.isVolume
            : isVolume // ignore: cast_nullable_to_non_nullable
                  as String?,
        isVip: freezed == isVip
            ? _self.isVip
            : isVip // ignore: cast_nullable_to_non_nullable
                  as String?,
        isPay: freezed == isPay
            ? _self.isPay
            : isPay // ignore: cast_nullable_to_non_nullable
                  as String?,
        updateTime: freezed == updateTime
            ? _self.updateTime
            : updateTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        nextTocUrl: freezed == nextTocUrl
            ? _self.nextTocUrl
            : nextTocUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [TocRule].
extension TocRulePatterns on TocRule {
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
    TResult Function(_TocRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TocRule() when $default != null:
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
    TResult Function(_TocRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TocRule():
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
    TResult? Function(_TocRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TocRule() when $default != null:
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
      @JsonKey(name: 'preUpdateJs') String? preUpdateJs,
      @JsonKey(name: 'chapterList') String? chapterList,
      @JsonKey(name: 'chapterName') String? chapterName,
      @JsonKey(name: 'chapterUrl') String? chapterUrl,
      @JsonKey(name: 'formatJs') String? formatJs,
      @JsonKey(name: 'isVolume') String? isVolume,
      @JsonKey(name: 'isVip') String? isVip,
      @JsonKey(name: 'isPay') String? isPay,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'nextTocUrl') String? nextTocUrl,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TocRule() when $default != null:
        return $default(
          _that.preUpdateJs,
          _that.chapterList,
          _that.chapterName,
          _that.chapterUrl,
          _that.formatJs,
          _that.isVolume,
          _that.isVip,
          _that.isPay,
          _that.updateTime,
          _that.nextTocUrl,
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
      @JsonKey(name: 'preUpdateJs') String? preUpdateJs,
      @JsonKey(name: 'chapterList') String? chapterList,
      @JsonKey(name: 'chapterName') String? chapterName,
      @JsonKey(name: 'chapterUrl') String? chapterUrl,
      @JsonKey(name: 'formatJs') String? formatJs,
      @JsonKey(name: 'isVolume') String? isVolume,
      @JsonKey(name: 'isVip') String? isVip,
      @JsonKey(name: 'isPay') String? isPay,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'nextTocUrl') String? nextTocUrl,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TocRule():
        return $default(
          _that.preUpdateJs,
          _that.chapterList,
          _that.chapterName,
          _that.chapterUrl,
          _that.formatJs,
          _that.isVolume,
          _that.isVip,
          _that.isPay,
          _that.updateTime,
          _that.nextTocUrl,
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
      @JsonKey(name: 'preUpdateJs') String? preUpdateJs,
      @JsonKey(name: 'chapterList') String? chapterList,
      @JsonKey(name: 'chapterName') String? chapterName,
      @JsonKey(name: 'chapterUrl') String? chapterUrl,
      @JsonKey(name: 'formatJs') String? formatJs,
      @JsonKey(name: 'isVolume') String? isVolume,
      @JsonKey(name: 'isVip') String? isVip,
      @JsonKey(name: 'isPay') String? isPay,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'nextTocUrl') String? nextTocUrl,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TocRule() when $default != null:
        return $default(
          _that.preUpdateJs,
          _that.chapterList,
          _that.chapterName,
          _that.chapterUrl,
          _that.formatJs,
          _that.isVolume,
          _that.isVip,
          _that.isPay,
          _that.updateTime,
          _that.nextTocUrl,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TocRule implements TocRule {
  const _TocRule({
    @JsonKey(name: 'preUpdateJs') this.preUpdateJs,
    @JsonKey(name: 'chapterList') this.chapterList,
    @JsonKey(name: 'chapterName') this.chapterName,
    @JsonKey(name: 'chapterUrl') this.chapterUrl,
    @JsonKey(name: 'formatJs') this.formatJs,
    @JsonKey(name: 'isVolume') this.isVolume,
    @JsonKey(name: 'isVip') this.isVip,
    @JsonKey(name: 'isPay') this.isPay,
    @JsonKey(name: 'updateTime') this.updateTime,
    @JsonKey(name: 'nextTocUrl') this.nextTocUrl,
  });
  factory _TocRule.fromJson(Map<String, dynamic> json) =>
      _$TocRuleFromJson(json);

  @override
  @JsonKey(name: 'preUpdateJs')
  final String? preUpdateJs;
  @override
  @JsonKey(name: 'chapterList')
  final String? chapterList;
  @override
  @JsonKey(name: 'chapterName')
  final String? chapterName;
  @override
  @JsonKey(name: 'chapterUrl')
  final String? chapterUrl;
  @override
  @JsonKey(name: 'formatJs')
  final String? formatJs;
  @override
  @JsonKey(name: 'isVolume')
  final String? isVolume;
  @override
  @JsonKey(name: 'isVip')
  final String? isVip;
  @override
  @JsonKey(name: 'isPay')
  final String? isPay;
  @override
  @JsonKey(name: 'updateTime')
  final String? updateTime;
  @override
  @JsonKey(name: 'nextTocUrl')
  final String? nextTocUrl;

  /// Create a copy of TocRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TocRuleCopyWith<_TocRule> get copyWith =>
      __$TocRuleCopyWithImpl<_TocRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TocRuleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TocRule &&
            (identical(other.preUpdateJs, preUpdateJs) ||
                other.preUpdateJs == preUpdateJs) &&
            (identical(other.chapterList, chapterList) ||
                other.chapterList == chapterList) &&
            (identical(other.chapterName, chapterName) ||
                other.chapterName == chapterName) &&
            (identical(other.chapterUrl, chapterUrl) ||
                other.chapterUrl == chapterUrl) &&
            (identical(other.formatJs, formatJs) ||
                other.formatJs == formatJs) &&
            (identical(other.isVolume, isVolume) ||
                other.isVolume == isVolume) &&
            (identical(other.isVip, isVip) || other.isVip == isVip) &&
            (identical(other.isPay, isPay) || other.isPay == isPay) &&
            (identical(other.updateTime, updateTime) ||
                other.updateTime == updateTime) &&
            (identical(other.nextTocUrl, nextTocUrl) ||
                other.nextTocUrl == nextTocUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      preUpdateJs,
      chapterList,
      chapterName,
      chapterUrl,
      formatJs,
      isVolume,
      isVip,
      isPay,
      updateTime,
      nextTocUrl,
    );
  }

  @override
  String toString() {
    return 'TocRule(preUpdateJs: $preUpdateJs, chapterList: $chapterList, chapterName: $chapterName, chapterUrl: $chapterUrl, formatJs: $formatJs, isVolume: $isVolume, isVip: $isVip, isPay: $isPay, updateTime: $updateTime, nextTocUrl: $nextTocUrl)';
  }
}

/// @nodoc
abstract mixin class _$TocRuleCopyWith<$Res> implements $TocRuleCopyWith<$Res> {
  factory _$TocRuleCopyWith(_TocRule value, $Res Function(_TocRule) _then) =
      __$TocRuleCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'preUpdateJs') String? preUpdateJs,
    @JsonKey(name: 'chapterList') String? chapterList,
    @JsonKey(name: 'chapterName') String? chapterName,
    @JsonKey(name: 'chapterUrl') String? chapterUrl,
    @JsonKey(name: 'formatJs') String? formatJs,
    @JsonKey(name: 'isVolume') String? isVolume,
    @JsonKey(name: 'isVip') String? isVip,
    @JsonKey(name: 'isPay') String? isPay,
    @JsonKey(name: 'updateTime') String? updateTime,
    @JsonKey(name: 'nextTocUrl') String? nextTocUrl,
  });
}

/// @nodoc
class __$TocRuleCopyWithImpl<$Res> implements _$TocRuleCopyWith<$Res> {
  __$TocRuleCopyWithImpl(this._self, this._then);

  final _TocRule _self;
  final $Res Function(_TocRule) _then;

  /// Create a copy of TocRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? preUpdateJs = freezed,
    Object? chapterList = freezed,
    Object? chapterName = freezed,
    Object? chapterUrl = freezed,
    Object? formatJs = freezed,
    Object? isVolume = freezed,
    Object? isVip = freezed,
    Object? isPay = freezed,
    Object? updateTime = freezed,
    Object? nextTocUrl = freezed,
  }) {
    return _then(
      _TocRule(
        preUpdateJs: freezed == preUpdateJs
            ? _self.preUpdateJs
            : preUpdateJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        chapterList: freezed == chapterList
            ? _self.chapterList
            : chapterList // ignore: cast_nullable_to_non_nullable
                  as String?,
        chapterName: freezed == chapterName
            ? _self.chapterName
            : chapterName // ignore: cast_nullable_to_non_nullable
                  as String?,
        chapterUrl: freezed == chapterUrl
            ? _self.chapterUrl
            : chapterUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        formatJs: freezed == formatJs
            ? _self.formatJs
            : formatJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        isVolume: freezed == isVolume
            ? _self.isVolume
            : isVolume // ignore: cast_nullable_to_non_nullable
                  as String?,
        isVip: freezed == isVip
            ? _self.isVip
            : isVip // ignore: cast_nullable_to_non_nullable
                  as String?,
        isPay: freezed == isPay
            ? _self.isPay
            : isPay // ignore: cast_nullable_to_non_nullable
                  as String?,
        updateTime: freezed == updateTime
            ? _self.updateTime
            : updateTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        nextTocUrl: freezed == nextTocUrl
            ? _self.nextTocUrl
            : nextTocUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
mixin _$ContentRule {
  String? get content;
  @JsonKey(name: 'subContent')
  String? get subContent;
  String? get title;
  @JsonKey(name: 'nextContentUrl')
  String? get nextContentUrl;
  @JsonKey(name: 'webJs')
  String? get webJs;
  @JsonKey(name: 'sourceRegex')
  String? get sourceRegex;
  @JsonKey(name: 'replaceRegex')
  String? get replaceRegex;
  @JsonKey(name: 'imageStyle')
  String? get imageStyle;
  @JsonKey(name: 'imageDecode')
  String? get imageDecode;
  @JsonKey(name: 'payAction')
  String? get payAction;
  @JsonKey(name: 'callBackJs')
  String? get callBackJs;
  @JsonKey(name: 'contentBatch')
  String? get contentBatch;
  @JsonKey(name: 'maxBatchSize')
  int? get maxBatchSize;

  /// Create a copy of ContentRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ContentRuleCopyWith<ContentRule> get copyWith =>
      _$ContentRuleCopyWithImpl<ContentRule>(this as ContentRule, _$identity);

  /// Serializes this ContentRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as ContentRule;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ContentRule &&
            (identical(other.content, _this.content) ||
                other.content == _this.content) &&
            (identical(other.subContent, _this.subContent) ||
                other.subContent == _this.subContent) &&
            (identical(other.title, _this.title) ||
                other.title == _this.title) &&
            (identical(other.nextContentUrl, _this.nextContentUrl) ||
                other.nextContentUrl == _this.nextContentUrl) &&
            (identical(other.webJs, _this.webJs) ||
                other.webJs == _this.webJs) &&
            (identical(other.sourceRegex, _this.sourceRegex) ||
                other.sourceRegex == _this.sourceRegex) &&
            (identical(other.replaceRegex, _this.replaceRegex) ||
                other.replaceRegex == _this.replaceRegex) &&
            (identical(other.imageStyle, _this.imageStyle) ||
                other.imageStyle == _this.imageStyle) &&
            (identical(other.imageDecode, _this.imageDecode) ||
                other.imageDecode == _this.imageDecode) &&
            (identical(other.payAction, _this.payAction) ||
                other.payAction == _this.payAction) &&
            (identical(other.callBackJs, _this.callBackJs) ||
                other.callBackJs == _this.callBackJs) &&
            (identical(other.contentBatch, _this.contentBatch) ||
                other.contentBatch == _this.contentBatch) &&
            (identical(other.maxBatchSize, _this.maxBatchSize) ||
                other.maxBatchSize == _this.maxBatchSize));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as ContentRule;
    return Object.hash(
      runtimeType,
      _this.content,
      _this.subContent,
      _this.title,
      _this.nextContentUrl,
      _this.webJs,
      _this.sourceRegex,
      _this.replaceRegex,
      _this.imageStyle,
      _this.imageDecode,
      _this.payAction,
      _this.callBackJs,
      _this.contentBatch,
      _this.maxBatchSize,
    );
  }

  @override
  String toString() {
    final _this = this as ContentRule;
    return 'ContentRule(content: ${_this.content}, subContent: ${_this.subContent}, title: ${_this.title}, nextContentUrl: ${_this.nextContentUrl}, webJs: ${_this.webJs}, sourceRegex: ${_this.sourceRegex}, replaceRegex: ${_this.replaceRegex}, imageStyle: ${_this.imageStyle}, imageDecode: ${_this.imageDecode}, payAction: ${_this.payAction}, callBackJs: ${_this.callBackJs}, contentBatch: ${_this.contentBatch}, maxBatchSize: ${_this.maxBatchSize})';
  }
}

/// @nodoc
abstract mixin class $ContentRuleCopyWith<$Res> {
  factory $ContentRuleCopyWith(
    ContentRule value,
    $Res Function(ContentRule) _then,
  ) = _$ContentRuleCopyWithImpl;
  @useResult
  $Res call({
    String? content,
    @JsonKey(name: 'subContent') String? subContent,
    String? title,
    @JsonKey(name: 'nextContentUrl') String? nextContentUrl,
    @JsonKey(name: 'webJs') String? webJs,
    @JsonKey(name: 'sourceRegex') String? sourceRegex,
    @JsonKey(name: 'replaceRegex') String? replaceRegex,
    @JsonKey(name: 'imageStyle') String? imageStyle,
    @JsonKey(name: 'imageDecode') String? imageDecode,
    @JsonKey(name: 'payAction') String? payAction,
    @JsonKey(name: 'callBackJs') String? callBackJs,
    @JsonKey(name: 'contentBatch') String? contentBatch,
    @JsonKey(name: 'maxBatchSize') int? maxBatchSize,
  });
}

/// @nodoc
class _$ContentRuleCopyWithImpl<$Res> implements $ContentRuleCopyWith<$Res> {
  _$ContentRuleCopyWithImpl(this._self, this._then);

  final ContentRule _self;
  final $Res Function(ContentRule) _then;

  /// Create a copy of ContentRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = freezed,
    Object? subContent = freezed,
    Object? title = freezed,
    Object? nextContentUrl = freezed,
    Object? webJs = freezed,
    Object? sourceRegex = freezed,
    Object? replaceRegex = freezed,
    Object? imageStyle = freezed,
    Object? imageDecode = freezed,
    Object? payAction = freezed,
    Object? callBackJs = freezed,
    Object? contentBatch = freezed,
    Object? maxBatchSize = freezed,
  }) {
    return _then(
      ContentRule(
        content: freezed == content
            ? _self.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        subContent: freezed == subContent
            ? _self.subContent
            : subContent // ignore: cast_nullable_to_non_nullable
                  as String?,
        title: freezed == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        nextContentUrl: freezed == nextContentUrl
            ? _self.nextContentUrl
            : nextContentUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        webJs: freezed == webJs
            ? _self.webJs
            : webJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        sourceRegex: freezed == sourceRegex
            ? _self.sourceRegex
            : sourceRegex // ignore: cast_nullable_to_non_nullable
                  as String?,
        replaceRegex: freezed == replaceRegex
            ? _self.replaceRegex
            : replaceRegex // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageStyle: freezed == imageStyle
            ? _self.imageStyle
            : imageStyle // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageDecode: freezed == imageDecode
            ? _self.imageDecode
            : imageDecode // ignore: cast_nullable_to_non_nullable
                  as String?,
        payAction: freezed == payAction
            ? _self.payAction
            : payAction // ignore: cast_nullable_to_non_nullable
                  as String?,
        callBackJs: freezed == callBackJs
            ? _self.callBackJs
            : callBackJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        contentBatch: freezed == contentBatch
            ? _self.contentBatch
            : contentBatch // ignore: cast_nullable_to_non_nullable
                  as String?,
        maxBatchSize: freezed == maxBatchSize
            ? _self.maxBatchSize
            : maxBatchSize // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ContentRule].
extension ContentRulePatterns on ContentRule {
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
    TResult Function(_ContentRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ContentRule() when $default != null:
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
    TResult Function(_ContentRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ContentRule():
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
    TResult? Function(_ContentRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ContentRule() when $default != null:
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
      String? content,
      @JsonKey(name: 'subContent') String? subContent,
      String? title,
      @JsonKey(name: 'nextContentUrl') String? nextContentUrl,
      @JsonKey(name: 'webJs') String? webJs,
      @JsonKey(name: 'sourceRegex') String? sourceRegex,
      @JsonKey(name: 'replaceRegex') String? replaceRegex,
      @JsonKey(name: 'imageStyle') String? imageStyle,
      @JsonKey(name: 'imageDecode') String? imageDecode,
      @JsonKey(name: 'payAction') String? payAction,
      @JsonKey(name: 'callBackJs') String? callBackJs,
      @JsonKey(name: 'contentBatch') String? contentBatch,
      @JsonKey(name: 'maxBatchSize') int? maxBatchSize,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ContentRule() when $default != null:
        return $default(
          _that.content,
          _that.subContent,
          _that.title,
          _that.nextContentUrl,
          _that.webJs,
          _that.sourceRegex,
          _that.replaceRegex,
          _that.imageStyle,
          _that.imageDecode,
          _that.payAction,
          _that.callBackJs,
          _that.contentBatch,
          _that.maxBatchSize,
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
      String? content,
      @JsonKey(name: 'subContent') String? subContent,
      String? title,
      @JsonKey(name: 'nextContentUrl') String? nextContentUrl,
      @JsonKey(name: 'webJs') String? webJs,
      @JsonKey(name: 'sourceRegex') String? sourceRegex,
      @JsonKey(name: 'replaceRegex') String? replaceRegex,
      @JsonKey(name: 'imageStyle') String? imageStyle,
      @JsonKey(name: 'imageDecode') String? imageDecode,
      @JsonKey(name: 'payAction') String? payAction,
      @JsonKey(name: 'callBackJs') String? callBackJs,
      @JsonKey(name: 'contentBatch') String? contentBatch,
      @JsonKey(name: 'maxBatchSize') int? maxBatchSize,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ContentRule():
        return $default(
          _that.content,
          _that.subContent,
          _that.title,
          _that.nextContentUrl,
          _that.webJs,
          _that.sourceRegex,
          _that.replaceRegex,
          _that.imageStyle,
          _that.imageDecode,
          _that.payAction,
          _that.callBackJs,
          _that.contentBatch,
          _that.maxBatchSize,
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
      String? content,
      @JsonKey(name: 'subContent') String? subContent,
      String? title,
      @JsonKey(name: 'nextContentUrl') String? nextContentUrl,
      @JsonKey(name: 'webJs') String? webJs,
      @JsonKey(name: 'sourceRegex') String? sourceRegex,
      @JsonKey(name: 'replaceRegex') String? replaceRegex,
      @JsonKey(name: 'imageStyle') String? imageStyle,
      @JsonKey(name: 'imageDecode') String? imageDecode,
      @JsonKey(name: 'payAction') String? payAction,
      @JsonKey(name: 'callBackJs') String? callBackJs,
      @JsonKey(name: 'contentBatch') String? contentBatch,
      @JsonKey(name: 'maxBatchSize') int? maxBatchSize,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ContentRule() when $default != null:
        return $default(
          _that.content,
          _that.subContent,
          _that.title,
          _that.nextContentUrl,
          _that.webJs,
          _that.sourceRegex,
          _that.replaceRegex,
          _that.imageStyle,
          _that.imageDecode,
          _that.payAction,
          _that.callBackJs,
          _that.contentBatch,
          _that.maxBatchSize,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ContentRule implements ContentRule {
  const _ContentRule({
    this.content,
    @JsonKey(name: 'subContent') this.subContent,
    this.title,
    @JsonKey(name: 'nextContentUrl') this.nextContentUrl,
    @JsonKey(name: 'webJs') this.webJs,
    @JsonKey(name: 'sourceRegex') this.sourceRegex,
    @JsonKey(name: 'replaceRegex') this.replaceRegex,
    @JsonKey(name: 'imageStyle') this.imageStyle,
    @JsonKey(name: 'imageDecode') this.imageDecode,
    @JsonKey(name: 'payAction') this.payAction,
    @JsonKey(name: 'callBackJs') this.callBackJs,
    @JsonKey(name: 'contentBatch') this.contentBatch,
    @JsonKey(name: 'maxBatchSize') this.maxBatchSize,
  });
  factory _ContentRule.fromJson(Map<String, dynamic> json) =>
      _$ContentRuleFromJson(json);

  @override
  final String? content;
  @override
  @JsonKey(name: 'subContent')
  final String? subContent;
  @override
  final String? title;
  @override
  @JsonKey(name: 'nextContentUrl')
  final String? nextContentUrl;
  @override
  @JsonKey(name: 'webJs')
  final String? webJs;
  @override
  @JsonKey(name: 'sourceRegex')
  final String? sourceRegex;
  @override
  @JsonKey(name: 'replaceRegex')
  final String? replaceRegex;
  @override
  @JsonKey(name: 'imageStyle')
  final String? imageStyle;
  @override
  @JsonKey(name: 'imageDecode')
  final String? imageDecode;
  @override
  @JsonKey(name: 'payAction')
  final String? payAction;
  @override
  @JsonKey(name: 'callBackJs')
  final String? callBackJs;
  @override
  @JsonKey(name: 'contentBatch')
  final String? contentBatch;
  @override
  @JsonKey(name: 'maxBatchSize')
  final int? maxBatchSize;

  /// Create a copy of ContentRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ContentRuleCopyWith<_ContentRule> get copyWith =>
      __$ContentRuleCopyWithImpl<_ContentRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ContentRuleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ContentRule &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.subContent, subContent) ||
                other.subContent == subContent) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.nextContentUrl, nextContentUrl) ||
                other.nextContentUrl == nextContentUrl) &&
            (identical(other.webJs, webJs) || other.webJs == webJs) &&
            (identical(other.sourceRegex, sourceRegex) ||
                other.sourceRegex == sourceRegex) &&
            (identical(other.replaceRegex, replaceRegex) ||
                other.replaceRegex == replaceRegex) &&
            (identical(other.imageStyle, imageStyle) ||
                other.imageStyle == imageStyle) &&
            (identical(other.imageDecode, imageDecode) ||
                other.imageDecode == imageDecode) &&
            (identical(other.payAction, payAction) ||
                other.payAction == payAction) &&
            (identical(other.callBackJs, callBackJs) ||
                other.callBackJs == callBackJs) &&
            (identical(other.contentBatch, contentBatch) ||
                other.contentBatch == contentBatch) &&
            (identical(other.maxBatchSize, maxBatchSize) ||
                other.maxBatchSize == maxBatchSize));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      content,
      subContent,
      title,
      nextContentUrl,
      webJs,
      sourceRegex,
      replaceRegex,
      imageStyle,
      imageDecode,
      payAction,
      callBackJs,
      contentBatch,
      maxBatchSize,
    );
  }

  @override
  String toString() {
    return 'ContentRule(content: $content, subContent: $subContent, title: $title, nextContentUrl: $nextContentUrl, webJs: $webJs, sourceRegex: $sourceRegex, replaceRegex: $replaceRegex, imageStyle: $imageStyle, imageDecode: $imageDecode, payAction: $payAction, callBackJs: $callBackJs, contentBatch: $contentBatch, maxBatchSize: $maxBatchSize)';
  }
}

/// @nodoc
abstract mixin class _$ContentRuleCopyWith<$Res>
    implements $ContentRuleCopyWith<$Res> {
  factory _$ContentRuleCopyWith(
    _ContentRule value,
    $Res Function(_ContentRule) _then,
  ) = __$ContentRuleCopyWithImpl;
  @override
  @useResult
  $Res call({
    String? content,
    @JsonKey(name: 'subContent') String? subContent,
    String? title,
    @JsonKey(name: 'nextContentUrl') String? nextContentUrl,
    @JsonKey(name: 'webJs') String? webJs,
    @JsonKey(name: 'sourceRegex') String? sourceRegex,
    @JsonKey(name: 'replaceRegex') String? replaceRegex,
    @JsonKey(name: 'imageStyle') String? imageStyle,
    @JsonKey(name: 'imageDecode') String? imageDecode,
    @JsonKey(name: 'payAction') String? payAction,
    @JsonKey(name: 'callBackJs') String? callBackJs,
    @JsonKey(name: 'contentBatch') String? contentBatch,
    @JsonKey(name: 'maxBatchSize') int? maxBatchSize,
  });
}

/// @nodoc
class __$ContentRuleCopyWithImpl<$Res> implements _$ContentRuleCopyWith<$Res> {
  __$ContentRuleCopyWithImpl(this._self, this._then);

  final _ContentRule _self;
  final $Res Function(_ContentRule) _then;

  /// Create a copy of ContentRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? content = freezed,
    Object? subContent = freezed,
    Object? title = freezed,
    Object? nextContentUrl = freezed,
    Object? webJs = freezed,
    Object? sourceRegex = freezed,
    Object? replaceRegex = freezed,
    Object? imageStyle = freezed,
    Object? imageDecode = freezed,
    Object? payAction = freezed,
    Object? callBackJs = freezed,
    Object? contentBatch = freezed,
    Object? maxBatchSize = freezed,
  }) {
    return _then(
      _ContentRule(
        content: freezed == content
            ? _self.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        subContent: freezed == subContent
            ? _self.subContent
            : subContent // ignore: cast_nullable_to_non_nullable
                  as String?,
        title: freezed == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        nextContentUrl: freezed == nextContentUrl
            ? _self.nextContentUrl
            : nextContentUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        webJs: freezed == webJs
            ? _self.webJs
            : webJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        sourceRegex: freezed == sourceRegex
            ? _self.sourceRegex
            : sourceRegex // ignore: cast_nullable_to_non_nullable
                  as String?,
        replaceRegex: freezed == replaceRegex
            ? _self.replaceRegex
            : replaceRegex // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageStyle: freezed == imageStyle
            ? _self.imageStyle
            : imageStyle // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageDecode: freezed == imageDecode
            ? _self.imageDecode
            : imageDecode // ignore: cast_nullable_to_non_nullable
                  as String?,
        payAction: freezed == payAction
            ? _self.payAction
            : payAction // ignore: cast_nullable_to_non_nullable
                  as String?,
        callBackJs: freezed == callBackJs
            ? _self.callBackJs
            : callBackJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        contentBatch: freezed == contentBatch
            ? _self.contentBatch
            : contentBatch // ignore: cast_nullable_to_non_nullable
                  as String?,
        maxBatchSize: freezed == maxBatchSize
            ? _self.maxBatchSize
            : maxBatchSize // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
mixin _$ExploreRule {
  @JsonKey(name: 'bookList')
  String? get bookList;
  String? get name;
  String? get author;
  String? get intro;
  String? get kind;
  @JsonKey(name: 'lastChapter')
  String? get lastChapter;
  @JsonKey(name: 'updateTime')
  String? get updateTime;
  @JsonKey(name: 'bookUrl')
  String? get bookUrl;
  @JsonKey(name: 'coverUrl')
  String? get coverUrl;
  @JsonKey(name: 'wordCount')
  String? get wordCount;

  /// Create a copy of ExploreRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExploreRuleCopyWith<ExploreRule> get copyWith =>
      _$ExploreRuleCopyWithImpl<ExploreRule>(this as ExploreRule, _$identity);

  /// Serializes this ExploreRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as ExploreRule;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExploreRule &&
            (identical(other.bookList, _this.bookList) ||
                other.bookList == _this.bookList) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.author, _this.author) ||
                other.author == _this.author) &&
            (identical(other.intro, _this.intro) ||
                other.intro == _this.intro) &&
            (identical(other.kind, _this.kind) || other.kind == _this.kind) &&
            (identical(other.lastChapter, _this.lastChapter) ||
                other.lastChapter == _this.lastChapter) &&
            (identical(other.updateTime, _this.updateTime) ||
                other.updateTime == _this.updateTime) &&
            (identical(other.bookUrl, _this.bookUrl) ||
                other.bookUrl == _this.bookUrl) &&
            (identical(other.coverUrl, _this.coverUrl) ||
                other.coverUrl == _this.coverUrl) &&
            (identical(other.wordCount, _this.wordCount) ||
                other.wordCount == _this.wordCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as ExploreRule;
    return Object.hash(
      runtimeType,
      _this.bookList,
      _this.name,
      _this.author,
      _this.intro,
      _this.kind,
      _this.lastChapter,
      _this.updateTime,
      _this.bookUrl,
      _this.coverUrl,
      _this.wordCount,
    );
  }

  @override
  String toString() {
    final _this = this as ExploreRule;
    return 'ExploreRule(bookList: ${_this.bookList}, name: ${_this.name}, author: ${_this.author}, intro: ${_this.intro}, kind: ${_this.kind}, lastChapter: ${_this.lastChapter}, updateTime: ${_this.updateTime}, bookUrl: ${_this.bookUrl}, coverUrl: ${_this.coverUrl}, wordCount: ${_this.wordCount})';
  }
}

/// @nodoc
abstract mixin class $ExploreRuleCopyWith<$Res> {
  factory $ExploreRuleCopyWith(
    ExploreRule value,
    $Res Function(ExploreRule) _then,
  ) = _$ExploreRuleCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'bookList') String? bookList,
    String? name,
    String? author,
    String? intro,
    String? kind,
    @JsonKey(name: 'lastChapter') String? lastChapter,
    @JsonKey(name: 'updateTime') String? updateTime,
    @JsonKey(name: 'bookUrl') String? bookUrl,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    @JsonKey(name: 'wordCount') String? wordCount,
  });
}

/// @nodoc
class _$ExploreRuleCopyWithImpl<$Res> implements $ExploreRuleCopyWith<$Res> {
  _$ExploreRuleCopyWithImpl(this._self, this._then);

  final ExploreRule _self;
  final $Res Function(ExploreRule) _then;

  /// Create a copy of ExploreRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookList = freezed,
    Object? name = freezed,
    Object? author = freezed,
    Object? intro = freezed,
    Object? kind = freezed,
    Object? lastChapter = freezed,
    Object? updateTime = freezed,
    Object? bookUrl = freezed,
    Object? coverUrl = freezed,
    Object? wordCount = freezed,
  }) {
    return _then(
      ExploreRule(
        bookList: freezed == bookList
            ? _self.bookList
            : bookList // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: freezed == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        author: freezed == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        kind: freezed == kind
            ? _self.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastChapter: freezed == lastChapter
            ? _self.lastChapter
            : lastChapter // ignore: cast_nullable_to_non_nullable
                  as String?,
        updateTime: freezed == updateTime
            ? _self.updateTime
            : updateTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookUrl: freezed == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ExploreRule].
extension ExploreRulePatterns on ExploreRule {
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
    TResult Function(_ExploreRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExploreRule() when $default != null:
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
    TResult Function(_ExploreRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreRule():
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
    TResult? Function(_ExploreRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreRule() when $default != null:
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
      @JsonKey(name: 'bookList') String? bookList,
      String? name,
      String? author,
      String? intro,
      String? kind,
      @JsonKey(name: 'lastChapter') String? lastChapter,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'bookUrl') String? bookUrl,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'wordCount') String? wordCount,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExploreRule() when $default != null:
        return $default(
          _that.bookList,
          _that.name,
          _that.author,
          _that.intro,
          _that.kind,
          _that.lastChapter,
          _that.updateTime,
          _that.bookUrl,
          _that.coverUrl,
          _that.wordCount,
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
      @JsonKey(name: 'bookList') String? bookList,
      String? name,
      String? author,
      String? intro,
      String? kind,
      @JsonKey(name: 'lastChapter') String? lastChapter,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'bookUrl') String? bookUrl,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'wordCount') String? wordCount,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreRule():
        return $default(
          _that.bookList,
          _that.name,
          _that.author,
          _that.intro,
          _that.kind,
          _that.lastChapter,
          _that.updateTime,
          _that.bookUrl,
          _that.coverUrl,
          _that.wordCount,
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
      @JsonKey(name: 'bookList') String? bookList,
      String? name,
      String? author,
      String? intro,
      String? kind,
      @JsonKey(name: 'lastChapter') String? lastChapter,
      @JsonKey(name: 'updateTime') String? updateTime,
      @JsonKey(name: 'bookUrl') String? bookUrl,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      @JsonKey(name: 'wordCount') String? wordCount,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreRule() when $default != null:
        return $default(
          _that.bookList,
          _that.name,
          _that.author,
          _that.intro,
          _that.kind,
          _that.lastChapter,
          _that.updateTime,
          _that.bookUrl,
          _that.coverUrl,
          _that.wordCount,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ExploreRule implements ExploreRule {
  const _ExploreRule({
    @JsonKey(name: 'bookList') this.bookList,
    this.name,
    this.author,
    this.intro,
    this.kind,
    @JsonKey(name: 'lastChapter') this.lastChapter,
    @JsonKey(name: 'updateTime') this.updateTime,
    @JsonKey(name: 'bookUrl') this.bookUrl,
    @JsonKey(name: 'coverUrl') this.coverUrl,
    @JsonKey(name: 'wordCount') this.wordCount,
  });
  factory _ExploreRule.fromJson(Map<String, dynamic> json) =>
      _$ExploreRuleFromJson(json);

  @override
  @JsonKey(name: 'bookList')
  final String? bookList;
  @override
  final String? name;
  @override
  final String? author;
  @override
  final String? intro;
  @override
  final String? kind;
  @override
  @JsonKey(name: 'lastChapter')
  final String? lastChapter;
  @override
  @JsonKey(name: 'updateTime')
  final String? updateTime;
  @override
  @JsonKey(name: 'bookUrl')
  final String? bookUrl;
  @override
  @JsonKey(name: 'coverUrl')
  final String? coverUrl;
  @override
  @JsonKey(name: 'wordCount')
  final String? wordCount;

  /// Create a copy of ExploreRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExploreRuleCopyWith<_ExploreRule> get copyWith =>
      __$ExploreRuleCopyWithImpl<_ExploreRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ExploreRuleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExploreRule &&
            (identical(other.bookList, bookList) ||
                other.bookList == bookList) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.intro, intro) || other.intro == intro) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.lastChapter, lastChapter) ||
                other.lastChapter == lastChapter) &&
            (identical(other.updateTime, updateTime) ||
                other.updateTime == updateTime) &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      bookList,
      name,
      author,
      intro,
      kind,
      lastChapter,
      updateTime,
      bookUrl,
      coverUrl,
      wordCount,
    );
  }

  @override
  String toString() {
    return 'ExploreRule(bookList: $bookList, name: $name, author: $author, intro: $intro, kind: $kind, lastChapter: $lastChapter, updateTime: $updateTime, bookUrl: $bookUrl, coverUrl: $coverUrl, wordCount: $wordCount)';
  }
}

/// @nodoc
abstract mixin class _$ExploreRuleCopyWith<$Res>
    implements $ExploreRuleCopyWith<$Res> {
  factory _$ExploreRuleCopyWith(
    _ExploreRule value,
    $Res Function(_ExploreRule) _then,
  ) = __$ExploreRuleCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'bookList') String? bookList,
    String? name,
    String? author,
    String? intro,
    String? kind,
    @JsonKey(name: 'lastChapter') String? lastChapter,
    @JsonKey(name: 'updateTime') String? updateTime,
    @JsonKey(name: 'bookUrl') String? bookUrl,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    @JsonKey(name: 'wordCount') String? wordCount,
  });
}

/// @nodoc
class __$ExploreRuleCopyWithImpl<$Res> implements _$ExploreRuleCopyWith<$Res> {
  __$ExploreRuleCopyWithImpl(this._self, this._then);

  final _ExploreRule _self;
  final $Res Function(_ExploreRule) _then;

  /// Create a copy of ExploreRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookList = freezed,
    Object? name = freezed,
    Object? author = freezed,
    Object? intro = freezed,
    Object? kind = freezed,
    Object? lastChapter = freezed,
    Object? updateTime = freezed,
    Object? bookUrl = freezed,
    Object? coverUrl = freezed,
    Object? wordCount = freezed,
  }) {
    return _then(
      _ExploreRule(
        bookList: freezed == bookList
            ? _self.bookList
            : bookList // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: freezed == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        author: freezed == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        kind: freezed == kind
            ? _self.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastChapter: freezed == lastChapter
            ? _self.lastChapter
            : lastChapter // ignore: cast_nullable_to_non_nullable
                  as String?,
        updateTime: freezed == updateTime
            ? _self.updateTime
            : updateTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookUrl: freezed == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
mixin _$ReviewRule {
  @JsonKey(name: 'reviewUrl')
  String? get reviewUrl;
  @JsonKey(name: 'avatarRule')
  String? get avatarRule;
  @JsonKey(name: 'contentRule')
  String? get contentRule;
  @JsonKey(name: 'postTimeRule')
  String? get postTimeRule;
  @JsonKey(name: 'reviewQuoteUrl')
  String? get reviewQuoteUrl;
  @JsonKey(name: 'voteUpUrl')
  String? get voteUpUrl;
  @JsonKey(name: 'voteDownUrl')
  String? get voteDownUrl;
  @JsonKey(name: 'postReviewUrl')
  String? get postReviewUrl;
  @JsonKey(name: 'postQuoteUrl')
  String? get postQuoteUrl;
  @JsonKey(name: 'deleteUrl')
  String? get deleteUrl;
  bool get enabled;
  @JsonKey(name: 'reviewSummaryUrl')
  String? get reviewSummaryUrl;
  @JsonKey(name: 'summaryListRule')
  String? get summaryListRule;
  @JsonKey(name: 'summaryParagraphIndexRule')
  String? get summaryParagraphIndexRule;
  @JsonKey(name: 'summaryParagraphDataRule')
  String? get summaryParagraphDataRule;
  @JsonKey(name: 'summaryCountRule')
  String? get summaryCountRule;
  @JsonKey(name: 'reviewDetailUrl')
  String? get reviewDetailUrl;
  @JsonKey(name: 'reviewDetailNextPageUrl')
  String? get reviewDetailNextPageUrl;
  @JsonKey(name: 'detailListRule')
  String? get detailListRule;
  @JsonKey(name: 'detailIdRule')
  String? get detailIdRule;
  @JsonKey(name: 'detailAvatarRule')
  String? get detailAvatarRule;
  @JsonKey(name: 'detailNameRule')
  String? get detailNameRule;
  @JsonKey(name: 'detailBadgeRule')
  String? get detailBadgeRule;
  @JsonKey(name: 'detailContentRule')
  String? get detailContentRule;
  @JsonKey(name: 'replyListRule')
  String? get replyListRule;
  @JsonKey(name: 'replyIdRule')
  String? get replyIdRule;
  @JsonKey(name: 'replyAvatarRule')
  String? get replyAvatarRule;
  @JsonKey(name: 'replyNameRule')
  String? get replyNameRule;
  @JsonKey(name: 'replyBadgeRule')
  String? get replyBadgeRule;
  @JsonKey(name: 'replyContentRule')
  String? get replyContentRule;

  /// Create a copy of ReviewRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReviewRuleCopyWith<ReviewRule> get copyWith =>
      _$ReviewRuleCopyWithImpl<ReviewRule>(this as ReviewRule, _$identity);

  /// Serializes this ReviewRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as ReviewRule;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReviewRule &&
            (identical(other.reviewUrl, _this.reviewUrl) ||
                other.reviewUrl == _this.reviewUrl) &&
            (identical(other.avatarRule, _this.avatarRule) ||
                other.avatarRule == _this.avatarRule) &&
            (identical(other.contentRule, _this.contentRule) ||
                other.contentRule == _this.contentRule) &&
            (identical(other.postTimeRule, _this.postTimeRule) ||
                other.postTimeRule == _this.postTimeRule) &&
            (identical(other.reviewQuoteUrl, _this.reviewQuoteUrl) ||
                other.reviewQuoteUrl == _this.reviewQuoteUrl) &&
            (identical(other.voteUpUrl, _this.voteUpUrl) ||
                other.voteUpUrl == _this.voteUpUrl) &&
            (identical(other.voteDownUrl, _this.voteDownUrl) ||
                other.voteDownUrl == _this.voteDownUrl) &&
            (identical(other.postReviewUrl, _this.postReviewUrl) ||
                other.postReviewUrl == _this.postReviewUrl) &&
            (identical(other.postQuoteUrl, _this.postQuoteUrl) ||
                other.postQuoteUrl == _this.postQuoteUrl) &&
            (identical(other.deleteUrl, _this.deleteUrl) ||
                other.deleteUrl == _this.deleteUrl) &&
            (identical(other.enabled, _this.enabled) ||
                other.enabled == _this.enabled) &&
            (identical(other.reviewSummaryUrl, _this.reviewSummaryUrl) ||
                other.reviewSummaryUrl == _this.reviewSummaryUrl) &&
            (identical(other.summaryListRule, _this.summaryListRule) ||
                other.summaryListRule == _this.summaryListRule) &&
            (identical(
                  other.summaryParagraphIndexRule,
                  _this.summaryParagraphIndexRule,
                ) ||
                other.summaryParagraphIndexRule ==
                    _this.summaryParagraphIndexRule) &&
            (identical(
                  other.summaryParagraphDataRule,
                  _this.summaryParagraphDataRule,
                ) ||
                other.summaryParagraphDataRule ==
                    _this.summaryParagraphDataRule) &&
            (identical(other.summaryCountRule, _this.summaryCountRule) ||
                other.summaryCountRule == _this.summaryCountRule) &&
            (identical(other.reviewDetailUrl, _this.reviewDetailUrl) ||
                other.reviewDetailUrl == _this.reviewDetailUrl) &&
            (identical(
                  other.reviewDetailNextPageUrl,
                  _this.reviewDetailNextPageUrl,
                ) ||
                other.reviewDetailNextPageUrl ==
                    _this.reviewDetailNextPageUrl) &&
            (identical(other.detailListRule, _this.detailListRule) ||
                other.detailListRule == _this.detailListRule) &&
            (identical(other.detailIdRule, _this.detailIdRule) ||
                other.detailIdRule == _this.detailIdRule) &&
            (identical(other.detailAvatarRule, _this.detailAvatarRule) ||
                other.detailAvatarRule == _this.detailAvatarRule) &&
            (identical(other.detailNameRule, _this.detailNameRule) ||
                other.detailNameRule == _this.detailNameRule) &&
            (identical(other.detailBadgeRule, _this.detailBadgeRule) ||
                other.detailBadgeRule == _this.detailBadgeRule) &&
            (identical(other.detailContentRule, _this.detailContentRule) ||
                other.detailContentRule == _this.detailContentRule) &&
            (identical(other.replyListRule, _this.replyListRule) ||
                other.replyListRule == _this.replyListRule) &&
            (identical(other.replyIdRule, _this.replyIdRule) ||
                other.replyIdRule == _this.replyIdRule) &&
            (identical(other.replyAvatarRule, _this.replyAvatarRule) ||
                other.replyAvatarRule == _this.replyAvatarRule) &&
            (identical(other.replyNameRule, _this.replyNameRule) ||
                other.replyNameRule == _this.replyNameRule) &&
            (identical(other.replyBadgeRule, _this.replyBadgeRule) ||
                other.replyBadgeRule == _this.replyBadgeRule) &&
            (identical(other.replyContentRule, _this.replyContentRule) ||
                other.replyContentRule == _this.replyContentRule));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as ReviewRule;
    return Object.hashAll([
      runtimeType,
      _this.reviewUrl,
      _this.avatarRule,
      _this.contentRule,
      _this.postTimeRule,
      _this.reviewQuoteUrl,
      _this.voteUpUrl,
      _this.voteDownUrl,
      _this.postReviewUrl,
      _this.postQuoteUrl,
      _this.deleteUrl,
      _this.enabled,
      _this.reviewSummaryUrl,
      _this.summaryListRule,
      _this.summaryParagraphIndexRule,
      _this.summaryParagraphDataRule,
      _this.summaryCountRule,
      _this.reviewDetailUrl,
      _this.reviewDetailNextPageUrl,
      _this.detailListRule,
      _this.detailIdRule,
      _this.detailAvatarRule,
      _this.detailNameRule,
      _this.detailBadgeRule,
      _this.detailContentRule,
      _this.replyListRule,
      _this.replyIdRule,
      _this.replyAvatarRule,
      _this.replyNameRule,
      _this.replyBadgeRule,
      _this.replyContentRule,
    ]);
  }

  @override
  String toString() {
    final _this = this as ReviewRule;
    return 'ReviewRule(reviewUrl: ${_this.reviewUrl}, avatarRule: ${_this.avatarRule}, contentRule: ${_this.contentRule}, postTimeRule: ${_this.postTimeRule}, reviewQuoteUrl: ${_this.reviewQuoteUrl}, voteUpUrl: ${_this.voteUpUrl}, voteDownUrl: ${_this.voteDownUrl}, postReviewUrl: ${_this.postReviewUrl}, postQuoteUrl: ${_this.postQuoteUrl}, deleteUrl: ${_this.deleteUrl}, enabled: ${_this.enabled}, reviewSummaryUrl: ${_this.reviewSummaryUrl}, summaryListRule: ${_this.summaryListRule}, summaryParagraphIndexRule: ${_this.summaryParagraphIndexRule}, summaryParagraphDataRule: ${_this.summaryParagraphDataRule}, summaryCountRule: ${_this.summaryCountRule}, reviewDetailUrl: ${_this.reviewDetailUrl}, reviewDetailNextPageUrl: ${_this.reviewDetailNextPageUrl}, detailListRule: ${_this.detailListRule}, detailIdRule: ${_this.detailIdRule}, detailAvatarRule: ${_this.detailAvatarRule}, detailNameRule: ${_this.detailNameRule}, detailBadgeRule: ${_this.detailBadgeRule}, detailContentRule: ${_this.detailContentRule}, replyListRule: ${_this.replyListRule}, replyIdRule: ${_this.replyIdRule}, replyAvatarRule: ${_this.replyAvatarRule}, replyNameRule: ${_this.replyNameRule}, replyBadgeRule: ${_this.replyBadgeRule}, replyContentRule: ${_this.replyContentRule})';
  }
}

/// @nodoc
abstract mixin class $ReviewRuleCopyWith<$Res> {
  factory $ReviewRuleCopyWith(
    ReviewRule value,
    $Res Function(ReviewRule) _then,
  ) = _$ReviewRuleCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'reviewUrl') String? reviewUrl,
    @JsonKey(name: 'avatarRule') String? avatarRule,
    @JsonKey(name: 'contentRule') String? contentRule,
    @JsonKey(name: 'postTimeRule') String? postTimeRule,
    @JsonKey(name: 'reviewQuoteUrl') String? reviewQuoteUrl,
    @JsonKey(name: 'voteUpUrl') String? voteUpUrl,
    @JsonKey(name: 'voteDownUrl') String? voteDownUrl,
    @JsonKey(name: 'postReviewUrl') String? postReviewUrl,
    @JsonKey(name: 'postQuoteUrl') String? postQuoteUrl,
    @JsonKey(name: 'deleteUrl') String? deleteUrl,
    bool enabled,
    @JsonKey(name: 'reviewSummaryUrl') String? reviewSummaryUrl,
    @JsonKey(name: 'summaryListRule') String? summaryListRule,
    @JsonKey(name: 'summaryParagraphIndexRule')
    String? summaryParagraphIndexRule,
    @JsonKey(name: 'summaryParagraphDataRule') String? summaryParagraphDataRule,
    @JsonKey(name: 'summaryCountRule') String? summaryCountRule,
    @JsonKey(name: 'reviewDetailUrl') String? reviewDetailUrl,
    @JsonKey(name: 'reviewDetailNextPageUrl') String? reviewDetailNextPageUrl,
    @JsonKey(name: 'detailListRule') String? detailListRule,
    @JsonKey(name: 'detailIdRule') String? detailIdRule,
    @JsonKey(name: 'detailAvatarRule') String? detailAvatarRule,
    @JsonKey(name: 'detailNameRule') String? detailNameRule,
    @JsonKey(name: 'detailBadgeRule') String? detailBadgeRule,
    @JsonKey(name: 'detailContentRule') String? detailContentRule,
    @JsonKey(name: 'replyListRule') String? replyListRule,
    @JsonKey(name: 'replyIdRule') String? replyIdRule,
    @JsonKey(name: 'replyAvatarRule') String? replyAvatarRule,
    @JsonKey(name: 'replyNameRule') String? replyNameRule,
    @JsonKey(name: 'replyBadgeRule') String? replyBadgeRule,
    @JsonKey(name: 'replyContentRule') String? replyContentRule,
  });
}

/// @nodoc
class _$ReviewRuleCopyWithImpl<$Res> implements $ReviewRuleCopyWith<$Res> {
  _$ReviewRuleCopyWithImpl(this._self, this._then);

  final ReviewRule _self;
  final $Res Function(ReviewRule) _then;

  /// Create a copy of ReviewRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? reviewUrl = freezed,
    Object? avatarRule = freezed,
    Object? contentRule = freezed,
    Object? postTimeRule = freezed,
    Object? reviewQuoteUrl = freezed,
    Object? voteUpUrl = freezed,
    Object? voteDownUrl = freezed,
    Object? postReviewUrl = freezed,
    Object? postQuoteUrl = freezed,
    Object? deleteUrl = freezed,
    Object? enabled = null,
    Object? reviewSummaryUrl = freezed,
    Object? summaryListRule = freezed,
    Object? summaryParagraphIndexRule = freezed,
    Object? summaryParagraphDataRule = freezed,
    Object? summaryCountRule = freezed,
    Object? reviewDetailUrl = freezed,
    Object? reviewDetailNextPageUrl = freezed,
    Object? detailListRule = freezed,
    Object? detailIdRule = freezed,
    Object? detailAvatarRule = freezed,
    Object? detailNameRule = freezed,
    Object? detailBadgeRule = freezed,
    Object? detailContentRule = freezed,
    Object? replyListRule = freezed,
    Object? replyIdRule = freezed,
    Object? replyAvatarRule = freezed,
    Object? replyNameRule = freezed,
    Object? replyBadgeRule = freezed,
    Object? replyContentRule = freezed,
  }) {
    return _then(
      ReviewRule(
        reviewUrl: freezed == reviewUrl
            ? _self.reviewUrl
            : reviewUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        avatarRule: freezed == avatarRule
            ? _self.avatarRule
            : avatarRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        contentRule: freezed == contentRule
            ? _self.contentRule
            : contentRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        postTimeRule: freezed == postTimeRule
            ? _self.postTimeRule
            : postTimeRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewQuoteUrl: freezed == reviewQuoteUrl
            ? _self.reviewQuoteUrl
            : reviewQuoteUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        voteUpUrl: freezed == voteUpUrl
            ? _self.voteUpUrl
            : voteUpUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        voteDownUrl: freezed == voteDownUrl
            ? _self.voteDownUrl
            : voteDownUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        postReviewUrl: freezed == postReviewUrl
            ? _self.postReviewUrl
            : postReviewUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        postQuoteUrl: freezed == postQuoteUrl
            ? _self.postQuoteUrl
            : postQuoteUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        deleteUrl: freezed == deleteUrl
            ? _self.deleteUrl
            : deleteUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabled: null == enabled
            ? _self.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        reviewSummaryUrl: freezed == reviewSummaryUrl
            ? _self.reviewSummaryUrl
            : reviewSummaryUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        summaryListRule: freezed == summaryListRule
            ? _self.summaryListRule
            : summaryListRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        summaryParagraphIndexRule: freezed == summaryParagraphIndexRule
            ? _self.summaryParagraphIndexRule
            : summaryParagraphIndexRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        summaryParagraphDataRule: freezed == summaryParagraphDataRule
            ? _self.summaryParagraphDataRule
            : summaryParagraphDataRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        summaryCountRule: freezed == summaryCountRule
            ? _self.summaryCountRule
            : summaryCountRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewDetailUrl: freezed == reviewDetailUrl
            ? _self.reviewDetailUrl
            : reviewDetailUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewDetailNextPageUrl: freezed == reviewDetailNextPageUrl
            ? _self.reviewDetailNextPageUrl
            : reviewDetailNextPageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailListRule: freezed == detailListRule
            ? _self.detailListRule
            : detailListRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailIdRule: freezed == detailIdRule
            ? _self.detailIdRule
            : detailIdRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailAvatarRule: freezed == detailAvatarRule
            ? _self.detailAvatarRule
            : detailAvatarRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailNameRule: freezed == detailNameRule
            ? _self.detailNameRule
            : detailNameRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailBadgeRule: freezed == detailBadgeRule
            ? _self.detailBadgeRule
            : detailBadgeRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailContentRule: freezed == detailContentRule
            ? _self.detailContentRule
            : detailContentRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyListRule: freezed == replyListRule
            ? _self.replyListRule
            : replyListRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyIdRule: freezed == replyIdRule
            ? _self.replyIdRule
            : replyIdRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyAvatarRule: freezed == replyAvatarRule
            ? _self.replyAvatarRule
            : replyAvatarRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyNameRule: freezed == replyNameRule
            ? _self.replyNameRule
            : replyNameRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyBadgeRule: freezed == replyBadgeRule
            ? _self.replyBadgeRule
            : replyBadgeRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyContentRule: freezed == replyContentRule
            ? _self.replyContentRule
            : replyContentRule // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ReviewRule].
extension ReviewRulePatterns on ReviewRule {
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
    TResult Function(_ReviewRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReviewRule() when $default != null:
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
    TResult Function(_ReviewRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReviewRule():
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
    TResult? Function(_ReviewRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReviewRule() when $default != null:
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
      @JsonKey(name: 'reviewUrl') String? reviewUrl,
      @JsonKey(name: 'avatarRule') String? avatarRule,
      @JsonKey(name: 'contentRule') String? contentRule,
      @JsonKey(name: 'postTimeRule') String? postTimeRule,
      @JsonKey(name: 'reviewQuoteUrl') String? reviewQuoteUrl,
      @JsonKey(name: 'voteUpUrl') String? voteUpUrl,
      @JsonKey(name: 'voteDownUrl') String? voteDownUrl,
      @JsonKey(name: 'postReviewUrl') String? postReviewUrl,
      @JsonKey(name: 'postQuoteUrl') String? postQuoteUrl,
      @JsonKey(name: 'deleteUrl') String? deleteUrl,
      bool enabled,
      @JsonKey(name: 'reviewSummaryUrl') String? reviewSummaryUrl,
      @JsonKey(name: 'summaryListRule') String? summaryListRule,
      @JsonKey(name: 'summaryParagraphIndexRule')
      String? summaryParagraphIndexRule,
      @JsonKey(name: 'summaryParagraphDataRule')
      String? summaryParagraphDataRule,
      @JsonKey(name: 'summaryCountRule') String? summaryCountRule,
      @JsonKey(name: 'reviewDetailUrl') String? reviewDetailUrl,
      @JsonKey(name: 'reviewDetailNextPageUrl') String? reviewDetailNextPageUrl,
      @JsonKey(name: 'detailListRule') String? detailListRule,
      @JsonKey(name: 'detailIdRule') String? detailIdRule,
      @JsonKey(name: 'detailAvatarRule') String? detailAvatarRule,
      @JsonKey(name: 'detailNameRule') String? detailNameRule,
      @JsonKey(name: 'detailBadgeRule') String? detailBadgeRule,
      @JsonKey(name: 'detailContentRule') String? detailContentRule,
      @JsonKey(name: 'replyListRule') String? replyListRule,
      @JsonKey(name: 'replyIdRule') String? replyIdRule,
      @JsonKey(name: 'replyAvatarRule') String? replyAvatarRule,
      @JsonKey(name: 'replyNameRule') String? replyNameRule,
      @JsonKey(name: 'replyBadgeRule') String? replyBadgeRule,
      @JsonKey(name: 'replyContentRule') String? replyContentRule,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReviewRule() when $default != null:
        return $default(
          _that.reviewUrl,
          _that.avatarRule,
          _that.contentRule,
          _that.postTimeRule,
          _that.reviewQuoteUrl,
          _that.voteUpUrl,
          _that.voteDownUrl,
          _that.postReviewUrl,
          _that.postQuoteUrl,
          _that.deleteUrl,
          _that.enabled,
          _that.reviewSummaryUrl,
          _that.summaryListRule,
          _that.summaryParagraphIndexRule,
          _that.summaryParagraphDataRule,
          _that.summaryCountRule,
          _that.reviewDetailUrl,
          _that.reviewDetailNextPageUrl,
          _that.detailListRule,
          _that.detailIdRule,
          _that.detailAvatarRule,
          _that.detailNameRule,
          _that.detailBadgeRule,
          _that.detailContentRule,
          _that.replyListRule,
          _that.replyIdRule,
          _that.replyAvatarRule,
          _that.replyNameRule,
          _that.replyBadgeRule,
          _that.replyContentRule,
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
      @JsonKey(name: 'reviewUrl') String? reviewUrl,
      @JsonKey(name: 'avatarRule') String? avatarRule,
      @JsonKey(name: 'contentRule') String? contentRule,
      @JsonKey(name: 'postTimeRule') String? postTimeRule,
      @JsonKey(name: 'reviewQuoteUrl') String? reviewQuoteUrl,
      @JsonKey(name: 'voteUpUrl') String? voteUpUrl,
      @JsonKey(name: 'voteDownUrl') String? voteDownUrl,
      @JsonKey(name: 'postReviewUrl') String? postReviewUrl,
      @JsonKey(name: 'postQuoteUrl') String? postQuoteUrl,
      @JsonKey(name: 'deleteUrl') String? deleteUrl,
      bool enabled,
      @JsonKey(name: 'reviewSummaryUrl') String? reviewSummaryUrl,
      @JsonKey(name: 'summaryListRule') String? summaryListRule,
      @JsonKey(name: 'summaryParagraphIndexRule')
      String? summaryParagraphIndexRule,
      @JsonKey(name: 'summaryParagraphDataRule')
      String? summaryParagraphDataRule,
      @JsonKey(name: 'summaryCountRule') String? summaryCountRule,
      @JsonKey(name: 'reviewDetailUrl') String? reviewDetailUrl,
      @JsonKey(name: 'reviewDetailNextPageUrl') String? reviewDetailNextPageUrl,
      @JsonKey(name: 'detailListRule') String? detailListRule,
      @JsonKey(name: 'detailIdRule') String? detailIdRule,
      @JsonKey(name: 'detailAvatarRule') String? detailAvatarRule,
      @JsonKey(name: 'detailNameRule') String? detailNameRule,
      @JsonKey(name: 'detailBadgeRule') String? detailBadgeRule,
      @JsonKey(name: 'detailContentRule') String? detailContentRule,
      @JsonKey(name: 'replyListRule') String? replyListRule,
      @JsonKey(name: 'replyIdRule') String? replyIdRule,
      @JsonKey(name: 'replyAvatarRule') String? replyAvatarRule,
      @JsonKey(name: 'replyNameRule') String? replyNameRule,
      @JsonKey(name: 'replyBadgeRule') String? replyBadgeRule,
      @JsonKey(name: 'replyContentRule') String? replyContentRule,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReviewRule():
        return $default(
          _that.reviewUrl,
          _that.avatarRule,
          _that.contentRule,
          _that.postTimeRule,
          _that.reviewQuoteUrl,
          _that.voteUpUrl,
          _that.voteDownUrl,
          _that.postReviewUrl,
          _that.postQuoteUrl,
          _that.deleteUrl,
          _that.enabled,
          _that.reviewSummaryUrl,
          _that.summaryListRule,
          _that.summaryParagraphIndexRule,
          _that.summaryParagraphDataRule,
          _that.summaryCountRule,
          _that.reviewDetailUrl,
          _that.reviewDetailNextPageUrl,
          _that.detailListRule,
          _that.detailIdRule,
          _that.detailAvatarRule,
          _that.detailNameRule,
          _that.detailBadgeRule,
          _that.detailContentRule,
          _that.replyListRule,
          _that.replyIdRule,
          _that.replyAvatarRule,
          _that.replyNameRule,
          _that.replyBadgeRule,
          _that.replyContentRule,
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
      @JsonKey(name: 'reviewUrl') String? reviewUrl,
      @JsonKey(name: 'avatarRule') String? avatarRule,
      @JsonKey(name: 'contentRule') String? contentRule,
      @JsonKey(name: 'postTimeRule') String? postTimeRule,
      @JsonKey(name: 'reviewQuoteUrl') String? reviewQuoteUrl,
      @JsonKey(name: 'voteUpUrl') String? voteUpUrl,
      @JsonKey(name: 'voteDownUrl') String? voteDownUrl,
      @JsonKey(name: 'postReviewUrl') String? postReviewUrl,
      @JsonKey(name: 'postQuoteUrl') String? postQuoteUrl,
      @JsonKey(name: 'deleteUrl') String? deleteUrl,
      bool enabled,
      @JsonKey(name: 'reviewSummaryUrl') String? reviewSummaryUrl,
      @JsonKey(name: 'summaryListRule') String? summaryListRule,
      @JsonKey(name: 'summaryParagraphIndexRule')
      String? summaryParagraphIndexRule,
      @JsonKey(name: 'summaryParagraphDataRule')
      String? summaryParagraphDataRule,
      @JsonKey(name: 'summaryCountRule') String? summaryCountRule,
      @JsonKey(name: 'reviewDetailUrl') String? reviewDetailUrl,
      @JsonKey(name: 'reviewDetailNextPageUrl') String? reviewDetailNextPageUrl,
      @JsonKey(name: 'detailListRule') String? detailListRule,
      @JsonKey(name: 'detailIdRule') String? detailIdRule,
      @JsonKey(name: 'detailAvatarRule') String? detailAvatarRule,
      @JsonKey(name: 'detailNameRule') String? detailNameRule,
      @JsonKey(name: 'detailBadgeRule') String? detailBadgeRule,
      @JsonKey(name: 'detailContentRule') String? detailContentRule,
      @JsonKey(name: 'replyListRule') String? replyListRule,
      @JsonKey(name: 'replyIdRule') String? replyIdRule,
      @JsonKey(name: 'replyAvatarRule') String? replyAvatarRule,
      @JsonKey(name: 'replyNameRule') String? replyNameRule,
      @JsonKey(name: 'replyBadgeRule') String? replyBadgeRule,
      @JsonKey(name: 'replyContentRule') String? replyContentRule,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReviewRule() when $default != null:
        return $default(
          _that.reviewUrl,
          _that.avatarRule,
          _that.contentRule,
          _that.postTimeRule,
          _that.reviewQuoteUrl,
          _that.voteUpUrl,
          _that.voteDownUrl,
          _that.postReviewUrl,
          _that.postQuoteUrl,
          _that.deleteUrl,
          _that.enabled,
          _that.reviewSummaryUrl,
          _that.summaryListRule,
          _that.summaryParagraphIndexRule,
          _that.summaryParagraphDataRule,
          _that.summaryCountRule,
          _that.reviewDetailUrl,
          _that.reviewDetailNextPageUrl,
          _that.detailListRule,
          _that.detailIdRule,
          _that.detailAvatarRule,
          _that.detailNameRule,
          _that.detailBadgeRule,
          _that.detailContentRule,
          _that.replyListRule,
          _that.replyIdRule,
          _that.replyAvatarRule,
          _that.replyNameRule,
          _that.replyBadgeRule,
          _that.replyContentRule,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ReviewRule implements ReviewRule {
  const _ReviewRule({
    @JsonKey(name: 'reviewUrl') this.reviewUrl,
    @JsonKey(name: 'avatarRule') this.avatarRule,
    @JsonKey(name: 'contentRule') this.contentRule,
    @JsonKey(name: 'postTimeRule') this.postTimeRule,
    @JsonKey(name: 'reviewQuoteUrl') this.reviewQuoteUrl,
    @JsonKey(name: 'voteUpUrl') this.voteUpUrl,
    @JsonKey(name: 'voteDownUrl') this.voteDownUrl,
    @JsonKey(name: 'postReviewUrl') this.postReviewUrl,
    @JsonKey(name: 'postQuoteUrl') this.postQuoteUrl,
    @JsonKey(name: 'deleteUrl') this.deleteUrl,
    this.enabled = false,
    @JsonKey(name: 'reviewSummaryUrl') this.reviewSummaryUrl,
    @JsonKey(name: 'summaryListRule') this.summaryListRule,
    @JsonKey(name: 'summaryParagraphIndexRule') this.summaryParagraphIndexRule,
    @JsonKey(name: 'summaryParagraphDataRule') this.summaryParagraphDataRule,
    @JsonKey(name: 'summaryCountRule') this.summaryCountRule,
    @JsonKey(name: 'reviewDetailUrl') this.reviewDetailUrl,
    @JsonKey(name: 'reviewDetailNextPageUrl') this.reviewDetailNextPageUrl,
    @JsonKey(name: 'detailListRule') this.detailListRule,
    @JsonKey(name: 'detailIdRule') this.detailIdRule,
    @JsonKey(name: 'detailAvatarRule') this.detailAvatarRule,
    @JsonKey(name: 'detailNameRule') this.detailNameRule,
    @JsonKey(name: 'detailBadgeRule') this.detailBadgeRule,
    @JsonKey(name: 'detailContentRule') this.detailContentRule,
    @JsonKey(name: 'replyListRule') this.replyListRule,
    @JsonKey(name: 'replyIdRule') this.replyIdRule,
    @JsonKey(name: 'replyAvatarRule') this.replyAvatarRule,
    @JsonKey(name: 'replyNameRule') this.replyNameRule,
    @JsonKey(name: 'replyBadgeRule') this.replyBadgeRule,
    @JsonKey(name: 'replyContentRule') this.replyContentRule,
  });
  factory _ReviewRule.fromJson(Map<String, dynamic> json) =>
      _$ReviewRuleFromJson(json);

  @override
  @JsonKey(name: 'reviewUrl')
  final String? reviewUrl;
  @override
  @JsonKey(name: 'avatarRule')
  final String? avatarRule;
  @override
  @JsonKey(name: 'contentRule')
  final String? contentRule;
  @override
  @JsonKey(name: 'postTimeRule')
  final String? postTimeRule;
  @override
  @JsonKey(name: 'reviewQuoteUrl')
  final String? reviewQuoteUrl;
  @override
  @JsonKey(name: 'voteUpUrl')
  final String? voteUpUrl;
  @override
  @JsonKey(name: 'voteDownUrl')
  final String? voteDownUrl;
  @override
  @JsonKey(name: 'postReviewUrl')
  final String? postReviewUrl;
  @override
  @JsonKey(name: 'postQuoteUrl')
  final String? postQuoteUrl;
  @override
  @JsonKey(name: 'deleteUrl')
  final String? deleteUrl;
  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey(name: 'reviewSummaryUrl')
  final String? reviewSummaryUrl;
  @override
  @JsonKey(name: 'summaryListRule')
  final String? summaryListRule;
  @override
  @JsonKey(name: 'summaryParagraphIndexRule')
  final String? summaryParagraphIndexRule;
  @override
  @JsonKey(name: 'summaryParagraphDataRule')
  final String? summaryParagraphDataRule;
  @override
  @JsonKey(name: 'summaryCountRule')
  final String? summaryCountRule;
  @override
  @JsonKey(name: 'reviewDetailUrl')
  final String? reviewDetailUrl;
  @override
  @JsonKey(name: 'reviewDetailNextPageUrl')
  final String? reviewDetailNextPageUrl;
  @override
  @JsonKey(name: 'detailListRule')
  final String? detailListRule;
  @override
  @JsonKey(name: 'detailIdRule')
  final String? detailIdRule;
  @override
  @JsonKey(name: 'detailAvatarRule')
  final String? detailAvatarRule;
  @override
  @JsonKey(name: 'detailNameRule')
  final String? detailNameRule;
  @override
  @JsonKey(name: 'detailBadgeRule')
  final String? detailBadgeRule;
  @override
  @JsonKey(name: 'detailContentRule')
  final String? detailContentRule;
  @override
  @JsonKey(name: 'replyListRule')
  final String? replyListRule;
  @override
  @JsonKey(name: 'replyIdRule')
  final String? replyIdRule;
  @override
  @JsonKey(name: 'replyAvatarRule')
  final String? replyAvatarRule;
  @override
  @JsonKey(name: 'replyNameRule')
  final String? replyNameRule;
  @override
  @JsonKey(name: 'replyBadgeRule')
  final String? replyBadgeRule;
  @override
  @JsonKey(name: 'replyContentRule')
  final String? replyContentRule;

  /// Create a copy of ReviewRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReviewRuleCopyWith<_ReviewRule> get copyWith =>
      __$ReviewRuleCopyWithImpl<_ReviewRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ReviewRuleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReviewRule &&
            (identical(other.reviewUrl, reviewUrl) ||
                other.reviewUrl == reviewUrl) &&
            (identical(other.avatarRule, avatarRule) ||
                other.avatarRule == avatarRule) &&
            (identical(other.contentRule, contentRule) ||
                other.contentRule == contentRule) &&
            (identical(other.postTimeRule, postTimeRule) ||
                other.postTimeRule == postTimeRule) &&
            (identical(other.reviewQuoteUrl, reviewQuoteUrl) ||
                other.reviewQuoteUrl == reviewQuoteUrl) &&
            (identical(other.voteUpUrl, voteUpUrl) ||
                other.voteUpUrl == voteUpUrl) &&
            (identical(other.voteDownUrl, voteDownUrl) ||
                other.voteDownUrl == voteDownUrl) &&
            (identical(other.postReviewUrl, postReviewUrl) ||
                other.postReviewUrl == postReviewUrl) &&
            (identical(other.postQuoteUrl, postQuoteUrl) ||
                other.postQuoteUrl == postQuoteUrl) &&
            (identical(other.deleteUrl, deleteUrl) ||
                other.deleteUrl == deleteUrl) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.reviewSummaryUrl, reviewSummaryUrl) ||
                other.reviewSummaryUrl == reviewSummaryUrl) &&
            (identical(other.summaryListRule, summaryListRule) ||
                other.summaryListRule == summaryListRule) &&
            (identical(
                  other.summaryParagraphIndexRule,
                  summaryParagraphIndexRule,
                ) ||
                other.summaryParagraphIndexRule == summaryParagraphIndexRule) &&
            (identical(
                  other.summaryParagraphDataRule,
                  summaryParagraphDataRule,
                ) ||
                other.summaryParagraphDataRule == summaryParagraphDataRule) &&
            (identical(other.summaryCountRule, summaryCountRule) ||
                other.summaryCountRule == summaryCountRule) &&
            (identical(other.reviewDetailUrl, reviewDetailUrl) ||
                other.reviewDetailUrl == reviewDetailUrl) &&
            (identical(
                  other.reviewDetailNextPageUrl,
                  reviewDetailNextPageUrl,
                ) ||
                other.reviewDetailNextPageUrl == reviewDetailNextPageUrl) &&
            (identical(other.detailListRule, detailListRule) ||
                other.detailListRule == detailListRule) &&
            (identical(other.detailIdRule, detailIdRule) ||
                other.detailIdRule == detailIdRule) &&
            (identical(other.detailAvatarRule, detailAvatarRule) ||
                other.detailAvatarRule == detailAvatarRule) &&
            (identical(other.detailNameRule, detailNameRule) ||
                other.detailNameRule == detailNameRule) &&
            (identical(other.detailBadgeRule, detailBadgeRule) ||
                other.detailBadgeRule == detailBadgeRule) &&
            (identical(other.detailContentRule, detailContentRule) ||
                other.detailContentRule == detailContentRule) &&
            (identical(other.replyListRule, replyListRule) ||
                other.replyListRule == replyListRule) &&
            (identical(other.replyIdRule, replyIdRule) ||
                other.replyIdRule == replyIdRule) &&
            (identical(other.replyAvatarRule, replyAvatarRule) ||
                other.replyAvatarRule == replyAvatarRule) &&
            (identical(other.replyNameRule, replyNameRule) ||
                other.replyNameRule == replyNameRule) &&
            (identical(other.replyBadgeRule, replyBadgeRule) ||
                other.replyBadgeRule == replyBadgeRule) &&
            (identical(other.replyContentRule, replyContentRule) ||
                other.replyContentRule == replyContentRule));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hashAll([
      runtimeType,
      reviewUrl,
      avatarRule,
      contentRule,
      postTimeRule,
      reviewQuoteUrl,
      voteUpUrl,
      voteDownUrl,
      postReviewUrl,
      postQuoteUrl,
      deleteUrl,
      enabled,
      reviewSummaryUrl,
      summaryListRule,
      summaryParagraphIndexRule,
      summaryParagraphDataRule,
      summaryCountRule,
      reviewDetailUrl,
      reviewDetailNextPageUrl,
      detailListRule,
      detailIdRule,
      detailAvatarRule,
      detailNameRule,
      detailBadgeRule,
      detailContentRule,
      replyListRule,
      replyIdRule,
      replyAvatarRule,
      replyNameRule,
      replyBadgeRule,
      replyContentRule,
    ]);
  }

  @override
  String toString() {
    return 'ReviewRule(reviewUrl: $reviewUrl, avatarRule: $avatarRule, contentRule: $contentRule, postTimeRule: $postTimeRule, reviewQuoteUrl: $reviewQuoteUrl, voteUpUrl: $voteUpUrl, voteDownUrl: $voteDownUrl, postReviewUrl: $postReviewUrl, postQuoteUrl: $postQuoteUrl, deleteUrl: $deleteUrl, enabled: $enabled, reviewSummaryUrl: $reviewSummaryUrl, summaryListRule: $summaryListRule, summaryParagraphIndexRule: $summaryParagraphIndexRule, summaryParagraphDataRule: $summaryParagraphDataRule, summaryCountRule: $summaryCountRule, reviewDetailUrl: $reviewDetailUrl, reviewDetailNextPageUrl: $reviewDetailNextPageUrl, detailListRule: $detailListRule, detailIdRule: $detailIdRule, detailAvatarRule: $detailAvatarRule, detailNameRule: $detailNameRule, detailBadgeRule: $detailBadgeRule, detailContentRule: $detailContentRule, replyListRule: $replyListRule, replyIdRule: $replyIdRule, replyAvatarRule: $replyAvatarRule, replyNameRule: $replyNameRule, replyBadgeRule: $replyBadgeRule, replyContentRule: $replyContentRule)';
  }
}

/// @nodoc
abstract mixin class _$ReviewRuleCopyWith<$Res>
    implements $ReviewRuleCopyWith<$Res> {
  factory _$ReviewRuleCopyWith(
    _ReviewRule value,
    $Res Function(_ReviewRule) _then,
  ) = __$ReviewRuleCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'reviewUrl') String? reviewUrl,
    @JsonKey(name: 'avatarRule') String? avatarRule,
    @JsonKey(name: 'contentRule') String? contentRule,
    @JsonKey(name: 'postTimeRule') String? postTimeRule,
    @JsonKey(name: 'reviewQuoteUrl') String? reviewQuoteUrl,
    @JsonKey(name: 'voteUpUrl') String? voteUpUrl,
    @JsonKey(name: 'voteDownUrl') String? voteDownUrl,
    @JsonKey(name: 'postReviewUrl') String? postReviewUrl,
    @JsonKey(name: 'postQuoteUrl') String? postQuoteUrl,
    @JsonKey(name: 'deleteUrl') String? deleteUrl,
    bool enabled,
    @JsonKey(name: 'reviewSummaryUrl') String? reviewSummaryUrl,
    @JsonKey(name: 'summaryListRule') String? summaryListRule,
    @JsonKey(name: 'summaryParagraphIndexRule')
    String? summaryParagraphIndexRule,
    @JsonKey(name: 'summaryParagraphDataRule') String? summaryParagraphDataRule,
    @JsonKey(name: 'summaryCountRule') String? summaryCountRule,
    @JsonKey(name: 'reviewDetailUrl') String? reviewDetailUrl,
    @JsonKey(name: 'reviewDetailNextPageUrl') String? reviewDetailNextPageUrl,
    @JsonKey(name: 'detailListRule') String? detailListRule,
    @JsonKey(name: 'detailIdRule') String? detailIdRule,
    @JsonKey(name: 'detailAvatarRule') String? detailAvatarRule,
    @JsonKey(name: 'detailNameRule') String? detailNameRule,
    @JsonKey(name: 'detailBadgeRule') String? detailBadgeRule,
    @JsonKey(name: 'detailContentRule') String? detailContentRule,
    @JsonKey(name: 'replyListRule') String? replyListRule,
    @JsonKey(name: 'replyIdRule') String? replyIdRule,
    @JsonKey(name: 'replyAvatarRule') String? replyAvatarRule,
    @JsonKey(name: 'replyNameRule') String? replyNameRule,
    @JsonKey(name: 'replyBadgeRule') String? replyBadgeRule,
    @JsonKey(name: 'replyContentRule') String? replyContentRule,
  });
}

/// @nodoc
class __$ReviewRuleCopyWithImpl<$Res> implements _$ReviewRuleCopyWith<$Res> {
  __$ReviewRuleCopyWithImpl(this._self, this._then);

  final _ReviewRule _self;
  final $Res Function(_ReviewRule) _then;

  /// Create a copy of ReviewRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? reviewUrl = freezed,
    Object? avatarRule = freezed,
    Object? contentRule = freezed,
    Object? postTimeRule = freezed,
    Object? reviewQuoteUrl = freezed,
    Object? voteUpUrl = freezed,
    Object? voteDownUrl = freezed,
    Object? postReviewUrl = freezed,
    Object? postQuoteUrl = freezed,
    Object? deleteUrl = freezed,
    Object? enabled = null,
    Object? reviewSummaryUrl = freezed,
    Object? summaryListRule = freezed,
    Object? summaryParagraphIndexRule = freezed,
    Object? summaryParagraphDataRule = freezed,
    Object? summaryCountRule = freezed,
    Object? reviewDetailUrl = freezed,
    Object? reviewDetailNextPageUrl = freezed,
    Object? detailListRule = freezed,
    Object? detailIdRule = freezed,
    Object? detailAvatarRule = freezed,
    Object? detailNameRule = freezed,
    Object? detailBadgeRule = freezed,
    Object? detailContentRule = freezed,
    Object? replyListRule = freezed,
    Object? replyIdRule = freezed,
    Object? replyAvatarRule = freezed,
    Object? replyNameRule = freezed,
    Object? replyBadgeRule = freezed,
    Object? replyContentRule = freezed,
  }) {
    return _then(
      _ReviewRule(
        reviewUrl: freezed == reviewUrl
            ? _self.reviewUrl
            : reviewUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        avatarRule: freezed == avatarRule
            ? _self.avatarRule
            : avatarRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        contentRule: freezed == contentRule
            ? _self.contentRule
            : contentRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        postTimeRule: freezed == postTimeRule
            ? _self.postTimeRule
            : postTimeRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewQuoteUrl: freezed == reviewQuoteUrl
            ? _self.reviewQuoteUrl
            : reviewQuoteUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        voteUpUrl: freezed == voteUpUrl
            ? _self.voteUpUrl
            : voteUpUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        voteDownUrl: freezed == voteDownUrl
            ? _self.voteDownUrl
            : voteDownUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        postReviewUrl: freezed == postReviewUrl
            ? _self.postReviewUrl
            : postReviewUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        postQuoteUrl: freezed == postQuoteUrl
            ? _self.postQuoteUrl
            : postQuoteUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        deleteUrl: freezed == deleteUrl
            ? _self.deleteUrl
            : deleteUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabled: null == enabled
            ? _self.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        reviewSummaryUrl: freezed == reviewSummaryUrl
            ? _self.reviewSummaryUrl
            : reviewSummaryUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        summaryListRule: freezed == summaryListRule
            ? _self.summaryListRule
            : summaryListRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        summaryParagraphIndexRule: freezed == summaryParagraphIndexRule
            ? _self.summaryParagraphIndexRule
            : summaryParagraphIndexRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        summaryParagraphDataRule: freezed == summaryParagraphDataRule
            ? _self.summaryParagraphDataRule
            : summaryParagraphDataRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        summaryCountRule: freezed == summaryCountRule
            ? _self.summaryCountRule
            : summaryCountRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewDetailUrl: freezed == reviewDetailUrl
            ? _self.reviewDetailUrl
            : reviewDetailUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewDetailNextPageUrl: freezed == reviewDetailNextPageUrl
            ? _self.reviewDetailNextPageUrl
            : reviewDetailNextPageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailListRule: freezed == detailListRule
            ? _self.detailListRule
            : detailListRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailIdRule: freezed == detailIdRule
            ? _self.detailIdRule
            : detailIdRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailAvatarRule: freezed == detailAvatarRule
            ? _self.detailAvatarRule
            : detailAvatarRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailNameRule: freezed == detailNameRule
            ? _self.detailNameRule
            : detailNameRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailBadgeRule: freezed == detailBadgeRule
            ? _self.detailBadgeRule
            : detailBadgeRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        detailContentRule: freezed == detailContentRule
            ? _self.detailContentRule
            : detailContentRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyListRule: freezed == replyListRule
            ? _self.replyListRule
            : replyListRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyIdRule: freezed == replyIdRule
            ? _self.replyIdRule
            : replyIdRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyAvatarRule: freezed == replyAvatarRule
            ? _self.replyAvatarRule
            : replyAvatarRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyNameRule: freezed == replyNameRule
            ? _self.replyNameRule
            : replyNameRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyBadgeRule: freezed == replyBadgeRule
            ? _self.replyBadgeRule
            : replyBadgeRule // ignore: cast_nullable_to_non_nullable
                  as String?,
        replyContentRule: freezed == replyContentRule
            ? _self.replyContentRule
            : replyContentRule // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
mixin _$FlexChildStyle {
  @JsonKey(name: 'layout_flexGrow')
  double get layoutFlexGrow;
  @JsonKey(name: 'layout_flexShrink')
  double get layoutFlexShrink;
  @JsonKey(name: 'layout_alignSelf')
  String get layoutAlignSelf;
  @JsonKey(name: 'layout_flexBasisPercent')
  double get layoutFlexBasisPercent;
  @JsonKey(name: 'layout_wrapBefore')
  bool get layoutWrapBefore;
  @JsonKey(name: 'layout_justifySelf')
  String get layoutJustifySelf;

  /// Create a copy of FlexChildStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FlexChildStyleCopyWith<FlexChildStyle> get copyWith =>
      _$FlexChildStyleCopyWithImpl<FlexChildStyle>(
        this as FlexChildStyle,
        _$identity,
      );

  /// Serializes this FlexChildStyle to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as FlexChildStyle;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FlexChildStyle &&
            (identical(other.layoutFlexGrow, _this.layoutFlexGrow) ||
                other.layoutFlexGrow == _this.layoutFlexGrow) &&
            (identical(other.layoutFlexShrink, _this.layoutFlexShrink) ||
                other.layoutFlexShrink == _this.layoutFlexShrink) &&
            (identical(other.layoutAlignSelf, _this.layoutAlignSelf) ||
                other.layoutAlignSelf == _this.layoutAlignSelf) &&
            (identical(
                  other.layoutFlexBasisPercent,
                  _this.layoutFlexBasisPercent,
                ) ||
                other.layoutFlexBasisPercent == _this.layoutFlexBasisPercent) &&
            (identical(other.layoutWrapBefore, _this.layoutWrapBefore) ||
                other.layoutWrapBefore == _this.layoutWrapBefore) &&
            (identical(other.layoutJustifySelf, _this.layoutJustifySelf) ||
                other.layoutJustifySelf == _this.layoutJustifySelf));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as FlexChildStyle;
    return Object.hash(
      runtimeType,
      _this.layoutFlexGrow,
      _this.layoutFlexShrink,
      _this.layoutAlignSelf,
      _this.layoutFlexBasisPercent,
      _this.layoutWrapBefore,
      _this.layoutJustifySelf,
    );
  }

  @override
  String toString() {
    final _this = this as FlexChildStyle;
    return 'FlexChildStyle(layoutFlexGrow: ${_this.layoutFlexGrow}, layoutFlexShrink: ${_this.layoutFlexShrink}, layoutAlignSelf: ${_this.layoutAlignSelf}, layoutFlexBasisPercent: ${_this.layoutFlexBasisPercent}, layoutWrapBefore: ${_this.layoutWrapBefore}, layoutJustifySelf: ${_this.layoutJustifySelf})';
  }
}

/// @nodoc
abstract mixin class $FlexChildStyleCopyWith<$Res> {
  factory $FlexChildStyleCopyWith(
    FlexChildStyle value,
    $Res Function(FlexChildStyle) _then,
  ) = _$FlexChildStyleCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'layout_flexGrow') double layoutFlexGrow,
    @JsonKey(name: 'layout_flexShrink') double layoutFlexShrink,
    @JsonKey(name: 'layout_alignSelf') String layoutAlignSelf,
    @JsonKey(name: 'layout_flexBasisPercent') double layoutFlexBasisPercent,
    @JsonKey(name: 'layout_wrapBefore') bool layoutWrapBefore,
    @JsonKey(name: 'layout_justifySelf') String layoutJustifySelf,
  });
}

/// @nodoc
class _$FlexChildStyleCopyWithImpl<$Res>
    implements $FlexChildStyleCopyWith<$Res> {
  _$FlexChildStyleCopyWithImpl(this._self, this._then);

  final FlexChildStyle _self;
  final $Res Function(FlexChildStyle) _then;

  /// Create a copy of FlexChildStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? layoutFlexGrow = null,
    Object? layoutFlexShrink = null,
    Object? layoutAlignSelf = null,
    Object? layoutFlexBasisPercent = null,
    Object? layoutWrapBefore = null,
    Object? layoutJustifySelf = null,
  }) {
    return _then(
      FlexChildStyle(
        layoutFlexGrow: null == layoutFlexGrow
            ? _self.layoutFlexGrow
            : layoutFlexGrow // ignore: cast_nullable_to_non_nullable
                  as double,
        layoutFlexShrink: null == layoutFlexShrink
            ? _self.layoutFlexShrink
            : layoutFlexShrink // ignore: cast_nullable_to_non_nullable
                  as double,
        layoutAlignSelf: null == layoutAlignSelf
            ? _self.layoutAlignSelf
            : layoutAlignSelf // ignore: cast_nullable_to_non_nullable
                  as String,
        layoutFlexBasisPercent: null == layoutFlexBasisPercent
            ? _self.layoutFlexBasisPercent
            : layoutFlexBasisPercent // ignore: cast_nullable_to_non_nullable
                  as double,
        layoutWrapBefore: null == layoutWrapBefore
            ? _self.layoutWrapBefore
            : layoutWrapBefore // ignore: cast_nullable_to_non_nullable
                  as bool,
        layoutJustifySelf: null == layoutJustifySelf
            ? _self.layoutJustifySelf
            : layoutJustifySelf // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [FlexChildStyle].
extension FlexChildStylePatterns on FlexChildStyle {
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
    TResult Function(_FlexChildStyle value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FlexChildStyle() when $default != null:
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
    TResult Function(_FlexChildStyle value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlexChildStyle():
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
    TResult? Function(_FlexChildStyle value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlexChildStyle() when $default != null:
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
      @JsonKey(name: 'layout_flexGrow') double layoutFlexGrow,
      @JsonKey(name: 'layout_flexShrink') double layoutFlexShrink,
      @JsonKey(name: 'layout_alignSelf') String layoutAlignSelf,
      @JsonKey(name: 'layout_flexBasisPercent') double layoutFlexBasisPercent,
      @JsonKey(name: 'layout_wrapBefore') bool layoutWrapBefore,
      @JsonKey(name: 'layout_justifySelf') String layoutJustifySelf,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FlexChildStyle() when $default != null:
        return $default(
          _that.layoutFlexGrow,
          _that.layoutFlexShrink,
          _that.layoutAlignSelf,
          _that.layoutFlexBasisPercent,
          _that.layoutWrapBefore,
          _that.layoutJustifySelf,
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
      @JsonKey(name: 'layout_flexGrow') double layoutFlexGrow,
      @JsonKey(name: 'layout_flexShrink') double layoutFlexShrink,
      @JsonKey(name: 'layout_alignSelf') String layoutAlignSelf,
      @JsonKey(name: 'layout_flexBasisPercent') double layoutFlexBasisPercent,
      @JsonKey(name: 'layout_wrapBefore') bool layoutWrapBefore,
      @JsonKey(name: 'layout_justifySelf') String layoutJustifySelf,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlexChildStyle():
        return $default(
          _that.layoutFlexGrow,
          _that.layoutFlexShrink,
          _that.layoutAlignSelf,
          _that.layoutFlexBasisPercent,
          _that.layoutWrapBefore,
          _that.layoutJustifySelf,
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
      @JsonKey(name: 'layout_flexGrow') double layoutFlexGrow,
      @JsonKey(name: 'layout_flexShrink') double layoutFlexShrink,
      @JsonKey(name: 'layout_alignSelf') String layoutAlignSelf,
      @JsonKey(name: 'layout_flexBasisPercent') double layoutFlexBasisPercent,
      @JsonKey(name: 'layout_wrapBefore') bool layoutWrapBefore,
      @JsonKey(name: 'layout_justifySelf') String layoutJustifySelf,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlexChildStyle() when $default != null:
        return $default(
          _that.layoutFlexGrow,
          _that.layoutFlexShrink,
          _that.layoutAlignSelf,
          _that.layoutFlexBasisPercent,
          _that.layoutWrapBefore,
          _that.layoutJustifySelf,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _FlexChildStyle implements FlexChildStyle {
  const _FlexChildStyle({
    @JsonKey(name: 'layout_flexGrow') this.layoutFlexGrow = 0,
    @JsonKey(name: 'layout_flexShrink') this.layoutFlexShrink = 1.0,
    @JsonKey(name: 'layout_alignSelf') this.layoutAlignSelf = 'auto',
    @JsonKey(name: 'layout_flexBasisPercent')
    this.layoutFlexBasisPercent = -1.0,
    @JsonKey(name: 'layout_wrapBefore') this.layoutWrapBefore = false,
    @JsonKey(name: 'layout_justifySelf') this.layoutJustifySelf = 'auto',
  });
  factory _FlexChildStyle.fromJson(Map<String, dynamic> json) =>
      _$FlexChildStyleFromJson(json);

  @override
  @JsonKey(name: 'layout_flexGrow')
  final double layoutFlexGrow;
  @override
  @JsonKey(name: 'layout_flexShrink')
  final double layoutFlexShrink;
  @override
  @JsonKey(name: 'layout_alignSelf')
  final String layoutAlignSelf;
  @override
  @JsonKey(name: 'layout_flexBasisPercent')
  final double layoutFlexBasisPercent;
  @override
  @JsonKey(name: 'layout_wrapBefore')
  final bool layoutWrapBefore;
  @override
  @JsonKey(name: 'layout_justifySelf')
  final String layoutJustifySelf;

  /// Create a copy of FlexChildStyle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FlexChildStyleCopyWith<_FlexChildStyle> get copyWith =>
      __$FlexChildStyleCopyWithImpl<_FlexChildStyle>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FlexChildStyleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FlexChildStyle &&
            (identical(other.layoutFlexGrow, layoutFlexGrow) ||
                other.layoutFlexGrow == layoutFlexGrow) &&
            (identical(other.layoutFlexShrink, layoutFlexShrink) ||
                other.layoutFlexShrink == layoutFlexShrink) &&
            (identical(other.layoutAlignSelf, layoutAlignSelf) ||
                other.layoutAlignSelf == layoutAlignSelf) &&
            (identical(other.layoutFlexBasisPercent, layoutFlexBasisPercent) ||
                other.layoutFlexBasisPercent == layoutFlexBasisPercent) &&
            (identical(other.layoutWrapBefore, layoutWrapBefore) ||
                other.layoutWrapBefore == layoutWrapBefore) &&
            (identical(other.layoutJustifySelf, layoutJustifySelf) ||
                other.layoutJustifySelf == layoutJustifySelf));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      layoutFlexGrow,
      layoutFlexShrink,
      layoutAlignSelf,
      layoutFlexBasisPercent,
      layoutWrapBefore,
      layoutJustifySelf,
    );
  }

  @override
  String toString() {
    return 'FlexChildStyle(layoutFlexGrow: $layoutFlexGrow, layoutFlexShrink: $layoutFlexShrink, layoutAlignSelf: $layoutAlignSelf, layoutFlexBasisPercent: $layoutFlexBasisPercent, layoutWrapBefore: $layoutWrapBefore, layoutJustifySelf: $layoutJustifySelf)';
  }
}

/// @nodoc
abstract mixin class _$FlexChildStyleCopyWith<$Res>
    implements $FlexChildStyleCopyWith<$Res> {
  factory _$FlexChildStyleCopyWith(
    _FlexChildStyle value,
    $Res Function(_FlexChildStyle) _then,
  ) = __$FlexChildStyleCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'layout_flexGrow') double layoutFlexGrow,
    @JsonKey(name: 'layout_flexShrink') double layoutFlexShrink,
    @JsonKey(name: 'layout_alignSelf') String layoutAlignSelf,
    @JsonKey(name: 'layout_flexBasisPercent') double layoutFlexBasisPercent,
    @JsonKey(name: 'layout_wrapBefore') bool layoutWrapBefore,
    @JsonKey(name: 'layout_justifySelf') String layoutJustifySelf,
  });
}

/// @nodoc
class __$FlexChildStyleCopyWithImpl<$Res>
    implements _$FlexChildStyleCopyWith<$Res> {
  __$FlexChildStyleCopyWithImpl(this._self, this._then);

  final _FlexChildStyle _self;
  final $Res Function(_FlexChildStyle) _then;

  /// Create a copy of FlexChildStyle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? layoutFlexGrow = null,
    Object? layoutFlexShrink = null,
    Object? layoutAlignSelf = null,
    Object? layoutFlexBasisPercent = null,
    Object? layoutWrapBefore = null,
    Object? layoutJustifySelf = null,
  }) {
    return _then(
      _FlexChildStyle(
        layoutFlexGrow: null == layoutFlexGrow
            ? _self.layoutFlexGrow
            : layoutFlexGrow // ignore: cast_nullable_to_non_nullable
                  as double,
        layoutFlexShrink: null == layoutFlexShrink
            ? _self.layoutFlexShrink
            : layoutFlexShrink // ignore: cast_nullable_to_non_nullable
                  as double,
        layoutAlignSelf: null == layoutAlignSelf
            ? _self.layoutAlignSelf
            : layoutAlignSelf // ignore: cast_nullable_to_non_nullable
                  as String,
        layoutFlexBasisPercent: null == layoutFlexBasisPercent
            ? _self.layoutFlexBasisPercent
            : layoutFlexBasisPercent // ignore: cast_nullable_to_non_nullable
                  as double,
        layoutWrapBefore: null == layoutWrapBefore
            ? _self.layoutWrapBefore
            : layoutWrapBefore // ignore: cast_nullable_to_non_nullable
                  as bool,
        layoutJustifySelf: null == layoutJustifySelf
            ? _self.layoutJustifySelf
            : layoutJustifySelf // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
mixin _$ExploreKind {
  String get title;
  String? get url;
  String get type;
  String? get action;
  List<String?>? get chars;
  @JsonKey(name: 'default')
  String? get defaultValue;
  @JsonKey(name: 'viewName')
  String? get viewName;
  FlexChildStyle? get style;

  /// Create a copy of ExploreKind
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExploreKindCopyWith<ExploreKind> get copyWith =>
      _$ExploreKindCopyWithImpl<ExploreKind>(this as ExploreKind, _$identity);

  /// Serializes this ExploreKind to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as ExploreKind;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ExploreKind &&
            (identical(other.title, _this.title) ||
                other.title == _this.title) &&
            (identical(other.url, _this.url) || other.url == _this.url) &&
            (identical(other.type, _this.type) || other.type == _this.type) &&
            (identical(other.action, _this.action) ||
                other.action == _this.action) &&
            const DeepCollectionEquality().equals(other.chars, _this.chars) &&
            (identical(other.defaultValue, _this.defaultValue) ||
                other.defaultValue == _this.defaultValue) &&
            (identical(other.viewName, _this.viewName) ||
                other.viewName == _this.viewName) &&
            (identical(other.style, _this.style) ||
                other.style == _this.style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as ExploreKind;
    return Object.hash(
      runtimeType,
      _this.title,
      _this.url,
      _this.type,
      _this.action,
      const DeepCollectionEquality().hash(_this.chars),
      _this.defaultValue,
      _this.viewName,
      _this.style,
    );
  }

  @override
  String toString() {
    final _this = this as ExploreKind;
    return 'ExploreKind(title: ${_this.title}, url: ${_this.url}, type: ${_this.type}, action: ${_this.action}, chars: ${_this.chars}, defaultValue: ${_this.defaultValue}, viewName: ${_this.viewName}, style: ${_this.style})';
  }
}

/// @nodoc
abstract mixin class $ExploreKindCopyWith<$Res> {
  factory $ExploreKindCopyWith(
    ExploreKind value,
    $Res Function(ExploreKind) _then,
  ) = _$ExploreKindCopyWithImpl;
  @useResult
  $Res call({
    String title,
    String? url,
    String type,
    String? action,
    List<String?>? chars,
    @JsonKey(name: 'default') String? defaultValue,
    @JsonKey(name: 'viewName') String? viewName,
    FlexChildStyle? style,
  });

  $FlexChildStyleCopyWith<$Res>? get style;
}

/// @nodoc
class _$ExploreKindCopyWithImpl<$Res> implements $ExploreKindCopyWith<$Res> {
  _$ExploreKindCopyWithImpl(this._self, this._then);

  final ExploreKind _self;
  final $Res Function(ExploreKind) _then;

  /// Create a copy of ExploreKind
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? url = freezed,
    Object? type = null,
    Object? action = freezed,
    Object? chars = freezed,
    Object? defaultValue = freezed,
    Object? viewName = freezed,
    Object? style = freezed,
  }) {
    return _then(
      ExploreKind(
        title: null == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        url: freezed == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String?,
        type: null == type
            ? _self.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        action: freezed == action
            ? _self.action
            : action // ignore: cast_nullable_to_non_nullable
                  as String?,
        chars: freezed == chars
            ? _self.chars
            : chars // ignore: cast_nullable_to_non_nullable
                  as List<String?>?,
        defaultValue: freezed == defaultValue
            ? _self.defaultValue
            : defaultValue // ignore: cast_nullable_to_non_nullable
                  as String?,
        viewName: freezed == viewName
            ? _self.viewName
            : viewName // ignore: cast_nullable_to_non_nullable
                  as String?,
        style: freezed == style
            ? _self.style
            : style // ignore: cast_nullable_to_non_nullable
                  as FlexChildStyle?,
      ),
    );
  }

  /// Create a copy of ExploreKind
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlexChildStyleCopyWith<$Res>? get style {
    if (_self.style == null) {
      return null;
    }

    return $FlexChildStyleCopyWith<$Res>(_self.style!, (value) {
      return _then(_self.copyWith(style: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ExploreKind].
extension ExploreKindPatterns on ExploreKind {
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
    TResult Function(_ExploreKind value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExploreKind() when $default != null:
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
    TResult Function(_ExploreKind value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreKind():
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
    TResult? Function(_ExploreKind value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreKind() when $default != null:
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
      String title,
      String? url,
      String type,
      String? action,
      List<String?>? chars,
      @JsonKey(name: 'default') String? defaultValue,
      @JsonKey(name: 'viewName') String? viewName,
      FlexChildStyle? style,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ExploreKind() when $default != null:
        return $default(
          _that.title,
          _that.url,
          _that.type,
          _that.action,
          _that.chars,
          _that.defaultValue,
          _that.viewName,
          _that.style,
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
      String title,
      String? url,
      String type,
      String? action,
      List<String?>? chars,
      @JsonKey(name: 'default') String? defaultValue,
      @JsonKey(name: 'viewName') String? viewName,
      FlexChildStyle? style,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreKind():
        return $default(
          _that.title,
          _that.url,
          _that.type,
          _that.action,
          _that.chars,
          _that.defaultValue,
          _that.viewName,
          _that.style,
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
      String title,
      String? url,
      String type,
      String? action,
      List<String?>? chars,
      @JsonKey(name: 'default') String? defaultValue,
      @JsonKey(name: 'viewName') String? viewName,
      FlexChildStyle? style,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ExploreKind() when $default != null:
        return $default(
          _that.title,
          _that.url,
          _that.type,
          _that.action,
          _that.chars,
          _that.defaultValue,
          _that.viewName,
          _that.style,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ExploreKind implements ExploreKind {
  const _ExploreKind({
    this.title = '',
    this.url,
    this.type = 'url',
    this.action,
    List<String?>? chars,
    @JsonKey(name: 'default') this.defaultValue,
    @JsonKey(name: 'viewName') this.viewName,
    this.style,
  }) : _chars = chars;
  factory _ExploreKind.fromJson(Map<String, dynamic> json) =>
      _$ExploreKindFromJson(json);

  @override
  @JsonKey()
  final String title;
  @override
  final String? url;
  @override
  @JsonKey()
  final String type;
  @override
  final String? action;
  final List<String?>? _chars;
  @override
  List<String?>? get chars {
    final value = _chars;
    if (value == null) return null;
    if (_chars is EqualUnmodifiableListView) return _chars;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'default')
  final String? defaultValue;
  @override
  @JsonKey(name: 'viewName')
  final String? viewName;
  @override
  final FlexChildStyle? style;

  /// Create a copy of ExploreKind
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExploreKindCopyWith<_ExploreKind> get copyWith =>
      __$ExploreKindCopyWithImpl<_ExploreKind>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ExploreKindToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ExploreKind &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.action, action) || other.action == action) &&
            const DeepCollectionEquality().equals(other.chars, _chars) &&
            (identical(other.defaultValue, defaultValue) ||
                other.defaultValue == defaultValue) &&
            (identical(other.viewName, viewName) ||
                other.viewName == viewName) &&
            (identical(other.style, style) || other.style == style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      title,
      url,
      type,
      action,
      const DeepCollectionEquality().hash(_chars),
      defaultValue,
      viewName,
      style,
    );
  }

  @override
  String toString() {
    return 'ExploreKind(title: $title, url: $url, type: $type, action: $action, chars: $chars, defaultValue: $defaultValue, viewName: $viewName, style: $style)';
  }
}

/// @nodoc
abstract mixin class _$ExploreKindCopyWith<$Res>
    implements $ExploreKindCopyWith<$Res> {
  factory _$ExploreKindCopyWith(
    _ExploreKind value,
    $Res Function(_ExploreKind) _then,
  ) = __$ExploreKindCopyWithImpl;
  @override
  @useResult
  $Res call({
    String title,
    String? url,
    String type,
    String? action,
    List<String?>? chars,
    @JsonKey(name: 'default') String? defaultValue,
    @JsonKey(name: 'viewName') String? viewName,
    FlexChildStyle? style,
  });

  @override
  $FlexChildStyleCopyWith<$Res>? get style;
}

/// @nodoc
class __$ExploreKindCopyWithImpl<$Res> implements _$ExploreKindCopyWith<$Res> {
  __$ExploreKindCopyWithImpl(this._self, this._then);

  final _ExploreKind _self;
  final $Res Function(_ExploreKind) _then;

  /// Create a copy of ExploreKind
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? title = null,
    Object? url = freezed,
    Object? type = null,
    Object? action = freezed,
    Object? chars = freezed,
    Object? defaultValue = freezed,
    Object? viewName = freezed,
    Object? style = freezed,
  }) {
    return _then(
      _ExploreKind(
        title: null == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        url: freezed == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String?,
        type: null == type
            ? _self.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        action: freezed == action
            ? _self.action
            : action // ignore: cast_nullable_to_non_nullable
                  as String?,
        chars: freezed == chars
            ? _self._chars
            : chars // ignore: cast_nullable_to_non_nullable
                  as List<String?>?,
        defaultValue: freezed == defaultValue
            ? _self.defaultValue
            : defaultValue // ignore: cast_nullable_to_non_nullable
                  as String?,
        viewName: freezed == viewName
            ? _self.viewName
            : viewName // ignore: cast_nullable_to_non_nullable
                  as String?,
        style: freezed == style
            ? _self.style
            : style // ignore: cast_nullable_to_non_nullable
                  as FlexChildStyle?,
      ),
    );
  }

  /// Create a copy of ExploreKind
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlexChildStyleCopyWith<$Res>? get style {
    if (_self.style == null) {
      return null;
    }

    return $FlexChildStyleCopyWith<$Res>(_self.style!, (value) {
      return _then(_self.copyWith(style: value));
    });
  }
}

/// @nodoc
mixin _$RowUi {
  String get name;
  String get type;
  String? get action;
  List<String?>? get chars;
  @JsonKey(name: 'default')
  String? get defaultValue;
  @JsonKey(name: 'viewName')
  String? get viewName;
  FlexChildStyle? get style;

  /// Create a copy of RowUi
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RowUiCopyWith<RowUi> get copyWith =>
      _$RowUiCopyWithImpl<RowUi>(this as RowUi, _$identity);

  /// Serializes this RowUi to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as RowUi;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RowUi &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.type, _this.type) || other.type == _this.type) &&
            (identical(other.action, _this.action) ||
                other.action == _this.action) &&
            const DeepCollectionEquality().equals(other.chars, _this.chars) &&
            (identical(other.defaultValue, _this.defaultValue) ||
                other.defaultValue == _this.defaultValue) &&
            (identical(other.viewName, _this.viewName) ||
                other.viewName == _this.viewName) &&
            (identical(other.style, _this.style) ||
                other.style == _this.style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as RowUi;
    return Object.hash(
      runtimeType,
      _this.name,
      _this.type,
      _this.action,
      const DeepCollectionEquality().hash(_this.chars),
      _this.defaultValue,
      _this.viewName,
      _this.style,
    );
  }

  @override
  String toString() {
    final _this = this as RowUi;
    return 'RowUi(name: ${_this.name}, type: ${_this.type}, action: ${_this.action}, chars: ${_this.chars}, defaultValue: ${_this.defaultValue}, viewName: ${_this.viewName}, style: ${_this.style})';
  }
}

/// @nodoc
abstract mixin class $RowUiCopyWith<$Res> {
  factory $RowUiCopyWith(RowUi value, $Res Function(RowUi) _then) =
      _$RowUiCopyWithImpl;
  @useResult
  $Res call({
    String name,
    String type,
    String? action,
    List<String?>? chars,
    @JsonKey(name: 'default') String? defaultValue,
    @JsonKey(name: 'viewName') String? viewName,
    FlexChildStyle? style,
  });

  $FlexChildStyleCopyWith<$Res>? get style;
}

/// @nodoc
class _$RowUiCopyWithImpl<$Res> implements $RowUiCopyWith<$Res> {
  _$RowUiCopyWithImpl(this._self, this._then);

  final RowUi _self;
  final $Res Function(RowUi) _then;

  /// Create a copy of RowUi
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? type = null,
    Object? action = freezed,
    Object? chars = freezed,
    Object? defaultValue = freezed,
    Object? viewName = freezed,
    Object? style = freezed,
  }) {
    return _then(
      RowUi(
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _self.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        action: freezed == action
            ? _self.action
            : action // ignore: cast_nullable_to_non_nullable
                  as String?,
        chars: freezed == chars
            ? _self.chars
            : chars // ignore: cast_nullable_to_non_nullable
                  as List<String?>?,
        defaultValue: freezed == defaultValue
            ? _self.defaultValue
            : defaultValue // ignore: cast_nullable_to_non_nullable
                  as String?,
        viewName: freezed == viewName
            ? _self.viewName
            : viewName // ignore: cast_nullable_to_non_nullable
                  as String?,
        style: freezed == style
            ? _self.style
            : style // ignore: cast_nullable_to_non_nullable
                  as FlexChildStyle?,
      ),
    );
  }

  /// Create a copy of RowUi
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlexChildStyleCopyWith<$Res>? get style {
    if (_self.style == null) {
      return null;
    }

    return $FlexChildStyleCopyWith<$Res>(_self.style!, (value) {
      return _then(_self.copyWith(style: value));
    });
  }
}

/// Adds pattern-matching-related methods to [RowUi].
extension RowUiPatterns on RowUi {
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
    TResult Function(_RowUi value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RowUi() when $default != null:
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
    TResult Function(_RowUi value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RowUi():
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
    TResult? Function(_RowUi value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RowUi() when $default != null:
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
      String name,
      String type,
      String? action,
      List<String?>? chars,
      @JsonKey(name: 'default') String? defaultValue,
      @JsonKey(name: 'viewName') String? viewName,
      FlexChildStyle? style,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RowUi() when $default != null:
        return $default(
          _that.name,
          _that.type,
          _that.action,
          _that.chars,
          _that.defaultValue,
          _that.viewName,
          _that.style,
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
      String name,
      String type,
      String? action,
      List<String?>? chars,
      @JsonKey(name: 'default') String? defaultValue,
      @JsonKey(name: 'viewName') String? viewName,
      FlexChildStyle? style,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RowUi():
        return $default(
          _that.name,
          _that.type,
          _that.action,
          _that.chars,
          _that.defaultValue,
          _that.viewName,
          _that.style,
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
      String name,
      String type,
      String? action,
      List<String?>? chars,
      @JsonKey(name: 'default') String? defaultValue,
      @JsonKey(name: 'viewName') String? viewName,
      FlexChildStyle? style,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RowUi() when $default != null:
        return $default(
          _that.name,
          _that.type,
          _that.action,
          _that.chars,
          _that.defaultValue,
          _that.viewName,
          _that.style,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RowUi implements RowUi {
  const _RowUi({
    this.name = '',
    this.type = 'text',
    this.action,
    List<String?>? chars,
    @JsonKey(name: 'default') this.defaultValue,
    @JsonKey(name: 'viewName') this.viewName,
    this.style,
  }) : _chars = chars;
  factory _RowUi.fromJson(Map<String, dynamic> json) => _$RowUiFromJson(json);

  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String type;
  @override
  final String? action;
  final List<String?>? _chars;
  @override
  List<String?>? get chars {
    final value = _chars;
    if (value == null) return null;
    if (_chars is EqualUnmodifiableListView) return _chars;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'default')
  final String? defaultValue;
  @override
  @JsonKey(name: 'viewName')
  final String? viewName;
  @override
  final FlexChildStyle? style;

  /// Create a copy of RowUi
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RowUiCopyWith<_RowUi> get copyWith =>
      __$RowUiCopyWithImpl<_RowUi>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RowUiToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RowUi &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.action, action) || other.action == action) &&
            const DeepCollectionEquality().equals(other.chars, _chars) &&
            (identical(other.defaultValue, defaultValue) ||
                other.defaultValue == defaultValue) &&
            (identical(other.viewName, viewName) ||
                other.viewName == viewName) &&
            (identical(other.style, style) || other.style == style));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      name,
      type,
      action,
      const DeepCollectionEquality().hash(_chars),
      defaultValue,
      viewName,
      style,
    );
  }

  @override
  String toString() {
    return 'RowUi(name: $name, type: $type, action: $action, chars: $chars, defaultValue: $defaultValue, viewName: $viewName, style: $style)';
  }
}

/// @nodoc
abstract mixin class _$RowUiCopyWith<$Res> implements $RowUiCopyWith<$Res> {
  factory _$RowUiCopyWith(_RowUi value, $Res Function(_RowUi) _then) =
      __$RowUiCopyWithImpl;
  @override
  @useResult
  $Res call({
    String name,
    String type,
    String? action,
    List<String?>? chars,
    @JsonKey(name: 'default') String? defaultValue,
    @JsonKey(name: 'viewName') String? viewName,
    FlexChildStyle? style,
  });

  @override
  $FlexChildStyleCopyWith<$Res>? get style;
}

/// @nodoc
class __$RowUiCopyWithImpl<$Res> implements _$RowUiCopyWith<$Res> {
  __$RowUiCopyWithImpl(this._self, this._then);

  final _RowUi _self;
  final $Res Function(_RowUi) _then;

  /// Create a copy of RowUi
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? name = null,
    Object? type = null,
    Object? action = freezed,
    Object? chars = freezed,
    Object? defaultValue = freezed,
    Object? viewName = freezed,
    Object? style = freezed,
  }) {
    return _then(
      _RowUi(
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _self.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        action: freezed == action
            ? _self.action
            : action // ignore: cast_nullable_to_non_nullable
                  as String?,
        chars: freezed == chars
            ? _self._chars
            : chars // ignore: cast_nullable_to_non_nullable
                  as List<String?>?,
        defaultValue: freezed == defaultValue
            ? _self.defaultValue
            : defaultValue // ignore: cast_nullable_to_non_nullable
                  as String?,
        viewName: freezed == viewName
            ? _self.viewName
            : viewName // ignore: cast_nullable_to_non_nullable
                  as String?,
        style: freezed == style
            ? _self.style
            : style // ignore: cast_nullable_to_non_nullable
                  as FlexChildStyle?,
      ),
    );
  }

  /// Create a copy of RowUi
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlexChildStyleCopyWith<$Res>? get style {
    if (_self.style == null) {
      return null;
    }

    return $FlexChildStyleCopyWith<$Res>(_self.style!, (value) {
      return _then(_self.copyWith(style: value));
    });
  }
}
