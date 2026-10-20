// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'misc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SearchBook {
  @JsonKey(name: 'bookUrl')
  String get bookUrl;
  String get origin;
  @JsonKey(name: 'originName')
  String get originName;
  @JsonKey(name: 'type')
  int get bookType;
  String get name;
  String get author;
  String? get kind;
  @JsonKey(name: 'coverUrl')
  String? get coverUrl;
  String? get intro;
  @JsonKey(name: 'wordCount')
  String? get wordCount;
  @JsonKey(name: 'latestChapterTitle')
  String? get latestChapterTitle;
  @JsonKey(name: 'tocUrl')
  String get tocUrl;
  int get time;
  String? get variable;
  @JsonKey(name: 'originOrder')
  int get originOrder;
  @JsonKey(name: 'chapterWordCountText')
  String? get chapterWordCountText;
  @JsonKey(name: 'chapterWordCount')
  int get chapterWordCount;
  @JsonKey(name: 'respondTime')
  int get respondTime;

  /// 跨源聚合 origins 集合（队列⑩a P1-1 项2，2026-09-22 加法式字段）
  ///
  /// Rust 侧 `CoreSearchBook.origins`（serde default + 空时省略序列化）：
  /// 由跨源聚合入口产出（同名同作者跨源合并后累加的 origins，首次出现序）；
  /// 既有流式批次 / 解析路径不填充（缺省空数组）。`SearchResult.fromSearchBook`
  /// 消费：非空时优先作为有效 origins，空时回退 `{origin}` 现行行为
  /// （对齐 Rust 聚合模块 effectiveOrigins 规则，见 docs/API_CONTRACT.md）。
  @JsonKey(name: 'origins')
  List<String> get origins;

  /// Create a copy of SearchBook
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SearchBookCopyWith<SearchBook> get copyWith =>
      _$SearchBookCopyWithImpl<SearchBook>(this as SearchBook, _$identity);

  /// Serializes this SearchBook to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as SearchBook;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SearchBook &&
            (identical(other.bookUrl, _this.bookUrl) ||
                other.bookUrl == _this.bookUrl) &&
            (identical(other.origin, _this.origin) ||
                other.origin == _this.origin) &&
            (identical(other.originName, _this.originName) ||
                other.originName == _this.originName) &&
            (identical(other.bookType, _this.bookType) ||
                other.bookType == _this.bookType) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.author, _this.author) ||
                other.author == _this.author) &&
            (identical(other.kind, _this.kind) || other.kind == _this.kind) &&
            (identical(other.coverUrl, _this.coverUrl) ||
                other.coverUrl == _this.coverUrl) &&
            (identical(other.intro, _this.intro) ||
                other.intro == _this.intro) &&
            (identical(other.wordCount, _this.wordCount) ||
                other.wordCount == _this.wordCount) &&
            (identical(other.latestChapterTitle, _this.latestChapterTitle) ||
                other.latestChapterTitle == _this.latestChapterTitle) &&
            (identical(other.tocUrl, _this.tocUrl) ||
                other.tocUrl == _this.tocUrl) &&
            (identical(other.time, _this.time) || other.time == _this.time) &&
            (identical(other.variable, _this.variable) ||
                other.variable == _this.variable) &&
            (identical(other.originOrder, _this.originOrder) ||
                other.originOrder == _this.originOrder) &&
            (identical(
                  other.chapterWordCountText,
                  _this.chapterWordCountText,
                ) ||
                other.chapterWordCountText == _this.chapterWordCountText) &&
            (identical(other.chapterWordCount, _this.chapterWordCount) ||
                other.chapterWordCount == _this.chapterWordCount) &&
            (identical(other.respondTime, _this.respondTime) ||
                other.respondTime == _this.respondTime) &&
            const DeepCollectionEquality().equals(
              other.origins,
              _this.origins,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as SearchBook;
    return Object.hashAll([
      runtimeType,
      _this.bookUrl,
      _this.origin,
      _this.originName,
      _this.bookType,
      _this.name,
      _this.author,
      _this.kind,
      _this.coverUrl,
      _this.intro,
      _this.wordCount,
      _this.latestChapterTitle,
      _this.tocUrl,
      _this.time,
      _this.variable,
      _this.originOrder,
      _this.chapterWordCountText,
      _this.chapterWordCount,
      _this.respondTime,
      const DeepCollectionEquality().hash(_this.origins),
    ]);
  }

  @override
  String toString() {
    final _this = this as SearchBook;
    return 'SearchBook(bookUrl: ${_this.bookUrl}, origin: ${_this.origin}, originName: ${_this.originName}, bookType: ${_this.bookType}, name: ${_this.name}, author: ${_this.author}, kind: ${_this.kind}, coverUrl: ${_this.coverUrl}, intro: ${_this.intro}, wordCount: ${_this.wordCount}, latestChapterTitle: ${_this.latestChapterTitle}, tocUrl: ${_this.tocUrl}, time: ${_this.time}, variable: ${_this.variable}, originOrder: ${_this.originOrder}, chapterWordCountText: ${_this.chapterWordCountText}, chapterWordCount: ${_this.chapterWordCount}, respondTime: ${_this.respondTime}, origins: ${_this.origins})';
  }
}

/// @nodoc
abstract mixin class $SearchBookCopyWith<$Res> {
  factory $SearchBookCopyWith(
    SearchBook value,
    $Res Function(SearchBook) _then,
  ) = _$SearchBookCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'bookUrl') String bookUrl,
    String origin,
    @JsonKey(name: 'originName') String originName,
    @JsonKey(name: 'type') int bookType,
    String name,
    String author,
    String? kind,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    String? intro,
    @JsonKey(name: 'wordCount') String? wordCount,
    @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
    @JsonKey(name: 'tocUrl') String tocUrl,
    int time,
    String? variable,
    @JsonKey(name: 'originOrder') int originOrder,
    @JsonKey(name: 'chapterWordCountText') String? chapterWordCountText,
    @JsonKey(name: 'chapterWordCount') int chapterWordCount,
    @JsonKey(name: 'respondTime') int respondTime,
    @JsonKey(name: 'origins') List<String> origins,
  });
}

/// @nodoc
class _$SearchBookCopyWithImpl<$Res> implements $SearchBookCopyWith<$Res> {
  _$SearchBookCopyWithImpl(this._self, this._then);

  final SearchBook _self;
  final $Res Function(SearchBook) _then;

  /// Create a copy of SearchBook
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookUrl = null,
    Object? origin = null,
    Object? originName = null,
    Object? bookType = null,
    Object? name = null,
    Object? author = null,
    Object? kind = freezed,
    Object? coverUrl = freezed,
    Object? intro = freezed,
    Object? wordCount = freezed,
    Object? latestChapterTitle = freezed,
    Object? tocUrl = null,
    Object? time = null,
    Object? variable = freezed,
    Object? originOrder = null,
    Object? chapterWordCountText = freezed,
    Object? chapterWordCount = null,
    Object? respondTime = null,
    Object? origins = null,
  }) {
    return _then(
      SearchBook(
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        originName: null == originName
            ? _self.originName
            : originName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookType: null == bookType
            ? _self.bookType
            : bookType // ignore: cast_nullable_to_non_nullable
                  as int,
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
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        latestChapterTitle: freezed == latestChapterTitle
            ? _self.latestChapterTitle
            : latestChapterTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        tocUrl: null == tocUrl
            ? _self.tocUrl
            : tocUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        time: null == time
            ? _self.time
            : time // ignore: cast_nullable_to_non_nullable
                  as int,
        variable: freezed == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String?,
        originOrder: null == originOrder
            ? _self.originOrder
            : originOrder // ignore: cast_nullable_to_non_nullable
                  as int,
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
        origins: null == origins
            ? _self.origins
            : origins // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [SearchBook].
extension SearchBookPatterns on SearchBook {
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
    TResult Function(_SearchBook value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchBook() when $default != null:
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
    TResult Function(_SearchBook value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchBook():
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
    TResult? Function(_SearchBook value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchBook() when $default != null:
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
      String origin,
      @JsonKey(name: 'originName') String originName,
      @JsonKey(name: 'type') int bookType,
      String name,
      String author,
      String? kind,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      String? intro,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
      @JsonKey(name: 'tocUrl') String tocUrl,
      int time,
      String? variable,
      @JsonKey(name: 'originOrder') int originOrder,
      @JsonKey(name: 'chapterWordCountText') String? chapterWordCountText,
      @JsonKey(name: 'chapterWordCount') int chapterWordCount,
      @JsonKey(name: 'respondTime') int respondTime,
      @JsonKey(name: 'origins') List<String> origins,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchBook() when $default != null:
        return $default(
          _that.bookUrl,
          _that.origin,
          _that.originName,
          _that.bookType,
          _that.name,
          _that.author,
          _that.kind,
          _that.coverUrl,
          _that.intro,
          _that.wordCount,
          _that.latestChapterTitle,
          _that.tocUrl,
          _that.time,
          _that.variable,
          _that.originOrder,
          _that.chapterWordCountText,
          _that.chapterWordCount,
          _that.respondTime,
          _that.origins,
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
      String origin,
      @JsonKey(name: 'originName') String originName,
      @JsonKey(name: 'type') int bookType,
      String name,
      String author,
      String? kind,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      String? intro,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
      @JsonKey(name: 'tocUrl') String tocUrl,
      int time,
      String? variable,
      @JsonKey(name: 'originOrder') int originOrder,
      @JsonKey(name: 'chapterWordCountText') String? chapterWordCountText,
      @JsonKey(name: 'chapterWordCount') int chapterWordCount,
      @JsonKey(name: 'respondTime') int respondTime,
      @JsonKey(name: 'origins') List<String> origins,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchBook():
        return $default(
          _that.bookUrl,
          _that.origin,
          _that.originName,
          _that.bookType,
          _that.name,
          _that.author,
          _that.kind,
          _that.coverUrl,
          _that.intro,
          _that.wordCount,
          _that.latestChapterTitle,
          _that.tocUrl,
          _that.time,
          _that.variable,
          _that.originOrder,
          _that.chapterWordCountText,
          _that.chapterWordCount,
          _that.respondTime,
          _that.origins,
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
      String origin,
      @JsonKey(name: 'originName') String originName,
      @JsonKey(name: 'type') int bookType,
      String name,
      String author,
      String? kind,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      String? intro,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
      @JsonKey(name: 'tocUrl') String tocUrl,
      int time,
      String? variable,
      @JsonKey(name: 'originOrder') int originOrder,
      @JsonKey(name: 'chapterWordCountText') String? chapterWordCountText,
      @JsonKey(name: 'chapterWordCount') int chapterWordCount,
      @JsonKey(name: 'respondTime') int respondTime,
      @JsonKey(name: 'origins') List<String> origins,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchBook() when $default != null:
        return $default(
          _that.bookUrl,
          _that.origin,
          _that.originName,
          _that.bookType,
          _that.name,
          _that.author,
          _that.kind,
          _that.coverUrl,
          _that.intro,
          _that.wordCount,
          _that.latestChapterTitle,
          _that.tocUrl,
          _that.time,
          _that.variable,
          _that.originOrder,
          _that.chapterWordCountText,
          _that.chapterWordCount,
          _that.respondTime,
          _that.origins,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SearchBook implements SearchBook {
  const _SearchBook({
    @JsonKey(name: 'bookUrl') this.bookUrl = '',
    this.origin = '',
    @JsonKey(name: 'originName') this.originName = '',
    @JsonKey(name: 'type') this.bookType = 0,
    this.name = '',
    this.author = '',
    this.kind,
    @JsonKey(name: 'coverUrl') this.coverUrl,
    this.intro,
    @JsonKey(name: 'wordCount') this.wordCount,
    @JsonKey(name: 'latestChapterTitle') this.latestChapterTitle,
    @JsonKey(name: 'tocUrl') this.tocUrl = '',
    this.time = 0,
    this.variable,
    @JsonKey(name: 'originOrder') this.originOrder = 0,
    @JsonKey(name: 'chapterWordCountText') this.chapterWordCountText,
    @JsonKey(name: 'chapterWordCount') this.chapterWordCount = -1,
    @JsonKey(name: 'respondTime') this.respondTime = -1,
    @JsonKey(name: 'origins') List<String> origins = const [],
  }) : _origins = origins;
  factory _SearchBook.fromJson(Map<String, dynamic> json) =>
      _$SearchBookFromJson(json);

  @override
  @JsonKey(name: 'bookUrl')
  final String bookUrl;
  @override
  @JsonKey()
  final String origin;
  @override
  @JsonKey(name: 'originName')
  final String originName;
  @override
  @JsonKey(name: 'type')
  final int bookType;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String author;
  @override
  final String? kind;
  @override
  @JsonKey(name: 'coverUrl')
  final String? coverUrl;
  @override
  final String? intro;
  @override
  @JsonKey(name: 'wordCount')
  final String? wordCount;
  @override
  @JsonKey(name: 'latestChapterTitle')
  final String? latestChapterTitle;
  @override
  @JsonKey(name: 'tocUrl')
  final String tocUrl;
  @override
  @JsonKey()
  final int time;
  @override
  final String? variable;
  @override
  @JsonKey(name: 'originOrder')
  final int originOrder;
  @override
  @JsonKey(name: 'chapterWordCountText')
  final String? chapterWordCountText;
  @override
  @JsonKey(name: 'chapterWordCount')
  final int chapterWordCount;
  @override
  @JsonKey(name: 'respondTime')
  final int respondTime;

  /// 跨源聚合 origins 集合（队列⑩a P1-1 项2，2026-09-22 加法式字段）
  ///
  /// Rust 侧 `CoreSearchBook.origins`（serde default + 空时省略序列化）：
  /// 由跨源聚合入口产出（同名同作者跨源合并后累加的 origins，首次出现序）；
  /// 既有流式批次 / 解析路径不填充（缺省空数组）。`SearchResult.fromSearchBook`
  /// 消费：非空时优先作为有效 origins，空时回退 `{origin}` 现行行为
  /// （对齐 Rust 聚合模块 effectiveOrigins 规则，见 docs/API_CONTRACT.md）。
  final List<String> _origins;

  /// 跨源聚合 origins 集合（队列⑩a P1-1 项2，2026-09-22 加法式字段）
  ///
  /// Rust 侧 `CoreSearchBook.origins`（serde default + 空时省略序列化）：
  /// 由跨源聚合入口产出（同名同作者跨源合并后累加的 origins，首次出现序）；
  /// 既有流式批次 / 解析路径不填充（缺省空数组）。`SearchResult.fromSearchBook`
  /// 消费：非空时优先作为有效 origins，空时回退 `{origin}` 现行行为
  /// （对齐 Rust 聚合模块 effectiveOrigins 规则，见 docs/API_CONTRACT.md）。
  @override
  @JsonKey(name: 'origins')
  List<String> get origins {
    if (_origins is EqualUnmodifiableListView) return _origins;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_origins);
  }

  /// Create a copy of SearchBook
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SearchBookCopyWith<_SearchBook> get copyWith =>
      __$SearchBookCopyWithImpl<_SearchBook>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SearchBookToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SearchBook &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.originName, originName) ||
                other.originName == originName) &&
            (identical(other.bookType, bookType) ||
                other.bookType == bookType) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.intro, intro) || other.intro == intro) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.latestChapterTitle, latestChapterTitle) ||
                other.latestChapterTitle == latestChapterTitle) &&
            (identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.variable, variable) ||
                other.variable == variable) &&
            (identical(other.originOrder, originOrder) ||
                other.originOrder == originOrder) &&
            (identical(other.chapterWordCountText, chapterWordCountText) ||
                other.chapterWordCountText == chapterWordCountText) &&
            (identical(other.chapterWordCount, chapterWordCount) ||
                other.chapterWordCount == chapterWordCount) &&
            (identical(other.respondTime, respondTime) ||
                other.respondTime == respondTime) &&
            const DeepCollectionEquality().equals(other.origins, _origins));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hashAll([
      runtimeType,
      bookUrl,
      origin,
      originName,
      bookType,
      name,
      author,
      kind,
      coverUrl,
      intro,
      wordCount,
      latestChapterTitle,
      tocUrl,
      time,
      variable,
      originOrder,
      chapterWordCountText,
      chapterWordCount,
      respondTime,
      const DeepCollectionEquality().hash(_origins),
    ]);
  }

  @override
  String toString() {
    return 'SearchBook(bookUrl: $bookUrl, origin: $origin, originName: $originName, bookType: $bookType, name: $name, author: $author, kind: $kind, coverUrl: $coverUrl, intro: $intro, wordCount: $wordCount, latestChapterTitle: $latestChapterTitle, tocUrl: $tocUrl, time: $time, variable: $variable, originOrder: $originOrder, chapterWordCountText: $chapterWordCountText, chapterWordCount: $chapterWordCount, respondTime: $respondTime, origins: $origins)';
  }
}

/// @nodoc
abstract mixin class _$SearchBookCopyWith<$Res>
    implements $SearchBookCopyWith<$Res> {
  factory _$SearchBookCopyWith(
    _SearchBook value,
    $Res Function(_SearchBook) _then,
  ) = __$SearchBookCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'bookUrl') String bookUrl,
    String origin,
    @JsonKey(name: 'originName') String originName,
    @JsonKey(name: 'type') int bookType,
    String name,
    String author,
    String? kind,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    String? intro,
    @JsonKey(name: 'wordCount') String? wordCount,
    @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
    @JsonKey(name: 'tocUrl') String tocUrl,
    int time,
    String? variable,
    @JsonKey(name: 'originOrder') int originOrder,
    @JsonKey(name: 'chapterWordCountText') String? chapterWordCountText,
    @JsonKey(name: 'chapterWordCount') int chapterWordCount,
    @JsonKey(name: 'respondTime') int respondTime,
    @JsonKey(name: 'origins') List<String> origins,
  });
}

/// @nodoc
class __$SearchBookCopyWithImpl<$Res> implements _$SearchBookCopyWith<$Res> {
  __$SearchBookCopyWithImpl(this._self, this._then);

  final _SearchBook _self;
  final $Res Function(_SearchBook) _then;

  /// Create a copy of SearchBook
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookUrl = null,
    Object? origin = null,
    Object? originName = null,
    Object? bookType = null,
    Object? name = null,
    Object? author = null,
    Object? kind = freezed,
    Object? coverUrl = freezed,
    Object? intro = freezed,
    Object? wordCount = freezed,
    Object? latestChapterTitle = freezed,
    Object? tocUrl = null,
    Object? time = null,
    Object? variable = freezed,
    Object? originOrder = null,
    Object? chapterWordCountText = freezed,
    Object? chapterWordCount = null,
    Object? respondTime = null,
    Object? origins = null,
  }) {
    return _then(
      _SearchBook(
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        originName: null == originName
            ? _self.originName
            : originName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookType: null == bookType
            ? _self.bookType
            : bookType // ignore: cast_nullable_to_non_nullable
                  as int,
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
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        latestChapterTitle: freezed == latestChapterTitle
            ? _self.latestChapterTitle
            : latestChapterTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        tocUrl: null == tocUrl
            ? _self.tocUrl
            : tocUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        time: null == time
            ? _self.time
            : time // ignore: cast_nullable_to_non_nullable
                  as int,
        variable: freezed == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String?,
        originOrder: null == originOrder
            ? _self.originOrder
            : originOrder // ignore: cast_nullable_to_non_nullable
                  as int,
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
        origins: null == origins
            ? _self._origins
            : origins // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
mixin _$ReplaceRule {
  int get id;
  String get name;
  String? get group;
  String get pattern;
  String get replacement;
  String? get scope;
  @JsonKey(name: 'scopeTitle')
  bool get scopeTitle;
  @JsonKey(name: 'scopeContent')
  bool get scopeContent;

  /// 书源作用域开关（对齐原版 `ReplaceRule.scopeSource`，默认 false）：
  /// 书源导入时按源名/源 URL 匹配 scope 后对整源 JSON 应用替换
  @JsonKey(name: 'scopeSource')
  bool get scopeSource;
  @JsonKey(name: 'excludeScope')
  String? get excludeScope;
  @JsonKey(name: 'isEnabled')
  bool get isEnabled;
  @JsonKey(name: 'isRegex')
  bool get isRegex;
  @JsonKey(name: 'timeoutMillisecond')
  int get timeoutMillisecond;
  @JsonKey(name: 'sortOrder')
  int get order;

  /// Create a copy of ReplaceRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReplaceRuleCopyWith<ReplaceRule> get copyWith =>
      _$ReplaceRuleCopyWithImpl<ReplaceRule>(this as ReplaceRule, _$identity);

  /// Serializes this ReplaceRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as ReplaceRule;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReplaceRule &&
            (identical(other.id, _this.id) || other.id == _this.id) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.group, _this.group) ||
                other.group == _this.group) &&
            (identical(other.pattern, _this.pattern) ||
                other.pattern == _this.pattern) &&
            (identical(other.replacement, _this.replacement) ||
                other.replacement == _this.replacement) &&
            (identical(other.scope, _this.scope) ||
                other.scope == _this.scope) &&
            (identical(other.scopeTitle, _this.scopeTitle) ||
                other.scopeTitle == _this.scopeTitle) &&
            (identical(other.scopeContent, _this.scopeContent) ||
                other.scopeContent == _this.scopeContent) &&
            (identical(other.scopeSource, _this.scopeSource) ||
                other.scopeSource == _this.scopeSource) &&
            (identical(other.excludeScope, _this.excludeScope) ||
                other.excludeScope == _this.excludeScope) &&
            (identical(other.isEnabled, _this.isEnabled) ||
                other.isEnabled == _this.isEnabled) &&
            (identical(other.isRegex, _this.isRegex) ||
                other.isRegex == _this.isRegex) &&
            (identical(other.timeoutMillisecond, _this.timeoutMillisecond) ||
                other.timeoutMillisecond == _this.timeoutMillisecond) &&
            (identical(other.order, _this.order) ||
                other.order == _this.order));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as ReplaceRule;
    return Object.hash(
      runtimeType,
      _this.id,
      _this.name,
      _this.group,
      _this.pattern,
      _this.replacement,
      _this.scope,
      _this.scopeTitle,
      _this.scopeContent,
      _this.scopeSource,
      _this.excludeScope,
      _this.isEnabled,
      _this.isRegex,
      _this.timeoutMillisecond,
      _this.order,
    );
  }

  @override
  String toString() {
    final _this = this as ReplaceRule;
    return 'ReplaceRule(id: ${_this.id}, name: ${_this.name}, group: ${_this.group}, pattern: ${_this.pattern}, replacement: ${_this.replacement}, scope: ${_this.scope}, scopeTitle: ${_this.scopeTitle}, scopeContent: ${_this.scopeContent}, scopeSource: ${_this.scopeSource}, excludeScope: ${_this.excludeScope}, isEnabled: ${_this.isEnabled}, isRegex: ${_this.isRegex}, timeoutMillisecond: ${_this.timeoutMillisecond}, order: ${_this.order})';
  }
}

/// @nodoc
abstract mixin class $ReplaceRuleCopyWith<$Res> {
  factory $ReplaceRuleCopyWith(
    ReplaceRule value,
    $Res Function(ReplaceRule) _then,
  ) = _$ReplaceRuleCopyWithImpl;
  @useResult
  $Res call({
    int id,
    String name,
    String? group,
    String pattern,
    String replacement,
    String? scope,
    @JsonKey(name: 'scopeTitle') bool scopeTitle,
    @JsonKey(name: 'scopeContent') bool scopeContent,
    @JsonKey(name: 'scopeSource') bool scopeSource,
    @JsonKey(name: 'excludeScope') String? excludeScope,
    @JsonKey(name: 'isEnabled') bool isEnabled,
    @JsonKey(name: 'isRegex') bool isRegex,
    @JsonKey(name: 'timeoutMillisecond') int timeoutMillisecond,
    @JsonKey(name: 'sortOrder') int order,
  });
}

/// @nodoc
class _$ReplaceRuleCopyWithImpl<$Res> implements $ReplaceRuleCopyWith<$Res> {
  _$ReplaceRuleCopyWithImpl(this._self, this._then);

  final ReplaceRule _self;
  final $Res Function(ReplaceRule) _then;

  /// Create a copy of ReplaceRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? group = freezed,
    Object? pattern = null,
    Object? replacement = null,
    Object? scope = freezed,
    Object? scopeTitle = null,
    Object? scopeContent = null,
    Object? scopeSource = null,
    Object? excludeScope = freezed,
    Object? isEnabled = null,
    Object? isRegex = null,
    Object? timeoutMillisecond = null,
    Object? order = null,
  }) {
    return _then(
      ReplaceRule(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        group: freezed == group
            ? _self.group
            : group // ignore: cast_nullable_to_non_nullable
                  as String?,
        pattern: null == pattern
            ? _self.pattern
            : pattern // ignore: cast_nullable_to_non_nullable
                  as String,
        replacement: null == replacement
            ? _self.replacement
            : replacement // ignore: cast_nullable_to_non_nullable
                  as String,
        scope: freezed == scope
            ? _self.scope
            : scope // ignore: cast_nullable_to_non_nullable
                  as String?,
        scopeTitle: null == scopeTitle
            ? _self.scopeTitle
            : scopeTitle // ignore: cast_nullable_to_non_nullable
                  as bool,
        scopeContent: null == scopeContent
            ? _self.scopeContent
            : scopeContent // ignore: cast_nullable_to_non_nullable
                  as bool,
        scopeSource: null == scopeSource
            ? _self.scopeSource
            : scopeSource // ignore: cast_nullable_to_non_nullable
                  as bool,
        excludeScope: freezed == excludeScope
            ? _self.excludeScope
            : excludeScope // ignore: cast_nullable_to_non_nullable
                  as String?,
        isEnabled: null == isEnabled
            ? _self.isEnabled
            : isEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        isRegex: null == isRegex
            ? _self.isRegex
            : isRegex // ignore: cast_nullable_to_non_nullable
                  as bool,
        timeoutMillisecond: null == timeoutMillisecond
            ? _self.timeoutMillisecond
            : timeoutMillisecond // ignore: cast_nullable_to_non_nullable
                  as int,
        order: null == order
            ? _self.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ReplaceRule].
extension ReplaceRulePatterns on ReplaceRule {
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
    TResult Function(_ReplaceRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReplaceRule() when $default != null:
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
    TResult Function(_ReplaceRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceRule():
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
    TResult? Function(_ReplaceRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceRule() when $default != null:
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
      int id,
      String name,
      String? group,
      String pattern,
      String replacement,
      String? scope,
      @JsonKey(name: 'scopeTitle') bool scopeTitle,
      @JsonKey(name: 'scopeContent') bool scopeContent,
      @JsonKey(name: 'scopeSource') bool scopeSource,
      @JsonKey(name: 'excludeScope') String? excludeScope,
      @JsonKey(name: 'isEnabled') bool isEnabled,
      @JsonKey(name: 'isRegex') bool isRegex,
      @JsonKey(name: 'timeoutMillisecond') int timeoutMillisecond,
      @JsonKey(name: 'sortOrder') int order,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReplaceRule() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.group,
          _that.pattern,
          _that.replacement,
          _that.scope,
          _that.scopeTitle,
          _that.scopeContent,
          _that.scopeSource,
          _that.excludeScope,
          _that.isEnabled,
          _that.isRegex,
          _that.timeoutMillisecond,
          _that.order,
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
      int id,
      String name,
      String? group,
      String pattern,
      String replacement,
      String? scope,
      @JsonKey(name: 'scopeTitle') bool scopeTitle,
      @JsonKey(name: 'scopeContent') bool scopeContent,
      @JsonKey(name: 'scopeSource') bool scopeSource,
      @JsonKey(name: 'excludeScope') String? excludeScope,
      @JsonKey(name: 'isEnabled') bool isEnabled,
      @JsonKey(name: 'isRegex') bool isRegex,
      @JsonKey(name: 'timeoutMillisecond') int timeoutMillisecond,
      @JsonKey(name: 'sortOrder') int order,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceRule():
        return $default(
          _that.id,
          _that.name,
          _that.group,
          _that.pattern,
          _that.replacement,
          _that.scope,
          _that.scopeTitle,
          _that.scopeContent,
          _that.scopeSource,
          _that.excludeScope,
          _that.isEnabled,
          _that.isRegex,
          _that.timeoutMillisecond,
          _that.order,
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
      int id,
      String name,
      String? group,
      String pattern,
      String replacement,
      String? scope,
      @JsonKey(name: 'scopeTitle') bool scopeTitle,
      @JsonKey(name: 'scopeContent') bool scopeContent,
      @JsonKey(name: 'scopeSource') bool scopeSource,
      @JsonKey(name: 'excludeScope') String? excludeScope,
      @JsonKey(name: 'isEnabled') bool isEnabled,
      @JsonKey(name: 'isRegex') bool isRegex,
      @JsonKey(name: 'timeoutMillisecond') int timeoutMillisecond,
      @JsonKey(name: 'sortOrder') int order,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceRule() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.group,
          _that.pattern,
          _that.replacement,
          _that.scope,
          _that.scopeTitle,
          _that.scopeContent,
          _that.scopeSource,
          _that.excludeScope,
          _that.isEnabled,
          _that.isRegex,
          _that.timeoutMillisecond,
          _that.order,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ReplaceRule implements ReplaceRule {
  const _ReplaceRule({
    this.id = 0,
    this.name = '',
    this.group,
    this.pattern = '',
    this.replacement = '',
    this.scope,
    @JsonKey(name: 'scopeTitle') this.scopeTitle = false,
    @JsonKey(name: 'scopeContent') this.scopeContent = true,
    @JsonKey(name: 'scopeSource') this.scopeSource = false,
    @JsonKey(name: 'excludeScope') this.excludeScope,
    @JsonKey(name: 'isEnabled') this.isEnabled = true,
    @JsonKey(name: 'isRegex') this.isRegex = true,
    @JsonKey(name: 'timeoutMillisecond') this.timeoutMillisecond = 3000,
    @JsonKey(name: 'sortOrder') this.order = 0,
  });
  factory _ReplaceRule.fromJson(Map<String, dynamic> json) =>
      _$ReplaceRuleFromJson(json);

  @override
  @JsonKey()
  final int id;
  @override
  @JsonKey()
  final String name;
  @override
  final String? group;
  @override
  @JsonKey()
  final String pattern;
  @override
  @JsonKey()
  final String replacement;
  @override
  final String? scope;
  @override
  @JsonKey(name: 'scopeTitle')
  final bool scopeTitle;
  @override
  @JsonKey(name: 'scopeContent')
  final bool scopeContent;

  /// 书源作用域开关（对齐原版 `ReplaceRule.scopeSource`，默认 false）：
  /// 书源导入时按源名/源 URL 匹配 scope 后对整源 JSON 应用替换
  @override
  @JsonKey(name: 'scopeSource')
  final bool scopeSource;
  @override
  @JsonKey(name: 'excludeScope')
  final String? excludeScope;
  @override
  @JsonKey(name: 'isEnabled')
  final bool isEnabled;
  @override
  @JsonKey(name: 'isRegex')
  final bool isRegex;
  @override
  @JsonKey(name: 'timeoutMillisecond')
  final int timeoutMillisecond;
  @override
  @JsonKey(name: 'sortOrder')
  final int order;

  /// Create a copy of ReplaceRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReplaceRuleCopyWith<_ReplaceRule> get copyWith =>
      __$ReplaceRuleCopyWithImpl<_ReplaceRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ReplaceRuleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReplaceRule &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.group, group) || other.group == group) &&
            (identical(other.pattern, pattern) || other.pattern == pattern) &&
            (identical(other.replacement, replacement) ||
                other.replacement == replacement) &&
            (identical(other.scope, scope) || other.scope == scope) &&
            (identical(other.scopeTitle, scopeTitle) ||
                other.scopeTitle == scopeTitle) &&
            (identical(other.scopeContent, scopeContent) ||
                other.scopeContent == scopeContent) &&
            (identical(other.scopeSource, scopeSource) ||
                other.scopeSource == scopeSource) &&
            (identical(other.excludeScope, excludeScope) ||
                other.excludeScope == excludeScope) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled) &&
            (identical(other.isRegex, isRegex) || other.isRegex == isRegex) &&
            (identical(other.timeoutMillisecond, timeoutMillisecond) ||
                other.timeoutMillisecond == timeoutMillisecond) &&
            (identical(other.order, order) || other.order == order));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      id,
      name,
      group,
      pattern,
      replacement,
      scope,
      scopeTitle,
      scopeContent,
      scopeSource,
      excludeScope,
      isEnabled,
      isRegex,
      timeoutMillisecond,
      order,
    );
  }

  @override
  String toString() {
    return 'ReplaceRule(id: $id, name: $name, group: $group, pattern: $pattern, replacement: $replacement, scope: $scope, scopeTitle: $scopeTitle, scopeContent: $scopeContent, scopeSource: $scopeSource, excludeScope: $excludeScope, isEnabled: $isEnabled, isRegex: $isRegex, timeoutMillisecond: $timeoutMillisecond, order: $order)';
  }
}

/// @nodoc
abstract mixin class _$ReplaceRuleCopyWith<$Res>
    implements $ReplaceRuleCopyWith<$Res> {
  factory _$ReplaceRuleCopyWith(
    _ReplaceRule value,
    $Res Function(_ReplaceRule) _then,
  ) = __$ReplaceRuleCopyWithImpl;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    String? group,
    String pattern,
    String replacement,
    String? scope,
    @JsonKey(name: 'scopeTitle') bool scopeTitle,
    @JsonKey(name: 'scopeContent') bool scopeContent,
    @JsonKey(name: 'scopeSource') bool scopeSource,
    @JsonKey(name: 'excludeScope') String? excludeScope,
    @JsonKey(name: 'isEnabled') bool isEnabled,
    @JsonKey(name: 'isRegex') bool isRegex,
    @JsonKey(name: 'timeoutMillisecond') int timeoutMillisecond,
    @JsonKey(name: 'sortOrder') int order,
  });
}

