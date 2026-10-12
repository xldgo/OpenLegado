import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localization.dart';
import '../providers/audio/audio_notifier.dart';
import '../providers/audio/read_aloud_preferences.dart';
import '../providers/audio/read_aloud_capsule.dart';
import '../routes.dart';
import '../widgets/app_menu.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/book_cover.dart';
import '../widgets/legado_app_bar.dart';
import '../widgets/reader/read_aloud_timer_sheet.dart';
import '../widgets/reader/read_aloud_player_transition.dart';

/// 独立播放器只观察和控制已有朗读会话，进入与退出均不重新加载书籍。
class ReadAloudPlayerScreen extends ConsumerStatefulWidget {
  const ReadAloudPlayerScreen({super.key});

  @override
  ConsumerState<ReadAloudPlayerScreen> createState() =>
      _ReadAloudPlayerScreenState();
}

class _ReadAloudPlayerScreenState extends ConsumerState<ReadAloudPlayerScreen> {
  bool _busy = false;
  double? _seekValue;
  String? _seekBook;
  int? _seekChapter;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.readAloudControlFailed('$error')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioNotifierProvider);
    final notifier = ref.read(audioNotifierProvider.notifier);
    final strings = context.l10n;
    final transition = ReadAloudPlayerTransition.maybeOf(context);
    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: ListenableBuilder(
        listenable: notifier,
        builder: (context, _) {
          final paragraphs = notifier.currentParagraphs;
          final enabled = !_busy && !audio.isLoading && !audio.isStreamMode;
          return AppScaffold(
            topBar: LegadoAppBar(
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: transition?.dragStart,
                onVerticalDragUpdate: transition?.dragUpdate,
                onVerticalDragEnd: transition?.dragEnd,
                onVerticalDragCancel: transition?.dragCancel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audio.bookName.isEmpty
                          ? strings.readAloud
                          : audio.bookName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (audio.currentChapter != null)
                      Text(
                        audio.currentChapter!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  tooltip: strings.readAloudSettingsTitle,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.readAloudSettings),
                ),
              ],
              bottom: TabBar(
                tabAlignment: TabAlignment.fill,
                tabs: [
                  Tab(text: strings.catalog),
                  Tab(text: strings.readAloudPlayer),
                  Tab(text: strings.readAloudChapterText),
                ],
              ),
            ),
            body: Column(
              children: [
                if (audio.isLoading) const LinearProgressIndicator(),
                if (audio.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      audio.errorMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _catalog(audio, notifier, enabled),
                      _cover(audio, notifier, paragraphs),
                      _chapterText(audio, notifier, paragraphs, enabled),
                    ],
                  ),
                ),
              ],
            ),
            bottomBar: _controls(audio, notifier, paragraphs, enabled),
          );
        },
      ),
    );
  }

  Widget _catalog(AudioState audio, AudioNotifier notifier, bool enabled) {
    if (!audio.hasChapters) return Center(child: Text(context.l10n.noData));
    return _ReadAloudCatalog(
      key: ValueKey(audio.bookUrl),
      chapters: audio.chapters,
      currentIndex: audio.currentIndex,
      onSelect: enabled ? (index) => _run(() => notifier.jumpTo(index)) : null,
    );
  }

  Widget _cover(
    AudioState audio,
    AudioNotifier notifier,
    List<String> paragraphs,
  ) {
    final theme = Theme.of(context);
    final book = notifier.currentBook;
    final current = notifier.currentParagraphIndex;
    final transition = ReadAloudPlayerTransition.maybeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxHeight * 0.4)
            .clamp(64.0, 220.0)
            .clamp(0.0, constraints.maxWidth * 0.6);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                children: [
                  _transitionCover(
                    transition?.coverImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: width,
                              height: width * 1.4,
                              child: RawImage(
                                image: transition!.coverImage,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : BookCover(
                            coverUrl: book?.customCoverUrl ?? book?.coverUrl,
                            sourceOrigin: book?.origin,
                            width: width,
                            height: width * 1.4,
                            borderRadius: 16,
                          ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    audio.bookName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (book != null && book.author.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(book.author, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 24),
                  if (current < paragraphs.length) ...[
                    Text(
                      paragraphs[current],
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (current + 1 < paragraphs.length) ...[
                      const SizedBox(height: 12),
                      Text(
                        paragraphs[current + 1],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ] else
                    Text(
                      context.l10n.readAloudTextUnavailable,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _transitionCover(Widget cover) {
    final transition = ReadAloudPlayerTransition.maybeOf(context);
    if (transition == null) return cover;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return ValueListenableBuilder(
      valueListenable: transition.coverInFlight,
      child: KeyedSubtree(key: transition.coverKey, child: cover),
      builder: (context, inFlight, child) => Opacity(
        opacity: inFlight && transition.coverImage != null && !reduced ? 0 : 1,
        child: child,
      ),
    );
  }

  Widget _chapterText(
    AudioState audio,
    AudioNotifier notifier,
    List<String> paragraphs,
    bool enabled,
  ) {
    if (paragraphs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.readAloudTextUnavailable,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    return ListView.builder(
      key: ValueKey(('text', audio.bookUrl, audio.currentIndex)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: paragraphs.length,
      itemBuilder: (context, index) {
        final selected = index == notifier.currentParagraphIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: selected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled
                  ? () => _run(() => notifier.seekToParagraph(index))
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  paragraphs[index],
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _controls(
    AudioState audio,
    AudioNotifier notifier,
    List<String> paragraphs,
    bool enabled,
  ) {
    final strings = context.l10n;
    final validSeek =
        _seekBook == audio.bookUrl && _seekChapter == audio.currentIndex;
    final current = notifier.currentParagraphIndex;
    final last = paragraphs.isEmpty ? 0 : paragraphs.length - 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 0,
                    max: last < 1 ? 1 : last.toDouble(),
                    value:
                        (validSeek
                                ? _seekValue ?? current.toDouble()
                                : current.toDouble())
                            .clamp(0, last < 1 ? 1.0 : last.toDouble()),
                    label: strings.readAloudParagraphProgress(
                      ((validSeek ? _seekValue : null) ?? current.toDouble())
                              .round() +
                          1,
                      paragraphs.length,
                    ),
                    onChanged: enabled && last > 0
                        ? (value) => setState(() {
                            _seekValue = value;
                            _seekBook = audio.bookUrl;
                            _seekChapter = audio.currentIndex;
                          })
                        : null,
                    onChangeEnd: enabled && last > 0
                        ? (value) {
                            if (_seekBook == audio.bookUrl &&
                                _seekChapter == audio.currentIndex) {
                              unawaited(
                                _run(
                                  () => notifier.seekToParagraph(value.round()),
                                ),
                              );
                            }
                            setState(() => _seekValue = null);
                          }
                        : null,
                  ),
                ),
                Text(
                  paragraphs.isEmpty
                      ? '—'
                      : '${current + 1}/${paragraphs.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: strings.readAloudPreviousParagraph,
                  icon: const Icon(Icons.skip_previous),
                  onPressed:
                      enabled &&
                          paragraphs.isNotEmpty &&
                          (notifier.hasPrevParagraph || audio.hasPrevious)
                      ? () => _run(notifier.prevParagraph)
                      : null,
                ),
                IconButton(
                  tooltip: strings.previousChapter,
                  icon: const Icon(Icons.fast_rewind),
                  onPressed: enabled && audio.hasPrevious
                      ? () => _run(notifier.previous)
                      : null,
                ),
                IconButton.filled(
                  iconSize: 36,
                  tooltip: audio.isPlaying ? strings.pause : strings.play,
                  icon: Icon(audio.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: enabled && audio.hasChapters
                      ? () {
                          if (audio.isPlaying) {
                            notifier.pause();
                          } else {
                            unawaited(_run(notifier.resumeOrPlay));
                          }
                        }
                      : null,
                ),
                IconButton(
                  tooltip: strings.nextChapter,
                  icon: const Icon(Icons.fast_forward),
                  onPressed: enabled && audio.hasNext
                      ? () => _run(notifier.next)
                      : null,
                ),
                IconButton(
                  tooltip: strings.readAloudNextParagraph,
                  icon: const Icon(Icons.skip_next),
                  onPressed:
                      enabled &&
                          paragraphs.isNotEmpty &&
                          (notifier.hasNextParagraph || audio.hasNext)
                      ? () => _run(notifier.nextParagraph)
                      : null,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: strings.readAloudClassicPanel,
                  icon: const Icon(Icons.tune),
                  onPressed: () {
                    ref
                        .read(readAloudCapsuleProvider.notifier)
                        .showClassic(true);
                    Navigator.pop(context, 'classic');
                  },
                ),
                _speedMenu(notifier, enabled),
                IconButton(
                  tooltip: strings.readAloudStop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  onPressed: audio.state != PlayerState.idle
                      ? notifier.stop
                      : null,
                ),
                IconButton(
                  tooltip: notifier.isSleepTimerActive
                      ? '${strings.readAloudTimer} · ${notifier.sleepTimerRemainingLabel}'
                      : strings.readAloudTimer,
                  icon: Icon(
                    notifier.isSleepTimerActive
                        ? Icons.timer
                        : Icons.timer_outlined,
                  ),
                  onPressed: () => showReadAloudTimerSheet(context, notifier),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedMenu(AudioNotifier notifier, bool enabled) {
    final strings = context.l10n;
    final preferences = ref.watch(readAloudPreferencesProvider);
    return AppMenuAnchor<double>(
      itemBuilder: (_) => [
        AppMenuItem(
          value: 0,
          child: Text(strings.readAloudFollowSystem),
          checked: preferences.followSystem,
        ),
        const AppMenuDivider(),
        for (final speed in [0.5, 0.8, 1.0, 1.2, 1.5, 2.0, 2.5, 3.0])
          AppMenuItem(
            value: speed,
            child: Text('$speed×'),
            checked:
                !preferences.followSystem &&
                (preferences.manualSpeed - speed).abs() < 0.001,
          ),
      ],
      onSelected: enabled
          ? (speed) => _run(() async {
              if (speed == 0) {
                await notifier.setReadAloudFollowSystem(true);
              } else {
                await notifier.setReadAloudSpeed(speed);
                if (ref.read(readAloudPreferencesProvider).followSystem) {
                  await notifier.setReadAloudFollowSystem(false);
                }
              }
            })
          : null,
      builder: (context, controller, _) => TextButton.icon(
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
        icon: const Icon(Icons.speed),
        label: Text('${preferences.effectiveSpeed.toStringAsFixed(2)}×'),
      ),
    );
  }
}

class _ReadAloudCatalog extends StatefulWidget {
  const _ReadAloudCatalog({
    super.key,
    required this.chapters,
    required this.currentIndex,
    this.onSelect,
  });
  final List<AudioChapter> chapters;
  final int currentIndex;
  final ValueChanged<int>? onSelect;

  @override
  State<_ReadAloudCatalog> createState() => _ReadAloudCatalogState();
}

class _ReadAloudCatalogState extends State<_ReadAloudCatalog> {
  late final _scroll = ScrollController(
    initialScrollOffset: widget.currentIndex * 64.0,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: _scroll,
    itemExtent: 64,
    itemCount: widget.chapters.length,
    itemBuilder: (context, index) => ListTile(
      selected: index == widget.currentIndex,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      title: Text(
        widget.chapters[index].title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: index == widget.currentIndex
          ? const Icon(Icons.graphic_eq)
          : null,
      onTap: widget.onSelect == null ? null : () => widget.onSelect!(index),
    ),
  );
}
