import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/platform/audio/read_aloud_audio_handler.dart';
import 'package:flutter_legado/src/services/media_session_models.dart';

void main() {
  late ReadAloudAudioHandler handler;
  late List<String> commands;
  late List<MediaSeekRequest> seeks;
  late List<MediaPlaybackTarget> opens;

  void metadata({
    String id = 'book',
    int token = 7,
    String chapter = '第一章',
    String timer = '剩余 4 章',
  }) {
    handler.publishMetadata(
      title: '书名',
      artist: chapter,
      album: '书名',
      mediaId: id,
      sessionToken: token,
      timerText: timer,
    );
  }

  void progress({
    String id = 'book',
    int token = 7,
    int chapter = 2,
    int duration = 60000,
    int position = 12500,
    bool canSeek = true,
    bool previous = false,
    bool next = true,
    String state = 'paused',
    double speed = 1.5,
  }) => handler.publishProgress(
    MediaPlaybackProgress(
      mediaId: id,
      sessionToken: token,
      chapterIndex: chapter,
      state: state,
      position: position,
      duration: duration,
      speed: speed,
      canSeek: canSeek,
      hasPrevious: previous,
      hasNext: next,
      isStream: true,
    ),
  );

  setUp(() {
    commands = [];
    seeks = [];
    opens = [];
    handler = ReadAloudAudioHandler(
      onPlay: () => commands.add('播放'),
      onPause: () => commands.add('暂停'),
      onStop: () => commands.add('停止'),
      onNext: () => commands.add('下一项'),
      onPrevious: () => commands.add('上一项'),
      onSeek: seeks.add,
      onOpen: opens.add,
    );
  });
  tearDown(() async {
    await handler.mediaItem.close();
    await handler.playbackState.close();
  });

  test('元数据保留书名、章节、定时及会话，毫秒进度和能力映射到系统状态', () {
    metadata();
    progress();
    final item = handler.mediaItem.value!;
    expect(item.title, '书名');
    expect(item.artist, '第一章');
    expect(item.displayTitle, '书名');
    expect(item.displaySubtitle, '第一章');
    expect(item.displayDescription, '剩余 4 章');
    expect(item.extras, {'sessionToken': 7, 'chapterIndex': 2});
    expect(item.duration, const Duration(minutes: 1));
    final state = handler.playbackState.value;
    expect(state.updatePosition, const Duration(milliseconds: 12500));
    expect(state.playing, isFalse);
    expect(state.speed, 1.5);
    expect(state.controls, [
      MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ]);
    expect(state.androidCompactActionIndices, [0, 1]);
    expect(state.systemActions, {MediaAction.seek});
    expect(handler.queue.value, isEmpty);
  });

  test('系统命令只转发，播放状态仍须由原控制器确认', () async {
    metadata();
    progress();
    await handler.play();
    await handler.pause();
    await handler.skipToNext();
    await handler.skipToPrevious();
    await handler.stop();
    expect(commands, ['播放', '暂停', '下一项', '停止']);
    expect(handler.playbackState.value.playing, isFalse);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
    progress(previous: true, next: false);
    await handler.skipToPrevious();
    await handler.skipToNext();
    expect(commands.last, '上一项');
  });

  test('锁屏定位携带当前身份且限制范围；未知时长或切章空窗不接受定位', () async {
    metadata();
    progress();
    await handler.seek(const Duration(milliseconds: 12500));
    await handler.seek(const Duration(minutes: 5));
    await handler.seek(const Duration(milliseconds: -1));
    expect(seeks.map((s) => s.position), [12500, 60000]);
    expect(seeks.first.target.mediaId, 'book');
    expect(seeks.first.target.sessionToken, 7);
    expect(seeks.first.target.chapterIndex, 2);
    progress(duration: 0);
    await handler.seek(const Duration(seconds: 1));
    expect(handler.playbackState.value.systemActions, isEmpty);
    metadata(chapter: '第二章');
    await handler.seek(const Duration(seconds: 2));
    expect(seeks, hasLength(2));
  });

  test('定时和封面刷新保留时间轴；章节变化不发 idle 中断前台服务', () {
    metadata();
    progress(state: 'playing');
    final art = Uri.file('/tmp/cover.png');
    handler.publishArtwork('book', 7, art);
    metadata(timer: '剩余 3 章');
    expect(handler.mediaItem.value!.artUri, art);
    expect(handler.mediaItem.value!.duration, const Duration(minutes: 1));
    expect(handler.playbackState.value.playing, isTrue);
    metadata(chapter: '下一章');
    expect(handler.mediaItem.value!.duration, isNull);
    expect(handler.mediaItem.value!.artUri, art);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.loading,
    );
    expect(handler.playbackState.value.playing, isTrue);
    expect(handler.playbackState.value.controls, isEmpty);
    progress(chapter: 3, state: 'playing');
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
  });

  test('旧会话进度和封面不污染新会话，停止后不导航或响应旧按钮', () async {
    metadata();
    progress();
    metadata(id: 'new', token: 8);
    progress(id: 'new', token: 8);
    progress();
    handler.publishArtwork('book', 7, Uri.file('/tmp/old.png'));
    expect(handler.mediaItem.value!.id, 'new');
    expect(handler.mediaItem.value!.artUri, isNull);
    handler.openCurrent();
    expect(opens.single.mediaId, 'new');
    expect(opens.single.sessionToken, 8);
    handler.publishState('stopped');
    handler.openCurrent();
    await handler.play();
    await handler.seek(Duration.zero);
    expect(opens, hasLength(1));
    expect(commands, isEmpty);
    expect(seeks, isEmpty);
    expect(handler.mediaItem.value, isNull);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
  });

  test('便捷暂停不会清空原进度、时长和倍率，划掉Activity不自动停止', () async {
    metadata();
    progress(state: 'playing', position: 20000);
    handler.publishState('paused');
    final state = handler.playbackState.value;
    expect(state.updatePosition.inMilliseconds, greaterThanOrEqualTo(20000));
    expect(state.speed, 1.5);
    expect(state.playing, isFalse);
    expect(handler.mediaItem.value!.duration, const Duration(minutes: 1));
    await handler.onTaskRemoved();
    expect(commands, isEmpty);
    await handler.onNotificationDeleted();
    expect(commands, ['停止']);
  });

  test('没有书名时章节成为主标题且不重复副标题', () {
    handler.publishMetadata(
      title: '',
      artist: '第一章',
      album: '',
      mediaId: 'book',
      sessionToken: 7,
      timerText: '',
    );
    progress();
    handler.publishMetadata(
      title: '',
      artist: '第一章',
      album: '',
      mediaId: 'book',
      sessionToken: 7,
      timerText: '剩余 1 分钟',
    );
    expect(handler.mediaItem.value!.displayTitle, '第一章');
    expect(handler.mediaItem.value!.displaySubtitle, '');
    expect(handler.mediaItem.value!.duration, const Duration(minutes: 1));
  });
}