/// @nodoc
class __$ReplaceRuleCopyWithImpl<$Res> implements _$ReplaceRuleCopyWith<$Res> {
  __$ReplaceRuleCopyWithImpl(this._self, this._then);

  final _ReplaceRule _self;
  final $Res Function(_ReplaceRule) _then;

  /// Create a copy of ReplaceRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? group = freezed,
    Object? pattern = null,
    Object? replacement = null,
    Object? scope = freezed,
    Object? scopeTitle = null,
    Object? scopeContent = null,
    Object? scopeSource = null,
    Object? excludeScope = freezed,
    Object? isEnabled = null,
    Object? isRegex = null,
    Object? timeoutMillisecond = null,
    Object? order = null,
  }) {
    return _then(
      _ReplaceRule(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        group: freezed == group
            ? _self.group
            : group // ignore: cast_nullable_to_non_nullable
                  as String?,
        pattern: null == pattern
            ? _self.pattern
            : pattern // ignore: cast_nullable_to_non_nullable
                  as String,
        replacement: null == replacement
            ? _self.replacement
            : replacement // ignore: cast_nullable_to_non_nullable
                  as String,
        scope: freezed == scope
            ? _self.scope
            : scope // ignore: cast_nullable_to_non_nullable
                  as String?,
        scopeTitle: null == scopeTitle
            ? _self.scopeTitle
            : scopeTitle // ignore: cast_nullable_to_non_nullable
                  as bool,
        scopeContent: null == scopeContent
            ? _self.scopeContent
            : scopeContent // ignore: cast_nullable_to_non_nullable
                  as bool,
        scopeSource: null == scopeSource
            ? _self.scopeSource
            : scopeSource // ignore: cast_nullable_to_non_nullable
                  as bool,
        excludeScope: freezed == excludeScope
            ? _self.excludeScope
            : excludeScope // ignore: cast_nullable_to_non_nullable
                  as String?,
        isEnabled: null == isEnabled
            ? _self.isEnabled
            : isEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        isRegex: null == isRegex
            ? _self.isRegex
            : isRegex // ignore: cast_nullable_to_non_nullable
                  as bool,
        timeoutMillisecond: null == timeoutMillisecond
            ? _self.timeoutMillisecond
            : timeoutMillisecond // ignore: cast_nullable_to_non_nullable
                  as int,
        order: null == order
            ? _self.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$HttpTts {
  int get id;
  String get name;
  String get url;
  @JsonKey(name: 'contentType')
  String? get contentType;
  @JsonKey(name: 'pauseDuration')
  int get pauseDuration;
  @JsonKey(name: 'concurrentRate')
  String? get concurrentRate;
  @JsonKey(name: 'loginUrl')
  String? get loginUrl;
  @JsonKey(name: 'loginUi', fromJson: _httpTtsLoginUiFromJson)
  String? get loginUi;
  String? get header;
  @JsonKey(name: 'jsLib')
  String? get jsLib;
  @JsonKey(name: 'enabledCookieJar', fromJson: _httpTtsNullableBoolFromJson)
  bool? get enabledCookieJar;
  @JsonKey(name: 'loginCheckJs')
  String? get loginCheckJs;
  @JsonKey(name: 'speed')
  int? get speed;
  @JsonKey(
    name: 'synthesisThreadCount',
    fromJson: _httpTtsSynthesisThreadCountFromJson,
  )
  int get synthesisThreadCount;
  @JsonKey(name: 'lastUpdateTime')
  int get lastUpdateTime;
  @JsonKey(name: 'isEnabled', fromJson: _httpTtsEnabledFromJson)
  bool get isEnabled;

  /// Create a copy of HttpTts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HttpTtsCopyWith<HttpTts> get copyWith =>
      _$HttpTtsCopyWithImpl<HttpTts>(this as HttpTts, _$identity);

  /// Serializes this HttpTts to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as HttpTts;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HttpTts &&
            (identical(other.id, _this.id) || other.id == _this.id) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.url, _this.url) || other.url == _this.url) &&
            (identical(other.contentType, _this.contentType) ||
                other.contentType == _this.contentType) &&
            (identical(other.pauseDuration, _this.pauseDuration) ||
                other.pauseDuration == _this.pauseDuration) &&
            (identical(other.concurrentRate, _this.concurrentRate) ||
                other.concurrentRate == _this.concurrentRate) &&
            (identical(other.loginUrl, _this.loginUrl) ||
                other.loginUrl == _this.loginUrl) &&
            (identical(other.loginUi, _this.loginUi) ||
                other.loginUi == _this.loginUi) &&
            (identical(other.header, _this.header) ||
                other.header == _this.header) &&
            (identical(other.jsLib, _this.jsLib) ||
                other.jsLib == _this.jsLib) &&
            (identical(other.enabledCookieJar, _this.enabledCookieJar) ||
                other.enabledCookieJar == _this.enabledCookieJar) &&
            (identical(other.loginCheckJs, _this.loginCheckJs) ||
                other.loginCheckJs == _this.loginCheckJs) &&
            (identical(other.speed, _this.speed) ||
                other.speed == _this.speed) &&
            (identical(
                  other.synthesisThreadCount,
                  _this.synthesisThreadCount,
                ) ||
                other.synthesisThreadCount == _this.synthesisThreadCount) &&
            (identical(other.lastUpdateTime, _this.lastUpdateTime) ||
                other.lastUpdateTime == _this.lastUpdateTime) &&
            (identical(other.isEnabled, _this.isEnabled) ||
                other.isEnabled == _this.isEnabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as HttpTts;
    return Object.hash(
      runtimeType,
      _this.id,
      _this.name,
      _this.url,
      _this.contentType,
      _this.pauseDuration,
      _this.concurrentRate,
      _this.loginUrl,
      _this.loginUi,
      _this.header,
      _this.jsLib,
      _this.enabledCookieJar,
      _this.loginCheckJs,
      _this.speed,
      _this.synthesisThreadCount,
      _this.lastUpdateTime,
      _this.isEnabled,
    );
  }

  @override
  String toString() {
    final _this = this as HttpTts;
    return 'HttpTts(id: ${_this.id}, name: ${_this.name}, url: ${_this.url}, contentType: ${_this.contentType}, pauseDuration: ${_this.pauseDuration}, concurrentRate: ${_this.concurrentRate}, loginUrl: ${_this.loginUrl}, loginUi: ${_this.loginUi}, header: ${_this.header}, jsLib: ${_this.jsLib}, enabledCookieJar: ${_this.enabledCookieJar}, loginCheckJs: ${_this.loginCheckJs}, speed: ${_this.speed}, synthesisThreadCount: ${_this.synthesisThreadCount}, lastUpdateTime: ${_this.lastUpdateTime}, isEnabled: ${_this.isEnabled})';
  }
}

/// @nodoc
abstract mixin class $HttpTtsCopyWith<$Res> {
  factory $HttpTtsCopyWith(HttpTts value, $Res Function(HttpTts) _then) =
      _$HttpTtsCopyWithImpl;
  @useResult
  $Res call({
    int id,
    String name,
    String url,
    @JsonKey(name: 'contentType') String? contentType,
    @JsonKey(name: 'pauseDuration') int pauseDuration,
    @JsonKey(name: 'concurrentRate') String? concurrentRate,
    @JsonKey(name: 'loginUrl') String? loginUrl,
    @JsonKey(name: 'loginUi', fromJson: _httpTtsLoginUiFromJson)
    String? loginUi,
    String? header,
    @JsonKey(name: 'jsLib') String? jsLib,
    @JsonKey(name: 'enabledCookieJar', fromJson: _httpTtsNullableBoolFromJson)
    bool? enabledCookieJar,
    @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
    @JsonKey(name: 'speed') int? speed,
    @JsonKey(
      name: 'synthesisThreadCount',
      fromJson: _httpTtsSynthesisThreadCountFromJson,
    )
    int synthesisThreadCount,
    @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
    @JsonKey(name: 'isEnabled', fromJson: _httpTtsEnabledFromJson)
    bool isEnabled,
  });
}

/// @nodoc
class _$HttpTtsCopyWithImpl<$Res> implements $HttpTtsCopyWith<$Res> {
  _$HttpTtsCopyWithImpl(this._self, this._then);

  final HttpTts _self;
  final $Res Function(HttpTts) _then;

  /// Create a copy of HttpTts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? url = null,
    Object? contentType = freezed,
    Object? pauseDuration = null,
    Object? concurrentRate = freezed,
    Object? loginUrl = freezed,
    Object? loginUi = freezed,
    Object? header = freezed,
    Object? jsLib = freezed,
    Object? enabledCookieJar = freezed,
    Object? loginCheckJs = freezed,
    Object? speed = freezed,
    Object? synthesisThreadCount = null,
    Object? lastUpdateTime = null,
    Object? isEnabled = null,
  }) {
    return _then(
      HttpTts(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        url: null == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        contentType: freezed == contentType
            ? _self.contentType
            : contentType // ignore: cast_nullable_to_non_nullable
                  as String?,
        pauseDuration: null == pauseDuration
            ? _self.pauseDuration
            : pauseDuration // ignore: cast_nullable_to_non_nullable
                  as int,
        concurrentRate: freezed == concurrentRate
            ? _self.concurrentRate
            : concurrentRate // ignore: cast_nullable_to_non_nullable
                  as String?,
        loginUrl: freezed == loginUrl
            ? _self.loginUrl
            : loginUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        loginUi: freezed == loginUi
            ? _self.loginUi
            : loginUi // ignore: cast_nullable_to_non_nullable
                  as String?,
        header: freezed == header
            ? _self.header
            : header // ignore: cast_nullable_to_non_nullable
                  as String?,
        jsLib: freezed == jsLib
            ? _self.jsLib
            : jsLib // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabledCookieJar: freezed == enabledCookieJar
            ? _self.enabledCookieJar
            : enabledCookieJar // ignore: cast_nullable_to_non_nullable
                  as bool?,
        loginCheckJs: freezed == loginCheckJs
            ? _self.loginCheckJs
            : loginCheckJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        speed: freezed == speed
            ? _self.speed
            : speed // ignore: cast_nullable_to_non_nullable
                  as int?,
        synthesisThreadCount: null == synthesisThreadCount
            ? _self.synthesisThreadCount
            : synthesisThreadCount // ignore: cast_nullable_to_non_nullable
                  as int,
        lastUpdateTime: null == lastUpdateTime
            ? _self.lastUpdateTime
            : lastUpdateTime // ignore: cast_nullable_to_non_nullable
                  as int,
        isEnabled: null == isEnabled
            ? _self.isEnabled
            : isEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [HttpTts].
extension HttpTtsPatterns on HttpTts {
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
    TResult Function(_HttpTts value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HttpTts() when $default != null:
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
    TResult Function(_HttpTts value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HttpTts():
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
    TResult? Function(_HttpTts value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HttpTts() when $default != null:
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
      int id,
      String name,
      String url,
      @JsonKey(name: 'contentType') String? contentType,
      @JsonKey(name: 'pauseDuration') int pauseDuration,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi', fromJson: _httpTtsLoginUiFromJson)
      String? loginUi,
      String? header,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'enabledCookieJar', fromJson: _httpTtsNullableBoolFromJson)
      bool? enabledCookieJar,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      @JsonKey(name: 'speed') int? speed,
      @JsonKey(
        name: 'synthesisThreadCount',
        fromJson: _httpTtsSynthesisThreadCountFromJson,
      )
      int synthesisThreadCount,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'isEnabled', fromJson: _httpTtsEnabledFromJson)
      bool isEnabled,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HttpTts() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.url,
          _that.contentType,
          _that.pauseDuration,
          _that.concurrentRate,
          _that.loginUrl,
          _that.loginUi,
          _that.header,
          _that.jsLib,
          _that.enabledCookieJar,
          _that.loginCheckJs,
          _that.speed,
          _that.synthesisThreadCount,
          _that.lastUpdateTime,
          _that.isEnabled,
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
      int id,
      String name,
      String url,
      @JsonKey(name: 'contentType') String? contentType,
      @JsonKey(name: 'pauseDuration') int pauseDuration,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi', fromJson: _httpTtsLoginUiFromJson)
      String? loginUi,
      String? header,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'enabledCookieJar', fromJson: _httpTtsNullableBoolFromJson)
      bool? enabledCookieJar,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      @JsonKey(name: 'speed') int? speed,
      @JsonKey(
        name: 'synthesisThreadCount',
        fromJson: _httpTtsSynthesisThreadCountFromJson,
      )
      int synthesisThreadCount,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'isEnabled', fromJson: _httpTtsEnabledFromJson)
      bool isEnabled,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HttpTts():
        return $default(
          _that.id,
          _that.name,
          _that.url,
          _that.contentType,
          _that.pauseDuration,
          _that.concurrentRate,
          _that.loginUrl,
          _that.loginUi,
          _that.header,
          _that.jsLib,
          _that.enabledCookieJar,
          _that.loginCheckJs,
          _that.speed,
          _that.synthesisThreadCount,
          _that.lastUpdateTime,
          _that.isEnabled,
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
      int id,
      String name,
      String url,
      @JsonKey(name: 'contentType') String? contentType,
      @JsonKey(name: 'pauseDuration') int pauseDuration,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi', fromJson: _httpTtsLoginUiFromJson)
      String? loginUi,
      String? header,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'enabledCookieJar', fromJson: _httpTtsNullableBoolFromJson)
      bool? enabledCookieJar,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      @JsonKey(name: 'speed') int? speed,
      @JsonKey(
        name: 'synthesisThreadCount',
        fromJson: _httpTtsSynthesisThreadCountFromJson,
      )
      int synthesisThreadCount,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'isEnabled', fromJson: _httpTtsEnabledFromJson)
      bool isEnabled,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HttpTts() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.url,
          _that.contentType,
          _that.pauseDuration,
          _that.concurrentRate,
          _that.loginUrl,
          _that.loginUi,
          _that.header,
          _that.jsLib,
          _that.enabledCookieJar,
          _that.loginCheckJs,
          _that.speed,
          _that.synthesisThreadCount,
          _that.lastUpdateTime,
          _that.isEnabled,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HttpTts implements HttpTts {
  const _HttpTts({
    this.id = 0,
    this.name = '',
    this.url = '',
    @JsonKey(name: 'contentType') this.contentType,
    @JsonKey(name: 'pauseDuration') this.pauseDuration = 0,
    @JsonKey(name: 'concurrentRate') this.concurrentRate,
    @JsonKey(name: 'loginUrl') this.loginUrl,
    @JsonKey(name: 'loginUi', fromJson: _httpTtsLoginUiFromJson) this.loginUi,
    this.header,
    @JsonKey(name: 'jsLib') this.jsLib,
    @JsonKey(name: 'enabledCookieJar', fromJson: _httpTtsNullableBoolFromJson)
    this.enabledCookieJar,
    @JsonKey(name: 'loginCheckJs') this.loginCheckJs,
    @JsonKey(name: 'speed') this.speed,
    @JsonKey(
      name: 'synthesisThreadCount',
      fromJson: _httpTtsSynthesisThreadCountFromJson,
    )
    this.synthesisThreadCount = 1,
    @JsonKey(name: 'lastUpdateTime') this.lastUpdateTime = 0,
    @JsonKey(name: 'isEnabled', fromJson: _httpTtsEnabledFromJson)
    this.isEnabled = true,
  });
  factory _HttpTts.fromJson(Map<String, dynamic> json) =>
      _$HttpTtsFromJson(json);

  @override
  @JsonKey()
  final int id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String url;
  @override
  @JsonKey(name: 'contentType')
  final String? contentType;
  @override
  @JsonKey(name: 'pauseDuration')
  final int pauseDuration;
  @override
  @JsonKey(name: 'concurrentRate')
  final String? concurrentRate;
  @override
  @JsonKey(name: 'loginUrl')
  final String? loginUrl;
  @override
  @JsonKey(name: 'loginUi', fromJson: _httpTtsLoginUiFromJson)
  final String? loginUi;
  @override
  final String? header;
  @override
  @JsonKey(name: 'jsLib')
  final String? jsLib;
  @override
  @JsonKey(name: 'enabledCookieJar', fromJson: _httpTtsNullableBoolFromJson)
  final bool? enabledCookieJar;
  @override
  @JsonKey(name: 'loginCheckJs')
  final String? loginCheckJs;
  @override
  @JsonKey(name: 'speed')
  final int? speed;
  @override
  @JsonKey(
    name: 'synthesisThreadCount',
    fromJson: _httpTtsSynthesisThreadCountFromJson,
  )
  final int synthesisThreadCount;
  @override
  @JsonKey(name: 'lastUpdateTime')
  final int lastUpdateTime;
  @override
  @JsonKey(name: 'isEnabled', fromJson: _httpTtsEnabledFromJson)
  final bool isEnabled;

  /// Create a copy of HttpTts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HttpTtsCopyWith<_HttpTts> get copyWith =>
      __$HttpTtsCopyWithImpl<_HttpTts>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HttpTtsToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HttpTts &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.pauseDuration, pauseDuration) ||
                other.pauseDuration == pauseDuration) &&
            (identical(other.concurrentRate, concurrentRate) ||
                other.concurrentRate == concurrentRate) &&
            (identical(other.loginUrl, loginUrl) ||
                other.loginUrl == loginUrl) &&
            (identical(other.loginUi, loginUi) || other.loginUi == loginUi) &&
            (identical(other.header, header) || other.header == header) &&
            (identical(other.jsLib, jsLib) || other.jsLib == jsLib) &&
            (identical(other.enabledCookieJar, enabledCookieJar) ||
                other.enabledCookieJar == enabledCookieJar) &&
            (identical(other.loginCheckJs, loginCheckJs) ||
                other.loginCheckJs == loginCheckJs) &&
            (identical(other.speed, speed) || other.speed == speed) &&
            (identical(other.synthesisThreadCount, synthesisThreadCount) ||
                other.synthesisThreadCount == synthesisThreadCount) &&
            (identical(other.lastUpdateTime, lastUpdateTime) ||
                other.lastUpdateTime == lastUpdateTime) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      id,
      name,
      url,
      contentType,
      pauseDuration,
      concurrentRate,
      loginUrl,
      loginUi,
      header,
      jsLib,
      enabledCookieJar,
      loginCheckJs,
      speed,
      synthesisThreadCount,
      lastUpdateTime,
      isEnabled,
    );
  }

  @override
  String toString() {
    return 'HttpTts(id: $id, name: $name, url: $url, contentType: $contentType, pauseDuration: $pauseDuration, concurrentRate: $concurrentRate, loginUrl: $loginUrl, loginUi: $loginUi, header: $header, jsLib: $jsLib, enabledCookieJar: $enabledCookieJar, loginCheckJs: $loginCheckJs, speed: $speed, synthesisThreadCount: $synthesisThreadCount, lastUpdateTime: $lastUpdateTime, isEnabled: $isEnabled)';
  }
}

/// @nodoc
abstract mixin class _$HttpTtsCopyWith<$Res> implements $HttpTtsCopyWith<$Res> {
  factory _$HttpTtsCopyWith(_HttpTts value, $Res Function(_HttpTts) _then) =
      __$HttpTtsCopyWithImpl;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    String url,
    @JsonKey(name: 'contentType') String? contentType,
    @JsonKey(name: 'pauseDuration') int pauseDuration,
    @JsonKey(name: 'concurrentRate') String? concurrentRate,
    @JsonKey(name: 'loginUrl') String? loginUrl,
    @JsonKey(name: 'loginUi', fromJson: _httpTtsLoginUiFromJson)
    String? loginUi,
    String? header,
    @JsonKey(name: 'jsLib') String? jsLib,
    @JsonKey(name: 'enabledCookieJar', fromJson: _httpTtsNullableBoolFromJson)
    bool? enabledCookieJar,
    @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
    @JsonKey(name: 'speed') int? speed,
    @JsonKey(
      name: 'synthesisThreadCount',
      fromJson: _httpTtsSynthesisThreadCountFromJson,
    )
    int synthesisThreadCount,
    @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
    @JsonKey(name: 'isEnabled', fromJson: _httpTtsEnabledFromJson)
    bool isEnabled,
  });
}

/// @nodoc
class __$HttpTtsCopyWithImpl<$Res> implements _$HttpTtsCopyWith<$Res> {
  __$HttpTtsCopyWithImpl(this._self, this._then);

  final _HttpTts _self;
  final $Res Function(_HttpTts) _then;

