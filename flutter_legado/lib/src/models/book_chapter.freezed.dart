// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_chapter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookChapter {
  String get url;
  String get title;
  @JsonKey(name: 'isVolume')
  bool get isVolume;
  @JsonKey(name: 'baseUrl')
  String get baseUrl;
  @JsonKey(name: 'bookUrl')
  String get bookUrl;
  int get index;
  @JsonKey(name: 'isVip')
  bool get isVip;
  @JsonKey(name: 'isPay')
  bool get isPay;
  @JsonKey(name: 'resourceUrl')
  String? get resourceUrl;
  String? get tag;
  @JsonKey(name: 'wordCount')
  String? get wordCount;
  int? get start;
  int? get end;
  @JsonKey(name: 'startFragmentId')
  String? get startFragmentId;
  @JsonKey(name: 'endFragmentId')
  String? get endFragmentId;
  String? get variable;
  @JsonKey(name: 'imgUrl')
  String? get imgUrl;

  /// Create a copy of BookChapter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookChapterCopyWith<BookChapter> get copyWith =>
      _$BookChapterCopyWithImpl<BookChapter>(this as BookChapter, _$identity);

  /// Serializes this BookChapter to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as BookChapter;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookChapter &&
            (identical(other.url, _this.url) || other.url == _this.url) &&
            (identical(other.title, _this.title) ||
                other.title == _this.title) &&
            (identical(other.isVolume, _this.isVolume) ||
                other.isVolume == _this.isVolume) &&
            (identical(other.baseUrl, _this.baseUrl) ||
                other.baseUrl == _this.baseUrl) &&
            (identical(other.bookUrl, _this.bookUrl) ||
                other.bookUrl == _this.bookUrl) &&
            (identical(other.index, _this.index) ||
                other.index == _this.index) &&
            (identical(other.isVip, _this.isVip) ||
                other.isVip == _this.isVip) &&
            (identical(other.isPay, _this.isPay) ||
                other.isPay == _this.isPay) &&
            (identical(other.resourceUrl, _this.resourceUrl) ||
                other.resourceUrl == _this.resourceUrl) &&
            (identical(other.tag, _this.tag) || other.tag == _this.tag) &&
            (identical(other.wordCount, _this.wordCount) ||
                other.wordCount == _this.wordCount) &&
            (identical(other.start, _this.start) ||
                other.start == _this.start) &&
            (identical(other.end, _this.end) || other.end == _this.end) &&
            (identical(other.startFragmentId, _this.startFragmentId) ||
                other.startFragmentId == _this.startFragmentId) &&
            (identical(other.endFragmentId, _this.endFragmentId) ||
                other.endFragmentId == _this.endFragmentId) &&
            (identical(other.variable, _this.variable) ||
                other.variable == _this.variable) &&
            (identical(other.imgUrl, _this.imgUrl) ||
                other.imgUrl == _this.imgUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as BookChapter;
    return Object.hash(
      runtimeType,
      _this.url,
      _this.title,
      _this.isVolume,
      _this.baseUrl,
      _this.bookUrl,
      _this.index,
      _this.isVip,
      _this.isPay,
      _this.resourceUrl,
      _this.tag,
      _this.wordCount,
      _this.start,
      _this.end,
      _this.startFragmentId,
      _this.endFragmentId,
      _this.variable,
      _this.imgUrl,
    );
  }

  @override
  String toString() {
    final _this = this as BookChapter;
    return 'BookChapter(url: ${_this.url}, title: ${_this.title}, isVolume: ${_this.isVolume}, baseUrl: ${_this.baseUrl}, bookUrl: ${_this.bookUrl}, index: ${_this.index}, isVip: ${_this.isVip}, isPay: ${_this.isPay}, resourceUrl: ${_this.resourceUrl}, tag: ${_this.tag}, wordCount: ${_this.wordCount}, start: ${_this.start}, end: ${_this.end}, startFragmentId: ${_this.startFragmentId}, endFragmentId: ${_this.endFragmentId}, variable: ${_this.variable}, imgUrl: ${_this.imgUrl})';
  }
}

/// @nodoc
abstract mixin class $BookChapterCopyWith<$Res> {
  factory $BookChapterCopyWith(
    BookChapter value,
    $Res Function(BookChapter) _then,
  ) = _$BookChapterCopyWithImpl;
  @useResult
  $Res call({
    String url,
    String title,
    @JsonKey(name: 'isVolume') bool isVolume,
    @JsonKey(name: 'baseUrl') String baseUrl,
    @JsonKey(name: 'bookUrl') String bookUrl,
    int index,
    @JsonKey(name: 'isVip') bool isVip,
    @JsonKey(name: 'isPay') bool isPay,
    @JsonKey(name: 'resourceUrl') String? resourceUrl,
    String? tag,
    @JsonKey(name: 'wordCount') String? wordCount,
    int? start,
    int? end,
    @JsonKey(name: 'startFragmentId') String? startFragmentId,
    @JsonKey(name: 'endFragmentId') String? endFragmentId,
    String? variable,
    @JsonKey(name: 'imgUrl') String? imgUrl,
  });
}

