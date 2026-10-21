// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReaderState {
  /// 当前阅读的书籍
  Book? get currentBook;

  /// 章节目录列表（Rust 返回，已排序）
  List<BookChapter> get chapters;

  /// 当前章节索引
  int get currentChapterIndex;

  /// 当前章节内阅读位置
  int get currentChapterPos;

  /// 当前章节正文（Rust 已完成净化/替换的最终文本）
  String get chapterContent;

  /// 是否正在加载
  bool get isLoading;

  /// 错误信息（null 表示无错误）
  String? get error;

  /// 工具栏是否显示
  bool get showControls;

  /// 字体大小
  /// [C2 R1] 默认字号对齐参考（参考 ~20-22sp/行 ~14 字；原版 ReadBookConfig
  /// textSize=20sp）：18.0 → 20.0
  double get fontSize;

  /// 行高倍数
  /// 参考版lineSpacingExtra=12：自然字体行盒的1.2倍推进。
  double get lineHeight;

  /// 背景色
  Color get backgroundColor;

  /// 当前阅读样式的文字色；空值根据背景亮度自动选择。
  Color? get foregroundColor;

  /// 阅读模式的有效亮度，与应用主题和背景颜色分别表达。
  Brightness? get readingBrightness;

  /// 翻页模式
  PageTurnMode get pageTurnMode;

  /// 全局页索引（跨章节连续编号，从 0 开始）
  int get globalPageIndex;

  /// 全局总页数（所有章节页数之和）
  int get totalPages;

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReaderStateCopyWith<ReaderState> get copyWith =>
      _$ReaderStateCopyWithImpl<ReaderState>(this as ReaderState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as ReaderState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReaderState &&
            (identical(other.currentBook, _this.currentBook) ||
                other.currentBook == _this.currentBook) &&
            const DeepCollectionEquality().equals(
              other.chapters,
              _this.chapters,
            ) &&
            (identical(other.currentChapterIndex, _this.currentChapterIndex) ||
                other.currentChapterIndex == _this.currentChapterIndex) &&
            (identical(other.currentChapterPos, _this.currentChapterPos) ||
                other.currentChapterPos == _this.currentChapterPos) &&
            (identical(other.chapterContent, _this.chapterContent) ||
                other.chapterContent == _this.chapterContent) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            (identical(other.showControls, _this.showControls) ||
                other.showControls == _this.showControls) &&
            (identical(other.fontSize, _this.fontSize) ||
                other.fontSize == _this.fontSize) &&
            (identical(other.lineHeight, _this.lineHeight) ||
                other.lineHeight == _this.lineHeight) &&
            (identical(other.backgroundColor, _this.backgroundColor) ||
                other.backgroundColor == _this.backgroundColor) &&
            (identical(other.foregroundColor, _this.foregroundColor) ||
                other.foregroundColor == _this.foregroundColor) &&
            (identical(other.readingBrightness, _this.readingBrightness) ||
                other.readingBrightness == _this.readingBrightness) &&
            (identical(other.pageTurnMode, _this.pageTurnMode) ||
                other.pageTurnMode == _this.pageTurnMode) &&
            (identical(other.globalPageIndex, _this.globalPageIndex) ||
                other.globalPageIndex == _this.globalPageIndex) &&
            (identical(other.totalPages, _this.totalPages) ||
                other.totalPages == _this.totalPages));
  }

  @override
  int get hashCode {
    final _this = this as ReaderState;
    return Object.hash(
      runtimeType,
      _this.currentBook,
      const DeepCollectionEquality().hash(_this.chapters),
      _this.currentChapterIndex,
      _this.currentChapterPos,
      _this.chapterContent,
      _this.isLoading,
      _this.error,
      _this.showControls,
      _this.fontSize,
      _this.lineHeight,
      _this.backgroundColor,
      _this.foregroundColor,
      _this.readingBrightness,
      _this.pageTurnMode,
      _this.globalPageIndex,
      _this.totalPages,
    );
  }

  @override
  String toString() {
    final _this = this as ReaderState;
    return 'ReaderState(currentBook: ${_this.currentBook}, chapters: ${_this.chapters}, currentChapterIndex: ${_this.currentChapterIndex}, currentChapterPos: ${_this.currentChapterPos}, chapterContent: ${_this.chapterContent}, isLoading: ${_this.isLoading}, error: ${_this.error}, showControls: ${_this.showControls}, fontSize: ${_this.fontSize}, lineHeight: ${_this.lineHeight}, backgroundColor: ${_this.backgroundColor}, foregroundColor: ${_this.foregroundColor}, readingBrightness: ${_this.readingBrightness}, pageTurnMode: ${_this.pageTurnMode}, globalPageIndex: ${_this.globalPageIndex}, totalPages: ${_this.totalPages})';
  }
}