  /// Create a copy of HttpTts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? url = null,
    Object? contentType = freezed,
    Object? pauseDuration = null,
    Object? concurrentRate = freezed,
    Object? loginUrl = freezed,
    Object? loginUi = freezed,
    Object? header = freezed,
    Object? jsLib = freezed,
    Object? enabledCookieJar = freezed,
    Object? loginCheckJs = freezed,
    Object? speed = freezed,
    Object? synthesisThreadCount = null,
    Object? lastUpdateTime = null,
    Object? isEnabled = null,
  }) {
    return _then(
      _HttpTts(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        url: null == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        contentType: freezed == contentType
            ? _self.contentType
            : contentType // ignore: cast_nullable_to_non_nullable
                  as String?,
        pauseDuration: null == pauseDuration
            ? _self.pauseDuration
            : pauseDuration // ignore: cast_nullable_to_non_nullable
                  as int,
        concurrentRate: freezed == concurrentRate
            ? _self.concurrentRate
            : concurrentRate // ignore: cast_nullable_to_non_nullable
                  as String?,
        loginUrl: freezed == loginUrl
            ? _self.loginUrl
            : loginUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        loginUi: freezed == loginUi
            ? _self.loginUi
            : loginUi // ignore: cast_nullable_to_non_nullable
                  as String?,
        header: freezed == header
            ? _self.header
            : header // ignore: cast_nullable_to_non_nullable
                  as String?,
        jsLib: freezed == jsLib
            ? _self.jsLib
            : jsLib // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabledCookieJar: freezed == enabledCookieJar
            ? _self.enabledCookieJar
            : enabledCookieJar // ignore: cast_nullable_to_non_nullable
                  as bool?,
        loginCheckJs: freezed == loginCheckJs
            ? _self.loginCheckJs
            : loginCheckJs // ignore: cast_nullable_to_non_nullable
                  as String?,
        speed: freezed == speed
            ? _self.speed
            : speed // ignore: cast_nullable_to_non_nullable
                  as int?,
        synthesisThreadCount: null == synthesisThreadCount
            ? _self.synthesisThreadCount
            : synthesisThreadCount // ignore: cast_nullable_to_non_nullable
                  as int,
        lastUpdateTime: null == lastUpdateTime
            ? _self.lastUpdateTime
            : lastUpdateTime // ignore: cast_nullable_to_non_nullable
                  as int,
        isEnabled: null == isEnabled
            ? _self.isEnabled
            : isEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
mixin _$Bookmark {
  int get id;
  int get time;
  @JsonKey(name: 'bookName')
  String get bookName;
  @JsonKey(name: 'bookAuthor')
  String get bookAuthor;
  @JsonKey(name: 'chapterIndex')
  int get chapterIndex;
  @JsonKey(name: 'chapterPos')
  int get chapterPos;
  @JsonKey(name: 'chapterName')
  String get chapterName;
  @JsonKey(name: 'bookText')
  String get bookText;
  String get content;

  /// Create a copy of Bookmark
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookmarkCopyWith<Bookmark> get copyWith =>
      _$BookmarkCopyWithImpl<Bookmark>(this as Bookmark, _$identity);

  /// Serializes this Bookmark to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as Bookmark;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Bookmark &&
            (identical(other.id, _this.id) || other.id == _this.id) &&
            (identical(other.time, _this.time) || other.time == _this.time) &&
            (identical(other.bookName, _this.bookName) ||
                other.bookName == _this.bookName) &&
            (identical(other.bookAuthor, _this.bookAuthor) ||
                other.bookAuthor == _this.bookAuthor) &&
            (identical(other.chapterIndex, _this.chapterIndex) ||
                other.chapterIndex == _this.chapterIndex) &&
            (identical(other.chapterPos, _this.chapterPos) ||
                other.chapterPos == _this.chapterPos) &&
            (identical(other.chapterName, _this.chapterName) ||
                other.chapterName == _this.chapterName) &&
            (identical(other.bookText, _this.bookText) ||
                other.bookText == _this.bookText) &&
            (identical(other.content, _this.content) ||
                other.content == _this.content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as Bookmark;
    return Object.hash(
      runtimeType,
      _this.id,
      _this.time,
      _this.bookName,
      _this.bookAuthor,
      _this.chapterIndex,
      _this.chapterPos,
      _this.chapterName,
      _this.bookText,
      _this.content,
    );
  }

  @override
  String toString() {
    final _this = this as Bookmark;
    return 'Bookmark(id: ${_this.id}, time: ${_this.time}, bookName: ${_this.bookName}, bookAuthor: ${_this.bookAuthor}, chapterIndex: ${_this.chapterIndex}, chapterPos: ${_this.chapterPos}, chapterName: ${_this.chapterName}, bookText: ${_this.bookText}, content: ${_this.content})';
  }
}

/// @nodoc
abstract mixin class $BookmarkCopyWith<$Res> {
  factory $BookmarkCopyWith(Bookmark value, $Res Function(Bookmark) _then) =
      _$BookmarkCopyWithImpl;
  @useResult
  $Res call({
    int id,
    int time,
    @JsonKey(name: 'bookName') String bookName,
    @JsonKey(name: 'bookAuthor') String bookAuthor,
    @JsonKey(name: 'chapterIndex') int chapterIndex,
    @JsonKey(name: 'chapterPos') int chapterPos,
    @JsonKey(name: 'chapterName') String chapterName,
    @JsonKey(name: 'bookText') String bookText,
    String content,
  });
}

/// @nodoc
class _$BookmarkCopyWithImpl<$Res> implements $BookmarkCopyWith<$Res> {
  _$BookmarkCopyWithImpl(this._self, this._then);

  final Bookmark _self;
  final $Res Function(Bookmark) _then;

  /// Create a copy of Bookmark
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? time = null,
    Object? bookName = null,
    Object? bookAuthor = null,
    Object? chapterIndex = null,
    Object? chapterPos = null,
    Object? chapterName = null,
    Object? bookText = null,
    Object? content = null,
  }) {
    return _then(
      Bookmark(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        time: null == time
            ? _self.time
            : time // ignore: cast_nullable_to_non_nullable
                  as int,
        bookName: null == bookName
            ? _self.bookName
            : bookName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookAuthor: null == bookAuthor
            ? _self.bookAuthor
            : bookAuthor // ignore: cast_nullable_to_non_nullable
                  as String,
        chapterIndex: null == chapterIndex
            ? _self.chapterIndex
            : chapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterPos: null == chapterPos
            ? _self.chapterPos
            : chapterPos // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterName: null == chapterName
            ? _self.chapterName
            : chapterName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookText: null == bookText
            ? _self.bookText
            : bookText // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _self.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [Bookmark].
extension BookmarkPatterns on Bookmark {
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
    TResult Function(_Bookmark value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Bookmark() when $default != null:
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
    TResult Function(_Bookmark value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Bookmark():
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
    TResult? Function(_Bookmark value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Bookmark() when $default != null:
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
      int id,
      int time,
      @JsonKey(name: 'bookName') String bookName,
      @JsonKey(name: 'bookAuthor') String bookAuthor,
      @JsonKey(name: 'chapterIndex') int chapterIndex,
      @JsonKey(name: 'chapterPos') int chapterPos,
      @JsonKey(name: 'chapterName') String chapterName,
      @JsonKey(name: 'bookText') String bookText,
      String content,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Bookmark() when $default != null:
        return $default(
          _that.id,
          _that.time,
          _that.bookName,
          _that.bookAuthor,
          _that.chapterIndex,
          _that.chapterPos,
          _that.chapterName,
          _that.bookText,
          _that.content,
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
      int id,
      int time,
      @JsonKey(name: 'bookName') String bookName,
      @JsonKey(name: 'bookAuthor') String bookAuthor,
      @JsonKey(name: 'chapterIndex') int chapterIndex,
      @JsonKey(name: 'chapterPos') int chapterPos,
      @JsonKey(name: 'chapterName') String chapterName,
      @JsonKey(name: 'bookText') String bookText,
      String content,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Bookmark():
        return $default(
          _that.id,
          _that.time,
          _that.bookName,
          _that.bookAuthor,
          _that.chapterIndex,
          _that.chapterPos,
          _that.chapterName,
          _that.bookText,
          _that.content,
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
      int id,
      int time,
      @JsonKey(name: 'bookName') String bookName,
      @JsonKey(name: 'bookAuthor') String bookAuthor,
      @JsonKey(name: 'chapterIndex') int chapterIndex,
      @JsonKey(name: 'chapterPos') int chapterPos,
      @JsonKey(name: 'chapterName') String chapterName,
      @JsonKey(name: 'bookText') String bookText,
      String content,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Bookmark() when $default != null:
        return $default(
          _that.id,
          _that.time,
          _that.bookName,
          _that.bookAuthor,
          _that.chapterIndex,
          _that.chapterPos,
          _that.chapterName,
          _that.bookText,
          _that.content,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Bookmark implements Bookmark {
  const _Bookmark({
    this.id = 0,
    this.time = 0,
    @JsonKey(name: 'bookName') this.bookName = '',
    @JsonKey(name: 'bookAuthor') this.bookAuthor = '',
    @JsonKey(name: 'chapterIndex') this.chapterIndex = 0,
    @JsonKey(name: 'chapterPos') this.chapterPos = 0,
    @JsonKey(name: 'chapterName') this.chapterName = '',
    @JsonKey(name: 'bookText') this.bookText = '',
    this.content = '',
  });
  factory _Bookmark.fromJson(Map<String, dynamic> json) =>
      _$BookmarkFromJson(json);

  @override
  @JsonKey()
  final int id;
  @override
  @JsonKey()
  final int time;
  @override
  @JsonKey(name: 'bookName')
  final String bookName;
  @override
  @JsonKey(name: 'bookAuthor')
  final String bookAuthor;
  @override
  @JsonKey(name: 'chapterIndex')
  final int chapterIndex;
  @override
  @JsonKey(name: 'chapterPos')
  final int chapterPos;
  @override
  @JsonKey(name: 'chapterName')
  final String chapterName;
  @override
  @JsonKey(name: 'bookText')
  final String bookText;
  @override
  @JsonKey()
  final String content;

  /// Create a copy of Bookmark
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookmarkCopyWith<_Bookmark> get copyWith =>
      __$BookmarkCopyWithImpl<_Bookmark>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BookmarkToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Bookmark &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.bookName, bookName) ||
                other.bookName == bookName) &&
            (identical(other.bookAuthor, bookAuthor) ||
                other.bookAuthor == bookAuthor) &&
            (identical(other.chapterIndex, chapterIndex) ||
                other.chapterIndex == chapterIndex) &&
            (identical(other.chapterPos, chapterPos) ||
                other.chapterPos == chapterPos) &&
            (identical(other.chapterName, chapterName) ||
                other.chapterName == chapterName) &&
            (identical(other.bookText, bookText) ||
                other.bookText == bookText) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      id,
      time,
      bookName,
      bookAuthor,
      chapterIndex,
      chapterPos,
      chapterName,
      bookText,
      content,
    );
  }

  @override
  String toString() {
    return 'Bookmark(id: $id, time: $time, bookName: $bookName, bookAuthor: $bookAuthor, chapterIndex: $chapterIndex, chapterPos: $chapterPos, chapterName: $chapterName, bookText: $bookText, content: $content)';
  }
}

/// @nodoc
abstract mixin class _$BookmarkCopyWith<$Res>
    implements $BookmarkCopyWith<$Res> {
  factory _$BookmarkCopyWith(_Bookmark value, $Res Function(_Bookmark) _then) =
      __$BookmarkCopyWithImpl;
  @override
  @useResult
  $Res call({
    int id,
    int time,
    @JsonKey(name: 'bookName') String bookName,
    @JsonKey(name: 'bookAuthor') String bookAuthor,
    @JsonKey(name: 'chapterIndex') int chapterIndex,
    @JsonKey(name: 'chapterPos') int chapterPos,
    @JsonKey(name: 'chapterName') String chapterName,
    @JsonKey(name: 'bookText') String bookText,
    String content,
  });
}

/// @nodoc
class __$BookmarkCopyWithImpl<$Res> implements _$BookmarkCopyWith<$Res> {
  __$BookmarkCopyWithImpl(this._self, this._then);

  final _Bookmark _self;
  final $Res Function(_Bookmark) _then;

  /// Create a copy of Bookmark
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? time = null,
    Object? bookName = null,
    Object? bookAuthor = null,
    Object? chapterIndex = null,
    Object? chapterPos = null,
    Object? chapterName = null,
    Object? bookText = null,
    Object? content = null,
  }) {
    return _then(
      _Bookmark(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        time: null == time
            ? _self.time
            : time // ignore: cast_nullable_to_non_nullable
                  as int,
        bookName: null == bookName
            ? _self.bookName
            : bookName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookAuthor: null == bookAuthor
            ? _self.bookAuthor
            : bookAuthor // ignore: cast_nullable_to_non_nullable
                  as String,
        chapterIndex: null == chapterIndex
            ? _self.chapterIndex
            : chapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterPos: null == chapterPos
            ? _self.chapterPos
            : chapterPos // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterName: null == chapterName
            ? _self.chapterName
            : chapterName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookText: null == bookText
            ? _self.bookText
            : bookText // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _self.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
mixin _$BookGroup {
  @JsonKey(name: 'groupId')
  int get groupId;
  bool get isPrivate;
  @JsonKey(name: 'groupName')
  String get groupName;
  String? get cover;
  int get order;
  @JsonKey(name: 'enableRefresh')
  bool get enableRefresh;
  bool get show;
  @JsonKey(name: 'bookSort')
  int get bookSort;
  @JsonKey(name: 'onlyUpdateRead')
  bool get onlyUpdateRead;

  /// Create a copy of BookGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookGroupCopyWith<BookGroup> get copyWith =>
      _$BookGroupCopyWithImpl<BookGroup>(this as BookGroup, _$identity);

  /// Serializes this BookGroup to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as BookGroup;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookGroup &&
            (identical(other.groupId, _this.groupId) ||
                other.groupId == _this.groupId) &&
            (identical(other.isPrivate, _this.isPrivate) ||
                other.isPrivate == _this.isPrivate) &&
            (identical(other.groupName, _this.groupName) ||
                other.groupName == _this.groupName) &&
            (identical(other.cover, _this.cover) ||
                other.cover == _this.cover) &&
            (identical(other.order, _this.order) ||
                other.order == _this.order) &&
            (identical(other.enableRefresh, _this.enableRefresh) ||
                other.enableRefresh == _this.enableRefresh) &&
            (identical(other.show, _this.show) || other.show == _this.show) &&
            (identical(other.bookSort, _this.bookSort) ||
                other.bookSort == _this.bookSort) &&
            (identical(other.onlyUpdateRead, _this.onlyUpdateRead) ||
                other.onlyUpdateRead == _this.onlyUpdateRead));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as BookGroup;
    return Object.hash(
      runtimeType,
      _this.groupId,
      _this.isPrivate,
      _this.groupName,
      _this.cover,
      _this.order,
      _this.enableRefresh,
      _this.show,
      _this.bookSort,
      _this.onlyUpdateRead,
    );
  }

  @override
  String toString() {
    final _this = this as BookGroup;
    return 'BookGroup(groupId: ${_this.groupId}, isPrivate: ${_this.isPrivate}, groupName: ${_this.groupName}, cover: ${_this.cover}, order: ${_this.order}, enableRefresh: ${_this.enableRefresh}, show: ${_this.show}, bookSort: ${_this.bookSort}, onlyUpdateRead: ${_this.onlyUpdateRead})';
  }
}

/// @nodoc
abstract mixin class $BookGroupCopyWith<$Res> {
  factory $BookGroupCopyWith(BookGroup value, $Res Function(BookGroup) _then) =
      _$BookGroupCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'groupId') int groupId,
    bool isPrivate,
    @JsonKey(name: 'groupName') String groupName,
    String? cover,
    int order,
    @JsonKey(name: 'enableRefresh') bool enableRefresh,
    bool show,
    @JsonKey(name: 'bookSort') int bookSort,
    @JsonKey(name: 'onlyUpdateRead') bool onlyUpdateRead,
  });
}

/// @nodoc
class _$BookGroupCopyWithImpl<$Res> implements $BookGroupCopyWith<$Res> {
  _$BookGroupCopyWithImpl(this._self, this._then);

  final BookGroup _self;
  final $Res Function(BookGroup) _then;

  /// Create a copy of BookGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? isPrivate = null,
    Object? groupName = null,
    Object? cover = freezed,
    Object? order = null,
    Object? enableRefresh = null,
    Object? show = null,
    Object? bookSort = null,
    Object? onlyUpdateRead = null,
  }) {
    return _then(
      BookGroup(
        groupId: null == groupId
            ? _self.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as int,
        isPrivate: null == isPrivate
            ? _self.isPrivate
            : isPrivate // ignore: cast_nullable_to_non_nullable
                  as bool,
        groupName: null == groupName
            ? _self.groupName
            : groupName // ignore: cast_nullable_to_non_nullable
                  as String,
        cover: freezed == cover
            ? _self.cover
            : cover // ignore: cast_nullable_to_non_nullable
                  as String?,
        order: null == order
            ? _self.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        enableRefresh: null == enableRefresh
            ? _self.enableRefresh
            : enableRefresh // ignore: cast_nullable_to_non_nullable
                  as bool,
        show: null == show
            ? _self.show
            : show // ignore: cast_nullable_to_non_nullable
                  as bool,
        bookSort: null == bookSort
            ? _self.bookSort
            : bookSort // ignore: cast_nullable_to_non_nullable
                  as int,
        onlyUpdateRead: null == onlyUpdateRead
            ? _self.onlyUpdateRead
            : onlyUpdateRead // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BookGroup].
extension BookGroupPatterns on BookGroup {
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
    TResult Function(_BookGroup value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookGroup() when $default != null:
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
    TResult Function(_BookGroup value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookGroup():
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
    TResult? Function(_BookGroup value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookGroup() when $default != null:
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
      @JsonKey(name: 'groupId') int groupId,
      bool isPrivate,
      @JsonKey(name: 'groupName') String groupName,
      String? cover,
      int order,
      @JsonKey(name: 'enableRefresh') bool enableRefresh,
      bool show,
      @JsonKey(name: 'bookSort') int bookSort,
      @JsonKey(name: 'onlyUpdateRead') bool onlyUpdateRead,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookGroup() when $default != null:
        return $default(
          _that.groupId,
          _that.isPrivate,
          _that.groupName,
          _that.cover,
          _that.order,
          _that.enableRefresh,
          _that.show,
          _that.bookSort,
          _that.onlyUpdateRead,
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
      @JsonKey(name: 'groupId') int groupId,
      bool isPrivate,
      @JsonKey(name: 'groupName') String groupName,
      String? cover,
      int order,
      @JsonKey(name: 'enableRefresh') bool enableRefresh,
      bool show,
      @JsonKey(name: 'bookSort') int bookSort,
      @JsonKey(name: 'onlyUpdateRead') bool onlyUpdateRead,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookGroup():
        return $default(
          _that.groupId,
          _that.isPrivate,
          _that.groupName,
          _that.cover,
          _that.order,
          _that.enableRefresh,
          _that.show,
          _that.bookSort,
          _that.onlyUpdateRead,
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
      @JsonKey(name: 'groupId') int groupId,
      bool isPrivate,
      @JsonKey(name: 'groupName') String groupName,
      String? cover,
      int order,
      @JsonKey(name: 'enableRefresh') bool enableRefresh,
      bool show,
      @JsonKey(name: 'bookSort') int bookSort,
      @JsonKey(name: 'onlyUpdateRead') bool onlyUpdateRead,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookGroup() when $default != null:
        return $default(
          _that.groupId,
          _that.isPrivate,
          _that.groupName,
          _that.cover,
          _that.order,
          _that.enableRefresh,
          _that.show,
          _that.bookSort,
          _that.onlyUpdateRead,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BookGroup implements BookGroup {
  const _BookGroup({
    @JsonKey(name: 'groupId') this.groupId = 1,
    this.isPrivate = false,
    @JsonKey(name: 'groupName') this.groupName = '',
    this.cover,
    this.order = 0,
    @JsonKey(name: 'enableRefresh') this.enableRefresh = true,
    this.show = true,
    @JsonKey(name: 'bookSort') this.bookSort = -1,
    @JsonKey(name: 'onlyUpdateRead') this.onlyUpdateRead = false,
  });
  factory _BookGroup.fromJson(Map<String, dynamic> json) =>
      _$BookGroupFromJson(json);

  @override
  @JsonKey(name: 'groupId')
  final int groupId;
  @override
  @JsonKey()
  final bool isPrivate;
  @override
  @JsonKey(name: 'groupName')
  final String groupName;
  @override
  final String? cover;
  @override
  @JsonKey()
  final int order;
  @override
  @JsonKey(name: 'enableRefresh')
  final bool enableRefresh;
  @override
  @JsonKey()
  final bool show;
  @override
  @JsonKey(name: 'bookSort')
  final int bookSort;
  @override
  @JsonKey(name: 'onlyUpdateRead')
  final bool onlyUpdateRead;

  /// Create a copy of BookGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookGroupCopyWith<_BookGroup> get copyWith =>
      __$BookGroupCopyWithImpl<_BookGroup>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BookGroupToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookGroup &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.isPrivate, isPrivate) ||
                other.isPrivate == isPrivate) &&
            (identical(other.groupName, groupName) ||
                other.groupName == groupName) &&
            (identical(other.cover, cover) || other.cover == cover) &&
            (identical(other.order, order) || other.order == order) &&
            (identical(other.enableRefresh, enableRefresh) ||
                other.enableRefresh == enableRefresh) &&
            (identical(other.show, show) || other.show == show) &&
            (identical(other.bookSort, bookSort) ||
                other.bookSort == bookSort) &&
            (identical(other.onlyUpdateRead, onlyUpdateRead) ||
                other.onlyUpdateRead == onlyUpdateRead));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      groupId,
      isPrivate,
      groupName,
      cover,
      order,
      enableRefresh,
      show,
      bookSort,
      onlyUpdateRead,
    );
  }

  @override
  String toString() {
    return 'BookGroup(groupId: $groupId, isPrivate: $isPrivate, groupName: $groupName, cover: $cover, order: $order, enableRefresh: $enableRefresh, show: $show, bookSort: $bookSort, onlyUpdateRead: $onlyUpdateRead)';
  }
}

/// @nodoc
abstract mixin class _$BookGroupCopyWith<$Res>
    implements $BookGroupCopyWith<$Res> {
  factory _$BookGroupCopyWith(
    _BookGroup value,
    $Res Function(_BookGroup) _then,
  ) = __$BookGroupCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'groupId') int groupId,
    bool isPrivate,
    @JsonKey(name: 'groupName') String groupName,
    String? cover,
    int order,
    @JsonKey(name: 'enableRefresh') bool enableRefresh,
    bool show,
    @JsonKey(name: 'bookSort') int bookSort,
    @JsonKey(name: 'onlyUpdateRead') bool onlyUpdateRead,
  });
}

/// @nodoc
class __$BookGroupCopyWithImpl<$Res> implements _$BookGroupCopyWith<$Res> {
  __$BookGroupCopyWithImpl(this._self, this._then);

  final _BookGroup _self;
  final $Res Function(_BookGroup) _then;

  /// Create a copy of BookGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? groupId = null,
    Object? isPrivate = null,
    Object? groupName = null,
    Object? cover = freezed,
    Object? order = null,
    Object? enableRefresh = null,
    Object? show = null,
    Object? bookSort = null,
    Object? onlyUpdateRead = null,
  }) {
    return _then(
      _BookGroup(
        groupId: null == groupId
            ? _self.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as int,
        isPrivate: null == isPrivate
            ? _self.isPrivate
            : isPrivate // ignore: cast_nullable_to_non_nullable
                  as bool,
        groupName: null == groupName
            ? _self.groupName
            : groupName // ignore: cast_nullable_to_non_nullable
                  as String,
        cover: freezed == cover
            ? _self.cover
            : cover // ignore: cast_nullable_to_non_nullable
                  as String?,
        order: null == order
            ? _self.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        enableRefresh: null == enableRefresh
            ? _self.enableRefresh
            : enableRefresh // ignore: cast_nullable_to_non_nullable
                  as bool,
        show: null == show
            ? _self.show
            : show // ignore: cast_nullable_to_non_nullable
                  as bool,
        bookSort: null == bookSort
            ? _self.bookSort
            : bookSort // ignore: cast_nullable_to_non_nullable
                  as int,
        onlyUpdateRead: null == onlyUpdateRead
            ? _self.onlyUpdateRead
            : onlyUpdateRead // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
mixin _$AutoTaskRule {
  String get id;
  String get name;
  bool get enable;
  String? get cron;
  @JsonKey(name: 'loginUrl')
  String? get loginUrl;
  @JsonKey(name: 'loginUi')
  String? get loginUi;
  @JsonKey(name: 'loginCheckJs')
  String? get loginCheckJs;
  String? get comment;
  String get script;
  String? get header;
  @JsonKey(name: 'jsLib')
  String? get jsLib;
  @JsonKey(name: 'concurrentRate')
  String? get concurrentRate;
  @JsonKey(name: 'enabledCookieJar')
  bool get enabledCookieJar;
  @JsonKey(name: 'customOrder')
  int get customOrder;
  @JsonKey(name: 'lastRunAt')
  int get lastRunAt;
  @JsonKey(name: 'lastResult')
  String? get lastResult;
  @JsonKey(name: 'lastError')
  String? get lastError;
  @JsonKey(name: 'lastLog')
  String? get lastLog;

  /// Create a copy of AutoTaskRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AutoTaskRuleCopyWith<AutoTaskRule> get copyWith =>
      _$AutoTaskRuleCopyWithImpl<AutoTaskRule>(
        this as AutoTaskRule,
        _$identity,
      );

  /// Serializes this AutoTaskRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as AutoTaskRule;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AutoTaskRule &&
            (identical(other.id, _this.id) || other.id == _this.id) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.enable, _this.enable) ||
                other.enable == _this.enable) &&
            (identical(other.cron, _this.cron) || other.cron == _this.cron) &&
            (identical(other.loginUrl, _this.loginUrl) ||
                other.loginUrl == _this.loginUrl) &&
            (identical(other.loginUi, _this.loginUi) ||
                other.loginUi == _this.loginUi) &&
            (identical(other.loginCheckJs, _this.loginCheckJs) ||
                other.loginCheckJs == _this.loginCheckJs) &&
            (identical(other.comment, _this.comment) ||
                other.comment == _this.comment) &&
            (identical(other.script, _this.script) ||
                other.script == _this.script) &&
            (identical(other.header, _this.header) ||
                other.header == _this.header) &&
            (identical(other.jsLib, _this.jsLib) ||
                other.jsLib == _this.jsLib) &&
            (identical(other.concurrentRate, _this.concurrentRate) ||
                other.concurrentRate == _this.concurrentRate) &&
            (identical(other.enabledCookieJar, _this.enabledCookieJar) ||
                other.enabledCookieJar == _this.enabledCookieJar) &&
            (identical(other.customOrder, _this.customOrder) ||
                other.customOrder == _this.customOrder) &&
            (identical(other.lastRunAt, _this.lastRunAt) ||
                other.lastRunAt == _this.lastRunAt) &&
            (identical(other.lastResult, _this.lastResult) ||
                other.lastResult == _this.lastResult) &&
            (identical(other.lastError, _this.lastError) ||
                other.lastError == _this.lastError) &&
            (identical(other.lastLog, _this.lastLog) ||
                other.lastLog == _this.lastLog));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as AutoTaskRule;
    return Object.hash(
      runtimeType,
      _this.id,
      _this.name,
      _this.enable,
      _this.cron,
      _this.loginUrl,
      _this.loginUi,
      _this.loginCheckJs,
      _this.comment,
      _this.script,
      _this.header,
      _this.jsLib,
      _this.concurrentRate,
      _this.enabledCookieJar,
      _this.customOrder,
      _this.lastRunAt,
      _this.lastResult,
      _this.lastError,
      _this.lastLog,
    );
  }

  @override
  String toString() {
    final _this = this as AutoTaskRule;
    return 'AutoTaskRule(id: ${_this.id}, name: ${_this.name}, enable: ${_this.enable}, cron: ${_this.cron}, loginUrl: ${_this.loginUrl}, loginUi: ${_this.loginUi}, loginCheckJs: ${_this.loginCheckJs}, comment: ${_this.comment}, script: ${_this.script}, header: ${_this.header}, jsLib: ${_this.jsLib}, concurrentRate: ${_this.concurrentRate}, enabledCookieJar: ${_this.enabledCookieJar}, customOrder: ${_this.customOrder}, lastRunAt: ${_this.lastRunAt}, lastResult: ${_this.lastResult}, lastError: ${_this.lastError}, lastLog: ${_this.lastLog})';
  }
}

/// @nodoc
abstract mixin class $AutoTaskRuleCopyWith<$Res> {
  factory $AutoTaskRuleCopyWith(
    AutoTaskRule value,
    $Res Function(AutoTaskRule) _then,
  ) = _$AutoTaskRuleCopyWithImpl;
  @useResult
  $Res call({
    String id,
    String name,
    bool enable,
    String? cron,
    @JsonKey(name: 'loginUrl') String? loginUrl,
    @JsonKey(name: 'loginUi') String? loginUi,
    @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
    String? comment,
    String script,
    String? header,
    @JsonKey(name: 'jsLib') String? jsLib,
    @JsonKey(name: 'concurrentRate') String? concurrentRate,
    @JsonKey(name: 'enabledCookieJar') bool enabledCookieJar,
    @JsonKey(name: 'customOrder') int customOrder,
    @JsonKey(name: 'lastRunAt') int lastRunAt,
    @JsonKey(name: 'lastResult') String? lastResult,
    @JsonKey(name: 'lastError') String? lastError,
    @JsonKey(name: 'lastLog') String? lastLog,
  });
}

/// @nodoc
class _$AutoTaskRuleCopyWithImpl<$Res> implements $AutoTaskRuleCopyWith<$Res> {
  _$AutoTaskRuleCopyWithImpl(this._self, this._then);

  final AutoTaskRule _self;
  final $Res Function(AutoTaskRule) _then;

  /// Create a copy of AutoTaskRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? enable = null,
    Object? cron = freezed,
    Object? loginUrl = freezed,
    Object? loginUi = freezed,
    Object? loginCheckJs = freezed,
    Object? comment = freezed,
    Object? script = null,
    Object? header = freezed,
    Object? jsLib = freezed,
    Object? concurrentRate = freezed,
    Object? enabledCookieJar = null,
    Object? customOrder = null,
    Object? lastRunAt = null,
    Object? lastResult = freezed,
    Object? lastError = freezed,
    Object? lastLog = freezed,
  }) {
    return _then(
      AutoTaskRule(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        enable: null == enable
            ? _self.enable
            : enable // ignore: cast_nullable_to_non_nullable
                  as bool,
        cron: freezed == cron
            ? _self.cron
            : cron // ignore: cast_nullable_to_non_nullable
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
        comment: freezed == comment
            ? _self.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String?,
        script: null == script
            ? _self.script
            : script // ignore: cast_nullable_to_non_nullable
                  as String,
        header: freezed == header
            ? _self.header
            : header // ignore: cast_nullable_to_non_nullable
                  as String?,
        jsLib: freezed == jsLib
            ? _self.jsLib
            : jsLib // ignore: cast_nullable_to_non_nullable
                  as String?,
        concurrentRate: freezed == concurrentRate
            ? _self.concurrentRate
            : concurrentRate // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabledCookieJar: null == enabledCookieJar
            ? _self.enabledCookieJar
            : enabledCookieJar // ignore: cast_nullable_to_non_nullable
                  as bool,
        customOrder: null == customOrder
            ? _self.customOrder
            : customOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        lastRunAt: null == lastRunAt
            ? _self.lastRunAt
            : lastRunAt // ignore: cast_nullable_to_non_nullable
                  as int,
        lastResult: freezed == lastResult
            ? _self.lastResult
            : lastResult // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastError: freezed == lastError
            ? _self.lastError
            : lastError // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastLog: freezed == lastLog
            ? _self.lastLog
            : lastLog // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [AutoTaskRule].
extension AutoTaskRulePatterns on AutoTaskRule {
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
    TResult Function(_AutoTaskRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AutoTaskRule() when $default != null:
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
    TResult Function(_AutoTaskRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AutoTaskRule():
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
    TResult? Function(_AutoTaskRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AutoTaskRule() when $default != null:
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
      String id,
      String name,
      bool enable,
      String? cron,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi') String? loginUi,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      String? comment,
      String script,
      String? header,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      @JsonKey(name: 'enabledCookieJar') bool enabledCookieJar,
      @JsonKey(name: 'customOrder') int customOrder,
      @JsonKey(name: 'lastRunAt') int lastRunAt,
      @JsonKey(name: 'lastResult') String? lastResult,
      @JsonKey(name: 'lastError') String? lastError,
      @JsonKey(name: 'lastLog') String? lastLog,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AutoTaskRule() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.enable,
          _that.cron,
          _that.loginUrl,
          _that.loginUi,
          _that.loginCheckJs,
          _that.comment,
          _that.script,
          _that.header,
          _that.jsLib,
          _that.concurrentRate,
          _that.enabledCookieJar,
          _that.customOrder,
          _that.lastRunAt,
          _that.lastResult,
          _that.lastError,
          _that.lastLog,
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
      String id,
      String name,
      bool enable,
      String? cron,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi') String? loginUi,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      String? comment,
      String script,
      String? header,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      @JsonKey(name: 'enabledCookieJar') bool enabledCookieJar,
      @JsonKey(name: 'customOrder') int customOrder,
      @JsonKey(name: 'lastRunAt') int lastRunAt,
      @JsonKey(name: 'lastResult') String? lastResult,
      @JsonKey(name: 'lastError') String? lastError,
      @JsonKey(name: 'lastLog') String? lastLog,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AutoTaskRule():
        return $default(
          _that.id,
          _that.name,
          _that.enable,
          _that.cron,
          _that.loginUrl,
          _that.loginUi,
          _that.loginCheckJs,
          _that.comment,
          _that.script,
          _that.header,
          _that.jsLib,
          _that.concurrentRate,
          _that.enabledCookieJar,
          _that.customOrder,
          _that.lastRunAt,
          _that.lastResult,
          _that.lastError,
          _that.lastLog,
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
      String id,
      String name,
      bool enable,
      String? cron,
      @JsonKey(name: 'loginUrl') String? loginUrl,
      @JsonKey(name: 'loginUi') String? loginUi,
      @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
      String? comment,
      String script,
      String? header,
      @JsonKey(name: 'jsLib') String? jsLib,
      @JsonKey(name: 'concurrentRate') String? concurrentRate,
      @JsonKey(name: 'enabledCookieJar') bool enabledCookieJar,
      @JsonKey(name: 'customOrder') int customOrder,
      @JsonKey(name: 'lastRunAt') int lastRunAt,
      @JsonKey(name: 'lastResult') String? lastResult,
      @JsonKey(name: 'lastError') String? lastError,
      @JsonKey(name: 'lastLog') String? lastLog,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AutoTaskRule() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.enable,
          _that.cron,
          _that.loginUrl,
          _that.loginUi,
          _that.loginCheckJs,
          _that.comment,
          _that.script,
          _that.header,
          _that.jsLib,
          _that.concurrentRate,
          _that.enabledCookieJar,
          _that.customOrder,
          _that.lastRunAt,
          _that.lastResult,
          _that.lastError,
          _that.lastLog,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AutoTaskRule implements AutoTaskRule {
  const _AutoTaskRule({
    this.id = '',
    this.name = '',
    this.enable = true,
    this.cron,
    @JsonKey(name: 'loginUrl') this.loginUrl,
    @JsonKey(name: 'loginUi') this.loginUi,
    @JsonKey(name: 'loginCheckJs') this.loginCheckJs,
    this.comment,
    this.script = '',
    this.header,
    @JsonKey(name: 'jsLib') this.jsLib,
    @JsonKey(name: 'concurrentRate') this.concurrentRate,
    @JsonKey(name: 'enabledCookieJar') this.enabledCookieJar = true,
    @JsonKey(name: 'customOrder') this.customOrder = 0,
    @JsonKey(name: 'lastRunAt') this.lastRunAt = 0,
    @JsonKey(name: 'lastResult') this.lastResult,
    @JsonKey(name: 'lastError') this.lastError,
    @JsonKey(name: 'lastLog') this.lastLog,
  });
  factory _AutoTaskRule.fromJson(Map<String, dynamic> json) =>
      _$AutoTaskRuleFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final bool enable;
  @override
  final String? cron;
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
  final String? comment;
  @override
  @JsonKey()
  final String script;
  @override
  final String? header;
  @override
  @JsonKey(name: 'jsLib')
  final String? jsLib;
  @override
  @JsonKey(name: 'concurrentRate')
  final String? concurrentRate;
  @override
  @JsonKey(name: 'enabledCookieJar')
  final bool enabledCookieJar;
  @override
  @JsonKey(name: 'customOrder')
  final int customOrder;
  @override
  @JsonKey(name: 'lastRunAt')
  final int lastRunAt;
  @override
  @JsonKey(name: 'lastResult')
  final String? lastResult;
  @override
  @JsonKey(name: 'lastError')
  final String? lastError;
  @override
  @JsonKey(name: 'lastLog')
  final String? lastLog;

  /// Create a copy of AutoTaskRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AutoTaskRuleCopyWith<_AutoTaskRule> get copyWith =>
      __$AutoTaskRuleCopyWithImpl<_AutoTaskRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AutoTaskRuleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AutoTaskRule &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.enable, enable) || other.enable == enable) &&
            (identical(other.cron, cron) || other.cron == cron) &&
            (identical(other.loginUrl, loginUrl) ||
                other.loginUrl == loginUrl) &&
            (identical(other.loginUi, loginUi) || other.loginUi == loginUi) &&
            (identical(other.loginCheckJs, loginCheckJs) ||
                other.loginCheckJs == loginCheckJs) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            (identical(other.script, script) || other.script == script) &&
            (identical(other.header, header) || other.header == header) &&
            (identical(other.jsLib, jsLib) || other.jsLib == jsLib) &&
            (identical(other.concurrentRate, concurrentRate) ||
                other.concurrentRate == concurrentRate) &&
            (identical(other.enabledCookieJar, enabledCookieJar) ||
                other.enabledCookieJar == enabledCookieJar) &&
            (identical(other.customOrder, customOrder) ||
                other.customOrder == customOrder) &&
            (identical(other.lastRunAt, lastRunAt) ||
                other.lastRunAt == lastRunAt) &&
            (identical(other.lastResult, lastResult) ||
                other.lastResult == lastResult) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.lastLog, lastLog) || other.lastLog == lastLog));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      id,
      name,
      enable,
      cron,
      loginUrl,
      loginUi,
      loginCheckJs,
      comment,
      script,
      header,
      jsLib,
      concurrentRate,
      enabledCookieJar,
      customOrder,
      lastRunAt,
      lastResult,
      lastError,
      lastLog,
    );
  }

  @override
  String toString() {
    return 'AutoTaskRule(id: $id, name: $name, enable: $enable, cron: $cron, loginUrl: $loginUrl, loginUi: $loginUi, loginCheckJs: $loginCheckJs, comment: $comment, script: $script, header: $header, jsLib: $jsLib, concurrentRate: $concurrentRate, enabledCookieJar: $enabledCookieJar, customOrder: $customOrder, lastRunAt: $lastRunAt, lastResult: $lastResult, lastError: $lastError, lastLog: $lastLog)';
  }
}

/// @nodoc
abstract mixin class _$AutoTaskRuleCopyWith<$Res>
    implements $AutoTaskRuleCopyWith<$Res> {
  factory _$AutoTaskRuleCopyWith(
    _AutoTaskRule value,
    $Res Function(_AutoTaskRule) _then,
  ) = __$AutoTaskRuleCopyWithImpl;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    bool enable,
    String? cron,
    @JsonKey(name: 'loginUrl') String? loginUrl,
    @JsonKey(name: 'loginUi') String? loginUi,
    @JsonKey(name: 'loginCheckJs') String? loginCheckJs,
    String? comment,
    String script,
    String? header,
    @JsonKey(name: 'jsLib') String? jsLib,
    @JsonKey(name: 'concurrentRate') String? concurrentRate,
    @JsonKey(name: 'enabledCookieJar') bool enabledCookieJar,
    @JsonKey(name: 'customOrder') int customOrder,
    @JsonKey(name: 'lastRunAt') int lastRunAt,
    @JsonKey(name: 'lastResult') String? lastResult,
    @JsonKey(name: 'lastError') String? lastError,
    @JsonKey(name: 'lastLog') String? lastLog,
  });
}

/// @nodoc
class __$AutoTaskRuleCopyWithImpl<$Res>
    implements _$AutoTaskRuleCopyWith<$Res> {
  __$AutoTaskRuleCopyWithImpl(this._self, this._then);

  final _AutoTaskRule _self;
  final $Res Function(_AutoTaskRule) _then;

  /// Create a copy of AutoTaskRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? enable = null,
    Object? cron = freezed,
    Object? loginUrl = freezed,
    Object? loginUi = freezed,
    Object? loginCheckJs = freezed,
    Object? comment = freezed,
    Object? script = null,
    Object? header = freezed,
    Object? jsLib = freezed,
    Object? concurrentRate = freezed,
    Object? enabledCookieJar = null,
    Object? customOrder = null,
    Object? lastRunAt = null,
    Object? lastResult = freezed,
    Object? lastError = freezed,
    Object? lastLog = freezed,
  }) {
    return _then(
      _AutoTaskRule(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        enable: null == enable
            ? _self.enable
            : enable // ignore: cast_nullable_to_non_nullable
                  as bool,
        cron: freezed == cron
            ? _self.cron
            : cron // ignore: cast_nullable_to_non_nullable
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
        comment: freezed == comment
            ? _self.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String?,
        script: null == script
            ? _self.script
            : script // ignore: cast_nullable_to_non_nullable
                  as String,
        header: freezed == header
            ? _self.header
            : header // ignore: cast_nullable_to_non_nullable
                  as String?,
        jsLib: freezed == jsLib
            ? _self.jsLib
            : jsLib // ignore: cast_nullable_to_non_nullable
                  as String?,
        concurrentRate: freezed == concurrentRate
            ? _self.concurrentRate
            : concurrentRate // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabledCookieJar: null == enabledCookieJar
            ? _self.enabledCookieJar
            : enabledCookieJar // ignore: cast_nullable_to_non_nullable
                  as bool,
        customOrder: null == customOrder
            ? _self.customOrder
            : customOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        lastRunAt: null == lastRunAt
            ? _self.lastRunAt
            : lastRunAt // ignore: cast_nullable_to_non_nullable
                  as int,
        lastResult: freezed == lastResult
            ? _self.lastResult
            : lastResult // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastError: freezed == lastError
            ? _self.lastError
            : lastError // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastLog: freezed == lastLog
            ? _self.lastLog
            : lastLog // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
mixin _$RssArticle {
  String get origin;
  String get sort;
  String get title;
  int get order;
  String get link;
  @JsonKey(name: 'pubDate')
  String? get pubDate;
  String? get description;
  String? get content;
  String? get image;
  String get group;
  bool get read;
  String? get variable;
  @JsonKey(name: 'type')
  int get articleType;
  @JsonKey(name: 'durPos')
  int get durPos;

  /// Create a copy of RssArticle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RssArticleCopyWith<RssArticle> get copyWith =>
      _$RssArticleCopyWithImpl<RssArticle>(this as RssArticle, _$identity);

  /// Serializes this RssArticle to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as RssArticle;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RssArticle &&
            (identical(other.origin, _this.origin) ||
                other.origin == _this.origin) &&
            (identical(other.sort, _this.sort) || other.sort == _this.sort) &&
            (identical(other.title, _this.title) ||
                other.title == _this.title) &&
            (identical(other.order, _this.order) ||
                other.order == _this.order) &&
            (identical(other.link, _this.link) || other.link == _this.link) &&
            (identical(other.pubDate, _this.pubDate) ||
                other.pubDate == _this.pubDate) &&
            (identical(other.description, _this.description) ||
                other.description == _this.description) &&
            (identical(other.content, _this.content) ||
                other.content == _this.content) &&
            (identical(other.image, _this.image) ||
                other.image == _this.image) &&
            (identical(other.group, _this.group) ||
                other.group == _this.group) &&
            (identical(other.read, _this.read) || other.read == _this.read) &&
            (identical(other.variable, _this.variable) ||
                other.variable == _this.variable) &&
            (identical(other.articleType, _this.articleType) ||
                other.articleType == _this.articleType) &&
            (identical(other.durPos, _this.durPos) ||
                other.durPos == _this.durPos));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as RssArticle;
    return Object.hash(
      runtimeType,
      _this.origin,
      _this.sort,
      _this.title,
      _this.order,
      _this.link,
      _this.pubDate,
      _this.description,
      _this.content,
      _this.image,
      _this.group,
      _this.read,
      _this.variable,
      _this.articleType,
      _this.durPos,
    );
  }

  @override
  String toString() {
    final _this = this as RssArticle;
    return 'RssArticle(origin: ${_this.origin}, sort: ${_this.sort}, title: ${_this.title}, order: ${_this.order}, link: ${_this.link}, pubDate: ${_this.pubDate}, description: ${_this.description}, content: ${_this.content}, image: ${_this.image}, group: ${_this.group}, read: ${_this.read}, variable: ${_this.variable}, articleType: ${_this.articleType}, durPos: ${_this.durPos})';
  }
}

/// @nodoc
abstract mixin class $RssArticleCopyWith<$Res> {
  factory $RssArticleCopyWith(
    RssArticle value,
    $Res Function(RssArticle) _then,
  ) = _$RssArticleCopyWithImpl;
  @useResult
  $Res call({
    String origin,
    String sort,
    String title,
    int order,
    String link,
    @JsonKey(name: 'pubDate') String? pubDate,
    String? description,
    String? content,
    String? image,
    String group,
    bool read,
    String? variable,
    @JsonKey(name: 'type') int articleType,
    @JsonKey(name: 'durPos') int durPos,
  });
}

/// @nodoc
class _$RssArticleCopyWithImpl<$Res> implements $RssArticleCopyWith<$Res> {
  _$RssArticleCopyWithImpl(this._self, this._then);

  final RssArticle _self;
  final $Res Function(RssArticle) _then;

  /// Create a copy of RssArticle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? origin = null,
    Object? sort = null,
    Object? title = null,
    Object? order = null,
    Object? link = null,
    Object? pubDate = freezed,
    Object? description = freezed,
    Object? content = freezed,
    Object? image = freezed,
    Object? group = null,
    Object? read = null,
    Object? variable = freezed,
    Object? articleType = null,
    Object? durPos = null,
  }) {
    return _then(
      RssArticle(
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        sort: null == sort
            ? _self.sort
            : sort // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        order: null == order
            ? _self.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        link: null == link
            ? _self.link
            : link // ignore: cast_nullable_to_non_nullable
                  as String,
        pubDate: freezed == pubDate
            ? _self.pubDate
            : pubDate // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _self.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        content: freezed == content
            ? _self.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        image: freezed == image
            ? _self.image
            : image // ignore: cast_nullable_to_non_nullable
                  as String?,
        group: null == group
            ? _self.group
            : group // ignore: cast_nullable_to_non_nullable
                  as String,
        read: null == read
            ? _self.read
            : read // ignore: cast_nullable_to_non_nullable
                  as bool,
        variable: freezed == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String?,
        articleType: null == articleType
            ? _self.articleType
            : articleType // ignore: cast_nullable_to_non_nullable
                  as int,
        durPos: null == durPos
            ? _self.durPos
            : durPos // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [RssArticle].
extension RssArticlePatterns on RssArticle {
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
    TResult Function(_RssArticle value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssArticle() when $default != null:
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
    TResult Function(_RssArticle value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssArticle():
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
    TResult? Function(_RssArticle value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssArticle() when $default != null:
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
      String sort,
      String title,
      int order,
      String link,
      @JsonKey(name: 'pubDate') String? pubDate,
      String? description,
      String? content,
      String? image,
      String group,
      bool read,
      String? variable,
      @JsonKey(name: 'type') int articleType,
      @JsonKey(name: 'durPos') int durPos,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssArticle() when $default != null:
        return $default(
          _that.origin,
          _that.sort,
          _that.title,
          _that.order,
          _that.link,
          _that.pubDate,
          _that.description,
          _that.content,
          _that.image,
          _that.group,
          _that.read,
          _that.variable,
          _that.articleType,
          _that.durPos,
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
      String origin,
      String sort,
      String title,
      int order,
      String link,
      @JsonKey(name: 'pubDate') String? pubDate,
      String? description,
      String? content,
      String? image,
      String group,
      bool read,
      String? variable,
      @JsonKey(name: 'type') int articleType,
      @JsonKey(name: 'durPos') int durPos,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssArticle():
        return $default(
          _that.origin,
          _that.sort,
          _that.title,
          _that.order,
          _that.link,
          _that.pubDate,
          _that.description,
          _that.content,
          _that.image,
          _that.group,
          _that.read,
          _that.variable,
          _that.articleType,
          _that.durPos,
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
      String origin,
      String sort,
      String title,
      int order,
      String link,
      @JsonKey(name: 'pubDate') String? pubDate,
      String? description,
      String? content,
      String? image,
      String group,
      bool read,
      String? variable,
      @JsonKey(name: 'type') int articleType,
      @JsonKey(name: 'durPos') int durPos,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssArticle() when $default != null:
        return $default(
          _that.origin,
          _that.sort,
          _that.title,
          _that.order,
          _that.link,
          _that.pubDate,
          _that.description,
          _that.content,
          _that.image,
          _that.group,
          _that.read,
          _that.variable,
          _that.articleType,
          _that.durPos,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RssArticle implements RssArticle {
  const _RssArticle({
    this.origin = '',
    this.sort = '',
    this.title = '',
    this.order = 0,
    this.link = '',
    @JsonKey(name: 'pubDate') this.pubDate,
    this.description,
    this.content,
    this.image,
    this.group = '默认分组',
    this.read = false,
    this.variable,
    @JsonKey(name: 'type') this.articleType = 0,
    @JsonKey(name: 'durPos') this.durPos = 0,
  });
  factory _RssArticle.fromJson(Map<String, dynamic> json) =>
      _$RssArticleFromJson(json);

  @override
  @JsonKey()
  final String origin;
  @override
  @JsonKey()
  final String sort;
  @override
  @JsonKey()
  final String title;
  @override
  @JsonKey()
  final int order;
  @override
  @JsonKey()
  final String link;
  @override
  @JsonKey(name: 'pubDate')
  final String? pubDate;
  @override
  final String? description;
  @override
  final String? content;
  @override
  final String? image;
  @override
  @JsonKey()
  final String group;
  @override
  @JsonKey()
  final bool read;
  @override
  final String? variable;
  @override
  @JsonKey(name: 'type')
  final int articleType;
  @override
  @JsonKey(name: 'durPos')
  final int durPos;

  /// Create a copy of RssArticle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RssArticleCopyWith<_RssArticle> get copyWith =>
      __$RssArticleCopyWithImpl<_RssArticle>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RssArticleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RssArticle &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.sort, sort) || other.sort == sort) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.order, order) || other.order == order) &&
            (identical(other.link, link) || other.link == link) &&
            (identical(other.pubDate, pubDate) || other.pubDate == pubDate) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.image, image) || other.image == image) &&
            (identical(other.group, group) || other.group == group) &&
            (identical(other.read, read) || other.read == read) &&
            (identical(other.variable, variable) ||
                other.variable == variable) &&
            (identical(other.articleType, articleType) ||
                other.articleType == articleType) &&
            (identical(other.durPos, durPos) || other.durPos == durPos));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      origin,
      sort,
      title,
      order,
      link,
      pubDate,
      description,
      content,
      image,
      group,
      read,
      variable,
      articleType,
      durPos,
    );
  }

  @override
  String toString() {
    return 'RssArticle(origin: $origin, sort: $sort, title: $title, order: $order, link: $link, pubDate: $pubDate, description: $description, content: $content, image: $image, group: $group, read: $read, variable: $variable, articleType: $articleType, durPos: $durPos)';
  }
}

/// @nodoc
abstract mixin class _$RssArticleCopyWith<$Res>
    implements $RssArticleCopyWith<$Res> {
  factory _$RssArticleCopyWith(
    _RssArticle value,
    $Res Function(_RssArticle) _then,
  ) = __$RssArticleCopyWithImpl;
  @override
  @useResult
  $Res call({
    String origin,
    String sort,
    String title,
    int order,
    String link,
    @JsonKey(name: 'pubDate') String? pubDate,
    String? description,
    String? content,
    String? image,
    String group,
    bool read,
    String? variable,
    @JsonKey(name: 'type') int articleType,
    @JsonKey(name: 'durPos') int durPos,
  });
}

/// @nodoc
class __$RssArticleCopyWithImpl<$Res> implements _$RssArticleCopyWith<$Res> {
  __$RssArticleCopyWithImpl(this._self, this._then);

  final _RssArticle _self;
  final $Res Function(_RssArticle) _then;

  /// Create a copy of RssArticle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? origin = null,
    Object? sort = null,
    Object? title = null,
    Object? order = null,
    Object? link = null,
    Object? pubDate = freezed,
    Object? description = freezed,
    Object? content = freezed,
    Object? image = freezed,
    Object? group = null,
    Object? read = null,
    Object? variable = freezed,
    Object? articleType = null,
    Object? durPos = null,
  }) {
    return _then(
      _RssArticle(
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        sort: null == sort
            ? _self.sort
            : sort // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        order: null == order
            ? _self.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        link: null == link
            ? _self.link
            : link // ignore: cast_nullable_to_non_nullable
                  as String,
        pubDate: freezed == pubDate
            ? _self.pubDate
            : pubDate // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _self.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        content: freezed == content
            ? _self.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        image: freezed == image
            ? _self.image
            : image // ignore: cast_nullable_to_non_nullable
                  as String?,
        group: null == group
            ? _self.group
            : group // ignore: cast_nullable_to_non_nullable
                  as String,
        read: null == read
            ? _self.read
            : read // ignore: cast_nullable_to_non_nullable
                  as bool,
        variable: freezed == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String?,
        articleType: null == articleType
            ? _self.articleType
            : articleType // ignore: cast_nullable_to_non_nullable
                  as int,
        durPos: null == durPos
            ? _self.durPos
            : durPos // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$RssStar {
  String get origin;
  String get sort;
  String get title;
  @JsonKey(name: 'starTime')
  int get starTime;
  String get link;
  @JsonKey(name: 'pubDate')
  String? get pubDate;
  String? get description;
  String? get content;
  String? get image;
  String get group;
  String? get variable;
  @JsonKey(name: 'type')
  int get starType;
  @JsonKey(name: 'durPos')
  int get durPos;

  /// Create a copy of RssStar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RssStarCopyWith<RssStar> get copyWith =>
      _$RssStarCopyWithImpl<RssStar>(this as RssStar, _$identity);

  /// Serializes this RssStar to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as RssStar;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RssStar &&
            (identical(other.origin, _this.origin) ||
                other.origin == _this.origin) &&
            (identical(other.sort, _this.sort) || other.sort == _this.sort) &&
            (identical(other.title, _this.title) ||
                other.title == _this.title) &&
            (identical(other.starTime, _this.starTime) ||
                other.starTime == _this.starTime) &&
            (identical(other.link, _this.link) || other.link == _this.link) &&
            (identical(other.pubDate, _this.pubDate) ||
                other.pubDate == _this.pubDate) &&
            (identical(other.description, _this.description) ||
                other.description == _this.description) &&
            (identical(other.content, _this.content) ||
                other.content == _this.content) &&
            (identical(other.image, _this.image) ||
                other.image == _this.image) &&
            (identical(other.group, _this.group) ||
                other.group == _this.group) &&
            (identical(other.variable, _this.variable) ||
                other.variable == _this.variable) &&
            (identical(other.starType, _this.starType) ||
                other.starType == _this.starType) &&
            (identical(other.durPos, _this.durPos) ||
                other.durPos == _this.durPos));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as RssStar;
    return Object.hash(
      runtimeType,
      _this.origin,
      _this.sort,
      _this.title,
      _this.starTime,
      _this.link,
      _this.pubDate,
      _this.description,
      _this.content,
      _this.image,
      _this.group,
      _this.variable,
      _this.starType,
      _this.durPos,
    );
  }

  @override
  String toString() {
    final _this = this as RssStar;
    return 'RssStar(origin: ${_this.origin}, sort: ${_this.sort}, title: ${_this.title}, starTime: ${_this.starTime}, link: ${_this.link}, pubDate: ${_this.pubDate}, description: ${_this.description}, content: ${_this.content}, image: ${_this.image}, group: ${_this.group}, variable: ${_this.variable}, starType: ${_this.starType}, durPos: ${_this.durPos})';
  }
}

/// @nodoc
abstract mixin class $RssStarCopyWith<$Res> {
  factory $RssStarCopyWith(RssStar value, $Res Function(RssStar) _then) =
      _$RssStarCopyWithImpl;
  @useResult
  $Res call({
    String origin,
    String sort,
    String title,
    @JsonKey(name: 'starTime') int starTime,
    String link,
    @JsonKey(name: 'pubDate') String? pubDate,
    String? description,
    String? content,
    String? image,
    String group,
    String? variable,
    @JsonKey(name: 'type') int starType,
    @JsonKey(name: 'durPos') int durPos,
  });
}

/// @nodoc
class _$RssStarCopyWithImpl<$Res> implements $RssStarCopyWith<$Res> {
  _$RssStarCopyWithImpl(this._self, this._then);

  final RssStar _self;
  final $Res Function(RssStar) _then;

  /// Create a copy of RssStar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? origin = null,
    Object? sort = null,
    Object? title = null,
    Object? starTime = null,
    Object? link = null,
    Object? pubDate = freezed,
    Object? description = freezed,
    Object? content = freezed,
    Object? image = freezed,
    Object? group = null,
    Object? variable = freezed,
    Object? starType = null,
    Object? durPos = null,
  }) {
    return _then(
      RssStar(
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        sort: null == sort
            ? _self.sort
            : sort // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        starTime: null == starTime
            ? _self.starTime
            : starTime // ignore: cast_nullable_to_non_nullable
                  as int,
        link: null == link
            ? _self.link
            : link // ignore: cast_nullable_to_non_nullable
                  as String,
        pubDate: freezed == pubDate
            ? _self.pubDate
            : pubDate // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _self.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        content: freezed == content
            ? _self.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        image: freezed == image
            ? _self.image
            : image // ignore: cast_nullable_to_non_nullable
                  as String?,
        group: null == group
            ? _self.group
            : group // ignore: cast_nullable_to_non_nullable
                  as String,
        variable: freezed == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String?,
        starType: null == starType
            ? _self.starType
            : starType // ignore: cast_nullable_to_non_nullable
                  as int,
        durPos: null == durPos
            ? _self.durPos
            : durPos // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [RssStar].
extension RssStarPatterns on RssStar {
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
    TResult Function(_RssStar value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssStar() when $default != null:
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
    TResult Function(_RssStar value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssStar():
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
    TResult? Function(_RssStar value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssStar() when $default != null:
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
      String sort,
      String title,
      @JsonKey(name: 'starTime') int starTime,
      String link,
      @JsonKey(name: 'pubDate') String? pubDate,
      String? description,
      String? content,
      String? image,
      String group,
      String? variable,
      @JsonKey(name: 'type') int starType,
      @JsonKey(name: 'durPos') int durPos,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssStar() when $default != null:
        return $default(
          _that.origin,
          _that.sort,
          _that.title,
          _that.starTime,
          _that.link,
          _that.pubDate,
          _that.description,
          _that.content,
          _that.image,
          _that.group,
          _that.variable,
          _that.starType,
          _that.durPos,
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
      String origin,
      String sort,
      String title,
      @JsonKey(name: 'starTime') int starTime,
      String link,
      @JsonKey(name: 'pubDate') String? pubDate,
      String? description,
      String? content,
      String? image,
      String group,
      String? variable,
      @JsonKey(name: 'type') int starType,
      @JsonKey(name: 'durPos') int durPos,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssStar():
        return $default(
          _that.origin,
          _that.sort,
          _that.title,
          _that.starTime,
          _that.link,
          _that.pubDate,
          _that.description,
          _that.content,
          _that.image,
          _that.group,
          _that.variable,
          _that.starType,
          _that.durPos,
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
      String origin,
      String sort,
      String title,
      @JsonKey(name: 'starTime') int starTime,
      String link,
      @JsonKey(name: 'pubDate') String? pubDate,
      String? description,
      String? content,
      String? image,
      String group,
      String? variable,
      @JsonKey(name: 'type') int starType,
      @JsonKey(name: 'durPos') int durPos,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssStar() when $default != null:
        return $default(
          _that.origin,
          _that.sort,
          _that.title,
          _that.starTime,
          _that.link,
          _that.pubDate,
          _that.description,
          _that.content,
          _that.image,
          _that.group,
          _that.variable,
          _that.starType,
          _that.durPos,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RssStar implements RssStar {
  const _RssStar({
    this.origin = '',
    this.sort = '',
    this.title = '',
    @JsonKey(name: 'starTime') this.starTime = 0,
    this.link = '',
    @JsonKey(name: 'pubDate') this.pubDate,
    this.description,
    this.content,
    this.image,
    this.group = '默认分组',
    this.variable,
    @JsonKey(name: 'type') this.starType = 0,
    @JsonKey(name: 'durPos') this.durPos = 0,
  });
  factory _RssStar.fromJson(Map<String, dynamic> json) =>
      _$RssStarFromJson(json);

  @override
  @JsonKey()
  final String origin;
  @override
  @JsonKey()
  final String sort;
  @override
  @JsonKey()
  final String title;
  @override
  @JsonKey(name: 'starTime')
  final int starTime;
  @override
  @JsonKey()
  final String link;
  @override
  @JsonKey(name: 'pubDate')
  final String? pubDate;
  @override
  final String? description;
  @override
  final String? content;
  @override
  final String? image;
  @override
  @JsonKey()
  final String group;
  @override
  final String? variable;
  @override
  @JsonKey(name: 'type')
  final int starType;
  @override
  @JsonKey(name: 'durPos')
  final int durPos;

  /// Create a copy of RssStar
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RssStarCopyWith<_RssStar> get copyWith =>
      __$RssStarCopyWithImpl<_RssStar>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RssStarToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RssStar &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.sort, sort) || other.sort == sort) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.starTime, starTime) ||
                other.starTime == starTime) &&
            (identical(other.link, link) || other.link == link) &&
            (identical(other.pubDate, pubDate) || other.pubDate == pubDate) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.image, image) || other.image == image) &&
            (identical(other.group, group) || other.group == group) &&
            (identical(other.variable, variable) ||
                other.variable == variable) &&
            (identical(other.starType, starType) ||
                other.starType == starType) &&
            (identical(other.durPos, durPos) || other.durPos == durPos));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      origin,
      sort,
      title,
      starTime,
      link,
      pubDate,
      description,
      content,
      image,
      group,
      variable,
      starType,
      durPos,
    );
  }

  @override
  String toString() {
    return 'RssStar(origin: $origin, sort: $sort, title: $title, starTime: $starTime, link: $link, pubDate: $pubDate, description: $description, content: $content, image: $image, group: $group, variable: $variable, starType: $starType, durPos: $durPos)';
  }
}

/// @nodoc
abstract mixin class _$RssStarCopyWith<$Res> implements $RssStarCopyWith<$Res> {
  factory _$RssStarCopyWith(_RssStar value, $Res Function(_RssStar) _then) =
      __$RssStarCopyWithImpl;
  @override
  @useResult
  $Res call({
    String origin,
    String sort,
    String title,
    @JsonKey(name: 'starTime') int starTime,
    String link,
    @JsonKey(name: 'pubDate') String? pubDate,
    String? description,
    String? content,
    String? image,
    String group,
    String? variable,
    @JsonKey(name: 'type') int starType,
    @JsonKey(name: 'durPos') int durPos,
  });
}

/// @nodoc
class __$RssStarCopyWithImpl<$Res> implements _$RssStarCopyWith<$Res> {
  __$RssStarCopyWithImpl(this._self, this._then);

  final _RssStar _self;
  final $Res Function(_RssStar) _then;

  /// Create a copy of RssStar
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? origin = null,
    Object? sort = null,
    Object? title = null,
    Object? starTime = null,
    Object? link = null,
    Object? pubDate = freezed,
    Object? description = freezed,
    Object? content = freezed,
    Object? image = freezed,
    Object? group = null,
    Object? variable = freezed,
    Object? starType = null,
    Object? durPos = null,
  }) {
    return _then(
      _RssStar(
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        sort: null == sort
            ? _self.sort
            : sort // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        starTime: null == starTime
            ? _self.starTime
            : starTime // ignore: cast_nullable_to_non_nullable
                  as int,
        link: null == link
            ? _self.link
            : link // ignore: cast_nullable_to_non_nullable
                  as String,
        pubDate: freezed == pubDate
            ? _self.pubDate
            : pubDate // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _self.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        content: freezed == content
            ? _self.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        image: freezed == image
            ? _self.image
            : image // ignore: cast_nullable_to_non_nullable
                  as String?,
        group: null == group
            ? _self.group
            : group // ignore: cast_nullable_to_non_nullable
                  as String,
        variable: freezed == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String?,
        starType: null == starType
            ? _self.starType
            : starType // ignore: cast_nullable_to_non_nullable
                  as int,
        durPos: null == durPos
            ? _self.durPos
            : durPos // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$Cookie {
  String get url;
  String get cookie;

  /// Create a copy of Cookie
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CookieCopyWith<Cookie> get copyWith =>
      _$CookieCopyWithImpl<Cookie>(this as Cookie, _$identity);

  /// Serializes this Cookie to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as Cookie;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Cookie &&
            (identical(other.url, _this.url) || other.url == _this.url) &&
            (identical(other.cookie, _this.cookie) ||
                other.cookie == _this.cookie));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as Cookie;
    return Object.hash(runtimeType, _this.url, _this.cookie);
  }

  @override
  String toString() {
    final _this = this as Cookie;
    return 'Cookie(url: ${_this.url}, cookie: ${_this.cookie})';
  }
}

