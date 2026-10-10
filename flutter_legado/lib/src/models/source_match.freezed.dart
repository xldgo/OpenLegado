// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_match.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SourceMatch {
  /// 书源 URL
  @JsonKey(name: 'source_url')
  String get sourceUrl;

  /// 书源名称
  @JsonKey(name: 'source_name')
  String get sourceName;

  /// 书籍详情页 URL
  @JsonKey(name: 'book_url')
  String get bookUrl;

  /// 书籍名称
  @JsonKey(name: 'book_name')
  String get bookName;

  /// 作者
  String get author;

  /// 最新章节
  @JsonKey(name: 'latest_chapter')
  String? get latestChapter;

  /// 字数信息
  @JsonKey(name: 'word_count')
  String? get wordCount;

  /// 匹配度评分（0.0 ~ 100.0）
  double get score;

  /// 试读章节字数展示
  @JsonKey(name: 'chapter_word_count_text')
  String? get chapterWordCountText;

  /// 试读章节字数（-1=未知）
  @JsonKey(name: 'chapter_word_count')
  int get chapterWordCount;

  /// 取字耗时毫秒
  @JsonKey(name: 'respond_time')
  int get respondTime;

  /// 书源 customOrder
  @JsonKey(name: 'origin_order')
  int get originOrder;

  /// 用户评分（-1 踩 / 0 无 / 1 赞，对标原版 SourceConfig 书维度评分）
  @JsonKey(name: 'book_score')
  int get bookScore;

  /// Create a copy of SourceMatch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SourceMatchCopyWith<SourceMatch> get copyWith =>
      _$SourceMatchCopyWithImpl<SourceMatch>(this as SourceMatch, _$identity);

  /// Serializes this SourceMatch to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as SourceMatch;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SourceMatch &&
            (identical(other.sourceUrl, _this.sourceUrl) ||
                other.sourceUrl == _this.sourceUrl) &&
            (identical(other.sourceName, _this.sourceName) ||
                other.sourceName == _this.sourceName) &&
            (identical(other.bookUrl, _this.bookUrl) ||
                other.bookUrl == _this.bookUrl) &&
            (identical(other.bookName, _this.bookName) ||
                other.bookName == _this.bookName) &&
            (identical(other.author, _this.author) ||
                other.author == _this.author) &&
            (identical(other.latestChapter, _this.latestChapter) ||
                other.latestChapter == _this.latestChapter) &&
            (identical(other.wordCount, _this.wordCount) ||
                other.wordCount == _this.wordCount) &&
            (identical(other.score, _this.score) ||
                other.score == _this.score) &&
            (identical(
                  other.chapterWordCountText,
                  _this.chapterWordCountText,
                ) ||
                other.chapterWordCountText == _this.chapterWordCountText) &&
            (identical(other.chapterWordCount, _this.chapterWordCount) ||
                other.chapterWordCount == _this.chapterWordCount) &&
            (identical(other.respondTime, _this.respondTime) ||
                other.respondTime == _this.respondTime) &&
            (identical(other.originOrder, _this.originOrder) ||
                other.originOrder == _this.originOrder) &&
            (identical(other.bookScore, _this.bookScore) ||
                other.bookScore == _this.bookScore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as SourceMatch;
    return Object.hash(
      runtimeType,
      _this.sourceUrl,
      _this.sourceName,
      _this.bookUrl,
      _this.bookName,
      _this.author,
      _this.latestChapter,
      _this.wordCount,
      _this.score,
      _this.chapterWordCountText,
      _this.chapterWordCount,
      _this.respondTime,
      _this.originOrder,
      _this.bookScore,
    );
  }

  @override
  String toString() {
    final _this = this as SourceMatch;
    return 'SourceMatch(sourceUrl: ${_this.sourceUrl}, sourceName: ${_this.sourceName}, bookUrl: ${_this.bookUrl}, bookName: ${_this.bookName}, author: ${_this.author}, latestChapter: ${_this.latestChapter}, wordCount: ${_this.wordCount}, score: ${_this.score}, chapterWordCountText: ${_this.chapterWordCountText}, chapterWordCount: ${_this.chapterWordCount}, respondTime: ${_this.respondTime}, originOrder: ${_this.originOrder}, bookScore: ${_this.bookScore})';
  }
}