/// @nodoc
abstract mixin class $ReaderStateCopyWith<$Res> {
  factory $ReaderStateCopyWith(
    ReaderState value,
    $Res Function(ReaderState) _then,
  ) = _$ReaderStateCopyWithImpl;
  @useResult
  $Res call({
    Book? currentBook,
    List<BookChapter> chapters,
    int currentChapterIndex,
    int currentChapterPos,
    String chapterContent,
    bool isLoading,
    String? error,
    bool showControls,
    double fontSize,
    double lineHeight,
    Color backgroundColor,
    Color? foregroundColor,
    Brightness? readingBrightness,
    PageTurnMode pageTurnMode,
    int globalPageIndex,
    int totalPages,
  });

  $BookCopyWith<$Res>? get currentBook;
}

/// @nodoc
class _$ReaderStateCopyWithImpl<$Res> implements $ReaderStateCopyWith<$Res> {
  _$ReaderStateCopyWithImpl(this._self, this._then);

  final ReaderState _self;
  final $Res Function(ReaderState) _then;

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentBook = freezed,
    Object? chapters = null,
    Object? currentChapterIndex = null,
    Object? currentChapterPos = null,
    Object? chapterContent = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? showControls = null,
    Object? fontSize = null,
    Object? lineHeight = null,
    Object? backgroundColor = null,
    Object? foregroundColor = freezed,
    Object? readingBrightness = freezed,
    Object? pageTurnMode = null,
    Object? globalPageIndex = null,
    Object? totalPages = null,
  }) {
    return _then(
      ReaderState(
        currentBook: freezed == currentBook
            ? _self.currentBook
            : currentBook // ignore: cast_nullable_to_non_nullable
                  as Book?,
        chapters: null == chapters
            ? _self.chapters
            : chapters // ignore: cast_nullable_to_non_nullable
                  as List<BookChapter>,
        currentChapterIndex: null == currentChapterIndex
            ? _self.currentChapterIndex
            : currentChapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        currentChapterPos: null == currentChapterPos
            ? _self.currentChapterPos
            : currentChapterPos // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterContent: null == chapterContent
            ? _self.chapterContent
            : chapterContent // ignore: cast_nullable_to_non_nullable
                  as String,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        showControls: null == showControls
            ? _self.showControls
            : showControls // ignore: cast_nullable_to_non_nullable
                  as bool,
        fontSize: null == fontSize
            ? _self.fontSize
            : fontSize // ignore: cast_nullable_to_non_nullable
                  as double,
        lineHeight: null == lineHeight
            ? _self.lineHeight
            : lineHeight // ignore: cast_nullable_to_non_nullable
                  as double,
        backgroundColor: null == backgroundColor
            ? _self.backgroundColor
            : backgroundColor // ignore: cast_nullable_to_non_nullable
                  as Color,
        foregroundColor: freezed == foregroundColor
            ? _self.foregroundColor
            : foregroundColor // ignore: cast_nullable_to_non_nullable
                  as Color?,
        readingBrightness: freezed == readingBrightness
            ? _self.readingBrightness
            : readingBrightness // ignore: cast_nullable_to_non_nullable
                  as Brightness?,
        pageTurnMode: null == pageTurnMode
            ? _self.pageTurnMode
            : pageTurnMode // ignore: cast_nullable_to_non_nullable
                  as PageTurnMode,
        globalPageIndex: null == globalPageIndex
            ? _self.globalPageIndex
            : globalPageIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        totalPages: null == totalPages
            ? _self.totalPages
            : totalPages // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BookCopyWith<$Res>? get currentBook {
    if (_self.currentBook == null) {
      return null;
    }

    return $BookCopyWith<$Res>(_self.currentBook!, (value) {
      return _then(_self.copyWith(currentBook: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ReaderState].
extension ReaderStatePatterns on ReaderState {
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
    TResult Function(_ReaderState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReaderState() when $default != null:
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
    TResult Function(_ReaderState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReaderState():
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
    TResult? Function(_ReaderState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReaderState() when $default != null:
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
      Book? currentBook,
      List<BookChapter> chapters,
      int currentChapterIndex,
      int currentChapterPos,
      String chapterContent,
      bool isLoading,
      String? error,
      bool showControls,
      double fontSize,
      double lineHeight,
      Color backgroundColor,
      Color? foregroundColor,
      Brightness? readingBrightness,
      PageTurnMode pageTurnMode,
      int globalPageIndex,
      int totalPages,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReaderState() when $default != null:
        return $default(
          _that.currentBook,
          _that.chapters,
          _that.currentChapterIndex,
          _that.currentChapterPos,
          _that.chapterContent,
          _that.isLoading,
          _that.error,
          _that.showControls,
          _that.fontSize,
          _that.lineHeight,
          _that.backgroundColor,
          _that.foregroundColor,
          _that.readingBrightness,
          _that.pageTurnMode,
          _that.globalPageIndex,
          _that.totalPages,
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
      Book? currentBook,
      List<BookChapter> chapters,
      int currentChapterIndex,
      int currentChapterPos,
      String chapterContent,
      bool isLoading,
      String? error,
      bool showControls,
      double fontSize,
      double lineHeight,
      Color backgroundColor,
      Color? foregroundColor,
      Brightness? readingBrightness,
      PageTurnMode pageTurnMode,
      int globalPageIndex,
      int totalPages,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReaderState():
        return $default(
          _that.currentBook,
          _that.chapters,
          _that.currentChapterIndex,
          _that.currentChapterPos,
          _that.chapterContent,
          _that.isLoading,
          _that.error,
          _that.showControls,
          _that.fontSize,
          _that.lineHeight,
          _that.backgroundColor,
          _that.foregroundColor,
          _that.readingBrightness,
          _that.pageTurnMode,
          _that.globalPageIndex,
          _that.totalPages,
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
      Book? currentBook,
      List<BookChapter> chapters,
      int currentChapterIndex,
      int currentChapterPos,
      String chapterContent,
      bool isLoading,
      String? error,
      bool showControls,
      double fontSize,
      double lineHeight,
      Color backgroundColor,
      Color? foregroundColor,
      Brightness? readingBrightness,
      PageTurnMode pageTurnMode,
      int globalPageIndex,
      int totalPages,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReaderState() when $default != null:
        return $default(
          _that.currentBook,
          _that.chapters,
          _that.currentChapterIndex,
          _that.currentChapterPos,
          _that.chapterContent,
          _that.isLoading,
          _that.error,
          _that.showControls,
          _that.fontSize,
          _that.lineHeight,
          _that.backgroundColor,
          _that.foregroundColor,
          _that.readingBrightness,
          _that.pageTurnMode,
          _that.globalPageIndex,
          _that.totalPages,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ReaderState implements ReaderState {
  const _ReaderState({
    this.currentBook,
    List<BookChapter> chapters = const [],
    this.currentChapterIndex = 0,
    this.currentChapterPos = 0,
    this.chapterContent = '',
    this.isLoading = false,
    this.error,
    this.showControls = false,
    this.fontSize = 20.0,
    this.lineHeight = 1.2,
    this.backgroundColor = ReaderBackground.white,
    this.foregroundColor,
    this.readingBrightness,
    this.pageTurnMode = PageTurnMode.cover,
    this.globalPageIndex = 0,
    this.totalPages = 0,
  }) : _chapters = chapters;

  /// 当前阅读的书籍
  @override
  final Book? currentBook;

  /// 章节目录列表（Rust 返回，已排序）
  final List<BookChapter> _chapters;

  /// 章节目录列表（Rust 返回，已排序）
  @override
  @JsonKey()
  List<BookChapter> get chapters {
    if (_chapters is EqualUnmodifiableListView) return _chapters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapters);
  }

  /// 当前章节索引
  @override
  @JsonKey()
  final int currentChapterIndex;

  /// 当前章节内阅读位置
  @override
  @JsonKey()
  final int currentChapterPos;

  /// 当前章节正文（Rust 已完成净化/替换的最终文本）
  @override
  @JsonKey()
  final String chapterContent;

  /// 是否正在加载
  @override
  @JsonKey()
  final bool isLoading;

  /// 错误信息（null 表示无错误）
  @override
  final String? error;

  /// 工具栏是否显示
  @override
  @JsonKey()
  final bool showControls;

  /// 字体大小
  /// [C2 R1] 默认字号对齐参考（参考 ~20-22sp/行 ~14 字；原版 ReadBookConfig
  /// textSize=20sp）：18.0 → 20.0
  @override
  @JsonKey()
  final double fontSize;

  /// 行高倍数
  /// 参考版lineSpacingExtra=12：自然字体行盒的1.2倍推进。
  @override
  @JsonKey()
  final double lineHeight;

  /// 背景色
  @override
  @JsonKey()
  final Color backgroundColor;

  /// 当前阅读样式的文字色；空值根据背景亮度自动选择。
  @override
  final Color? foregroundColor;

  /// 阅读模式的有效亮度，与应用主题和背景颜色分别表达。
  @override
  final Brightness? readingBrightness;

  /// 翻页模式
  @override
  @JsonKey()
  final PageTurnMode pageTurnMode;

  /// 全局页索引（跨章节连续编号，从 0 开始）
  @override
  @JsonKey()
  final int globalPageIndex;

  /// 全局总页数（所有章节页数之和）
  @override
  @JsonKey()
  final int totalPages;

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReaderStateCopyWith<_ReaderState> get copyWith =>
      __$ReaderStateCopyWithImpl<_ReaderState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReaderState &&
            (identical(other.currentBook, currentBook) ||
                other.currentBook == currentBook) &&
            const DeepCollectionEquality().equals(other.chapters, _chapters) &&
            (identical(other.currentChapterIndex, currentChapterIndex) ||
                other.currentChapterIndex == currentChapterIndex) &&
            (identical(other.currentChapterPos, currentChapterPos) ||
                other.currentChapterPos == currentChapterPos) &&
            (identical(other.chapterContent, chapterContent) ||
                other.chapterContent == chapterContent) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.showControls, showControls) ||
                other.showControls == showControls) &&
            (identical(other.fontSize, fontSize) ||
                other.fontSize == fontSize) &&
            (identical(other.lineHeight, lineHeight) ||
                other.lineHeight == lineHeight) &&
            (identical(other.backgroundColor, backgroundColor) ||
                other.backgroundColor == backgroundColor) &&
            (identical(other.foregroundColor, foregroundColor) ||
                other.foregroundColor == foregroundColor) &&
            (identical(other.readingBrightness, readingBrightness) ||
                other.readingBrightness == readingBrightness) &&
            (identical(other.pageTurnMode, pageTurnMode) ||
                other.pageTurnMode == pageTurnMode) &&
            (identical(other.globalPageIndex, globalPageIndex) ||
                other.globalPageIndex == globalPageIndex) &&
            (identical(other.totalPages, totalPages) ||
                other.totalPages == totalPages));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      currentBook,
      const DeepCollectionEquality().hash(_chapters),
      currentChapterIndex,
      currentChapterPos,
      chapterContent,
      isLoading,
      error,
      showControls,
      fontSize,
      lineHeight,
      backgroundColor,
      foregroundColor,
      readingBrightness,
      pageTurnMode,
      globalPageIndex,
      totalPages,
    );
  }

  @override
  String toString() {
    return 'ReaderState(currentBook: $currentBook, chapters: $chapters, currentChapterIndex: $currentChapterIndex, currentChapterPos: $currentChapterPos, chapterContent: $chapterContent, isLoading: $isLoading, error: $error, showControls: $showControls, fontSize: $fontSize, lineHeight: $lineHeight, backgroundColor: $backgroundColor, foregroundColor: $foregroundColor, readingBrightness: $readingBrightness, pageTurnMode: $pageTurnMode, globalPageIndex: $globalPageIndex, totalPages: $totalPages)';
  }
}

/// @nodoc
abstract mixin class _$ReaderStateCopyWith<$Res>
    implements $ReaderStateCopyWith<$Res> {
  factory _$ReaderStateCopyWith(
    _ReaderState value,
    $Res Function(_ReaderState) _then,
  ) = __$ReaderStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    Book? currentBook,
    List<BookChapter> chapters,
    int currentChapterIndex,
    int currentChapterPos,
    String chapterContent,
    bool isLoading,
    String? error,
    bool showControls,
    double fontSize,
    double lineHeight,
    Color backgroundColor,
    Color? foregroundColor,
    Brightness? readingBrightness,
    PageTurnMode pageTurnMode,
    int globalPageIndex,
    int totalPages,
  });

  @override
  $BookCopyWith<$Res>? get currentBook;
}

/// @nodoc
class __$ReaderStateCopyWithImpl<$Res> implements _$ReaderStateCopyWith<$Res> {
  __$ReaderStateCopyWithImpl(this._self, this._then);

  final _ReaderState _self;
  final $Res Function(_ReaderState) _then;

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? currentBook = freezed,
    Object? chapters = null,
    Object? currentChapterIndex = null,
    Object? currentChapterPos = null,
    Object? chapterContent = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? showControls = null,
    Object? fontSize = null,
    Object? lineHeight = null,
    Object? backgroundColor = null,
    Object? foregroundColor = freezed,
    Object? readingBrightness = freezed,
    Object? pageTurnMode = null,
    Object? globalPageIndex = null,
    Object? totalPages = null,
  }) {
    return _then(
      _ReaderState(
        currentBook: freezed == currentBook
            ? _self.currentBook
            : currentBook // ignore: cast_nullable_to_non_nullable
                  as Book?,
        chapters: null == chapters
            ? _self._chapters
            : chapters // ignore: cast_nullable_to_non_nullable
                  as List<BookChapter>,
        currentChapterIndex: null == currentChapterIndex
            ? _self.currentChapterIndex
            : currentChapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        currentChapterPos: null == currentChapterPos
            ? _self.currentChapterPos
            : currentChapterPos // ignore: cast_nullable_to_non_nullable
                  as int,
        chapterContent: null == chapterContent
            ? _self.chapterContent
            : chapterContent // ignore: cast_nullable_to_non_nullable
                  as String,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        showControls: null == showControls
            ? _self.showControls
            : showControls // ignore: cast_nullable_to_non_nullable
                  as bool,
        fontSize: null == fontSize
            ? _self.fontSize
            : fontSize // ignore: cast_nullable_to_non_nullable
                  as double,
        lineHeight: null == lineHeight
            ? _self.lineHeight
            : lineHeight // ignore: cast_nullable_to_non_nullable
                  as double,
        backgroundColor: null == backgroundColor
            ? _self.backgroundColor
            : backgroundColor // ignore: cast_nullable_to_non_nullable
                  as Color,
        foregroundColor: freezed == foregroundColor
            ? _self.foregroundColor
            : foregroundColor // ignore: cast_nullable_to_non_nullable
                  as Color?,
        readingBrightness: freezed == readingBrightness
            ? _self.readingBrightness
            : readingBrightness // ignore: cast_nullable_to_non_nullable
                  as Brightness?,
        pageTurnMode: null == pageTurnMode
            ? _self.pageTurnMode
            : pageTurnMode // ignore: cast_nullable_to_non_nullable
                  as PageTurnMode,
        globalPageIndex: null == globalPageIndex
            ? _self.globalPageIndex
            : globalPageIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        totalPages: null == totalPages
            ? _self.totalPages
            : totalPages // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BookCopyWith<$Res>? get currentBook {
    if (_self.currentBook == null) {
      return null;
    }

    return $BookCopyWith<$Res>(_self.currentBook!, (value) {
      return _then(_self.copyWith(currentBook: value));
    });
  }
}