/// @nodoc
abstract mixin class $CookieCopyWith<$Res> {
  factory $CookieCopyWith(Cookie value, $Res Function(Cookie) _then) =
      _$CookieCopyWithImpl;
  @useResult
  $Res call({String url, String cookie});
}

/// @nodoc
class _$CookieCopyWithImpl<$Res> implements $CookieCopyWith<$Res> {
  _$CookieCopyWithImpl(this._self, this._then);

  final Cookie _self;
  final $Res Function(Cookie) _then;

  /// Create a copy of Cookie
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? url = null, Object? cookie = null}) {
    return _then(
      Cookie(
        url: null == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        cookie: null == cookie
            ? _self.cookie
            : cookie // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [Cookie].
extension CookiePatterns on Cookie {
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
    TResult Function(_Cookie value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Cookie() when $default != null:
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
    TResult Function(_Cookie value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Cookie():
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
    TResult? Function(_Cookie value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Cookie() when $default != null:
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
    TResult Function(String url, String cookie)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Cookie() when $default != null:
        return $default(_that.url, _that.cookie);
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
    TResult Function(String url, String cookie) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Cookie():
        return $default(_that.url, _that.cookie);
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
    TResult? Function(String url, String cookie)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Cookie() when $default != null:
        return $default(_that.url, _that.cookie);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Cookie implements Cookie {
  const _Cookie({this.url = '', this.cookie = ''});
  factory _Cookie.fromJson(Map<String, dynamic> json) => _$CookieFromJson(json);

  @override
  @JsonKey()
  final String url;
  @override
  @JsonKey()
  final String cookie;

  /// Create a copy of Cookie
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CookieCopyWith<_Cookie> get copyWith =>
      __$CookieCopyWithImpl<_Cookie>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CookieToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Cookie &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.cookie, cookie) || other.cookie == cookie));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, url, cookie);
  }

  @override
  String toString() {
    return 'Cookie(url: $url, cookie: $cookie)';
  }
}

/// @nodoc
abstract mixin class _$CookieCopyWith<$Res> implements $CookieCopyWith<$Res> {
  factory _$CookieCopyWith(_Cookie value, $Res Function(_Cookie) _then) =
      __$CookieCopyWithImpl;
  @override
  @useResult
  $Res call({String url, String cookie});
}

/// @nodoc
class __$CookieCopyWithImpl<$Res> implements _$CookieCopyWith<$Res> {
  __$CookieCopyWithImpl(this._self, this._then);

  final _Cookie _self;
  final $Res Function(_Cookie) _then;

  /// Create a copy of Cookie
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? url = null, Object? cookie = null}) {
    return _then(
      _Cookie(
        url: null == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        cookie: null == cookie
            ? _self.cookie
            : cookie // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
mixin _$Cache {
  String get key;
  String? get value;
  int get deadline;

  /// Create a copy of Cache
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CacheCopyWith<Cache> get copyWith =>
      _$CacheCopyWithImpl<Cache>(this as Cache, _$identity);

  /// Serializes this Cache to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as Cache;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Cache &&
            (identical(other.key, _this.key) || other.key == _this.key) &&
            (identical(other.value, _this.value) ||
                other.value == _this.value) &&
            (identical(other.deadline, _this.deadline) ||
                other.deadline == _this.deadline));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as Cache;
    return Object.hash(runtimeType, _this.key, _this.value, _this.deadline);
  }

  @override
  String toString() {
    final _this = this as Cache;
    return 'Cache(key: ${_this.key}, value: ${_this.value}, deadline: ${_this.deadline})';
  }
}

/// @nodoc
abstract mixin class $CacheCopyWith<$Res> {
  factory $CacheCopyWith(Cache value, $Res Function(Cache) _then) =
      _$CacheCopyWithImpl;
  @useResult
  $Res call({String key, String? value, int deadline});
}

/// @nodoc
class _$CacheCopyWithImpl<$Res> implements $CacheCopyWith<$Res> {
  _$CacheCopyWithImpl(this._self, this._then);

  final Cache _self;
  final $Res Function(Cache) _then;

  /// Create a copy of Cache
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? value = freezed,
    Object? deadline = null,
  }) {
    return _then(
      Cache(
        key: null == key
            ? _self.key
            : key // ignore: cast_nullable_to_non_nullable
                  as String,
        value: freezed == value
            ? _self.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String?,
        deadline: null == deadline
            ? _self.deadline
            : deadline // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [Cache].
extension CachePatterns on Cache {
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
    TResult Function(_Cache value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Cache() when $default != null:
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
    TResult Function(_Cache value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Cache():
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
    TResult? Function(_Cache value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Cache() when $default != null:
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
    TResult Function(String key, String? value, int deadline)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Cache() when $default != null:
        return $default(_that.key, _that.value, _that.deadline);
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
    TResult Function(String key, String? value, int deadline) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Cache():
        return $default(_that.key, _that.value, _that.deadline);
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
    TResult? Function(String key, String? value, int deadline)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Cache() when $default != null:
        return $default(_that.key, _that.value, _that.deadline);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Cache implements Cache {
  const _Cache({this.key = '', this.value, this.deadline = 0});
  factory _Cache.fromJson(Map<String, dynamic> json) => _$CacheFromJson(json);

  @override
  @JsonKey()
  final String key;
  @override
  final String? value;
  @override
  @JsonKey()
  final int deadline;

  /// Create a copy of Cache
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CacheCopyWith<_Cache> get copyWith =>
      __$CacheCopyWithImpl<_Cache>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CacheToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Cache &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, key, value, deadline);
  }

  @override
  String toString() {
    return 'Cache(key: $key, value: $value, deadline: $deadline)';
  }
}

/// @nodoc
abstract mixin class _$CacheCopyWith<$Res> implements $CacheCopyWith<$Res> {
  factory _$CacheCopyWith(_Cache value, $Res Function(_Cache) _then) =
      __$CacheCopyWithImpl;
  @override
  @useResult
  $Res call({String key, String? value, int deadline});
}

/// @nodoc
class __$CacheCopyWithImpl<$Res> implements _$CacheCopyWith<$Res> {
  __$CacheCopyWithImpl(this._self, this._then);

  final _Cache _self;
  final $Res Function(_Cache) _then;

  /// Create a copy of Cache
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? key = null,
    Object? value = freezed,
    Object? deadline = null,
  }) {
    return _then(
      _Cache(
        key: null == key
            ? _self.key
            : key // ignore: cast_nullable_to_non_nullable
                  as String,
        value: freezed == value
            ? _self.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String?,
        deadline: null == deadline
            ? _self.deadline
            : deadline // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$DictRule {
  int get id;
  String get name;
  @JsonKey(name: 'urlRule')
  String get urlRule;
  @JsonKey(name: 'showRule')
  String get showRule;
  bool get enabled;
  @JsonKey(name: 'sortNumber')
  int get sortNumber;

  /// Create a copy of DictRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DictRuleCopyWith<DictRule> get copyWith =>
      _$DictRuleCopyWithImpl<DictRule>(this as DictRule, _$identity);

  /// Serializes this DictRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as DictRule;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DictRule &&
            (identical(other.id, _this.id) || other.id == _this.id) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.urlRule, _this.urlRule) ||
                other.urlRule == _this.urlRule) &&
            (identical(other.showRule, _this.showRule) ||
                other.showRule == _this.showRule) &&
            (identical(other.enabled, _this.enabled) ||
                other.enabled == _this.enabled) &&
            (identical(other.sortNumber, _this.sortNumber) ||
                other.sortNumber == _this.sortNumber));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as DictRule;
    return Object.hash(
      runtimeType,
      _this.id,
      _this.name,
      _this.urlRule,
      _this.showRule,
      _this.enabled,
      _this.sortNumber,
    );
  }

  @override
  String toString() {
    final _this = this as DictRule;
    return 'DictRule(id: ${_this.id}, name: ${_this.name}, urlRule: ${_this.urlRule}, showRule: ${_this.showRule}, enabled: ${_this.enabled}, sortNumber: ${_this.sortNumber})';
  }
}

/// @nodoc
abstract mixin class $DictRuleCopyWith<$Res> {
  factory $DictRuleCopyWith(DictRule value, $Res Function(DictRule) _then) =
      _$DictRuleCopyWithImpl;
  @useResult
  $Res call({
    int id,
    String name,
    @JsonKey(name: 'urlRule') String urlRule,
    @JsonKey(name: 'showRule') String showRule,
    bool enabled,
    @JsonKey(name: 'sortNumber') int sortNumber,
  });
}

/// @nodoc
class _$DictRuleCopyWithImpl<$Res> implements $DictRuleCopyWith<$Res> {
  _$DictRuleCopyWithImpl(this._self, this._then);

  final DictRule _self;
  final $Res Function(DictRule) _then;

  /// Create a copy of DictRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? urlRule = null,
    Object? showRule = null,
    Object? enabled = null,
    Object? sortNumber = null,
  }) {
    return _then(
      DictRule(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        urlRule: null == urlRule
            ? _self.urlRule
            : urlRule // ignore: cast_nullable_to_non_nullable
                  as String,
        showRule: null == showRule
            ? _self.showRule
            : showRule // ignore: cast_nullable_to_non_nullable
                  as String,
        enabled: null == enabled
            ? _self.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        sortNumber: null == sortNumber
            ? _self.sortNumber
            : sortNumber // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [DictRule].
extension DictRulePatterns on DictRule {
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
    TResult Function(_DictRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DictRule() when $default != null:
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
    TResult Function(_DictRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictRule():
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
    TResult? Function(_DictRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictRule() when $default != null:
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
      int id,
      String name,
      @JsonKey(name: 'urlRule') String urlRule,
      @JsonKey(name: 'showRule') String showRule,
      bool enabled,
      @JsonKey(name: 'sortNumber') int sortNumber,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DictRule() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.urlRule,
          _that.showRule,
          _that.enabled,
          _that.sortNumber,
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
      int id,
      String name,
      @JsonKey(name: 'urlRule') String urlRule,
      @JsonKey(name: 'showRule') String showRule,
      bool enabled,
      @JsonKey(name: 'sortNumber') int sortNumber,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictRule():
        return $default(
          _that.id,
          _that.name,
          _that.urlRule,
          _that.showRule,
          _that.enabled,
          _that.sortNumber,
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
      int id,
      String name,
      @JsonKey(name: 'urlRule') String urlRule,
      @JsonKey(name: 'showRule') String showRule,
      bool enabled,
      @JsonKey(name: 'sortNumber') int sortNumber,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictRule() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.urlRule,
          _that.showRule,
          _that.enabled,
          _that.sortNumber,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DictRule implements DictRule {
  const _DictRule({
    this.id = 0,
    this.name = '',
    @JsonKey(name: 'urlRule') this.urlRule = '',
    @JsonKey(name: 'showRule') this.showRule = '',
    this.enabled = true,
    @JsonKey(name: 'sortNumber') this.sortNumber = 0,
  });
  factory _DictRule.fromJson(Map<String, dynamic> json) =>
      _$DictRuleFromJson(json);

  @override
  @JsonKey()
  final int id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey(name: 'urlRule')
  final String urlRule;
  @override
  @JsonKey(name: 'showRule')
  final String showRule;
  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey(name: 'sortNumber')
  final int sortNumber;

  /// Create a copy of DictRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DictRuleCopyWith<_DictRule> get copyWith =>
      __$DictRuleCopyWithImpl<_DictRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DictRuleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DictRule &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.urlRule, urlRule) || other.urlRule == urlRule) &&
            (identical(other.showRule, showRule) ||
                other.showRule == showRule) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.sortNumber, sortNumber) ||
                other.sortNumber == sortNumber));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      id,
      name,
      urlRule,
      showRule,
      enabled,
      sortNumber,
    );
  }

  @override
  String toString() {
    return 'DictRule(id: $id, name: $name, urlRule: $urlRule, showRule: $showRule, enabled: $enabled, sortNumber: $sortNumber)';
  }
}

/// @nodoc
abstract mixin class _$DictRuleCopyWith<$Res>
    implements $DictRuleCopyWith<$Res> {
  factory _$DictRuleCopyWith(_DictRule value, $Res Function(_DictRule) _then) =
      __$DictRuleCopyWithImpl;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    @JsonKey(name: 'urlRule') String urlRule,
    @JsonKey(name: 'showRule') String showRule,
    bool enabled,
    @JsonKey(name: 'sortNumber') int sortNumber,
  });
}

/// @nodoc
class __$DictRuleCopyWithImpl<$Res> implements _$DictRuleCopyWith<$Res> {
  __$DictRuleCopyWithImpl(this._self, this._then);

  final _DictRule _self;
  final $Res Function(_DictRule) _then;

  /// Create a copy of DictRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? urlRule = null,
    Object? showRule = null,
    Object? enabled = null,
    Object? sortNumber = null,
  }) {
    return _then(
      _DictRule(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        urlRule: null == urlRule
            ? _self.urlRule
            : urlRule // ignore: cast_nullable_to_non_nullable
                  as String,
        showRule: null == showRule
            ? _self.showRule
            : showRule // ignore: cast_nullable_to_non_nullable
                  as String,
        enabled: null == enabled
            ? _self.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        sortNumber: null == sortNumber
            ? _self.sortNumber
            : sortNumber // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$Server {
  int get id;
  String get name;
  @JsonKey(name: 'type')
  String get serverType;
  String? get config;
  @JsonKey(name: 'sortNumber')
  int get sortNumber;

  /// Create a copy of Server
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ServerCopyWith<Server> get copyWith =>
      _$ServerCopyWithImpl<Server>(this as Server, _$identity);

  /// Serializes this Server to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as Server;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Server &&
            (identical(other.id, _this.id) || other.id == _this.id) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.serverType, _this.serverType) ||
                other.serverType == _this.serverType) &&
            (identical(other.config, _this.config) ||
                other.config == _this.config) &&
            (identical(other.sortNumber, _this.sortNumber) ||
                other.sortNumber == _this.sortNumber));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as Server;
    return Object.hash(
      runtimeType,
      _this.id,
      _this.name,
      _this.serverType,
      _this.config,
      _this.sortNumber,
    );
  }

  @override
  String toString() {
    final _this = this as Server;
    return 'Server(id: ${_this.id}, name: ${_this.name}, serverType: ${_this.serverType}, config: ${_this.config}, sortNumber: ${_this.sortNumber})';
  }
}

