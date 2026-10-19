import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/application/reader_presentation_provider.dart';
import 'package:flutter_legado/src/features/audio/application/audio_notifier.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Reader extends ReaderNotifier {
  @override
  ReaderState build() => const ReaderState(
    currentBook: Book(bookUrl: 'book'),
    chapterContent: '正文',
  );
  void change(ReaderState value) => state = value;
  ReaderState get value => state;
}

class _Audio extends AudioNotifier {
  @override
  AudioState build() => AudioState(
    bookUrl: 'book',
    state: PlayerState.playing,
    config: TtsConfig(),
  );
  void progress() => state = state.copyWith(positionMs: 500);
  void pausePlayback() => state = state.copyWith(state: PlayerState.paused);
  void stopPlayback() => state = state.copyWith(state: PlayerState.idle);
}

void main() {
  test('文本分类按内容缓存，页码和播放采样不通知页面组合', () {
    final reader = _Reader();
    final audio = _Audio();
    var classified = 0;
    final container = ProviderContainer(
      overrides: [
        readerNotifierProvider.overrideWith(() => reader),
        audioNotifierProvider.overrideWith(() => audio),
        readerContentClassifierProvider.overrideWithValue((text) {
          classified++;
          return text.startsWith('<img');
        }),
      ],
    );
    addTearDown(container.dispose);
    var frames = 0;
    var activeChanges = 0;
    container.listen(readerScreenDependenciesProvider, (_, _) => frames++);
    container.listen(readerReadAloudActiveProvider, (_, _) => activeChanges++);
    container.listen(readerImageDominantProvider, (_, _) {});
    expect(container.read(readerImageDominantProvider), isFalse);
    expect(classified, 1);
    reader.change(
      reader.value.copyWith(
        currentChapterPos: 2,
        totalPages: 10,
        globalPageIndex: 2,
      ),
    );
    container.read(readerScreenDependenciesProvider);
    audio.progress();
    audio.pausePlayback();
    container.read(readerReadAloudActiveProvider);
    expect(frames, 0);
    expect(activeChanges, 0);
    reader.change(reader.value.copyWith(showControls: true));
    container.read(readerScreenDependenciesProvider);
    expect(frames, 1);
    expect(container.read(readerImageDominantProvider), isFalse);
    expect(classified, 1);
    reader.change(reader.value.copyWith(chapterContent: '<img src="a">'));
    expect(container.read(readerImageDominantProvider), isTrue);
    expect(classified, 2);
    audio.stopPlayback();
    expect(container.read(readerReadAloudActiveProvider), isFalse);
    expect(activeChanges, 1);
  });
}
