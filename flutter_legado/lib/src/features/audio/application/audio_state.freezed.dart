// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AudioState {
  /// 播放器状态机
  PlayerState get state;

  /// 播放模式
  AudioPlayMode get mode;

  /// TTS 配置（构造时由 Notifier 注入默认实例）
  TtsConfig get config;

  /// 章节列表
  List<AudioChapter> get chapters;

  /// 当前章节索引
  int get currentIndex;

  /// 错误信息（null 表示无错误）
  String? get errorMessage;

  /// 当前听书书籍 URL
  String get bookUrl;

  /// 当前听书书名
  String get bookName;

  /// 媒体会话是否已就绪（用于 UI 显示后台播放状态）
  bool get isMediaSessionReady;

  /// 是否音频书流媒体模式（false = TTS 朗读）
  bool get isStreamMode;

  /// 当前可播媒体 URL（流媒体模式；TTS 为空）
  String get mediaUrl;

  /// 流媒体播放进度（毫秒）
  int get positionMs;

  /// 流媒体时长（毫秒；未知为 0）
  int get durationMs;

  /// 可选歌词/旁白（getAudioChapterMedia 返回）
  String? get lyric;

  /// Create a copy of AudioState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AudioStateCopyWith<AudioState> get copyWith =>
      _$AudioStateCopyWithImpl<AudioState>(this as AudioState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as AudioState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AudioState &&
            (identical(other.state, _this.state) ||
                other.state == _this.state) &&
            (identical(other.mode, _this.mode) || other.mode == _this.mode) &&
            (identical(other.config, _this.config) ||
                other.config == _this.config) &&
            const DeepCollectionEquality().equals(
              other.chapters,
              _this.chapters,
            ) &&
            (identical(other.currentIndex, _this.currentIndex) ||
                other.currentIndex == _this.currentIndex) &&
            (identical(other.errorMessage, _this.errorMessage) ||
                other.errorMessage == _this.errorMessage) &&
            (identical(other.bookUrl, _this.bookUrl) ||
                other.bookUrl == _this.bookUrl) &&
            (identical(other.bookName, _this.bookName) ||
                other.bookName == _this.bookName) &&
            (identical(other.isMediaSessionReady, _this.isMediaSessionReady) ||
                other.isMediaSessionReady == _this.isMediaSessionReady) &&
            (identical(other.isStreamMode, _this.isStreamMode) ||
                other.isStreamMode == _this.isStreamMode) &&
            (identical(other.mediaUrl, _this.mediaUrl) ||
                other.mediaUrl == _this.mediaUrl) &&
            (identical(other.positionMs, _this.positionMs) ||
                other.positionMs == _this.positionMs) &&
            (identical(other.durationMs, _this.durationMs) ||
                other.durationMs == _this.durationMs) &&
            (identical(other.lyric, _this.lyric) ||
                other.lyric == _this.lyric));
  }

  @override
  int get hashCode {
    final _this = this as AudioState;
    return Object.hash(
      runtimeType,
      _this.state,
      _this.mode,
      _this.config,
      const DeepCollectionEquality().hash(_this.chapters),
      _this.currentIndex,
      _this.errorMessage,
      _this.bookUrl,
      _this.bookName,
      _this.isMediaSessionReady,
      _this.isStreamMode,
      _this.mediaUrl,
      _this.positionMs,
      _this.durationMs,
      _this.lyric,
    );
  }

  @override
  String toString() {
    final _this = this as AudioState;
    return 'AudioState(state: ${_this.state}, mode: ${_this.mode}, config: ${_this.config}, chapters: ${_this.chapters}, currentIndex: ${_this.currentIndex}, errorMessage: ${_this.errorMessage}, bookUrl: ${_this.bookUrl}, bookName: ${_this.bookName}, isMediaSessionReady: ${_this.isMediaSessionReady}, isStreamMode: ${_this.isStreamMode}, mediaUrl: ${_this.mediaUrl}, positionMs: ${_this.positionMs}, durationMs: ${_this.durationMs}, lyric: ${_this.lyric})';
  }
}