/// @nodoc
abstract mixin class $ServerCopyWith<$Res> {
  factory $ServerCopyWith(Server value, $Res Function(Server) _then) =
      _$ServerCopyWithImpl;
  @useResult
  $Res call({
    int id,
    String name,
    @JsonKey(name: 'type') String serverType,
    String? config,
    @JsonKey(name: 'sortNumber') int sortNumber,
  });
}

/// @nodoc
class _$ServerCopyWithImpl<$Res> implements $ServerCopyWith<$Res> {
  _$ServerCopyWithImpl(this._self, this._then);

  final Server _self;
  final $Res Function(Server) _then;

  /// Create a copy of Server
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? serverType = null,
    Object? config = freezed,
    Object? sortNumber = null,
  }) {
    return _then(
      Server(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        serverType: null == serverType
            ? _self.serverType
            : serverType // ignore: cast_nullable_to_non_nullable
                  as String,
        config: freezed == config
            ? _self.config
            : config // ignore: cast_nullable_to_non_nullable
                  as String?,
        sortNumber: null == sortNumber
            ? _self.sortNumber
            : sortNumber // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [Server].
extension ServerPatterns on Server {
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
    TResult Function(_Server value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Server() when $default != null:
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
    TResult Function(_Server value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Server():
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
    TResult? Function(_Server value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Server() when $default != null:
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
      int id,
      String name,
      @JsonKey(name: 'type') String serverType,
      String? config,
      @JsonKey(name: 'sortNumber') int sortNumber,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Server() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.serverType,
          _that.config,
          _that.sortNumber,
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
      int id,
      String name,
      @JsonKey(name: 'type') String serverType,
      String? config,
      @JsonKey(name: 'sortNumber') int sortNumber,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Server():
        return $default(
          _that.id,
          _that.name,
          _that.serverType,
          _that.config,
          _that.sortNumber,
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
      int id,
      String name,
      @JsonKey(name: 'type') String serverType,
      String? config,
      @JsonKey(name: 'sortNumber') int sortNumber,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Server() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.serverType,
          _that.config,
          _that.sortNumber,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Server implements Server {
  const _Server({
    this.id = 0,
    this.name = '',
    @JsonKey(name: 'type') this.serverType = 'WEBDAV',
    this.config,
    @JsonKey(name: 'sortNumber') this.sortNumber = 0,
  });
  factory _Server.fromJson(Map<String, dynamic> json) => _$ServerFromJson(json);

  @override
  @JsonKey()
  final int id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey(name: 'type')
  final String serverType;
  @override
  final String? config;
  @override
  @JsonKey(name: 'sortNumber')
  final int sortNumber;

  /// Create a copy of Server
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ServerCopyWith<_Server> get copyWith =>
      __$ServerCopyWithImpl<_Server>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ServerToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Server &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.serverType, serverType) ||
                other.serverType == serverType) &&
            (identical(other.config, config) || other.config == config) &&
            (identical(other.sortNumber, sortNumber) ||
                other.sortNumber == sortNumber));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, id, name, serverType, config, sortNumber);
  }

  @override
  String toString() {
    return 'Server(id: $id, name: $name, serverType: $serverType, config: $config, sortNumber: $sortNumber)';
  }
}

/// @nodoc
abstract mixin class _$ServerCopyWith<$Res> implements $ServerCopyWith<$Res> {
  factory _$ServerCopyWith(_Server value, $Res Function(_Server) _then) =
      __$ServerCopyWithImpl;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    @JsonKey(name: 'type') String serverType,
    String? config,
    @JsonKey(name: 'sortNumber') int sortNumber,
  });
}

/// @nodoc
class __$ServerCopyWithImpl<$Res> implements _$ServerCopyWith<$Res> {
  __$ServerCopyWithImpl(this._self, this._then);

  final _Server _self;
  final $Res Function(_Server) _then;

  /// Create a copy of Server
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? serverType = null,
    Object? config = freezed,
    Object? sortNumber = null,
  }) {
    return _then(
      _Server(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        serverType: null == serverType
            ? _self.serverType
            : serverType // ignore: cast_nullable_to_non_nullable
                  as String,
        config: freezed == config
            ? _self.config
            : config // ignore: cast_nullable_to_non_nullable
                  as String?,
        sortNumber: null == sortNumber
            ? _self.sortNumber
            : sortNumber // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$WebDavConfig {
  String get url;
  String get username;
  String get password;

  /// Create a copy of WebDavConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WebDavConfigCopyWith<WebDavConfig> get copyWith =>
      _$WebDavConfigCopyWithImpl<WebDavConfig>(
        this as WebDavConfig,
        _$identity,
      );

  /// Serializes this WebDavConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as WebDavConfig;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WebDavConfig &&
            (identical(other.url, _this.url) || other.url == _this.url) &&
            (identical(other.username, _this.username) ||
                other.username == _this.username) &&
            (identical(other.password, _this.password) ||
                other.password == _this.password));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as WebDavConfig;
    return Object.hash(runtimeType, _this.url, _this.username, _this.password);
  }

  @override
  String toString() {
    final _this = this as WebDavConfig;
    return 'WebDavConfig(url: ${_this.url}, username: ${_this.username}, password: ${_this.password})';
  }
}

/// @nodoc
abstract mixin class $WebDavConfigCopyWith<$Res> {
  factory $WebDavConfigCopyWith(
    WebDavConfig value,
    $Res Function(WebDavConfig) _then,
  ) = _$WebDavConfigCopyWithImpl;
  @useResult
  $Res call({String url, String username, String password});
}

/// @nodoc
class _$WebDavConfigCopyWithImpl<$Res> implements $WebDavConfigCopyWith<$Res> {
  _$WebDavConfigCopyWithImpl(this._self, this._then);

  final WebDavConfig _self;
  final $Res Function(WebDavConfig) _then;