/// @nodoc
abstract mixin class $SourceMatchCopyWith<$Res> {
  factory $SourceMatchCopyWith(
    SourceMatch value,
    $Res Function(SourceMatch) _then,
  ) = _$SourceMatchCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'source_url') String sourceUrl,
    @JsonKey(name: 'source_name') String sourceName,
    @JsonKey(name: 'book_url') String bookUrl,
    @JsonKey(name: 'book_name') String bookName,
    String author,
    @JsonKey(name: 'latest_chapter') String? latestChapter,
    @JsonKey(name: 'word_count') String? wordCount,
    double score,
    @JsonKey(name: 'chapter_word_count_text') String? chapterWordCountText,
    @JsonKey(name: 'chapter_word_count') int chapterWordCount,
    @JsonKey(name: 'respond_time') int respondTime,
    @JsonKey(name: 'origin_order') int originOrder,
    @JsonKey(name: 'book_score') int bookScore,
  });
}

/// @nodoc
class _$SourceMatchCopyWithImpl<$Res> implements $SourceMatchCopyWith<$Res> {
  _$SourceMatchCopyWithImpl(this._self, this._then);

  final SourceMatch _self;
  final $Res Function(SourceMatch) _then;

  /// Create a copy of SourceMatch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sourceUrl = null,
    Object? sourceName = null,
    Object? bookUrl = null,
    Object? bookName = null,
    Object? author = null,
    Object? latestChapter = freezed,
    Object? wordCount = freezed,
    Object? score = null,
    Object? chapterWordCountText = freezed,
    Object? chapterWordCount = null,
    Object? respondTime = null,
    Object? originOrder = null,
    Object? bookScore = null,
  }) {
    return _then(
      SourceMatch(
        sourceUrl: null == sourceUrl
            ? _self.sourceUrl
            : sourceUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceName: null == sourceName
            ? _self.sourceName
            : sourceName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        bookName: null == bookName
            ? _self.bookName
            : bookName // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        latestChapter: freezed == latestChapter
            ? _self.latestChapter
            : latestChapter // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        score: null == score
            ? _self.score
            : score // ignore: cast_nullable_to_non_nullable
                  as double,
        chapterWordCountText: freezed == chapterWordCountText
            ? _self.chapterWordCountText
            : chapterWordCountText // ignore: cast_nullable_to_non_nullable
                  as String?,
        chapterWordCount: null == chapterWordCount
            ? _self.chapterWordCount
            : chapterWordCount // ignore: cast_nullable_to_non_nullable
                  as int,
        respondTime: null == respondTime
            ? _self.respondTime
            : respondTime // ignore: cast_nullable_to_non_nullable
                  as int,
        originOrder: null == originOrder
            ? _self.originOrder
            : originOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        bookScore: null == bookScore
            ? _self.bookScore
            : bookScore // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [SourceMatch].
extension SourceMatchPatterns on SourceMatch {
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
    TResult Function(_SourceMatch value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SourceMatch() when $default != null:
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
    TResult Function(_SourceMatch value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceMatch():
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
    TResult? Function(_SourceMatch value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceMatch() when $default != null:
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
      @JsonKey(name: 'source_url') String sourceUrl,
      @JsonKey(name: 'source_name') String sourceName,
      @JsonKey(name: 'book_url') String bookUrl,
      @JsonKey(name: 'book_name') String bookName,
      String author,
      @JsonKey(name: 'latest_chapter') String? latestChapter,
      @JsonKey(name: 'word_count') String? wordCount,
      double score,
      @JsonKey(name: 'chapter_word_count_text') String? chapterWordCountText,
      @JsonKey(name: 'chapter_word_count') int chapterWordCount,
      @JsonKey(name: 'respond_time') int respondTime,
      @JsonKey(name: 'origin_order') int originOrder,
      @JsonKey(name: 'book_score') int bookScore,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SourceMatch() when $default != null:
        return $default(
          _that.sourceUrl,
          _that.sourceName,
          _that.bookUrl,
          _that.bookName,
          _that.author,
          _that.latestChapter,
          _that.wordCount,
          _that.score,
          _that.chapterWordCountText,
          _that.chapterWordCount,
          _that.respondTime,
          _that.originOrder,
          _that.bookScore,
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
      @JsonKey(name: 'source_url') String sourceUrl,
      @JsonKey(name: 'source_name') String sourceName,
      @JsonKey(name: 'book_url') String bookUrl,
      @JsonKey(name: 'book_name') String bookName,
      String author,
      @JsonKey(name: 'latest_chapter') String? latestChapter,
      @JsonKey(name: 'word_count') String? wordCount,
      double score,
      @JsonKey(name: 'chapter_word_count_text') String? chapterWordCountText,
      @JsonKey(name: 'chapter_word_count') int chapterWordCount,
      @JsonKey(name: 'respond_time') int respondTime,
      @JsonKey(name: 'origin_order') int originOrder,
      @JsonKey(name: 'book_score') int bookScore,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceMatch():
        return $default(
          _that.sourceUrl,
          _that.sourceName,
          _that.bookUrl,
          _that.bookName,
          _that.author,
          _that.latestChapter,
          _that.wordCount,
          _that.score,
          _that.chapterWordCountText,
          _that.chapterWordCount,
          _that.respondTime,
          _that.originOrder,
          _that.bookScore,
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
      @JsonKey(name: 'source_url') String sourceUrl,
      @JsonKey(name: 'source_name') String sourceName,
      @JsonKey(name: 'book_url') String bookUrl,
      @JsonKey(name: 'book_name') String bookName,
      String author,
      @JsonKey(name: 'latest_chapter') String? latestChapter,
      @JsonKey(name: 'word_count') String? wordCount,
      double score,
      @JsonKey(name: 'chapter_word_count_text') String? chapterWordCountText,
      @JsonKey(name: 'chapter_word_count') int chapterWordCount,
      @JsonKey(name: 'respond_time') int respondTime,
      @JsonKey(name: 'origin_order') int originOrder,
      @JsonKey(name: 'book_score') int bookScore,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceMatch() when $default != null:
        return $default(
          _that.sourceUrl,
          _that.sourceName,
          _that.bookUrl,
          _that.bookName,
          _that.author,
          _that.latestChapter,
          _that.wordCount,
          _that.score,
          _that.chapterWordCountText,
          _that.chapterWordCount,
          _that.respondTime,
          _that.originOrder,
          _that.bookScore,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SourceMatch implements SourceMatch {
  const _SourceMatch({
    @JsonKey(name: 'source_url') this.sourceUrl = '',
    @JsonKey(name: 'source_name') this.sourceName = '',
    @JsonKey(name: 'book_url') this.bookUrl = '',
    @JsonKey(name: 'book_name') this.bookName = '',
    this.author = '',
    @JsonKey(name: 'latest_chapter') this.latestChapter,
    @JsonKey(name: 'word_count') this.wordCount,
    this.score = 0.0,
    @JsonKey(name: 'chapter_word_count_text') this.chapterWordCountText,
    @JsonKey(name: 'chapter_word_count') this.chapterWordCount = -1,
    @JsonKey(name: 'respond_time') this.respondTime = -1,
    @JsonKey(name: 'origin_order') this.originOrder = 0,
    @JsonKey(name: 'book_score') this.bookScore = 0,
  });
  factory _SourceMatch.fromJson(Map<String, dynamic> json) =>
      _$SourceMatchFromJson(json);

  /// 书源 URL
  @override
  @JsonKey(name: 'source_url')
  final String sourceUrl;

  /// 书源名称
  @override
  @JsonKey(name: 'source_name')
  final String sourceName;

  /// 书籍详情页 URL
  @override
  @JsonKey(name: 'book_url')
  final String bookUrl;

  /// 书籍名称
  @override
  @JsonKey(name: 'book_name')
  final String bookName;

  /// 作者
  @override
  @JsonKey()
  final String author;

  /// 最新章节
  @override
  @JsonKey(name: 'latest_chapter')
  final String? latestChapter;

  /// 字数信息
  @override
  @JsonKey(name: 'word_count')
  final String? wordCount;

  /// 匹配度评分（0.0 ~ 100.0）
  @override
  @JsonKey()
  final double score;

  /// 试读章节字数展示
  @override
  @JsonKey(name: 'chapter_word_count_text')
  final String? chapterWordCountText;

  /// 试读章节字数（-1=未知）
  @override
  @JsonKey(name: 'chapter_word_count')
  final int chapterWordCount;

  /// 取字耗时毫秒
  @override
  @JsonKey(name: 'respond_time')
  final int respondTime;

  /// 书源 customOrder
  @override
  @JsonKey(name: 'origin_order')
  final int originOrder;

  /// 用户评分（-1 踩 / 0 无 / 1 赞，对标原版 SourceConfig 书维度评分）
  @override
  @JsonKey(name: 'book_score')
  final int bookScore;

  /// Create a copy of SourceMatch
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SourceMatchCopyWith<_SourceMatch> get copyWith =>
      __$SourceMatchCopyWithImpl<_SourceMatch>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SourceMatchToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SourceMatch &&
            (identical(other.sourceUrl, sourceUrl) ||
                other.sourceUrl == sourceUrl) &&
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl) &&
            (identical(other.bookName, bookName) ||
                other.bookName == bookName) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.latestChapter, latestChapter) ||
                other.latestChapter == latestChapter) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.score, score) || other.score == score) &&
            (identical(other.chapterWordCountText, chapterWordCountText) ||
                other.chapterWordCountText == chapterWordCountText) &&
            (identical(other.chapterWordCount, chapterWordCount) ||
                other.chapterWordCount == chapterWordCount) &&
            (identical(other.respondTime, respondTime) ||
                other.respondTime == respondTime) &&
            (identical(other.originOrder, originOrder) ||
                other.originOrder == originOrder) &&
            (identical(other.bookScore, bookScore) ||
                other.bookScore == bookScore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      sourceUrl,
      sourceName,
      bookUrl,
      bookName,
      author,
      latestChapter,
      wordCount,
      score,
      chapterWordCountText,
      chapterWordCount,
      respondTime,
      originOrder,
      bookScore,
    );
  }

  @override
  String toString() {
    return 'SourceMatch(sourceUrl: $sourceUrl, sourceName: $sourceName, bookUrl: $bookUrl, bookName: $bookName, author: $author, latestChapter: $latestChapter, wordCount: $wordCount, score: $score, chapterWordCountText: $chapterWordCountText, chapterWordCount: $chapterWordCount, respondTime: $respondTime, originOrder: $originOrder, bookScore: $bookScore)';
  }
}

/// @nodoc
abstract mixin class _$SourceMatchCopyWith<$Res>
    implements $SourceMatchCopyWith<$Res> {
  factory _$SourceMatchCopyWith(
    _SourceMatch value,
    $Res Function(_SourceMatch) _then,
  ) = __$SourceMatchCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'source_url') String sourceUrl,
    @JsonKey(name: 'source_name') String sourceName,
    @JsonKey(name: 'book_url') String bookUrl,
    @JsonKey(name: 'book_name') String bookName,
    String author,
    @JsonKey(name: 'latest_chapter') String? latestChapter,
    @JsonKey(name: 'word_count') String? wordCount,
    double score,
    @JsonKey(name: 'chapter_word_count_text') String? chapterWordCountText,
    @JsonKey(name: 'chapter_word_count') int chapterWordCount,
    @JsonKey(name: 'respond_time') int respondTime,
    @JsonKey(name: 'origin_order') int originOrder,
    @JsonKey(name: 'book_score') int bookScore,
  });
}

/// @nodoc
class __$SourceMatchCopyWithImpl<$Res> implements _$SourceMatchCopyWith<$Res> {
  __$SourceMatchCopyWithImpl(this._self, this._then);

  final _SourceMatch _self;
  final $Res Function(_SourceMatch) _then;

  /// Create a copy of SourceMatch
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sourceUrl = null,
    Object? sourceName = null,
    Object? bookUrl = null,
    Object? bookName = null,
    Object? author = null,
    Object? latestChapter = freezed,
    Object? wordCount = freezed,
    Object? score = null,
    Object? chapterWordCountText = freezed,
    Object? chapterWordCount = null,
    Object? respondTime = null,
    Object? originOrder = null,
    Object? bookScore = null,
  }) {
    return _then(
      _SourceMatch(
        sourceUrl: null == sourceUrl
            ? _self.sourceUrl
            : sourceUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceName: null == sourceName
            ? _self.sourceName
            : sourceName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        bookName: null == bookName
            ? _self.bookName
            : bookName // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        latestChapter: freezed == latestChapter
            ? _self.latestChapter
            : latestChapter // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        score: null == score
            ? _self.score
            : score // ignore: cast_nullable_to_non_nullable
                  as double,
        chapterWordCountText: freezed == chapterWordCountText
            ? _self.chapterWordCountText
            : chapterWordCountText // ignore: cast_nullable_to_non_nullable
                  as String?,
        chapterWordCount: null == chapterWordCount
            ? _self.chapterWordCount
            : chapterWordCount // ignore: cast_nullable_to_non_nullable
                  as int,
        respondTime: null == respondTime
            ? _self.respondTime
            : respondTime // ignore: cast_nullable_to_non_nullable
                  as int,
        originOrder: null == originOrder
            ? _self.originOrder
            : originOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        bookScore: null == bookScore
            ? _self.bookScore
            : bookScore // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}