/// @nodoc
abstract mixin class $AudioStateCopyWith<$Res> {
  factory $AudioStateCopyWith(
    AudioState value,
    $Res Function(AudioState) _then,
  ) = _$AudioStateCopyWithImpl;
  @useResult
  $Res call({
    PlayerState state,
    AudioPlayMode mode,
    TtsConfig config,
    List<AudioChapter> chapters,
    int currentIndex,
    String? errorMessage,
    String bookUrl,
    String bookName,
    bool isMediaSessionReady,
    bool isStreamMode,
    String mediaUrl,
    int positionMs,
    int durationMs,
    String? lyric,
  });
}

/// @nodoc
class _$AudioStateCopyWithImpl<$Res> implements $AudioStateCopyWith<$Res> {
  _$AudioStateCopyWithImpl(this._self, this._then);

  final AudioState _self;
  final $Res Function(AudioState) _then;

  /// Create a copy of AudioState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = null,
    Object? mode = null,
    Object? config = null,
    Object? chapters = null,
    Object? currentIndex = null,
    Object? errorMessage = freezed,
    Object? bookUrl = null,
    Object? bookName = null,
    Object? isMediaSessionReady = null,
    Object? isStreamMode = null,
    Object? mediaUrl = null,
    Object? positionMs = null,
    Object? durationMs = null,
    Object? lyric = freezed,
  }) {
    return _then(
      AudioState(
        state: null == state
            ? _self.state
            : state // ignore: cast_nullable_to_non_nullable
                  as PlayerState,
        mode: null == mode
            ? _self.mode
            : mode // ignore: cast_nullable_to_non_nullable
                  as AudioPlayMode,
        config: null == config
            ? _self.config
            : config // ignore: cast_nullable_to_non_nullable
                  as TtsConfig,
        chapters: null == chapters
            ? _self.chapters
            : chapters // ignore: cast_nullable_to_non_nullable
                  as List<AudioChapter>,
        currentIndex: null == currentIndex
            ? _self.currentIndex
            : currentIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        errorMessage: freezed == errorMessage
            ? _self.errorMessage
            : errorMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        bookName: null == bookName
            ? _self.bookName
            : bookName // ignore: cast_nullable_to_non_nullable
                  as String,
        isMediaSessionReady: null == isMediaSessionReady
            ? _self.isMediaSessionReady
            : isMediaSessionReady // ignore: cast_nullable_to_non_nullable
                  as bool,
        isStreamMode: null == isStreamMode
            ? _self.isStreamMode
            : isStreamMode // ignore: cast_nullable_to_non_nullable
                  as bool,
        mediaUrl: null == mediaUrl
            ? _self.mediaUrl
            : mediaUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        positionMs: null == positionMs
            ? _self.positionMs
            : positionMs // ignore: cast_nullable_to_non_nullable
                  as int,
        durationMs: null == durationMs
            ? _self.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int,
        lyric: freezed == lyric
            ? _self.lyric
            : lyric // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [AudioState].
extension AudioStatePatterns on AudioState {
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
    TResult Function(_AudioState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioState() when $default != null:
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
    TResult Function(_AudioState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioState():
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
    TResult? Function(_AudioState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioState() when $default != null:
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
      PlayerState state,
      AudioPlayMode mode,
      TtsConfig config,
      List<AudioChapter> chapters,
      int currentIndex,
      String? errorMessage,
      String bookUrl,
      String bookName,
      bool isMediaSessionReady,
      bool isStreamMode,
      String mediaUrl,
      int positionMs,
      int durationMs,
      String? lyric,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioState() when $default != null:
        return $default(
          _that.state,
          _that.mode,
          _that.config,
          _that.chapters,
          _that.currentIndex,
          _that.errorMessage,
          _that.bookUrl,
          _that.bookName,
          _that.isMediaSessionReady,
          _that.isStreamMode,
          _that.mediaUrl,
          _that.positionMs,
          _that.durationMs,
          _that.lyric,
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
      PlayerState state,
      AudioPlayMode mode,
      TtsConfig config,
      List<AudioChapter> chapters,
      int currentIndex,
      String? errorMessage,
      String bookUrl,
      String bookName,
      bool isMediaSessionReady,
      bool isStreamMode,
      String mediaUrl,
      int positionMs,
      int durationMs,
      String? lyric,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioState():
        return $default(
          _that.state,
          _that.mode,
          _that.config,
          _that.chapters,
          _that.currentIndex,
          _that.errorMessage,
          _that.bookUrl,
          _that.bookName,
          _that.isMediaSessionReady,
          _that.isStreamMode,
          _that.mediaUrl,
          _that.positionMs,
          _that.durationMs,
          _that.lyric,
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
      PlayerState state,
      AudioPlayMode mode,
      TtsConfig config,
      List<AudioChapter> chapters,
      int currentIndex,
      String? errorMessage,
      String bookUrl,
      String bookName,
      bool isMediaSessionReady,
      bool isStreamMode,
      String mediaUrl,
      int positionMs,
      int durationMs,
      String? lyric,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioState() when $default != null:
        return $default(
          _that.state,
          _that.mode,
          _that.config,
          _that.chapters,
          _that.currentIndex,
          _that.errorMessage,
          _that.bookUrl,
          _that.bookName,
          _that.isMediaSessionReady,
          _that.isStreamMode,
          _that.mediaUrl,
          _that.positionMs,
          _that.durationMs,
          _that.lyric,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AudioState implements AudioState {
  const _AudioState({
    this.state = PlayerState.idle,
    this.mode = AudioPlayMode.sequential,
    required this.config,
    List<AudioChapter> chapters = const <AudioChapter>[],
    this.currentIndex = 0,
    this.errorMessage,
    this.bookUrl = '',
    this.bookName = '',
    this.isMediaSessionReady = false,
    this.isStreamMode = false,
    this.mediaUrl = '',
    this.positionMs = 0,
    this.durationMs = 0,
    this.lyric,
  }) : _chapters = chapters;

  /// 播放器状态机
  @override
  @JsonKey()
  final PlayerState state;

  /// 播放模式
  @override
  @JsonKey()
  final AudioPlayMode mode;

  /// TTS 配置（构造时由 Notifier 注入默认实例）
  @override
  final TtsConfig config;

  /// 章节列表
  final List<AudioChapter> _chapters;

  /// 章节列表
  @override
  @JsonKey()
  List<AudioChapter> get chapters {
    if (_chapters is EqualUnmodifiableListView) return _chapters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapters);
  }

  /// 当前章节索引
  @override
  @JsonKey()
  final int currentIndex;

  /// 错误信息（null 表示无错误）
  @override
  final String? errorMessage;

  /// 当前听书书籍 URL
  @override
  @JsonKey()
  final String bookUrl;

  /// 当前听书书名
  @override
  @JsonKey()
  final String bookName;

  /// 媒体会话是否已就绪（用于 UI 显示后台播放状态）
  @override
  @JsonKey()
  final bool isMediaSessionReady;

  /// 是否音频书流媒体模式（false = TTS 朗读）
  @override
  @JsonKey()
  final bool isStreamMode;

  /// 当前可播媒体 URL（流媒体模式；TTS 为空）
  @override
  @JsonKey()
  final String mediaUrl;

  /// 流媒体播放进度（毫秒）
  @override
  @JsonKey()
  final int positionMs;

  /// 流媒体时长（毫秒；未知为 0）
  @override
  @JsonKey()
  final int durationMs;

  /// 可选歌词/旁白（getAudioChapterMedia 返回）
  @override
  final String? lyric;

  /// Create a copy of AudioState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AudioStateCopyWith<_AudioState> get copyWith =>
      __$AudioStateCopyWithImpl<_AudioState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AudioState &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.config, config) || other.config == config) &&
            const DeepCollectionEquality().equals(other.chapters, _chapters) &&
            (identical(other.currentIndex, currentIndex) ||
                other.currentIndex == currentIndex) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl) &&
            (identical(other.bookName, bookName) ||
                other.bookName == bookName) &&
            (identical(other.isMediaSessionReady, isMediaSessionReady) ||
                other.isMediaSessionReady == isMediaSessionReady) &&
            (identical(other.isStreamMode, isStreamMode) ||
                other.isStreamMode == isStreamMode) &&
            (identical(other.mediaUrl, mediaUrl) ||
                other.mediaUrl == mediaUrl) &&
            (identical(other.positionMs, positionMs) ||
                other.positionMs == positionMs) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.lyric, lyric) || other.lyric == lyric));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      state,
      mode,
      config,
      const DeepCollectionEquality().hash(_chapters),
      currentIndex,
      errorMessage,
      bookUrl,
      bookName,
      isMediaSessionReady,
      isStreamMode,
      mediaUrl,
      positionMs,
      durationMs,
      lyric,
    );
  }

  @override
  String toString() {
    return 'AudioState(state: $state, mode: $mode, config: $config, chapters: $chapters, currentIndex: $currentIndex, errorMessage: $errorMessage, bookUrl: $bookUrl, bookName: $bookName, isMediaSessionReady: $isMediaSessionReady, isStreamMode: $isStreamMode, mediaUrl: $mediaUrl, positionMs: $positionMs, durationMs: $durationMs, lyric: $lyric)';
  }
}

/// @nodoc
abstract mixin class _$AudioStateCopyWith<$Res>
    implements $AudioStateCopyWith<$Res> {
  factory _$AudioStateCopyWith(
    _AudioState value,
    $Res Function(_AudioState) _then,
  ) = __$AudioStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    PlayerState state,
    AudioPlayMode mode,
    TtsConfig config,
    List<AudioChapter> chapters,
    int currentIndex,
    String? errorMessage,
    String bookUrl,
    String bookName,
    bool isMediaSessionReady,
    bool isStreamMode,
    String mediaUrl,
    int positionMs,
    int durationMs,
    String? lyric,
  });
}