  /// Create a copy of WebDavConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? username = null,
    Object? password = null,
  }) {
    return _then(
      WebDavConfig(
        url: null == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        username: null == username
            ? _self.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String,
        password: null == password
            ? _self.password
            : password // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [WebDavConfig].
extension WebDavConfigPatterns on WebDavConfig {
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
    TResult Function(_WebDavConfig value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WebDavConfig() when $default != null:
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
    TResult Function(_WebDavConfig value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WebDavConfig():
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
    TResult? Function(_WebDavConfig value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WebDavConfig() when $default != null:
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
    TResult Function(String url, String username, String password)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WebDavConfig() when $default != null:
        return $default(_that.url, _that.username, _that.password);
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
    TResult Function(String url, String username, String password) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WebDavConfig():
        return $default(_that.url, _that.username, _that.password);
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
    TResult? Function(String url, String username, String password)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WebDavConfig() when $default != null:
        return $default(_that.url, _that.username, _that.password);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _WebDavConfig implements WebDavConfig {
  const _WebDavConfig({this.url = '', this.username = '', this.password = ''});
  factory _WebDavConfig.fromJson(Map<String, dynamic> json) =>
      _$WebDavConfigFromJson(json);

  @override
  @JsonKey()
  final String url;
  @override
  @JsonKey()
  final String username;
  @override
  @JsonKey()
  final String password;

  /// Create a copy of WebDavConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WebDavConfigCopyWith<_WebDavConfig> get copyWith =>
      __$WebDavConfigCopyWithImpl<_WebDavConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WebDavConfigToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WebDavConfig &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.password, password) ||
                other.password == password));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, url, username, password);
  }

  @override
  String toString() {
    return 'WebDavConfig(url: $url, username: $username, password: $password)';
  }
}

/// @nodoc
abstract mixin class _$WebDavConfigCopyWith<$Res>
    implements $WebDavConfigCopyWith<$Res> {
  factory _$WebDavConfigCopyWith(
    _WebDavConfig value,
    $Res Function(_WebDavConfig) _then,
  ) = __$WebDavConfigCopyWithImpl;
  @override
  @useResult
  $Res call({String url, String username, String password});
}

/// @nodoc
class __$WebDavConfigCopyWithImpl<$Res>
    implements _$WebDavConfigCopyWith<$Res> {
  __$WebDavConfigCopyWithImpl(this._self, this._then);

  final _WebDavConfig _self;
  final $Res Function(_WebDavConfig) _then;

  /// Create a copy of WebDavConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? url = null,
    Object? username = null,
    Object? password = null,
  }) {
    return _then(
      _WebDavConfig(
        url: null == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        username: null == username
            ? _self.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String,
        password: null == password
            ? _self.password
            : password // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
mixin _$BookSourcePart {
  @JsonKey(name: 'bookSourceUrl')
  String get bookSourceUrl;
  @JsonKey(name: 'bookSourceName')
  String get bookSourceName;
  @JsonKey(name: 'bookSourceGroup')
  String? get bookSourceGroup;
  @JsonKey(name: 'customOrder')
  int get customOrder;
  bool get enabled;
  @JsonKey(name: 'enabledExplore')
  bool get enabledExplore;
  @JsonKey(name: 'hasLoginUrl')
  bool get hasLoginUrl;
  @JsonKey(name: 'lastUpdateTime')
  int get lastUpdateTime;
  @JsonKey(name: 'respondTime')
  int get respondTime;
  int get weight;
  @JsonKey(name: 'hasExploreUrl')
  bool get hasExploreUrl;
  @JsonKey(name: 'eventListener')
  bool get eventListener;
  @JsonKey(name: 'bookSourceType')
  int get bookSourceType;
  @JsonKey(name: 'hasJs')
  bool get hasJs;

  /// Create a copy of BookSourcePart
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookSourcePartCopyWith<BookSourcePart> get copyWith =>
      _$BookSourcePartCopyWithImpl<BookSourcePart>(
        this as BookSourcePart,
        _$identity,
      );

  /// Serializes this BookSourcePart to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as BookSourcePart;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookSourcePart &&
            (identical(other.bookSourceUrl, _this.bookSourceUrl) ||
                other.bookSourceUrl == _this.bookSourceUrl) &&
            (identical(other.bookSourceName, _this.bookSourceName) ||
                other.bookSourceName == _this.bookSourceName) &&
            (identical(other.bookSourceGroup, _this.bookSourceGroup) ||
                other.bookSourceGroup == _this.bookSourceGroup) &&
            (identical(other.customOrder, _this.customOrder) ||
                other.customOrder == _this.customOrder) &&
            (identical(other.enabled, _this.enabled) ||
                other.enabled == _this.enabled) &&
            (identical(other.enabledExplore, _this.enabledExplore) ||
                other.enabledExplore == _this.enabledExplore) &&
            (identical(other.hasLoginUrl, _this.hasLoginUrl) ||
                other.hasLoginUrl == _this.hasLoginUrl) &&
            (identical(other.lastUpdateTime, _this.lastUpdateTime) ||
                other.lastUpdateTime == _this.lastUpdateTime) &&
            (identical(other.respondTime, _this.respondTime) ||
                other.respondTime == _this.respondTime) &&
            (identical(other.weight, _this.weight) ||
                other.weight == _this.weight) &&
            (identical(other.hasExploreUrl, _this.hasExploreUrl) ||
                other.hasExploreUrl == _this.hasExploreUrl) &&
            (identical(other.eventListener, _this.eventListener) ||
                other.eventListener == _this.eventListener) &&
            (identical(other.bookSourceType, _this.bookSourceType) ||
                other.bookSourceType == _this.bookSourceType) &&
            (identical(other.hasJs, _this.hasJs) ||
                other.hasJs == _this.hasJs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as BookSourcePart;
    return Object.hash(
      runtimeType,
      _this.bookSourceUrl,
      _this.bookSourceName,
      _this.bookSourceGroup,
      _this.customOrder,
      _this.enabled,
      _this.enabledExplore,
      _this.hasLoginUrl,
      _this.lastUpdateTime,
      _this.respondTime,
      _this.weight,
      _this.hasExploreUrl,
      _this.eventListener,
      _this.bookSourceType,
      _this.hasJs,
    );
  }

  @override
  String toString() {
    final _this = this as BookSourcePart;
    return 'BookSourcePart(bookSourceUrl: ${_this.bookSourceUrl}, bookSourceName: ${_this.bookSourceName}, bookSourceGroup: ${_this.bookSourceGroup}, customOrder: ${_this.customOrder}, enabled: ${_this.enabled}, enabledExplore: ${_this.enabledExplore}, hasLoginUrl: ${_this.hasLoginUrl}, lastUpdateTime: ${_this.lastUpdateTime}, respondTime: ${_this.respondTime}, weight: ${_this.weight}, hasExploreUrl: ${_this.hasExploreUrl}, eventListener: ${_this.eventListener}, bookSourceType: ${_this.bookSourceType}, hasJs: ${_this.hasJs})';
  }
}

/// @nodoc
abstract mixin class $BookSourcePartCopyWith<$Res> {
  factory $BookSourcePartCopyWith(
    BookSourcePart value,
    $Res Function(BookSourcePart) _then,
  ) = _$BookSourcePartCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'bookSourceUrl') String bookSourceUrl,
    @JsonKey(name: 'bookSourceName') String bookSourceName,
    @JsonKey(name: 'bookSourceGroup') String? bookSourceGroup,
    @JsonKey(name: 'customOrder') int customOrder,
    bool enabled,
    @JsonKey(name: 'enabledExplore') bool enabledExplore,
    @JsonKey(name: 'hasLoginUrl') bool hasLoginUrl,
    @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
    @JsonKey(name: 'respondTime') int respondTime,
    int weight,
    @JsonKey(name: 'hasExploreUrl') bool hasExploreUrl,
    @JsonKey(name: 'eventListener') bool eventListener,
    @JsonKey(name: 'bookSourceType') int bookSourceType,
    @JsonKey(name: 'hasJs') bool hasJs,
  });
}

/// @nodoc
class _$BookSourcePartCopyWithImpl<$Res>
    implements $BookSourcePartCopyWith<$Res> {
  _$BookSourcePartCopyWithImpl(this._self, this._then);

  final BookSourcePart _self;
  final $Res Function(BookSourcePart) _then;

  /// Create a copy of BookSourcePart
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookSourceUrl = null,
    Object? bookSourceName = null,
    Object? bookSourceGroup = freezed,
    Object? customOrder = null,
    Object? enabled = null,
    Object? enabledExplore = null,
    Object? hasLoginUrl = null,
    Object? lastUpdateTime = null,
    Object? respondTime = null,
    Object? weight = null,
    Object? hasExploreUrl = null,
    Object? eventListener = null,
    Object? bookSourceType = null,
    Object? hasJs = null,
  }) {
    return _then(
      BookSourcePart(
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
        hasLoginUrl: null == hasLoginUrl
            ? _self.hasLoginUrl
            : hasLoginUrl // ignore: cast_nullable_to_non_nullable
                  as bool,
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
        hasExploreUrl: null == hasExploreUrl
            ? _self.hasExploreUrl
            : hasExploreUrl // ignore: cast_nullable_to_non_nullable
                  as bool,
        eventListener: null == eventListener
            ? _self.eventListener
            : eventListener // ignore: cast_nullable_to_non_nullable
                  as bool,
        bookSourceType: null == bookSourceType
            ? _self.bookSourceType
            : bookSourceType // ignore: cast_nullable_to_non_nullable
                  as int,
        hasJs: null == hasJs
            ? _self.hasJs
            : hasJs // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BookSourcePart].
extension BookSourcePartPatterns on BookSourcePart {
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
    TResult Function(_BookSourcePart value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookSourcePart() when $default != null:
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
    TResult Function(_BookSourcePart value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookSourcePart():
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
    TResult? Function(_BookSourcePart value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookSourcePart() when $default != null:
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
      @JsonKey(name: 'customOrder') int customOrder,
      bool enabled,
      @JsonKey(name: 'enabledExplore') bool enabledExplore,
      @JsonKey(name: 'hasLoginUrl') bool hasLoginUrl,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'respondTime') int respondTime,
      int weight,
      @JsonKey(name: 'hasExploreUrl') bool hasExploreUrl,
      @JsonKey(name: 'eventListener') bool eventListener,
      @JsonKey(name: 'bookSourceType') int bookSourceType,
      @JsonKey(name: 'hasJs') bool hasJs,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookSourcePart() when $default != null:
        return $default(
          _that.bookSourceUrl,
          _that.bookSourceName,
          _that.bookSourceGroup,
          _that.customOrder,
          _that.enabled,
          _that.enabledExplore,
          _that.hasLoginUrl,
          _that.lastUpdateTime,
          _that.respondTime,
          _that.weight,
          _that.hasExploreUrl,
          _that.eventListener,
          _that.bookSourceType,
          _that.hasJs,
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
      @JsonKey(name: 'customOrder') int customOrder,
      bool enabled,
      @JsonKey(name: 'enabledExplore') bool enabledExplore,
      @JsonKey(name: 'hasLoginUrl') bool hasLoginUrl,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'respondTime') int respondTime,
      int weight,
      @JsonKey(name: 'hasExploreUrl') bool hasExploreUrl,
      @JsonKey(name: 'eventListener') bool eventListener,
      @JsonKey(name: 'bookSourceType') int bookSourceType,
      @JsonKey(name: 'hasJs') bool hasJs,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookSourcePart():
        return $default(
          _that.bookSourceUrl,
          _that.bookSourceName,
          _that.bookSourceGroup,
          _that.customOrder,
          _that.enabled,
          _that.enabledExplore,
          _that.hasLoginUrl,
          _that.lastUpdateTime,
          _that.respondTime,
          _that.weight,
          _that.hasExploreUrl,
          _that.eventListener,
          _that.bookSourceType,
          _that.hasJs,
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
      @JsonKey(name: 'customOrder') int customOrder,
      bool enabled,
      @JsonKey(name: 'enabledExplore') bool enabledExplore,
      @JsonKey(name: 'hasLoginUrl') bool hasLoginUrl,
      @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
      @JsonKey(name: 'respondTime') int respondTime,
      int weight,
      @JsonKey(name: 'hasExploreUrl') bool hasExploreUrl,
      @JsonKey(name: 'eventListener') bool eventListener,
      @JsonKey(name: 'bookSourceType') int bookSourceType,
      @JsonKey(name: 'hasJs') bool hasJs,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookSourcePart() when $default != null:
        return $default(
          _that.bookSourceUrl,
          _that.bookSourceName,
          _that.bookSourceGroup,
          _that.customOrder,
          _that.enabled,
          _that.enabledExplore,
          _that.hasLoginUrl,
          _that.lastUpdateTime,
          _that.respondTime,
          _that.weight,
          _that.hasExploreUrl,
          _that.eventListener,
          _that.bookSourceType,
          _that.hasJs,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BookSourcePart implements BookSourcePart {
  const _BookSourcePart({
    @JsonKey(name: 'bookSourceUrl') this.bookSourceUrl = '',
    @JsonKey(name: 'bookSourceName') this.bookSourceName = '',
    @JsonKey(name: 'bookSourceGroup') this.bookSourceGroup,
    @JsonKey(name: 'customOrder') this.customOrder = 0,
    this.enabled = true,
    @JsonKey(name: 'enabledExplore') this.enabledExplore = true,
    @JsonKey(name: 'hasLoginUrl') this.hasLoginUrl = false,
    @JsonKey(name: 'lastUpdateTime') this.lastUpdateTime = 0,
    @JsonKey(name: 'respondTime') this.respondTime = 180000,
    this.weight = 0,
    @JsonKey(name: 'hasExploreUrl') this.hasExploreUrl = false,
    @JsonKey(name: 'eventListener') this.eventListener = false,
    @JsonKey(name: 'bookSourceType') this.bookSourceType = 0,
    @JsonKey(name: 'hasJs') this.hasJs = false,
  });
  factory _BookSourcePart.fromJson(Map<String, dynamic> json) =>
      _$BookSourcePartFromJson(json);

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
  @JsonKey(name: 'customOrder')
  final int customOrder;
  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey(name: 'enabledExplore')
  final bool enabledExplore;
  @override
  @JsonKey(name: 'hasLoginUrl')
  final bool hasLoginUrl;
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
  @JsonKey(name: 'hasExploreUrl')
  final bool hasExploreUrl;
  @override
  @JsonKey(name: 'eventListener')
  final bool eventListener;
  @override
  @JsonKey(name: 'bookSourceType')
  final int bookSourceType;
  @override
  @JsonKey(name: 'hasJs')
  final bool hasJs;

  /// Create a copy of BookSourcePart
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookSourcePartCopyWith<_BookSourcePart> get copyWith =>
      __$BookSourcePartCopyWithImpl<_BookSourcePart>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BookSourcePartToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookSourcePart &&
            (identical(other.bookSourceUrl, bookSourceUrl) ||
                other.bookSourceUrl == bookSourceUrl) &&
            (identical(other.bookSourceName, bookSourceName) ||
                other.bookSourceName == bookSourceName) &&
            (identical(other.bookSourceGroup, bookSourceGroup) ||
                other.bookSourceGroup == bookSourceGroup) &&
            (identical(other.customOrder, customOrder) ||
                other.customOrder == customOrder) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.enabledExplore, enabledExplore) ||
                other.enabledExplore == enabledExplore) &&
            (identical(other.hasLoginUrl, hasLoginUrl) ||
                other.hasLoginUrl == hasLoginUrl) &&
            (identical(other.lastUpdateTime, lastUpdateTime) ||
                other.lastUpdateTime == lastUpdateTime) &&
            (identical(other.respondTime, respondTime) ||
                other.respondTime == respondTime) &&
            (identical(other.weight, weight) || other.weight == weight) &&
            (identical(other.hasExploreUrl, hasExploreUrl) ||
                other.hasExploreUrl == hasExploreUrl) &&
            (identical(other.eventListener, eventListener) ||
                other.eventListener == eventListener) &&
            (identical(other.bookSourceType, bookSourceType) ||
                other.bookSourceType == bookSourceType) &&
            (identical(other.hasJs, hasJs) || other.hasJs == hasJs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      bookSourceUrl,
      bookSourceName,
      bookSourceGroup,
      customOrder,
      enabled,
      enabledExplore,
      hasLoginUrl,
      lastUpdateTime,
      respondTime,
      weight,
      hasExploreUrl,
      eventListener,
      bookSourceType,
      hasJs,
    );
  }

  @override
  String toString() {
    return 'BookSourcePart(bookSourceUrl: $bookSourceUrl, bookSourceName: $bookSourceName, bookSourceGroup: $bookSourceGroup, customOrder: $customOrder, enabled: $enabled, enabledExplore: $enabledExplore, hasLoginUrl: $hasLoginUrl, lastUpdateTime: $lastUpdateTime, respondTime: $respondTime, weight: $weight, hasExploreUrl: $hasExploreUrl, eventListener: $eventListener, bookSourceType: $bookSourceType, hasJs: $hasJs)';
  }
}

/// @nodoc
abstract mixin class _$BookSourcePartCopyWith<$Res>
    implements $BookSourcePartCopyWith<$Res> {
  factory _$BookSourcePartCopyWith(
    _BookSourcePart value,
    $Res Function(_BookSourcePart) _then,
  ) = __$BookSourcePartCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'bookSourceUrl') String bookSourceUrl,
    @JsonKey(name: 'bookSourceName') String bookSourceName,
    @JsonKey(name: 'bookSourceGroup') String? bookSourceGroup,
    @JsonKey(name: 'customOrder') int customOrder,
    bool enabled,
    @JsonKey(name: 'enabledExplore') bool enabledExplore,
    @JsonKey(name: 'hasLoginUrl') bool hasLoginUrl,
    @JsonKey(name: 'lastUpdateTime') int lastUpdateTime,
    @JsonKey(name: 'respondTime') int respondTime,
    int weight,
    @JsonKey(name: 'hasExploreUrl') bool hasExploreUrl,
    @JsonKey(name: 'eventListener') bool eventListener,
    @JsonKey(name: 'bookSourceType') int bookSourceType,
    @JsonKey(name: 'hasJs') bool hasJs,
  });
}

/// @nodoc
class __$BookSourcePartCopyWithImpl<$Res>
    implements _$BookSourcePartCopyWith<$Res> {
  __$BookSourcePartCopyWithImpl(this._self, this._then);

  final _BookSourcePart _self;
  final $Res Function(_BookSourcePart) _then;

  /// Create a copy of BookSourcePart
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookSourceUrl = null,
    Object? bookSourceName = null,
    Object? bookSourceGroup = freezed,
    Object? customOrder = null,
    Object? enabled = null,
    Object? enabledExplore = null,
    Object? hasLoginUrl = null,
    Object? lastUpdateTime = null,
    Object? respondTime = null,
    Object? weight = null,
    Object? hasExploreUrl = null,
    Object? eventListener = null,
    Object? bookSourceType = null,
    Object? hasJs = null,
  }) {
    return _then(
      _BookSourcePart(
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
        hasLoginUrl: null == hasLoginUrl
            ? _self.hasLoginUrl
            : hasLoginUrl // ignore: cast_nullable_to_non_nullable
                  as bool,
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
        hasExploreUrl: null == hasExploreUrl
            ? _self.hasExploreUrl
            : hasExploreUrl // ignore: cast_nullable_to_non_nullable
                  as bool,
        eventListener: null == eventListener
            ? _self.eventListener
            : eventListener // ignore: cast_nullable_to_non_nullable
                  as bool,
        bookSourceType: null == bookSourceType
            ? _self.bookSourceType
            : bookSourceType // ignore: cast_nullable_to_non_nullable
                  as int,
        hasJs: null == hasJs
            ? _self.hasJs
            : hasJs // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
mixin _$SearchKeyword {
  String get word;
  int get usage;
  @JsonKey(name: 'lastUseTime')
  int get lastUseTime;

  /// Create a copy of SearchKeyword
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SearchKeywordCopyWith<SearchKeyword> get copyWith =>
      _$SearchKeywordCopyWithImpl<SearchKeyword>(
        this as SearchKeyword,
        _$identity,
      );

  /// Serializes this SearchKeyword to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as SearchKeyword;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SearchKeyword &&
            (identical(other.word, _this.word) || other.word == _this.word) &&
            (identical(other.usage, _this.usage) ||
                other.usage == _this.usage) &&
            (identical(other.lastUseTime, _this.lastUseTime) ||
                other.lastUseTime == _this.lastUseTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as SearchKeyword;
    return Object.hash(runtimeType, _this.word, _this.usage, _this.lastUseTime);
  }

  @override
  String toString() {
    final _this = this as SearchKeyword;
    return 'SearchKeyword(word: ${_this.word}, usage: ${_this.usage}, lastUseTime: ${_this.lastUseTime})';
  }
}

/// @nodoc
abstract mixin class $SearchKeywordCopyWith<$Res> {
  factory $SearchKeywordCopyWith(
    SearchKeyword value,
    $Res Function(SearchKeyword) _then,
  ) = _$SearchKeywordCopyWithImpl;
  @useResult
  $Res call({
    String word,
    int usage,
    @JsonKey(name: 'lastUseTime') int lastUseTime,
  });
}

/// @nodoc
class _$SearchKeywordCopyWithImpl<$Res>
    implements $SearchKeywordCopyWith<$Res> {
  _$SearchKeywordCopyWithImpl(this._self, this._then);

  final SearchKeyword _self;
  final $Res Function(SearchKeyword) _then;

  /// Create a copy of SearchKeyword
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? word = null,
    Object? usage = null,
    Object? lastUseTime = null,
  }) {
    return _then(
      SearchKeyword(
        word: null == word
            ? _self.word
            : word // ignore: cast_nullable_to_non_nullable
                  as String,
        usage: null == usage
            ? _self.usage
            : usage // ignore: cast_nullable_to_non_nullable
                  as int,
        lastUseTime: null == lastUseTime
            ? _self.lastUseTime
            : lastUseTime // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [SearchKeyword].
extension SearchKeywordPatterns on SearchKeyword {
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
    TResult Function(_SearchKeyword value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchKeyword() when $default != null:
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
    TResult Function(_SearchKeyword value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchKeyword():
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
    TResult? Function(_SearchKeyword value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchKeyword() when $default != null:
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
      String word,
      int usage,
      @JsonKey(name: 'lastUseTime') int lastUseTime,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchKeyword() when $default != null:
        return $default(_that.word, _that.usage, _that.lastUseTime);
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
      String word,
      int usage,
      @JsonKey(name: 'lastUseTime') int lastUseTime,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchKeyword():
        return $default(_that.word, _that.usage, _that.lastUseTime);
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
      String word,
      int usage,
      @JsonKey(name: 'lastUseTime') int lastUseTime,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchKeyword() when $default != null:
        return $default(_that.word, _that.usage, _that.lastUseTime);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SearchKeyword implements SearchKeyword {
  const _SearchKeyword({
    this.word = '',
    this.usage = 1,
    @JsonKey(name: 'lastUseTime') this.lastUseTime = 0,
  });
  factory _SearchKeyword.fromJson(Map<String, dynamic> json) =>
      _$SearchKeywordFromJson(json);

  @override
  @JsonKey()
  final String word;
  @override
  @JsonKey()
  final int usage;
  @override
  @JsonKey(name: 'lastUseTime')
  final int lastUseTime;

  /// Create a copy of SearchKeyword
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SearchKeywordCopyWith<_SearchKeyword> get copyWith =>
      __$SearchKeywordCopyWithImpl<_SearchKeyword>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SearchKeywordToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SearchKeyword &&
            (identical(other.word, word) || other.word == word) &&
            (identical(other.usage, usage) || other.usage == usage) &&
            (identical(other.lastUseTime, lastUseTime) ||
                other.lastUseTime == lastUseTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, word, usage, lastUseTime);
  }

  @override
  String toString() {
    return 'SearchKeyword(word: $word, usage: $usage, lastUseTime: $lastUseTime)';
  }
}

/// @nodoc
abstract mixin class _$SearchKeywordCopyWith<$Res>
    implements $SearchKeywordCopyWith<$Res> {
  factory _$SearchKeywordCopyWith(
    _SearchKeyword value,
    $Res Function(_SearchKeyword) _then,
  ) = __$SearchKeywordCopyWithImpl;
  @override
  @useResult
  $Res call({
    String word,
    int usage,
    @JsonKey(name: 'lastUseTime') int lastUseTime,
  });
}

/// @nodoc
class __$SearchKeywordCopyWithImpl<$Res>
    implements _$SearchKeywordCopyWith<$Res> {
  __$SearchKeywordCopyWithImpl(this._self, this._then);

  final _SearchKeyword _self;
  final $Res Function(_SearchKeyword) _then;

  /// Create a copy of SearchKeyword
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? word = null,
    Object? usage = null,
    Object? lastUseTime = null,
  }) {
    return _then(
      _SearchKeyword(
        word: null == word
            ? _self.word
            : word // ignore: cast_nullable_to_non_nullable
                  as String,
        usage: null == usage
            ? _self.usage
            : usage // ignore: cast_nullable_to_non_nullable
                  as int,
        lastUseTime: null == lastUseTime
            ? _self.lastUseTime
            : lastUseTime // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$TxtTocRule {
  int get id;
  String get name;
  String get rule;
  String get replacement;
  String? get example;
  @JsonKey(name: 'serialNumber')
  int get serialNumber;
  bool get enable;

  /// Create a copy of TxtTocRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TxtTocRuleCopyWith<TxtTocRule> get copyWith =>
      _$TxtTocRuleCopyWithImpl<TxtTocRule>(this as TxtTocRule, _$identity);

  /// Serializes this TxtTocRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as TxtTocRule;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TxtTocRule &&
            (identical(other.id, _this.id) || other.id == _this.id) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.rule, _this.rule) || other.rule == _this.rule) &&
            (identical(other.replacement, _this.replacement) ||
                other.replacement == _this.replacement) &&
            (identical(other.example, _this.example) ||
                other.example == _this.example) &&
            (identical(other.serialNumber, _this.serialNumber) ||
                other.serialNumber == _this.serialNumber) &&
            (identical(other.enable, _this.enable) ||
                other.enable == _this.enable));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as TxtTocRule;
    return Object.hash(
      runtimeType,
      _this.id,
      _this.name,
      _this.rule,
      _this.replacement,
      _this.example,
      _this.serialNumber,
      _this.enable,
    );
  }

  @override
  String toString() {
    final _this = this as TxtTocRule;
    return 'TxtTocRule(id: ${_this.id}, name: ${_this.name}, rule: ${_this.rule}, replacement: ${_this.replacement}, example: ${_this.example}, serialNumber: ${_this.serialNumber}, enable: ${_this.enable})';
  }
}

/// @nodoc
abstract mixin class $TxtTocRuleCopyWith<$Res> {
  factory $TxtTocRuleCopyWith(
    TxtTocRule value,
    $Res Function(TxtTocRule) _then,
  ) = _$TxtTocRuleCopyWithImpl;
  @useResult
  $Res call({
    int id,
    String name,
    String rule,
    String replacement,
    String? example,
    @JsonKey(name: 'serialNumber') int serialNumber,
    bool enable,
  });
}

/// @nodoc
class _$TxtTocRuleCopyWithImpl<$Res> implements $TxtTocRuleCopyWith<$Res> {
  _$TxtTocRuleCopyWithImpl(this._self, this._then);

  final TxtTocRule _self;
  final $Res Function(TxtTocRule) _then;

  /// Create a copy of TxtTocRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? rule = null,
    Object? replacement = null,
    Object? example = freezed,
    Object? serialNumber = null,
    Object? enable = null,
  }) {
    return _then(
      TxtTocRule(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        rule: null == rule
            ? _self.rule
            : rule // ignore: cast_nullable_to_non_nullable
                  as String,
        replacement: null == replacement
            ? _self.replacement
            : replacement // ignore: cast_nullable_to_non_nullable
                  as String,
        example: freezed == example
            ? _self.example
            : example // ignore: cast_nullable_to_non_nullable
                  as String?,
        serialNumber: null == serialNumber
            ? _self.serialNumber
            : serialNumber // ignore: cast_nullable_to_non_nullable
                  as int,
        enable: null == enable
            ? _self.enable
            : enable // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [TxtTocRule].
extension TxtTocRulePatterns on TxtTocRule {
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
    TResult Function(_TxtTocRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TxtTocRule() when $default != null:
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
    TResult Function(_TxtTocRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TxtTocRule():
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
    TResult? Function(_TxtTocRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TxtTocRule() when $default != null:
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
      int id,
      String name,
      String rule,
      String replacement,
      String? example,
      @JsonKey(name: 'serialNumber') int serialNumber,
      bool enable,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TxtTocRule() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.rule,
          _that.replacement,
          _that.example,
          _that.serialNumber,
          _that.enable,
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
      int id,
      String name,
      String rule,
      String replacement,
      String? example,
      @JsonKey(name: 'serialNumber') int serialNumber,
      bool enable,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TxtTocRule():
        return $default(
          _that.id,
          _that.name,
          _that.rule,
          _that.replacement,
          _that.example,
          _that.serialNumber,
          _that.enable,
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
      int id,
      String name,
      String rule,
      String replacement,
      String? example,
      @JsonKey(name: 'serialNumber') int serialNumber,
      bool enable,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TxtTocRule() when $default != null:
        return $default(
          _that.id,
          _that.name,
          _that.rule,
          _that.replacement,
          _that.example,
          _that.serialNumber,
          _that.enable,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TxtTocRule implements TxtTocRule {
  const _TxtTocRule({
    this.id = 0,
    this.name = '',
    this.rule = '',
    this.replacement = '',
    this.example,
    @JsonKey(name: 'serialNumber') this.serialNumber = -1,
    this.enable = true,
  });
  factory _TxtTocRule.fromJson(Map<String, dynamic> json) =>
      _$TxtTocRuleFromJson(json);

  @override
  @JsonKey()
  final int id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String rule;
  @override
  @JsonKey()
  final String replacement;
  @override
  final String? example;
  @override
  @JsonKey(name: 'serialNumber')
  final int serialNumber;
  @override
  @JsonKey()
  final bool enable;

  /// Create a copy of TxtTocRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TxtTocRuleCopyWith<_TxtTocRule> get copyWith =>
      __$TxtTocRuleCopyWithImpl<_TxtTocRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TxtTocRuleToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TxtTocRule &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.rule, rule) || other.rule == rule) &&
            (identical(other.replacement, replacement) ||
                other.replacement == replacement) &&
            (identical(other.example, example) || other.example == example) &&
            (identical(other.serialNumber, serialNumber) ||
                other.serialNumber == serialNumber) &&
            (identical(other.enable, enable) || other.enable == enable));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      id,
      name,
      rule,
      replacement,
      example,
      serialNumber,
      enable,
    );
  }

  @override
  String toString() {
    return 'TxtTocRule(id: $id, name: $name, rule: $rule, replacement: $replacement, example: $example, serialNumber: $serialNumber, enable: $enable)';
  }
}

/// @nodoc
abstract mixin class _$TxtTocRuleCopyWith<$Res>
    implements $TxtTocRuleCopyWith<$Res> {
  factory _$TxtTocRuleCopyWith(
    _TxtTocRule value,
    $Res Function(_TxtTocRule) _then,
  ) = __$TxtTocRuleCopyWithImpl;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    String rule,
    String replacement,
    String? example,
    @JsonKey(name: 'serialNumber') int serialNumber,
    bool enable,
  });
}

/// @nodoc
class __$TxtTocRuleCopyWithImpl<$Res> implements _$TxtTocRuleCopyWith<$Res> {
  __$TxtTocRuleCopyWithImpl(this._self, this._then);

  final _TxtTocRule _self;
  final $Res Function(_TxtTocRule) _then;

  /// Create a copy of TxtTocRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? rule = null,
    Object? replacement = null,
    Object? example = freezed,
    Object? serialNumber = null,
    Object? enable = null,
  }) {
    return _then(
      _TxtTocRule(
        id: null == id
            ? _self.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        rule: null == rule
            ? _self.rule
            : rule // ignore: cast_nullable_to_non_nullable
                  as String,
        replacement: null == replacement
            ? _self.replacement
            : replacement // ignore: cast_nullable_to_non_nullable
                  as String,
        example: freezed == example
            ? _self.example
            : example // ignore: cast_nullable_to_non_nullable
                  as String?,
        serialNumber: null == serialNumber
            ? _self.serialNumber
            : serialNumber // ignore: cast_nullable_to_non_nullable
                  as int,
        enable: null == enable
            ? _self.enable
            : enable // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
mixin _$BookChapterReview {
  @JsonKey(name: 'bookId')
  int get bookId;
  @JsonKey(name: 'chapterId')
  int get chapterId;
  @JsonKey(name: 'summaryUrl')
  String get summaryUrl;

  /// Create a copy of BookChapterReview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookChapterReviewCopyWith<BookChapterReview> get copyWith =>
      _$BookChapterReviewCopyWithImpl<BookChapterReview>(
        this as BookChapterReview,
        _$identity,
      );

  /// Serializes this BookChapterReview to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as BookChapterReview;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookChapterReview &&
            (identical(other.bookId, _this.bookId) ||
                other.bookId == _this.bookId) &&
            (identical(other.chapterId, _this.chapterId) ||
                other.chapterId == _this.chapterId) &&
            (identical(other.summaryUrl, _this.summaryUrl) ||
                other.summaryUrl == _this.summaryUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as BookChapterReview;
    return Object.hash(
      runtimeType,
      _this.bookId,
      _this.chapterId,
      _this.summaryUrl,
    );
  }

  @override
  String toString() {
    final _this = this as BookChapterReview;
    return 'BookChapterReview(bookId: ${_this.bookId}, chapterId: ${_this.chapterId}, summaryUrl: ${_this.summaryUrl})';
  }
}

/// @nodoc
abstract mixin class $BookChapterReviewCopyWith<$Res> {
  factory $BookChapterReviewCopyWith(
    BookChapterReview value,
    $Res Function(BookChapterReview) _then,
  ) = _$BookChapterReviewCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'bookId') int bookId,
    @JsonKey(name: 'chapterId') int chapterId,
    @JsonKey(name: 'summaryUrl') String summaryUrl,
  });
}

/// @nodoc
class _$BookChapterReviewCopyWithImpl<$Res>
    implements $BookChapterReviewCopyWith<$Res> {
  _$BookChapterReviewCopyWithImpl(this._self, this._then);

  final BookChapterReview _self;
  final $Res Function(BookChapterReview) _then;

  /// Create a copy of BookChapterReview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookId = null,
    Object? chapterId = null,
    Object? summaryUrl = null,
  }) {
    return _then(
      BookChapterReview(
        bookId: null == bookId
            ? _self.bookId
            : bookId // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterId: null == chapterId
            ? _self.chapterId
            : chapterId // ignore: cast_nullable_to_non_nullable
                  as int,
        summaryUrl: null == summaryUrl
            ? _self.summaryUrl
            : summaryUrl // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BookChapterReview].
extension BookChapterReviewPatterns on BookChapterReview {
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
    TResult Function(_BookChapterReview value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookChapterReview() when $default != null:
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
    TResult Function(_BookChapterReview value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookChapterReview():
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
    TResult? Function(_BookChapterReview value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookChapterReview() when $default != null:
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
      @JsonKey(name: 'bookId') int bookId,
      @JsonKey(name: 'chapterId') int chapterId,
      @JsonKey(name: 'summaryUrl') String summaryUrl,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookChapterReview() when $default != null:
        return $default(_that.bookId, _that.chapterId, _that.summaryUrl);
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
      @JsonKey(name: 'bookId') int bookId,
      @JsonKey(name: 'chapterId') int chapterId,
      @JsonKey(name: 'summaryUrl') String summaryUrl,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookChapterReview():
        return $default(_that.bookId, _that.chapterId, _that.summaryUrl);
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
      @JsonKey(name: 'bookId') int bookId,
      @JsonKey(name: 'chapterId') int chapterId,
      @JsonKey(name: 'summaryUrl') String summaryUrl,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookChapterReview() when $default != null:
        return $default(_that.bookId, _that.chapterId, _that.summaryUrl);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BookChapterReview implements BookChapterReview {
  const _BookChapterReview({
    @JsonKey(name: 'bookId') this.bookId = 0,
    @JsonKey(name: 'chapterId') this.chapterId = 0,
    @JsonKey(name: 'summaryUrl') this.summaryUrl = '',
  });
  factory _BookChapterReview.fromJson(Map<String, dynamic> json) =>
      _$BookChapterReviewFromJson(json);

  @override
  @JsonKey(name: 'bookId')
  final int bookId;
  @override
  @JsonKey(name: 'chapterId')
  final int chapterId;
  @override
  @JsonKey(name: 'summaryUrl')
  final String summaryUrl;

  /// Create a copy of BookChapterReview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookChapterReviewCopyWith<_BookChapterReview> get copyWith =>
      __$BookChapterReviewCopyWithImpl<_BookChapterReview>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BookChapterReviewToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookChapterReview &&
            (identical(other.bookId, bookId) || other.bookId == bookId) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.summaryUrl, summaryUrl) ||
                other.summaryUrl == summaryUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, bookId, chapterId, summaryUrl);
  }

  @override
  String toString() {
    return 'BookChapterReview(bookId: $bookId, chapterId: $chapterId, summaryUrl: $summaryUrl)';
  }
}

/// @nodoc
abstract mixin class _$BookChapterReviewCopyWith<$Res>
    implements $BookChapterReviewCopyWith<$Res> {
  factory _$BookChapterReviewCopyWith(
    _BookChapterReview value,
    $Res Function(_BookChapterReview) _then,
  ) = __$BookChapterReviewCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'bookId') int bookId,
    @JsonKey(name: 'chapterId') int chapterId,
    @JsonKey(name: 'summaryUrl') String summaryUrl,
  });
}

/// @nodoc
class __$BookChapterReviewCopyWithImpl<$Res>
    implements _$BookChapterReviewCopyWith<$Res> {
  __$BookChapterReviewCopyWithImpl(this._self, this._then);

  final _BookChapterReview _self;
  final $Res Function(_BookChapterReview) _then;

  /// Create a copy of BookChapterReview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookId = null,
    Object? chapterId = null,
    Object? summaryUrl = null,
  }) {
    return _then(
      _BookChapterReview(
        bookId: null == bookId
            ? _self.bookId
            : bookId // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterId: null == chapterId
            ? _self.chapterId
            : chapterId // ignore: cast_nullable_to_non_nullable
                  as int,
        summaryUrl: null == summaryUrl
            ? _self.summaryUrl
            : summaryUrl // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
mixin _$KeyboardAssist {
  @JsonKey(name: 'type')
  int get assistType;
  String get key;
  String get value;
  @JsonKey(name: 'serialNo')
  int get serialNo;

  /// Create a copy of KeyboardAssist
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $KeyboardAssistCopyWith<KeyboardAssist> get copyWith =>
      _$KeyboardAssistCopyWithImpl<KeyboardAssist>(
        this as KeyboardAssist,
        _$identity,
      );

  /// Serializes this KeyboardAssist to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as KeyboardAssist;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is KeyboardAssist &&
            (identical(other.assistType, _this.assistType) ||
                other.assistType == _this.assistType) &&
            (identical(other.key, _this.key) || other.key == _this.key) &&
            (identical(other.value, _this.value) ||
                other.value == _this.value) &&
            (identical(other.serialNo, _this.serialNo) ||
                other.serialNo == _this.serialNo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as KeyboardAssist;
    return Object.hash(
      runtimeType,
      _this.assistType,
      _this.key,
      _this.value,
      _this.serialNo,
    );
  }

  @override
  String toString() {
    final _this = this as KeyboardAssist;
    return 'KeyboardAssist(assistType: ${_this.assistType}, key: ${_this.key}, value: ${_this.value}, serialNo: ${_this.serialNo})';
  }
}

/// @nodoc
abstract mixin class $KeyboardAssistCopyWith<$Res> {
  factory $KeyboardAssistCopyWith(
    KeyboardAssist value,
    $Res Function(KeyboardAssist) _then,
  ) = _$KeyboardAssistCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'type') int assistType,
    String key,
    String value,
    @JsonKey(name: 'serialNo') int serialNo,
  });
}

/// @nodoc
class _$KeyboardAssistCopyWithImpl<$Res>
    implements $KeyboardAssistCopyWith<$Res> {
  _$KeyboardAssistCopyWithImpl(this._self, this._then);

  final KeyboardAssist _self;
  final $Res Function(KeyboardAssist) _then;

  /// Create a copy of KeyboardAssist
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? assistType = null,
    Object? key = null,
    Object? value = null,
    Object? serialNo = null,
  }) {
    return _then(
      KeyboardAssist(
        assistType: null == assistType
            ? _self.assistType
            : assistType // ignore: cast_nullable_to_non_nullable
                  as int,
        key: null == key
            ? _self.key
            : key // ignore: cast_nullable_to_non_nullable
                  as String,
        value: null == value
            ? _self.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
        serialNo: null == serialNo
            ? _self.serialNo
            : serialNo // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [KeyboardAssist].
extension KeyboardAssistPatterns on KeyboardAssist {
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
    TResult Function(_KeyboardAssist value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _KeyboardAssist() when $default != null:
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
    TResult Function(_KeyboardAssist value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _KeyboardAssist():
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
    TResult? Function(_KeyboardAssist value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _KeyboardAssist() when $default != null:
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
      @JsonKey(name: 'type') int assistType,
      String key,
      String value,
      @JsonKey(name: 'serialNo') int serialNo,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _KeyboardAssist() when $default != null:
        return $default(
          _that.assistType,
          _that.key,
          _that.value,
          _that.serialNo,
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
      @JsonKey(name: 'type') int assistType,
      String key,
      String value,
      @JsonKey(name: 'serialNo') int serialNo,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _KeyboardAssist():
        return $default(
          _that.assistType,
          _that.key,
          _that.value,
          _that.serialNo,
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
      @JsonKey(name: 'type') int assistType,
      String key,
      String value,
      @JsonKey(name: 'serialNo') int serialNo,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _KeyboardAssist() when $default != null:
        return $default(
          _that.assistType,
          _that.key,
          _that.value,
          _that.serialNo,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _KeyboardAssist implements KeyboardAssist {
  const _KeyboardAssist({
    @JsonKey(name: 'type') this.assistType = 0,
    this.key = '',
    this.value = '',
    @JsonKey(name: 'serialNo') this.serialNo = 0,
  });
  factory _KeyboardAssist.fromJson(Map<String, dynamic> json) =>
      _$KeyboardAssistFromJson(json);

  @override
  @JsonKey(name: 'type')
  final int assistType;
  @override
  @JsonKey()
  final String key;
  @override
  @JsonKey()
  final String value;
  @override
  @JsonKey(name: 'serialNo')
  final int serialNo;

  /// Create a copy of KeyboardAssist
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$KeyboardAssistCopyWith<_KeyboardAssist> get copyWith =>
      __$KeyboardAssistCopyWithImpl<_KeyboardAssist>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$KeyboardAssistToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _KeyboardAssist &&
            (identical(other.assistType, assistType) ||
                other.assistType == assistType) &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.serialNo, serialNo) ||
                other.serialNo == serialNo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, assistType, key, value, serialNo);
  }

  @override
  String toString() {
    return 'KeyboardAssist(assistType: $assistType, key: $key, value: $value, serialNo: $serialNo)';
  }
}

/// @nodoc
abstract mixin class _$KeyboardAssistCopyWith<$Res>
    implements $KeyboardAssistCopyWith<$Res> {
  factory _$KeyboardAssistCopyWith(
    _KeyboardAssist value,
    $Res Function(_KeyboardAssist) _then,
  ) = __$KeyboardAssistCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'type') int assistType,
    String key,
    String value,
    @JsonKey(name: 'serialNo') int serialNo,
  });
}

/// @nodoc
class __$KeyboardAssistCopyWithImpl<$Res>
    implements _$KeyboardAssistCopyWith<$Res> {
  __$KeyboardAssistCopyWithImpl(this._self, this._then);

  final _KeyboardAssist _self;
  final $Res Function(_KeyboardAssist) _then;

  /// Create a copy of KeyboardAssist
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? assistType = null,
    Object? key = null,
    Object? value = null,
    Object? serialNo = null,
  }) {
    return _then(
      _KeyboardAssist(
        assistType: null == assistType
            ? _self.assistType
            : assistType // ignore: cast_nullable_to_non_nullable
                  as int,
        key: null == key
            ? _self.key
            : key // ignore: cast_nullable_to_non_nullable
                  as String,
        value: null == value
            ? _self.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
        serialNo: null == serialNo
            ? _self.serialNo
            : serialNo // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$ReadRecord {
  @JsonKey(name: 'deviceId')
  String get deviceId;
  @JsonKey(name: 'bookName')
  String get bookName;
  String get author;
  int? get startTime;
  @JsonKey(name: 'readTime')
  int get readTime;
  @JsonKey(name: 'lastRead')
  int get lastRead;

  /// Create a copy of ReadRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReadRecordCopyWith<ReadRecord> get copyWith =>
      _$ReadRecordCopyWithImpl<ReadRecord>(this as ReadRecord, _$identity);

  /// Serializes this ReadRecord to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as ReadRecord;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReadRecord &&
            (identical(other.deviceId, _this.deviceId) ||
                other.deviceId == _this.deviceId) &&
            (identical(other.bookName, _this.bookName) ||
                other.bookName == _this.bookName) &&
            (identical(other.author, _this.author) ||
                other.author == _this.author) &&
            (identical(other.startTime, _this.startTime) ||
                other.startTime == _this.startTime) &&
            (identical(other.readTime, _this.readTime) ||
                other.readTime == _this.readTime) &&
            (identical(other.lastRead, _this.lastRead) ||
                other.lastRead == _this.lastRead));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as ReadRecord;
    return Object.hash(
      runtimeType,
      _this.deviceId,
      _this.bookName,
      _this.author,
      _this.startTime,
      _this.readTime,
      _this.lastRead,
    );
  }

  @override
  String toString() {
    final _this = this as ReadRecord;
    return 'ReadRecord(deviceId: ${_this.deviceId}, bookName: ${_this.bookName}, author: ${_this.author}, startTime: ${_this.startTime}, readTime: ${_this.readTime}, lastRead: ${_this.lastRead})';
  }
}

/// @nodoc
abstract mixin class $ReadRecordCopyWith<$Res> {
  factory $ReadRecordCopyWith(
    ReadRecord value,
    $Res Function(ReadRecord) _then,
  ) = _$ReadRecordCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'deviceId') String deviceId,
    @JsonKey(name: 'bookName') String bookName,
    String author,
    int? startTime,
    @JsonKey(name: 'readTime') int readTime,
    @JsonKey(name: 'lastRead') int lastRead,
  });
}

/// @nodoc
class _$ReadRecordCopyWithImpl<$Res> implements $ReadRecordCopyWith<$Res> {
  _$ReadRecordCopyWithImpl(this._self, this._then);

  final ReadRecord _self;
  final $Res Function(ReadRecord) _then;

  /// Create a copy of ReadRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceId = null,
    Object? bookName = null,
    Object? author = null,
    Object? startTime = freezed,
    Object? readTime = null,
    Object? lastRead = null,
  }) {
    return _then(
      ReadRecord(
        deviceId: null == deviceId
            ? _self.deviceId
            : deviceId // ignore: cast_nullable_to_non_nullable
                  as String,
        bookName: null == bookName
            ? _self.bookName
            : bookName // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        startTime: freezed == startTime
            ? _self.startTime
            : startTime // ignore: cast_nullable_to_non_nullable
                  as int?,
        readTime: null == readTime
            ? _self.readTime
            : readTime // ignore: cast_nullable_to_non_nullable
                  as int,
        lastRead: null == lastRead
            ? _self.lastRead
            : lastRead // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ReadRecord].
extension ReadRecordPatterns on ReadRecord {
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
    TResult Function(_ReadRecord value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReadRecord() when $default != null:
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
    TResult Function(_ReadRecord value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadRecord():
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
    TResult? Function(_ReadRecord value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadRecord() when $default != null:
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
      @JsonKey(name: 'deviceId') String deviceId,
      @JsonKey(name: 'bookName') String bookName,
      String author,
      int? startTime,
      @JsonKey(name: 'readTime') int readTime,
      @JsonKey(name: 'lastRead') int lastRead,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReadRecord() when $default != null:
        return $default(
          _that.deviceId,
          _that.bookName,
          _that.author,
          _that.startTime,
          _that.readTime,
          _that.lastRead,
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
      @JsonKey(name: 'deviceId') String deviceId,
      @JsonKey(name: 'bookName') String bookName,
      String author,
      int? startTime,
      @JsonKey(name: 'readTime') int readTime,
      @JsonKey(name: 'lastRead') int lastRead,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadRecord():
        return $default(
          _that.deviceId,
          _that.bookName,
          _that.author,
          _that.startTime,
          _that.readTime,
          _that.lastRead,
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
      @JsonKey(name: 'deviceId') String deviceId,
      @JsonKey(name: 'bookName') String bookName,
      String author,
      int? startTime,
      @JsonKey(name: 'readTime') int readTime,
      @JsonKey(name: 'lastRead') int lastRead,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadRecord() when $default != null:
        return $default(
          _that.deviceId,
          _that.bookName,
          _that.author,
          _that.startTime,
          _that.readTime,
          _that.lastRead,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ReadRecord implements ReadRecord {
  const _ReadRecord({
    @JsonKey(name: 'deviceId') this.deviceId = '',
    @JsonKey(name: 'bookName') this.bookName = '',
    this.author = '',
    this.startTime,
    @JsonKey(name: 'readTime') this.readTime = 0,
    @JsonKey(name: 'lastRead') this.lastRead = 0,
  });
  factory _ReadRecord.fromJson(Map<String, dynamic> json) =>
      _$ReadRecordFromJson(json);

  @override
  @JsonKey(name: 'deviceId')
  final String deviceId;
  @override
  @JsonKey(name: 'bookName')
  final String bookName;
  @override
  @JsonKey()
  final String author;
  @override
  final int? startTime;
  @override
  @JsonKey(name: 'readTime')
  final int readTime;
  @override
  @JsonKey(name: 'lastRead')
  final int lastRead;

  /// Create a copy of ReadRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReadRecordCopyWith<_ReadRecord> get copyWith =>
      __$ReadRecordCopyWithImpl<_ReadRecord>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ReadRecordToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReadRecord &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.bookName, bookName) ||
                other.bookName == bookName) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.readTime, readTime) ||
                other.readTime == readTime) &&
            (identical(other.lastRead, lastRead) ||
                other.lastRead == lastRead));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      deviceId,
      bookName,
      author,
      startTime,
      readTime,
      lastRead,
    );
  }

  @override
  String toString() {
    return 'ReadRecord(deviceId: $deviceId, bookName: $bookName, author: $author, startTime: $startTime, readTime: $readTime, lastRead: $lastRead)';
  }
}

/// @nodoc
abstract mixin class _$ReadRecordCopyWith<$Res>
    implements $ReadRecordCopyWith<$Res> {
  factory _$ReadRecordCopyWith(
    _ReadRecord value,
    $Res Function(_ReadRecord) _then,
  ) = __$ReadRecordCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'deviceId') String deviceId,
    @JsonKey(name: 'bookName') String bookName,
    String author,
    int? startTime,
    @JsonKey(name: 'readTime') int readTime,
    @JsonKey(name: 'lastRead') int lastRead,
  });
}

/// @nodoc
class __$ReadRecordCopyWithImpl<$Res> implements _$ReadRecordCopyWith<$Res> {
  __$ReadRecordCopyWithImpl(this._self, this._then);

  final _ReadRecord _self;
  final $Res Function(_ReadRecord) _then;

  /// Create a copy of ReadRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? deviceId = null,
    Object? bookName = null,
    Object? author = null,
    Object? startTime = freezed,
    Object? readTime = null,
    Object? lastRead = null,
  }) {
    return _then(
      _ReadRecord(
        deviceId: null == deviceId
            ? _self.deviceId
            : deviceId // ignore: cast_nullable_to_non_nullable
                  as String,
        bookName: null == bookName
            ? _self.bookName
            : bookName // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        startTime: freezed == startTime
            ? _self.startTime
            : startTime // ignore: cast_nullable_to_non_nullable
                  as int?,
        readTime: null == readTime
            ? _self.readTime
            : readTime // ignore: cast_nullable_to_non_nullable
                  as int,
        lastRead: null == lastRead
            ? _self.lastRead
            : lastRead // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$RssReadRecord {
  String get record;
  String? get title;
  @JsonKey(name: 'readTime')
  int? get readTime;
  bool get read;
  String get origin;
  String get sort;
  String? get image;
  @JsonKey(name: 'type')
  int get recordType;
  @JsonKey(name: 'durPos')
  int get durPos;
  @JsonKey(name: 'pubDate')
  String? get pubDate;

  /// Create a copy of RssReadRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RssReadRecordCopyWith<RssReadRecord> get copyWith =>
      _$RssReadRecordCopyWithImpl<RssReadRecord>(
        this as RssReadRecord,
        _$identity,
      );

  /// Serializes this RssReadRecord to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as RssReadRecord;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RssReadRecord &&
            (identical(other.record, _this.record) ||
                other.record == _this.record) &&
            (identical(other.title, _this.title) ||
                other.title == _this.title) &&
            (identical(other.readTime, _this.readTime) ||
                other.readTime == _this.readTime) &&
            (identical(other.read, _this.read) || other.read == _this.read) &&
            (identical(other.origin, _this.origin) ||
                other.origin == _this.origin) &&
            (identical(other.sort, _this.sort) || other.sort == _this.sort) &&
            (identical(other.image, _this.image) ||
                other.image == _this.image) &&
            (identical(other.recordType, _this.recordType) ||
                other.recordType == _this.recordType) &&
            (identical(other.durPos, _this.durPos) ||
                other.durPos == _this.durPos) &&
            (identical(other.pubDate, _this.pubDate) ||
                other.pubDate == _this.pubDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as RssReadRecord;
    return Object.hash(
      runtimeType,
      _this.record,
      _this.title,
      _this.readTime,
      _this.read,
      _this.origin,
      _this.sort,
      _this.image,
      _this.recordType,
      _this.durPos,
      _this.pubDate,
    );
  }

  @override
  String toString() {
    final _this = this as RssReadRecord;
    return 'RssReadRecord(record: ${_this.record}, title: ${_this.title}, readTime: ${_this.readTime}, read: ${_this.read}, origin: ${_this.origin}, sort: ${_this.sort}, image: ${_this.image}, recordType: ${_this.recordType}, durPos: ${_this.durPos}, pubDate: ${_this.pubDate})';
  }
}

/// @nodoc
abstract mixin class $RssReadRecordCopyWith<$Res> {
  factory $RssReadRecordCopyWith(
    RssReadRecord value,
    $Res Function(RssReadRecord) _then,
  ) = _$RssReadRecordCopyWithImpl;
  @useResult
  $Res call({
    String record,
    String? title,
    @JsonKey(name: 'readTime') int? readTime,
    bool read,
    String origin,
    String sort,
    String? image,
    @JsonKey(name: 'type') int recordType,
    @JsonKey(name: 'durPos') int durPos,
    @JsonKey(name: 'pubDate') String? pubDate,
  });
}

/// @nodoc
class _$RssReadRecordCopyWithImpl<$Res>
    implements $RssReadRecordCopyWith<$Res> {
  _$RssReadRecordCopyWithImpl(this._self, this._then);

  final RssReadRecord _self;
  final $Res Function(RssReadRecord) _then;

  /// Create a copy of RssReadRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? record = null,
    Object? title = freezed,
    Object? readTime = freezed,
    Object? read = null,
    Object? origin = null,
    Object? sort = null,
    Object? image = freezed,
    Object? recordType = null,
    Object? durPos = null,
    Object? pubDate = freezed,
  }) {
    return _then(
      RssReadRecord(
        record: null == record
            ? _self.record
            : record // ignore: cast_nullable_to_non_nullable
                  as String,
        title: freezed == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        readTime: freezed == readTime
            ? _self.readTime
            : readTime // ignore: cast_nullable_to_non_nullable
                  as int?,
        read: null == read
            ? _self.read
            : read // ignore: cast_nullable_to_non_nullable
                  as bool,
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        sort: null == sort
            ? _self.sort
            : sort // ignore: cast_nullable_to_non_nullable
                  as String,
        image: freezed == image
            ? _self.image
            : image // ignore: cast_nullable_to_non_nullable
                  as String?,
        recordType: null == recordType
            ? _self.recordType
            : recordType // ignore: cast_nullable_to_non_nullable
                  as int,
        durPos: null == durPos
            ? _self.durPos
            : durPos // ignore: cast_nullable_to_non_nullable
                  as int,
        pubDate: freezed == pubDate
            ? _self.pubDate
            : pubDate // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [RssReadRecord].
extension RssReadRecordPatterns on RssReadRecord {
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
    TResult Function(_RssReadRecord value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssReadRecord() when $default != null:
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
    TResult Function(_RssReadRecord value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssReadRecord():
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
    TResult? Function(_RssReadRecord value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssReadRecord() when $default != null:
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
      String record,
      String? title,
      @JsonKey(name: 'readTime') int? readTime,
      bool read,
      String origin,
      String sort,
      String? image,
      @JsonKey(name: 'type') int recordType,
      @JsonKey(name: 'durPos') int durPos,
      @JsonKey(name: 'pubDate') String? pubDate,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RssReadRecord() when $default != null:
        return $default(
          _that.record,
          _that.title,
          _that.readTime,
          _that.read,
          _that.origin,
          _that.sort,
          _that.image,
          _that.recordType,
          _that.durPos,
          _that.pubDate,
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
      String record,
      String? title,
      @JsonKey(name: 'readTime') int? readTime,
      bool read,
      String origin,
      String sort,
      String? image,
      @JsonKey(name: 'type') int recordType,
      @JsonKey(name: 'durPos') int durPos,
      @JsonKey(name: 'pubDate') String? pubDate,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssReadRecord():
        return $default(
          _that.record,
          _that.title,
          _that.readTime,
          _that.read,
          _that.origin,
          _that.sort,
          _that.image,
          _that.recordType,
          _that.durPos,
          _that.pubDate,
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
      String record,
      String? title,
      @JsonKey(name: 'readTime') int? readTime,
      bool read,
      String origin,
      String sort,
      String? image,
      @JsonKey(name: 'type') int recordType,
      @JsonKey(name: 'durPos') int durPos,
      @JsonKey(name: 'pubDate') String? pubDate,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RssReadRecord() when $default != null:
        return $default(
          _that.record,
          _that.title,
          _that.readTime,
          _that.read,
          _that.origin,
          _that.sort,
          _that.image,
          _that.recordType,
          _that.durPos,
          _that.pubDate,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RssReadRecord implements RssReadRecord {
  const _RssReadRecord({
    this.record = '',
    this.title,
    @JsonKey(name: 'readTime') this.readTime,
    this.read = true,
    this.origin = '',
    this.sort = '',
    this.image,
    @JsonKey(name: 'type') this.recordType = 0,
    @JsonKey(name: 'durPos') this.durPos = 0,
    @JsonKey(name: 'pubDate') this.pubDate,
  });
  factory _RssReadRecord.fromJson(Map<String, dynamic> json) =>
      _$RssReadRecordFromJson(json);

  @override
  @JsonKey()
  final String record;
  @override
  final String? title;
  @override
  @JsonKey(name: 'readTime')
  final int? readTime;
  @override
  @JsonKey()
  final bool read;
  @override
  @JsonKey()
  final String origin;
  @override
  @JsonKey()
  final String sort;
  @override
  final String? image;
  @override
  @JsonKey(name: 'type')
  final int recordType;
  @override
  @JsonKey(name: 'durPos')
  final int durPos;
  @override
  @JsonKey(name: 'pubDate')
  final String? pubDate;

  /// Create a copy of RssReadRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RssReadRecordCopyWith<_RssReadRecord> get copyWith =>
      __$RssReadRecordCopyWithImpl<_RssReadRecord>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RssReadRecordToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RssReadRecord &&
            (identical(other.record, record) || other.record == record) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.readTime, readTime) ||
                other.readTime == readTime) &&
            (identical(other.read, read) || other.read == read) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.sort, sort) || other.sort == sort) &&
            (identical(other.image, image) || other.image == image) &&
            (identical(other.recordType, recordType) ||
                other.recordType == recordType) &&
            (identical(other.durPos, durPos) || other.durPos == durPos) &&
            (identical(other.pubDate, pubDate) || other.pubDate == pubDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      record,
      title,
      readTime,
      read,
      origin,
      sort,
      image,
      recordType,
      durPos,
      pubDate,
    );
  }

  @override
  String toString() {
    return 'RssReadRecord(record: $record, title: $title, readTime: $readTime, read: $read, origin: $origin, sort: $sort, image: $image, recordType: $recordType, durPos: $durPos, pubDate: $pubDate)';
  }
}

/// @nodoc
abstract mixin class _$RssReadRecordCopyWith<$Res>
    implements $RssReadRecordCopyWith<$Res> {
  factory _$RssReadRecordCopyWith(
    _RssReadRecord value,
    $Res Function(_RssReadRecord) _then,
  ) = __$RssReadRecordCopyWithImpl;
  @override
  @useResult
  $Res call({
    String record,
    String? title,
    @JsonKey(name: 'readTime') int? readTime,
    bool read,
    String origin,
    String sort,
    String? image,
    @JsonKey(name: 'type') int recordType,
    @JsonKey(name: 'durPos') int durPos,
    @JsonKey(name: 'pubDate') String? pubDate,
  });
}

/// @nodoc
class __$RssReadRecordCopyWithImpl<$Res>
    implements _$RssReadRecordCopyWith<$Res> {
  __$RssReadRecordCopyWithImpl(this._self, this._then);

  final _RssReadRecord _self;
  final $Res Function(_RssReadRecord) _then;

  /// Create a copy of RssReadRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? record = null,
    Object? title = freezed,
    Object? readTime = freezed,
    Object? read = null,
    Object? origin = null,
    Object? sort = null,
    Object? image = freezed,
    Object? recordType = null,
    Object? durPos = null,
    Object? pubDate = freezed,
  }) {
    return _then(
      _RssReadRecord(
        record: null == record
            ? _self.record
            : record // ignore: cast_nullable_to_non_nullable
                  as String,
        title: freezed == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        readTime: freezed == readTime
            ? _self.readTime
            : readTime // ignore: cast_nullable_to_non_nullable
                  as int?,
        read: null == read
            ? _self.read
            : read // ignore: cast_nullable_to_non_nullable
                  as bool,
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        sort: null == sort
            ? _self.sort
            : sort // ignore: cast_nullable_to_non_nullable
                  as String,
        image: freezed == image
            ? _self.image
            : image // ignore: cast_nullable_to_non_nullable
                  as String?,
        recordType: null == recordType
            ? _self.recordType
            : recordType // ignore: cast_nullable_to_non_nullable
                  as int,
        durPos: null == durPos
            ? _self.durPos
            : durPos // ignore: cast_nullable_to_non_nullable
                  as int,
        pubDate: freezed == pubDate
            ? _self.pubDate
            : pubDate // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
mixin _$BookProgress {
  String get name;
  String get author;
  @JsonKey(name: 'durChapterIndex')
  int get durChapterIndex;
  @JsonKey(name: 'durChapterPos')
  int get durChapterPos;
  @JsonKey(name: 'durChapterTime')
  int get durChapterTime;
  @JsonKey(name: 'durChapterTitle')
  String? get durChapterTitle;

  /// Create a copy of BookProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookProgressCopyWith<BookProgress> get copyWith =>
      _$BookProgressCopyWithImpl<BookProgress>(
        this as BookProgress,
        _$identity,
      );

  /// Serializes this BookProgress to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as BookProgress;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookProgress &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.author, _this.author) ||
                other.author == _this.author) &&
            (identical(other.durChapterIndex, _this.durChapterIndex) ||
                other.durChapterIndex == _this.durChapterIndex) &&
            (identical(other.durChapterPos, _this.durChapterPos) ||
                other.durChapterPos == _this.durChapterPos) &&
            (identical(other.durChapterTime, _this.durChapterTime) ||
                other.durChapterTime == _this.durChapterTime) &&
            (identical(other.durChapterTitle, _this.durChapterTitle) ||
                other.durChapterTitle == _this.durChapterTitle));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as BookProgress;
    return Object.hash(
      runtimeType,
      _this.name,
      _this.author,
      _this.durChapterIndex,
      _this.durChapterPos,
      _this.durChapterTime,
      _this.durChapterTitle,
    );
  }

  @override
  String toString() {
    final _this = this as BookProgress;
    return 'BookProgress(name: ${_this.name}, author: ${_this.author}, durChapterIndex: ${_this.durChapterIndex}, durChapterPos: ${_this.durChapterPos}, durChapterTime: ${_this.durChapterTime}, durChapterTitle: ${_this.durChapterTitle})';
  }
}

/// @nodoc
abstract mixin class $BookProgressCopyWith<$Res> {
  factory $BookProgressCopyWith(
    BookProgress value,
    $Res Function(BookProgress) _then,
  ) = _$BookProgressCopyWithImpl;
  @useResult
  $Res call({
    String name,
    String author,
    @JsonKey(name: 'durChapterIndex') int durChapterIndex,
    @JsonKey(name: 'durChapterPos') int durChapterPos,
    @JsonKey(name: 'durChapterTime') int durChapterTime,
    @JsonKey(name: 'durChapterTitle') String? durChapterTitle,
  });
}

/// @nodoc
class _$BookProgressCopyWithImpl<$Res> implements $BookProgressCopyWith<$Res> {
  _$BookProgressCopyWithImpl(this._self, this._then);

  final BookProgress _self;
  final $Res Function(BookProgress) _then;

  /// Create a copy of BookProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? author = null,
    Object? durChapterIndex = null,
    Object? durChapterPos = null,
    Object? durChapterTime = null,
    Object? durChapterTitle = freezed,
  }) {
    return _then(
      BookProgress(
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        durChapterIndex: null == durChapterIndex
            ? _self.durChapterIndex
            : durChapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterPos: null == durChapterPos
            ? _self.durChapterPos
            : durChapterPos // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterTime: null == durChapterTime
            ? _self.durChapterTime
            : durChapterTime // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterTitle: freezed == durChapterTitle
            ? _self.durChapterTitle
            : durChapterTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BookProgress].
extension BookProgressPatterns on BookProgress {
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
    TResult Function(_BookProgress value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookProgress() when $default != null:
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
    TResult Function(_BookProgress value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookProgress():
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
    TResult? Function(_BookProgress value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookProgress() when $default != null:
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
      String author,
      @JsonKey(name: 'durChapterIndex') int durChapterIndex,
      @JsonKey(name: 'durChapterPos') int durChapterPos,
      @JsonKey(name: 'durChapterTime') int durChapterTime,
      @JsonKey(name: 'durChapterTitle') String? durChapterTitle,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookProgress() when $default != null:
        return $default(
          _that.name,
          _that.author,
          _that.durChapterIndex,
          _that.durChapterPos,
          _that.durChapterTime,
          _that.durChapterTitle,
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
      String author,
      @JsonKey(name: 'durChapterIndex') int durChapterIndex,
      @JsonKey(name: 'durChapterPos') int durChapterPos,
      @JsonKey(name: 'durChapterTime') int durChapterTime,
      @JsonKey(name: 'durChapterTitle') String? durChapterTitle,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookProgress():
        return $default(
          _that.name,
          _that.author,
          _that.durChapterIndex,
          _that.durChapterPos,
          _that.durChapterTime,
          _that.durChapterTitle,
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
      String author,
      @JsonKey(name: 'durChapterIndex') int durChapterIndex,
      @JsonKey(name: 'durChapterPos') int durChapterPos,
      @JsonKey(name: 'durChapterTime') int durChapterTime,
      @JsonKey(name: 'durChapterTitle') String? durChapterTitle,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookProgress() when $default != null:
        return $default(
          _that.name,
          _that.author,
          _that.durChapterIndex,
          _that.durChapterPos,
          _that.durChapterTime,
          _that.durChapterTitle,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BookProgress implements BookProgress {
  const _BookProgress({
    this.name = '',
    this.author = '',
    @JsonKey(name: 'durChapterIndex') this.durChapterIndex = 0,
    @JsonKey(name: 'durChapterPos') this.durChapterPos = 0,
    @JsonKey(name: 'durChapterTime') this.durChapterTime = 0,
    @JsonKey(name: 'durChapterTitle') this.durChapterTitle,
  });
  factory _BookProgress.fromJson(Map<String, dynamic> json) =>
      _$BookProgressFromJson(json);

  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String author;
  @override
  @JsonKey(name: 'durChapterIndex')
  final int durChapterIndex;
  @override
  @JsonKey(name: 'durChapterPos')
  final int durChapterPos;
  @override
  @JsonKey(name: 'durChapterTime')
  final int durChapterTime;
  @override
  @JsonKey(name: 'durChapterTitle')
  final String? durChapterTitle;

  /// Create a copy of BookProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookProgressCopyWith<_BookProgress> get copyWith =>
      __$BookProgressCopyWithImpl<_BookProgress>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BookProgressToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookProgress &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.durChapterIndex, durChapterIndex) ||
                other.durChapterIndex == durChapterIndex) &&
            (identical(other.durChapterPos, durChapterPos) ||
                other.durChapterPos == durChapterPos) &&
            (identical(other.durChapterTime, durChapterTime) ||
                other.durChapterTime == durChapterTime) &&
            (identical(other.durChapterTitle, durChapterTitle) ||
                other.durChapterTitle == durChapterTitle));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      name,
      author,
      durChapterIndex,
      durChapterPos,
      durChapterTime,
      durChapterTitle,
    );
  }

  @override
  String toString() {
    return 'BookProgress(name: $name, author: $author, durChapterIndex: $durChapterIndex, durChapterPos: $durChapterPos, durChapterTime: $durChapterTime, durChapterTitle: $durChapterTitle)';
  }
}

/// @nodoc
abstract mixin class _$BookProgressCopyWith<$Res>
    implements $BookProgressCopyWith<$Res> {
  factory _$BookProgressCopyWith(
    _BookProgress value,
    $Res Function(_BookProgress) _then,
  ) = __$BookProgressCopyWithImpl;
  @override
  @useResult
  $Res call({
    String name,
    String author,
    @JsonKey(name: 'durChapterIndex') int durChapterIndex,
    @JsonKey(name: 'durChapterPos') int durChapterPos,
    @JsonKey(name: 'durChapterTime') int durChapterTime,
    @JsonKey(name: 'durChapterTitle') String? durChapterTitle,
  });
}

/// @nodoc
class __$BookProgressCopyWithImpl<$Res>
    implements _$BookProgressCopyWith<$Res> {
  __$BookProgressCopyWithImpl(this._self, this._then);

  final _BookProgress _self;
  final $Res Function(_BookProgress) _then;

  /// Create a copy of BookProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? name = null,
    Object? author = null,
    Object? durChapterIndex = null,
    Object? durChapterPos = null,
    Object? durChapterTime = null,
    Object? durChapterTitle = freezed,
  }) {
    return _then(
      _BookProgress(
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _self.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        durChapterIndex: null == durChapterIndex
            ? _self.durChapterIndex
            : durChapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterPos: null == durChapterPos
            ? _self.durChapterPos
            : durChapterPos // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterTime: null == durChapterTime
            ? _self.durChapterTime
            : durChapterTime // ignore: cast_nullable_to_non_nullable
                  as int,
        durChapterTitle: freezed == durChapterTitle
            ? _self.durChapterTitle
            : durChapterTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
mixin _$ReplaceBook {
  @JsonKey(name: 'bookUrl')
  String get bookUrl;
  String get origin;
  @JsonKey(name: 'originName')
  String get originName;
  @JsonKey(name: 'type')
  int get bookType;
  String get name;
  String get author;
  String? get kind;
  @JsonKey(name: 'coverUrl')
  String? get coverUrl;
  String? get intro;
  @JsonKey(name: 'wordCount')
  String? get wordCount;
  @JsonKey(name: 'latestChapterTitle')
  String? get latestChapterTitle;
  @JsonKey(name: 'tocUrl')
  String get tocUrl;
  @JsonKey(name: 'originOrder')
  int get originOrder;

  /// Create a copy of ReplaceBook
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReplaceBookCopyWith<ReplaceBook> get copyWith =>
      _$ReplaceBookCopyWithImpl<ReplaceBook>(this as ReplaceBook, _$identity);

  /// Serializes this ReplaceBook to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as ReplaceBook;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReplaceBook &&
            (identical(other.bookUrl, _this.bookUrl) ||
                other.bookUrl == _this.bookUrl) &&
            (identical(other.origin, _this.origin) ||
                other.origin == _this.origin) &&
            (identical(other.originName, _this.originName) ||
                other.originName == _this.originName) &&
            (identical(other.bookType, _this.bookType) ||
                other.bookType == _this.bookType) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.author, _this.author) ||
                other.author == _this.author) &&
            (identical(other.kind, _this.kind) || other.kind == _this.kind) &&
            (identical(other.coverUrl, _this.coverUrl) ||
                other.coverUrl == _this.coverUrl) &&
            (identical(other.intro, _this.intro) ||
                other.intro == _this.intro) &&
            (identical(other.wordCount, _this.wordCount) ||
                other.wordCount == _this.wordCount) &&
            (identical(other.latestChapterTitle, _this.latestChapterTitle) ||
                other.latestChapterTitle == _this.latestChapterTitle) &&
            (identical(other.tocUrl, _this.tocUrl) ||
                other.tocUrl == _this.tocUrl) &&
            (identical(other.originOrder, _this.originOrder) ||
                other.originOrder == _this.originOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as ReplaceBook;
    return Object.hash(
      runtimeType,
      _this.bookUrl,
      _this.origin,
      _this.originName,
      _this.bookType,
      _this.name,
      _this.author,
      _this.kind,
      _this.coverUrl,
      _this.intro,
      _this.wordCount,
      _this.latestChapterTitle,
      _this.tocUrl,
      _this.originOrder,
    );
  }

  @override
  String toString() {
    final _this = this as ReplaceBook;
    return 'ReplaceBook(bookUrl: ${_this.bookUrl}, origin: ${_this.origin}, originName: ${_this.originName}, bookType: ${_this.bookType}, name: ${_this.name}, author: ${_this.author}, kind: ${_this.kind}, coverUrl: ${_this.coverUrl}, intro: ${_this.intro}, wordCount: ${_this.wordCount}, latestChapterTitle: ${_this.latestChapterTitle}, tocUrl: ${_this.tocUrl}, originOrder: ${_this.originOrder})';
  }
}

/// @nodoc
abstract mixin class $ReplaceBookCopyWith<$Res> {
  factory $ReplaceBookCopyWith(
    ReplaceBook value,
    $Res Function(ReplaceBook) _then,
  ) = _$ReplaceBookCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'bookUrl') String bookUrl,
    String origin,
    @JsonKey(name: 'originName') String originName,
    @JsonKey(name: 'type') int bookType,
    String name,
    String author,
    String? kind,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    String? intro,
    @JsonKey(name: 'wordCount') String? wordCount,
    @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
    @JsonKey(name: 'tocUrl') String tocUrl,
    @JsonKey(name: 'originOrder') int originOrder,
  });
}

/// @nodoc
class _$ReplaceBookCopyWithImpl<$Res> implements $ReplaceBookCopyWith<$Res> {
  _$ReplaceBookCopyWithImpl(this._self, this._then);

  final ReplaceBook _self;
  final $Res Function(ReplaceBook) _then;

  /// Create a copy of ReplaceBook
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookUrl = null,
    Object? origin = null,
    Object? originName = null,
    Object? bookType = null,
    Object? name = null,
    Object? author = null,
    Object? kind = freezed,
    Object? coverUrl = freezed,
    Object? intro = freezed,
    Object? wordCount = freezed,
    Object? latestChapterTitle = freezed,
    Object? tocUrl = null,
    Object? originOrder = null,
  }) {
    return _then(
      ReplaceBook(
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        originName: null == originName
            ? _self.originName
            : originName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookType: null == bookType
            ? _self.bookType
            : bookType // ignore: cast_nullable_to_non_nullable
                  as int,
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
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        latestChapterTitle: freezed == latestChapterTitle
            ? _self.latestChapterTitle
            : latestChapterTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        tocUrl: null == tocUrl
            ? _self.tocUrl
            : tocUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        originOrder: null == originOrder
            ? _self.originOrder
            : originOrder // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ReplaceBook].
extension ReplaceBookPatterns on ReplaceBook {
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
    TResult Function(_ReplaceBook value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReplaceBook() when $default != null:
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
    TResult Function(_ReplaceBook value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceBook():
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
    TResult? Function(_ReplaceBook value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceBook() when $default != null:
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
      String origin,
      @JsonKey(name: 'originName') String originName,
      @JsonKey(name: 'type') int bookType,
      String name,
      String author,
      String? kind,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      String? intro,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
      @JsonKey(name: 'tocUrl') String tocUrl,
      @JsonKey(name: 'originOrder') int originOrder,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReplaceBook() when $default != null:
        return $default(
          _that.bookUrl,
          _that.origin,
          _that.originName,
          _that.bookType,
          _that.name,
          _that.author,
          _that.kind,
          _that.coverUrl,
          _that.intro,
          _that.wordCount,
          _that.latestChapterTitle,
          _that.tocUrl,
          _that.originOrder,
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
      String origin,
      @JsonKey(name: 'originName') String originName,
      @JsonKey(name: 'type') int bookType,
      String name,
      String author,
      String? kind,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      String? intro,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
      @JsonKey(name: 'tocUrl') String tocUrl,
      @JsonKey(name: 'originOrder') int originOrder,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceBook():
        return $default(
          _that.bookUrl,
          _that.origin,
          _that.originName,
          _that.bookType,
          _that.name,
          _that.author,
          _that.kind,
          _that.coverUrl,
          _that.intro,
          _that.wordCount,
          _that.latestChapterTitle,
          _that.tocUrl,
          _that.originOrder,
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
      String origin,
      @JsonKey(name: 'originName') String originName,
      @JsonKey(name: 'type') int bookType,
      String name,
      String author,
      String? kind,
      @JsonKey(name: 'coverUrl') String? coverUrl,
      String? intro,
      @JsonKey(name: 'wordCount') String? wordCount,
      @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
      @JsonKey(name: 'tocUrl') String tocUrl,
      @JsonKey(name: 'originOrder') int originOrder,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReplaceBook() when $default != null:
        return $default(
          _that.bookUrl,
          _that.origin,
          _that.originName,
          _that.bookType,
          _that.name,
          _that.author,
          _that.kind,
          _that.coverUrl,
          _that.intro,
          _that.wordCount,
          _that.latestChapterTitle,
          _that.tocUrl,
          _that.originOrder,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ReplaceBook implements ReplaceBook {
  const _ReplaceBook({
    @JsonKey(name: 'bookUrl') this.bookUrl = '',
    this.origin = '',
    @JsonKey(name: 'originName') this.originName = '',
    @JsonKey(name: 'type') this.bookType = 0,
    this.name = '',
    this.author = '',
    this.kind,
    @JsonKey(name: 'coverUrl') this.coverUrl,
    this.intro,
    @JsonKey(name: 'wordCount') this.wordCount,
    @JsonKey(name: 'latestChapterTitle') this.latestChapterTitle,
    @JsonKey(name: 'tocUrl') this.tocUrl = '',
    @JsonKey(name: 'originOrder') this.originOrder = 0,
  });
  factory _ReplaceBook.fromJson(Map<String, dynamic> json) =>
      _$ReplaceBookFromJson(json);

  @override
  @JsonKey(name: 'bookUrl')
  final String bookUrl;
  @override
  @JsonKey()
  final String origin;
  @override
  @JsonKey(name: 'originName')
  final String originName;
  @override
  @JsonKey(name: 'type')
  final int bookType;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String author;
  @override
  final String? kind;
  @override
  @JsonKey(name: 'coverUrl')
  final String? coverUrl;
  @override
  final String? intro;
  @override
  @JsonKey(name: 'wordCount')
  final String? wordCount;
  @override
  @JsonKey(name: 'latestChapterTitle')
  final String? latestChapterTitle;
  @override
  @JsonKey(name: 'tocUrl')
  final String tocUrl;
  @override
  @JsonKey(name: 'originOrder')
  final int originOrder;

  /// Create a copy of ReplaceBook
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReplaceBookCopyWith<_ReplaceBook> get copyWith =>
      __$ReplaceBookCopyWithImpl<_ReplaceBook>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ReplaceBookToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReplaceBook &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.originName, originName) ||
                other.originName == originName) &&
            (identical(other.bookType, bookType) ||
                other.bookType == bookType) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.intro, intro) || other.intro == intro) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.latestChapterTitle, latestChapterTitle) ||
                other.latestChapterTitle == latestChapterTitle) &&
            (identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl) &&
            (identical(other.originOrder, originOrder) ||
                other.originOrder == originOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      bookUrl,
      origin,
      originName,
      bookType,
      name,
      author,
      kind,
      coverUrl,
      intro,
      wordCount,
      latestChapterTitle,
      tocUrl,
      originOrder,
    );
  }

  @override
  String toString() {
    return 'ReplaceBook(bookUrl: $bookUrl, origin: $origin, originName: $originName, bookType: $bookType, name: $name, author: $author, kind: $kind, coverUrl: $coverUrl, intro: $intro, wordCount: $wordCount, latestChapterTitle: $latestChapterTitle, tocUrl: $tocUrl, originOrder: $originOrder)';
  }
}

/// @nodoc
abstract mixin class _$ReplaceBookCopyWith<$Res>
    implements $ReplaceBookCopyWith<$Res> {
  factory _$ReplaceBookCopyWith(
    _ReplaceBook value,
    $Res Function(_ReplaceBook) _then,
  ) = __$ReplaceBookCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'bookUrl') String bookUrl,
    String origin,
    @JsonKey(name: 'originName') String originName,
    @JsonKey(name: 'type') int bookType,
    String name,
    String author,
    String? kind,
    @JsonKey(name: 'coverUrl') String? coverUrl,
    String? intro,
    @JsonKey(name: 'wordCount') String? wordCount,
    @JsonKey(name: 'latestChapterTitle') String? latestChapterTitle,
    @JsonKey(name: 'tocUrl') String tocUrl,
    @JsonKey(name: 'originOrder') int originOrder,
  });
}

/// @nodoc
class __$ReplaceBookCopyWithImpl<$Res> implements _$ReplaceBookCopyWith<$Res> {
  __$ReplaceBookCopyWithImpl(this._self, this._then);

  final _ReplaceBook _self;
  final $Res Function(_ReplaceBook) _then;

  /// Create a copy of ReplaceBook
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookUrl = null,
    Object? origin = null,
    Object? originName = null,
    Object? bookType = null,
    Object? name = null,
    Object? author = null,
    Object? kind = freezed,
    Object? coverUrl = freezed,
    Object? intro = freezed,
    Object? wordCount = freezed,
    Object? latestChapterTitle = freezed,
    Object? tocUrl = null,
    Object? originOrder = null,
  }) {
    return _then(
      _ReplaceBook(
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        originName: null == originName
            ? _self.originName
            : originName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookType: null == bookType
            ? _self.bookType
            : bookType // ignore: cast_nullable_to_non_nullable
                  as int,
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
        coverUrl: freezed == coverUrl
            ? _self.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        intro: freezed == intro
            ? _self.intro
            : intro // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        latestChapterTitle: freezed == latestChapterTitle
            ? _self.latestChapterTitle
            : latestChapterTitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        tocUrl: null == tocUrl
            ? _self.tocUrl
            : tocUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        originOrder: null == originOrder
            ? _self.originOrder
            : originOrder // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$BookCacheInfo {
  @JsonKey(name: 'bookUrl')
  String get bookUrl;
  String get name;
  String get origin;
  @JsonKey(name: 'originName')
  String get originName;
  @JsonKey(name: 'type')
  int get bookType;

  /// Create a copy of BookCacheInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookCacheInfoCopyWith<BookCacheInfo> get copyWith =>
      _$BookCacheInfoCopyWithImpl<BookCacheInfo>(
        this as BookCacheInfo,
        _$identity,
      );

  /// Serializes this BookCacheInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as BookCacheInfo;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookCacheInfo &&
            (identical(other.bookUrl, _this.bookUrl) ||
                other.bookUrl == _this.bookUrl) &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.origin, _this.origin) ||
                other.origin == _this.origin) &&
            (identical(other.originName, _this.originName) ||
                other.originName == _this.originName) &&
            (identical(other.bookType, _this.bookType) ||
                other.bookType == _this.bookType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as BookCacheInfo;
    return Object.hash(
      runtimeType,
      _this.bookUrl,
      _this.name,
      _this.origin,
      _this.originName,
      _this.bookType,
    );
  }

  @override
  String toString() {
    final _this = this as BookCacheInfo;
    return 'BookCacheInfo(bookUrl: ${_this.bookUrl}, name: ${_this.name}, origin: ${_this.origin}, originName: ${_this.originName}, bookType: ${_this.bookType})';
  }
}

/// @nodoc
abstract mixin class $BookCacheInfoCopyWith<$Res> {
  factory $BookCacheInfoCopyWith(
    BookCacheInfo value,
    $Res Function(BookCacheInfo) _then,
  ) = _$BookCacheInfoCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'bookUrl') String bookUrl,
    String name,
    String origin,
    @JsonKey(name: 'originName') String originName,
    @JsonKey(name: 'type') int bookType,
  });
}

/// @nodoc
class _$BookCacheInfoCopyWithImpl<$Res>
    implements $BookCacheInfoCopyWith<$Res> {
  _$BookCacheInfoCopyWithImpl(this._self, this._then);

  final BookCacheInfo _self;
  final $Res Function(BookCacheInfo) _then;

  /// Create a copy of BookCacheInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookUrl = null,
    Object? name = null,
    Object? origin = null,
    Object? originName = null,
    Object? bookType = null,
  }) {
    return _then(
      BookCacheInfo(
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        originName: null == originName
            ? _self.originName
            : originName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookType: null == bookType
            ? _self.bookType
            : bookType // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BookCacheInfo].
extension BookCacheInfoPatterns on BookCacheInfo {
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
    TResult Function(_BookCacheInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookCacheInfo() when $default != null:
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
    TResult Function(_BookCacheInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookCacheInfo():
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
    TResult? Function(_BookCacheInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookCacheInfo() when $default != null:
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
      String name,
      String origin,
      @JsonKey(name: 'originName') String originName,
      @JsonKey(name: 'type') int bookType,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookCacheInfo() when $default != null:
        return $default(
          _that.bookUrl,
          _that.name,
          _that.origin,
          _that.originName,
          _that.bookType,
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
      String name,
      String origin,
      @JsonKey(name: 'originName') String originName,
      @JsonKey(name: 'type') int bookType,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookCacheInfo():
        return $default(
          _that.bookUrl,
          _that.name,
          _that.origin,
          _that.originName,
          _that.bookType,
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
      String name,
      String origin,
      @JsonKey(name: 'originName') String originName,
      @JsonKey(name: 'type') int bookType,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookCacheInfo() when $default != null:
        return $default(
          _that.bookUrl,
          _that.name,
          _that.origin,
          _that.originName,
          _that.bookType,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BookCacheInfo implements BookCacheInfo {
  const _BookCacheInfo({
    @JsonKey(name: 'bookUrl') this.bookUrl = '',
    this.name = '',
    this.origin = '',
    @JsonKey(name: 'originName') this.originName = '',
    @JsonKey(name: 'type') this.bookType = 0,
  });
  factory _BookCacheInfo.fromJson(Map<String, dynamic> json) =>
      _$BookCacheInfoFromJson(json);

  @override
  @JsonKey(name: 'bookUrl')
  final String bookUrl;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String origin;
  @override
  @JsonKey(name: 'originName')
  final String originName;
  @override
  @JsonKey(name: 'type')
  final int bookType;

  /// Create a copy of BookCacheInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookCacheInfoCopyWith<_BookCacheInfo> get copyWith =>
      __$BookCacheInfoCopyWithImpl<_BookCacheInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BookCacheInfoToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookCacheInfo &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.originName, originName) ||
                other.originName == originName) &&
            (identical(other.bookType, bookType) ||
                other.bookType == bookType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      bookUrl,
      name,
      origin,
      originName,
      bookType,
    );
  }

  @override
  String toString() {
    return 'BookCacheInfo(bookUrl: $bookUrl, name: $name, origin: $origin, originName: $originName, bookType: $bookType)';
  }
}

/// @nodoc
abstract mixin class _$BookCacheInfoCopyWith<$Res>
    implements $BookCacheInfoCopyWith<$Res> {
  factory _$BookCacheInfoCopyWith(
    _BookCacheInfo value,
    $Res Function(_BookCacheInfo) _then,
  ) = __$BookCacheInfoCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'bookUrl') String bookUrl,
    String name,
    String origin,
    @JsonKey(name: 'originName') String originName,
    @JsonKey(name: 'type') int bookType,
  });
}

/// @nodoc
class __$BookCacheInfoCopyWithImpl<$Res>
    implements _$BookCacheInfoCopyWith<$Res> {
  __$BookCacheInfoCopyWithImpl(this._self, this._then);

  final _BookCacheInfo _self;
  final $Res Function(_BookCacheInfo) _then;

  /// Create a copy of BookCacheInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookUrl = null,
    Object? name = null,
    Object? origin = null,
    Object? originName = null,
    Object? bookType = null,
  }) {
    return _then(
      _BookCacheInfo(
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        origin: null == origin
            ? _self.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as String,
        originName: null == originName
            ? _self.originName
            : originName // ignore: cast_nullable_to_non_nullable
                  as String,
        bookType: null == bookType
            ? _self.bookType
            : bookType // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$ReadRecordShow {
  @JsonKey(name: 'bookName')
  String get bookName;
  @JsonKey(name: 'readTime')
  int get readTime;
  @JsonKey(name: 'lastRead')
  int get lastRead;

  /// Create a copy of ReadRecordShow
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReadRecordShowCopyWith<ReadRecordShow> get copyWith =>
      _$ReadRecordShowCopyWithImpl<ReadRecordShow>(
        this as ReadRecordShow,
        _$identity,
      );

  /// Serializes this ReadRecordShow to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as ReadRecordShow;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReadRecordShow &&
            (identical(other.bookName, _this.bookName) ||
                other.bookName == _this.bookName) &&
            (identical(other.readTime, _this.readTime) ||
                other.readTime == _this.readTime) &&
            (identical(other.lastRead, _this.lastRead) ||
                other.lastRead == _this.lastRead));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as ReadRecordShow;
    return Object.hash(
      runtimeType,
      _this.bookName,
      _this.readTime,
      _this.lastRead,
    );
  }

  @override
  String toString() {
    final _this = this as ReadRecordShow;
    return 'ReadRecordShow(bookName: ${_this.bookName}, readTime: ${_this.readTime}, lastRead: ${_this.lastRead})';
  }
}

/// @nodoc
abstract mixin class $ReadRecordShowCopyWith<$Res> {
  factory $ReadRecordShowCopyWith(
    ReadRecordShow value,
    $Res Function(ReadRecordShow) _then,
  ) = _$ReadRecordShowCopyWithImpl;
  @useResult
  $Res call({
    @JsonKey(name: 'bookName') String bookName,
    @JsonKey(name: 'readTime') int readTime,
    @JsonKey(name: 'lastRead') int lastRead,
  });
}

/// @nodoc
class _$ReadRecordShowCopyWithImpl<$Res>
    implements $ReadRecordShowCopyWith<$Res> {
  _$ReadRecordShowCopyWithImpl(this._self, this._then);

  final ReadRecordShow _self;
  final $Res Function(ReadRecordShow) _then;

  /// Create a copy of ReadRecordShow
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookName = null,
    Object? readTime = null,
    Object? lastRead = null,
  }) {
    return _then(
      ReadRecordShow(
        bookName: null == bookName
            ? _self.bookName
            : bookName // ignore: cast_nullable_to_non_nullable
                  as String,
        readTime: null == readTime
            ? _self.readTime
            : readTime // ignore: cast_nullable_to_non_nullable
                  as int,
        lastRead: null == lastRead
            ? _self.lastRead
            : lastRead // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ReadRecordShow].
extension ReadRecordShowPatterns on ReadRecordShow {
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
    TResult Function(_ReadRecordShow value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReadRecordShow() when $default != null:
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
    TResult Function(_ReadRecordShow value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadRecordShow():
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
    TResult? Function(_ReadRecordShow value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadRecordShow() when $default != null:
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
      @JsonKey(name: 'bookName') String bookName,
      @JsonKey(name: 'readTime') int readTime,
      @JsonKey(name: 'lastRead') int lastRead,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReadRecordShow() when $default != null:
        return $default(_that.bookName, _that.readTime, _that.lastRead);
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
      @JsonKey(name: 'bookName') String bookName,
      @JsonKey(name: 'readTime') int readTime,
      @JsonKey(name: 'lastRead') int lastRead,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadRecordShow():
        return $default(_that.bookName, _that.readTime, _that.lastRead);
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
      @JsonKey(name: 'bookName') String bookName,
      @JsonKey(name: 'readTime') int readTime,
      @JsonKey(name: 'lastRead') int lastRead,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReadRecordShow() when $default != null:
        return $default(_that.bookName, _that.readTime, _that.lastRead);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ReadRecordShow implements ReadRecordShow {
  const _ReadRecordShow({
    @JsonKey(name: 'bookName') this.bookName = '',
    @JsonKey(name: 'readTime') this.readTime = 0,
    @JsonKey(name: 'lastRead') this.lastRead = 0,
  });
  factory _ReadRecordShow.fromJson(Map<String, dynamic> json) =>
      _$ReadRecordShowFromJson(json);

  @override
  @JsonKey(name: 'bookName')
  final String bookName;
  @override
  @JsonKey(name: 'readTime')
  final int readTime;
  @override
  @JsonKey(name: 'lastRead')
  final int lastRead;

  /// Create a copy of ReadRecordShow
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReadRecordShowCopyWith<_ReadRecordShow> get copyWith =>
      __$ReadRecordShowCopyWithImpl<_ReadRecordShow>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ReadRecordShowToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReadRecordShow &&
            (identical(other.bookName, bookName) ||
                other.bookName == bookName) &&
            (identical(other.readTime, readTime) ||
                other.readTime == readTime) &&
            (identical(other.lastRead, lastRead) ||
                other.lastRead == lastRead));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, bookName, readTime, lastRead);
  }

  @override
  String toString() {
    return 'ReadRecordShow(bookName: $bookName, readTime: $readTime, lastRead: $lastRead)';
  }
}

/// @nodoc
abstract mixin class _$ReadRecordShowCopyWith<$Res>
    implements $ReadRecordShowCopyWith<$Res> {
  factory _$ReadRecordShowCopyWith(
    _ReadRecordShow value,
    $Res Function(_ReadRecordShow) _then,
  ) = __$ReadRecordShowCopyWithImpl;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'bookName') String bookName,
    @JsonKey(name: 'readTime') int readTime,
    @JsonKey(name: 'lastRead') int lastRead,
  });
}

/// @nodoc
class __$ReadRecordShowCopyWithImpl<$Res>
    implements _$ReadRecordShowCopyWith<$Res> {
  __$ReadRecordShowCopyWithImpl(this._self, this._then);

  final _ReadRecordShow _self;
  final $Res Function(_ReadRecordShow) _then;

  /// Create a copy of ReadRecordShow
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bookName = null,
    Object? readTime = null,
    Object? lastRead = null,
  }) {
    return _then(
      _ReadRecordShow(
        bookName: null == bookName
            ? _self.bookName
            : bookName // ignore: cast_nullable_to_non_nullable
                  as String,
        readTime: null == readTime
            ? _self.readTime
            : readTime // ignore: cast_nullable_to_non_nullable
                  as int,
        lastRead: null == lastRead
            ? _self.lastRead
            : lastRead // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
mixin _$DictEntry {
  String get word;
  String get phonetic;
  List<String> get definitions;

  /// Create a copy of DictEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DictEntryCopyWith<DictEntry> get copyWith =>
      _$DictEntryCopyWithImpl<DictEntry>(this as DictEntry, _$identity);

  /// Serializes this DictEntry to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as DictEntry;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DictEntry &&
            (identical(other.word, _this.word) || other.word == _this.word) &&
            (identical(other.phonetic, _this.phonetic) ||
                other.phonetic == _this.phonetic) &&
            const DeepCollectionEquality().equals(
              other.definitions,
              _this.definitions,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as DictEntry;
    return Object.hash(
      runtimeType,
      _this.word,
      _this.phonetic,
      const DeepCollectionEquality().hash(_this.definitions),
    );
  }

  @override
  String toString() {
    final _this = this as DictEntry;
    return 'DictEntry(word: ${_this.word}, phonetic: ${_this.phonetic}, definitions: ${_this.definitions})';
  }
}

/// @nodoc
abstract mixin class $DictEntryCopyWith<$Res> {
  factory $DictEntryCopyWith(DictEntry value, $Res Function(DictEntry) _then) =
      _$DictEntryCopyWithImpl;
  @useResult
  $Res call({String word, String phonetic, List<String> definitions});
}

/// @nodoc
class _$DictEntryCopyWithImpl<$Res> implements $DictEntryCopyWith<$Res> {
  _$DictEntryCopyWithImpl(this._self, this._then);

  final DictEntry _self;
  final $Res Function(DictEntry) _then;

  /// Create a copy of DictEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? word = null,
    Object? phonetic = null,
    Object? definitions = null,
  }) {
    return _then(
      DictEntry(
        word: null == word
            ? _self.word
            : word // ignore: cast_nullable_to_non_nullable
                  as String,
        phonetic: null == phonetic
            ? _self.phonetic
            : phonetic // ignore: cast_nullable_to_non_nullable
                  as String,
        definitions: null == definitions
            ? _self.definitions
            : definitions // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [DictEntry].
extension DictEntryPatterns on DictEntry {
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
    TResult Function(_DictEntry value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DictEntry() when $default != null:
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
    TResult Function(_DictEntry value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictEntry():
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
    TResult? Function(_DictEntry value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictEntry() when $default != null:
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
    TResult Function(String word, String phonetic, List<String> definitions)?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DictEntry() when $default != null:
        return $default(_that.word, _that.phonetic, _that.definitions);
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
    TResult Function(String word, String phonetic, List<String> definitions)
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictEntry():
        return $default(_that.word, _that.phonetic, _that.definitions);
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
    TResult? Function(String word, String phonetic, List<String> definitions)?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DictEntry() when $default != null:
        return $default(_that.word, _that.phonetic, _that.definitions);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DictEntry implements DictEntry {
  const _DictEntry({
    this.word = '',
    this.phonetic = '',
    List<String> definitions = const [],
  }) : _definitions = definitions;
  factory _DictEntry.fromJson(Map<String, dynamic> json) =>
      _$DictEntryFromJson(json);

  @override
  @JsonKey()
  final String word;
  @override
  @JsonKey()
  final String phonetic;
  final List<String> _definitions;
  @override
  @JsonKey()
  List<String> get definitions {
    if (_definitions is EqualUnmodifiableListView) return _definitions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_definitions);
  }

  /// Create a copy of DictEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DictEntryCopyWith<_DictEntry> get copyWith =>
      __$DictEntryCopyWithImpl<_DictEntry>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DictEntryToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DictEntry &&
            (identical(other.word, word) || other.word == word) &&
            (identical(other.phonetic, phonetic) ||
                other.phonetic == phonetic) &&
            const DeepCollectionEquality().equals(
              other.definitions,
              _definitions,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      word,
      phonetic,
      const DeepCollectionEquality().hash(_definitions),
    );
  }

  @override
  String toString() {
    return 'DictEntry(word: $word, phonetic: $phonetic, definitions: $definitions)';
  }
}

/// @nodoc
abstract mixin class _$DictEntryCopyWith<$Res>
    implements $DictEntryCopyWith<$Res> {
  factory _$DictEntryCopyWith(
    _DictEntry value,
    $Res Function(_DictEntry) _then,
  ) = __$DictEntryCopyWithImpl;
  @override
  @useResult
  $Res call({String word, String phonetic, List<String> definitions});
}

/// @nodoc
class __$DictEntryCopyWithImpl<$Res> implements _$DictEntryCopyWith<$Res> {
  __$DictEntryCopyWithImpl(this._self, this._then);

  final _DictEntry _self;
  final $Res Function(_DictEntry) _then;

  /// Create a copy of DictEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? word = null,
    Object? phonetic = null,
    Object? definitions = null,
  }) {
    return _then(
      _DictEntry(
        word: null == word
            ? _self.word
            : word // ignore: cast_nullable_to_non_nullable
                  as String,
        phonetic: null == phonetic
            ? _self.phonetic
            : phonetic // ignore: cast_nullable_to_non_nullable
                  as String,
        definitions: null == definitions
            ? _self._definitions
            : definitions // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
mixin _$LoginKeyValue {
  String get name;
  String get value;

  /// Create a copy of LoginKeyValue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LoginKeyValueCopyWith<LoginKeyValue> get copyWith =>
      _$LoginKeyValueCopyWithImpl<LoginKeyValue>(
        this as LoginKeyValue,
        _$identity,
      );

  /// Serializes this LoginKeyValue to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as LoginKeyValue;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LoginKeyValue &&
            (identical(other.name, _this.name) || other.name == _this.name) &&
            (identical(other.value, _this.value) ||
                other.value == _this.value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as LoginKeyValue;
    return Object.hash(runtimeType, _this.name, _this.value);
  }

  @override
  String toString() {
    final _this = this as LoginKeyValue;
    return 'LoginKeyValue(name: ${_this.name}, value: ${_this.value})';
  }
}

/// @nodoc
abstract mixin class $LoginKeyValueCopyWith<$Res> {
  factory $LoginKeyValueCopyWith(
    LoginKeyValue value,
    $Res Function(LoginKeyValue) _then,
  ) = _$LoginKeyValueCopyWithImpl;
  @useResult
  $Res call({String name, String value});
}

/// @nodoc
class _$LoginKeyValueCopyWithImpl<$Res>
    implements $LoginKeyValueCopyWith<$Res> {
  _$LoginKeyValueCopyWithImpl(this._self, this._then);

  final LoginKeyValue _self;
  final $Res Function(LoginKeyValue) _then;

  /// Create a copy of LoginKeyValue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? value = null}) {
    return _then(
      LoginKeyValue(
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        value: null == value
            ? _self.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [LoginKeyValue].
extension LoginKeyValuePatterns on LoginKeyValue {
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
    TResult Function(_LoginKeyValue value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LoginKeyValue() when $default != null:
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
    TResult Function(_LoginKeyValue value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoginKeyValue():
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
    TResult? Function(_LoginKeyValue value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoginKeyValue() when $default != null:
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
    TResult Function(String name, String value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LoginKeyValue() when $default != null:
        return $default(_that.name, _that.value);
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
    TResult Function(String name, String value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoginKeyValue():
        return $default(_that.name, _that.value);
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
    TResult? Function(String name, String value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoginKeyValue() when $default != null:
        return $default(_that.name, _that.value);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _LoginKeyValue implements LoginKeyValue {
  const _LoginKeyValue({this.name = '', this.value = ''});
  factory _LoginKeyValue.fromJson(Map<String, dynamic> json) =>
      _$LoginKeyValueFromJson(json);

  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String value;

  /// Create a copy of LoginKeyValue
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LoginKeyValueCopyWith<_LoginKeyValue> get copyWith =>
      __$LoginKeyValueCopyWithImpl<_LoginKeyValue>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LoginKeyValueToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LoginKeyValue &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(runtimeType, name, value);
  }

  @override
  String toString() {
    return 'LoginKeyValue(name: $name, value: $value)';
  }
}

/// @nodoc
abstract mixin class _$LoginKeyValueCopyWith<$Res>
    implements $LoginKeyValueCopyWith<$Res> {
  factory _$LoginKeyValueCopyWith(
    _LoginKeyValue value,
    $Res Function(_LoginKeyValue) _then,
  ) = __$LoginKeyValueCopyWithImpl;
  @override
  @useResult
  $Res call({String name, String value});
}

/// @nodoc
class __$LoginKeyValueCopyWithImpl<$Res>
    implements _$LoginKeyValueCopyWith<$Res> {
  __$LoginKeyValueCopyWithImpl(this._self, this._then);

  final _LoginKeyValue _self;
  final $Res Function(_LoginKeyValue) _then;

  /// Create a copy of LoginKeyValue
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? name = null, Object? value = null}) {
    return _then(
      _LoginKeyValue(
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        value: null == value
            ? _self.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}