/// @nodoc
class _$BookChapterCopyWithImpl<$Res> implements $BookChapterCopyWith<$Res> {
  _$BookChapterCopyWithImpl(this._self, this._then);

  final BookChapter _self;
  final $Res Function(BookChapter) _then;

  /// Create a copy of BookChapter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? title = null,
    Object? isVolume = null,
    Object? baseUrl = null,
    Object? bookUrl = null,
    Object? index = null,
    Object? isVip = null,
    Object? isPay = null,
    Object? resourceUrl = freezed,
    Object? tag = freezed,
    Object? wordCount = freezed,
    Object? start = freezed,
    Object? end = freezed,
    Object? startFragmentId = freezed,
    Object? endFragmentId = freezed,
    Object? variable = freezed,
    Object? imgUrl = freezed,
  }) {
    return _then(
      BookChapter(
        url: null == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        isVolume: null == isVolume
            ? _self.isVolume
            : isVolume // ignore: cast_nullable_to_non_nullable
                  as bool,
        baseUrl: null == baseUrl
            ? _self.baseUrl
            : baseUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        index: null == index
            ? _self.index
            : index // ignore: cast_nullable_to_non_nullable
                  as int,
        isVip: null == isVip
            ? _self.isVip
            : isVip // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPay: null == isPay
            ? _self.isPay
            : isPay // ignore: cast_nullable_to_non_nullable
                  as bool,
        resourceUrl: freezed == resourceUrl
            ? _self.resourceUrl
            : resourceUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        tag: freezed == tag
            ? _self.tag
            : tag // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        start: freezed == start
            ? _self.start
            : start // ignore: cast_nullable_to_non_nullable
                  as int?,
        end: freezed == end
            ? _self.end
            : end // ignore: cast_nullable_to_non_nullable
                  as int?,
        startFragmentId: freezed == startFragmentId
            ? _self.startFragmentId
            : startFragmentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        endFragmentId: freezed == endFragmentId
            ? _self.endFragmentId
            : endFragmentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        variable: freezed == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String?,
        imgUrl: freezed == imgUrl
            ? _self.imgUrl
            : imgUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BookChapter].
extension BookChapterPatterns on BookChapter {
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
    TResult Function(_BookChapter value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookChapter() when $default != null:
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
    TResult Function(_BookChapter value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookChapter():
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
    TResult? Function(_BookChapter value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookChapter() when $default != null:
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
      String url,
      String title,
      @JsonKey(name: 'isVolume') bool isVolume,
      @JsonKey(name: 'baseUrl') String baseUrl,
      @JsonKey(name: 'bookUrl') String bookUrl,
      int index,
      @JsonKey(name: 'isVip') bool isVip,
      @JsonKey(name: 'isPay') bool isPay,
      @JsonKey(name: 'resourceUrl') String? resourceUrl,
      String? tag,
      @JsonKey(name: 'wordCount') String? wordCount,
      int? start,
      int? end,
      @JsonKey(name: 'startFragmentId') String? startFragmentId,
      @JsonKey(name: 'endFragmentId') String? endFragmentId,
      String? variable,
      @JsonKey(name: 'imgUrl') String? imgUrl,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookChapter() when $default != null:
        return $default(
          _that.url,
          _that.title,
          _that.isVolume,
          _that.baseUrl,
          _that.bookUrl,
          _that.index,
          _that.isVip,
          _that.isPay,
          _that.resourceUrl,
          _that.tag,
          _that.wordCount,
          _that.start,
          _that.end,
          _that.startFragmentId,
          _that.endFragmentId,
          _that.variable,
          _that.imgUrl,
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
      String url,
      String title,
      @JsonKey(name: 'isVolume') bool isVolume,
      @JsonKey(name: 'baseUrl') String baseUrl,
      @JsonKey(name: 'bookUrl') String bookUrl,
      int index,
      @JsonKey(name: 'isVip') bool isVip,
      @JsonKey(name: 'isPay') bool isPay,
      @JsonKey(name: 'resourceUrl') String? resourceUrl,
      String? tag,
      @JsonKey(name: 'wordCount') String? wordCount,
      int? start,
      int? end,
      @JsonKey(name: 'startFragmentId') String? startFragmentId,
      @JsonKey(name: 'endFragmentId') String? endFragmentId,
      String? variable,
      @JsonKey(name: 'imgUrl') String? imgUrl,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookChapter():
        return $default(
          _that.url,
          _that.title,
          _that.isVolume,
          _that.baseUrl,
          _that.bookUrl,
          _that.index,
          _that.isVip,
          _that.isPay,
          _that.resourceUrl,
          _that.tag,
          _that.wordCount,
          _that.start,
          _that.end,
          _that.startFragmentId,
          _that.endFragmentId,
          _that.variable,
          _that.imgUrl,
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
      String url,
      String title,
      @JsonKey(name: 'isVolume') bool isVolume,
      @JsonKey(name: 'baseUrl') String baseUrl,
      @JsonKey(name: 'bookUrl') String bookUrl,
      int index,
      @JsonKey(name: 'isVip') bool isVip,
      @JsonKey(name: 'isPay') bool isPay,
      @JsonKey(name: 'resourceUrl') String? resourceUrl,
      String? tag,
      @JsonKey(name: 'wordCount') String? wordCount,
      int? start,
      int? end,
      @JsonKey(name: 'startFragmentId') String? startFragmentId,
      @JsonKey(name: 'endFragmentId') String? endFragmentId,
      String? variable,
      @JsonKey(name: 'imgUrl') String? imgUrl,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookChapter() when $default != null:
        return $default(
          _that.url,
          _that.title,
          _that.isVolume,
          _that.baseUrl,
          _that.bookUrl,
          _that.index,
          _that.isVip,
          _that.isPay,
          _that.resourceUrl,
          _that.tag,
          _that.wordCount,
          _that.start,
          _that.end,
          _that.startFragmentId,
          _that.endFragmentId,
          _that.variable,
          _that.imgUrl,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BookChapter implements BookChapter {
  const _BookChapter({
    this.url = '',
    this.title = '',
    @JsonKey(name: 'isVolume') this.isVolume = false,
    @JsonKey(name: 'baseUrl') this.baseUrl = '',
    @JsonKey(name: 'bookUrl') this.bookUrl = '',
    this.index = 0,
    @JsonKey(name: 'isVip') this.isVip = false,
    @JsonKey(name: 'isPay') this.isPay = false,
    @JsonKey(name: 'resourceUrl') this.resourceUrl,
    this.tag,
    @JsonKey(name: 'wordCount') this.wordCount,
    this.start,
    this.end,
    @JsonKey(name: 'startFragmentId') this.startFragmentId,
    @JsonKey(name: 'endFragmentId') this.endFragmentId,
    this.variable,
    @JsonKey(name: 'imgUrl') this.imgUrl,
  });
  factory _BookChapter.fromJson(Map<String, dynamic> json) =>
      _$BookChapterFromJson(json);

  @override
  @JsonKey()
  final String url;
  @override
  @JsonKey()
  final String title;
  @override
  @JsonKey(name: 'isVolume')
  final bool isVolume;
  @override
  @JsonKey(name: 'baseUrl')
  final String baseUrl;
  @override
  @JsonKey(name: 'bookUrl')
  final String bookUrl;
  @override
  @JsonKey()
  final int index;
  @override
  @JsonKey(name: 'isVip')
  final bool isVip;
  @override
  @JsonKey(name: 'isPay')
  final bool isPay;
  @override
  @JsonKey(name: 'resourceUrl')
  final String? resourceUrl;
  @override
  final String? tag;
  @override
  @JsonKey(name: 'wordCount')
  final String? wordCount;
  @override
  final int? start;
  @override
  final int? end;
  @override
  @JsonKey(name: 'startFragmentId')
  final String? startFragmentId;
  @override
  @JsonKey(name: 'endFragmentId')
  final String? endFragmentId;
  @override
  final String? variable;
  @override
  @JsonKey(name: 'imgUrl')
  final String? imgUrl;

  /// Create a copy of BookChapter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookChapterCopyWith<_BookChapter> get copyWith =>
      __$BookChapterCopyWithImpl<_BookChapter>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BookChapterToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookChapter &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.isVolume, isVolume) ||
                other.isVolume == isVolume) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.isVip, isVip) || other.isVip == isVip) &&
            (identical(other.isPay, isPay) || other.isPay == isPay) &&
            (identical(other.resourceUrl, resourceUrl) ||
                other.resourceUrl == resourceUrl) &&
            (identical(other.tag, tag) || other.tag == tag) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.end, end) || other.end == end) &&
            (identical(other.startFragmentId, startFragmentId) ||
                other.startFragmentId == startFragmentId) &&
            (identical(other.endFragmentId, endFragmentId) ||
                other.endFragmentId == endFragmentId) &&
            (identical(other.variable, variable) ||
                other.variable == variable) &&
            (identical(other.imgUrl, imgUrl) || other.imgUrl == imgUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      url,
      title,
      isVolume,
      baseUrl,
      bookUrl,
      index,
      isVip,
      isPay,
      resourceUrl,
      tag,
      wordCount,
      start,
      end,
      startFragmentId,
      endFragmentId,
      variable,
      imgUrl,
    );
  }

  @override
  String toString() {
    return 'BookChapter(url: $url, title: $title, isVolume: $isVolume, baseUrl: $baseUrl, bookUrl: $bookUrl, index: $index, isVip: $isVip, isPay: $isPay, resourceUrl: $resourceUrl, tag: $tag, wordCount: $wordCount, start: $start, end: $end, startFragmentId: $startFragmentId, endFragmentId: $endFragmentId, variable: $variable, imgUrl: $imgUrl)';
  }
}

/// @nodoc
abstract mixin class _$BookChapterCopyWith<$Res>
    implements $BookChapterCopyWith<$Res> {
  factory _$BookChapterCopyWith(
    _BookChapter value,
    $Res Function(_BookChapter) _then,
  ) = __$BookChapterCopyWithImpl;
  @override
  @useResult
  $Res call({
    String url,
    String title,
    @JsonKey(name: 'isVolume') bool isVolume,
    @JsonKey(name: 'baseUrl') String baseUrl,
    @JsonKey(name: 'bookUrl') String bookUrl,
    int index,
    @JsonKey(name: 'isVip') bool isVip,
    @JsonKey(name: 'isPay') bool isPay,
    @JsonKey(name: 'resourceUrl') String? resourceUrl,
    String? tag,
    @JsonKey(name: 'wordCount') String? wordCount,
    int? start,
    int? end,
    @JsonKey(name: 'startFragmentId') String? startFragmentId,
    @JsonKey(name: 'endFragmentId') String? endFragmentId,
    String? variable,
    @JsonKey(name: 'imgUrl') String? imgUrl,
  });
}

/// @nodoc
class __$BookChapterCopyWithImpl<$Res> implements _$BookChapterCopyWith<$Res> {
  __$BookChapterCopyWithImpl(this._self, this._then);

  final _BookChapter _self;
  final $Res Function(_BookChapter) _then;

  /// Create a copy of BookChapter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? url = null,
    Object? title = null,
    Object? isVolume = null,
    Object? baseUrl = null,
    Object? bookUrl = null,
    Object? index = null,
    Object? isVip = null,
    Object? isPay = null,
    Object? resourceUrl = freezed,
    Object? tag = freezed,
    Object? wordCount = freezed,
    Object? start = freezed,
    Object? end = freezed,
    Object? startFragmentId = freezed,
    Object? endFragmentId = freezed,
    Object? variable = freezed,
    Object? imgUrl = freezed,
  }) {
    return _then(
      _BookChapter(
        url: null == url
            ? _self.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _self.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        isVolume: null == isVolume
            ? _self.isVolume
            : isVolume // ignore: cast_nullable_to_non_nullable
                  as bool,
        baseUrl: null == baseUrl
            ? _self.baseUrl
            : baseUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        index: null == index
            ? _self.index
            : index // ignore: cast_nullable_to_non_nullable
                  as int,
        isVip: null == isVip
            ? _self.isVip
            : isVip // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPay: null == isPay
            ? _self.isPay
            : isPay // ignore: cast_nullable_to_non_nullable
                  as bool,
        resourceUrl: freezed == resourceUrl
            ? _self.resourceUrl
            : resourceUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        tag: freezed == tag
            ? _self.tag
            : tag // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: freezed == wordCount
            ? _self.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as String?,
        start: freezed == start
            ? _self.start
            : start // ignore: cast_nullable_to_non_nullable
                  as int?,
        end: freezed == end
            ? _self.end
            : end // ignore: cast_nullable_to_non_nullable
                  as int?,
        startFragmentId: freezed == startFragmentId
            ? _self.startFragmentId
            : startFragmentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        endFragmentId: freezed == endFragmentId
            ? _self.endFragmentId
            : endFragmentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        variable: freezed == variable
            ? _self.variable
            : variable // ignore: cast_nullable_to_non_nullable
                  as String?,
        imgUrl: freezed == imgUrl
            ? _self.imgUrl
            : imgUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