/// @nodoc
class __$AudioStateCopyWithImpl<$Res> implements _$AudioStateCopyWith<$Res> {
  __$AudioStateCopyWithImpl(this._self, this._then);

  final _AudioState _self;
  final $Res Function(_AudioState) _then;

  /// Create a copy of AudioState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? state = null,
    Object? mode = null,
    Object? config = null,
    Object? chapters = null,
    Object? currentIndex = null,
    Object? errorMessage = freezed,
    Object? bookUrl = null,
    Object? bookName = null,
    Object? isMediaSessionReady = null,
    Object? isStreamMode = null,
    Object? mediaUrl = null,
    Object? positionMs = null,
    Object? durationMs = null,
    Object? lyric = freezed,
  }) {
    return _then(
      _AudioState(
        state: null == state
            ? _self.state
            : state // ignore: cast_nullable_to_non_nullable
                  as PlayerState,
        mode: null == mode
            ? _self.mode
            : mode // ignore: cast_nullable_to_non_nullable
                  as AudioPlayMode,
        config: null == config
            ? _self.config
            : config // ignore: cast_nullable_to_non_nullable
                  as TtsConfig,
        chapters: null == chapters
            ? _self._chapters
            : chapters // ignore: cast_nullable_to_non_nullable
                  as List<AudioChapter>,
        currentIndex: null == currentIndex
            ? _self.currentIndex
            : currentIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        errorMessage: freezed == errorMessage
            ? _self.errorMessage
            : errorMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookUrl: null == bookUrl
            ? _self.bookUrl
            : bookUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        bookName: null == bookName
            ? _self.bookName
            : bookName // ignore: cast_nullable_to_non_nullable
                  as String,
        isMediaSessionReady: null == isMediaSessionReady
            ? _self.isMediaSessionReady
            : isMediaSessionReady // ignore: cast_nullable_to_non_nullable
                  as bool,
        isStreamMode: null == isStreamMode
            ? _self.isStreamMode
            : isStreamMode // ignore: cast_nullable_to_non_nullable
                  as bool,
        mediaUrl: null == mediaUrl
            ? _self.mediaUrl
            : mediaUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        positionMs: null == positionMs
            ? _self.positionMs
            : positionMs // ignore: cast_nullable_to_non_nullable
                  as int,
        durationMs: null == durationMs
            ? _self.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int,
        lyric: freezed == lyric
            ? _self.lyric
            : lyric // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
