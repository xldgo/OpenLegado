import '../../../app/routing/app_navigation.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localization.dart';
import '../read_aloud_player_info.dart';
import '../widgets/read_aloud_player_content.dart';
import '../widgets/read_aloud_chapter_text.dart';
import '../widgets/read_aloud_progress_slider.dart';
import '../../audio/application/audio_notifier.dart';
import '../../audio/application/read_aloud_preferences.dart';
import '../../audio/application/read_aloud_capsule.dart';
import '../../../app/routing/route_names.dart';
import '../../../widgets/app_menu.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/book_cover.dart';
import '../../../widgets/legado_app_bar.dart';
import '../../../widgets/reader/read_aloud_timer_sheet.dart';
import '../../../widgets/reader/read_aloud_speed_sheet.dart';
import '../../../widgets/reader/read_aloud_player_transition.dart';

/// 独立播放器只观察和控制已有朗读会话，进入与退出均不重新加载书籍。
class ReadAloudPlayerScreen extends ConsumerStatefulWidget {
  const ReadAloudPlayerScreen({super.key});

  @override
  ConsumerState<ReadAloudPlayerScreen> createState() =>
      _ReadAloudPlayerScreenState();
}

class _ReadAloudPlayerScreenState extends ConsumerState<ReadAloudPlayerScreen> {
  bool _busy = false;
  final _pages = PageController(initialPage: 1);
  int _page = 1;
  bool _textScrolling = false;
  (String, int)? _textChapter;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _showPage(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      unawaited(
        _pages.animateToPage(
          page,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _onTextScroll(bool scrolling) {
    if (!mounted || _page != 2 || _textScrolling == scrolling) return;
    setState(() => _textScrolling = scrolling);
  }

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
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final paragraphs = notifier.currentParagraphs;
        final chapter = (audio.bookUrl, audio.currentIndex);
        if (_textChapter != chapter || paragraphs.isEmpty) {
          _textChapter = chapter;
          _textScrolling = false;
        }
        final enabled = !_busy && !audio.isLoading && !audio.isStreamMode;
        return AppScaffold(
          topBar: LegadoAppBar(
            toolbarHeight: _toolbarHeight(audio.currentChapter != null),
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
                    audio.bookName.isEmpty ? strings.readAloud : audio.bookName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
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
              AppMenuAnchor<int>(
                itemBuilder: (_) => [
                  for (final (index, label) in [
                    (0, strings.catalog),
                    (1, strings.readAloudPlayer),
                    (2, strings.readAloudChapterText),
                  ])
                    AppMenuItem(
                      value: index,
                      child: Text(label),
                      checked: _page == index,
                    ),
                ],
                onSelected: _showPage,
                builder: (context, controller, _) => IconButton(
                  tooltip: strings.readAloudPlayer,
                  icon: const Icon(Icons.view_carousel_outlined),
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
              IconButton(
                tooltip: strings.readAloudSettingsTitle,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    GoRouter.of(context)
                        .pushAppRoute(AppRoutes.readAloudSettings),
              ),
            ],
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
                child: PageView(
                  controller: _pages,
                  onPageChanged: (page) => setState(() {
                    _page = page;
                    _textScrolling = false;
                  }),
                  children: [
                    _catalog(audio, notifier, enabled),
                    _cover(audio, notifier, paragraphs),
                    _chapterText(audio, notifier, paragraphs, enabled),
                  ],
                ),
              ),
            ],
          ),
          bottomBar: ReadAloudControlsVisibility(
            visible: _page != 2 || !_textScrolling,
            child: _controls(audio, notifier, paragraphs, enabled),
          ),
        );
      },
    );
  }

  double _toolbarHeight(bool hasChapter) {
    final theme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double height(TextStyle style) =>
        scaler.scale(style.fontSize!) * (style.height ?? 1.4);
    return (height(theme.titleMedium!) +
            (hasChapter ? height(theme.bodySmall!) : 0) +
            16)
        .clamp(kToolbarHeight, double.infinity);
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
        final width = (constraints.maxWidth * 0.52).clamp(
          0.0,
          (constraints.maxHeight * 0.42).clamp(64.0, 220.0),
        );
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
                  const SizedBox(height: 24),
                  if (current >= 0 && current < paragraphs.length)
                    ReadAloudPlayerText(
                      current: paragraphs[current],
                      next: current + 1 < paragraphs.length
                          ? paragraphs[current + 1]
                          : null,
                    )
                  else
                    Text(
                      context.l10n.readAloudTextUnavailable,
                      style: theme.textTheme.bodyMedium,
                    ),
                  if (!audio.isStreamMode) ...[
                    const SizedBox(height: 24),
                    _engineInfo(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _engineInfo() => Consumer(
    builder: (context, ref, _) {
      final strings = context.l10n;
      final info = ref.watch(readAloudPlayerInfoProvider);
      return info.when(
        loading: () => const SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => Text(
          strings.readAloudPlayerInfoUnavailable,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        data: (info) => Chip(
          avatar: const Icon(Icons.record_voice_over_outlined, size: 16),
          side: BorderSide.none,
          label: Text(
            info.voiceName ??
                (info.engineName != null || info.system
                    ? strings.readAloudDefaultVoice
                    : strings.readAloudNoEngine),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    },
  );

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
    return _ParagraphScope(
      // 正文只需要换段：段内进度由下方进度条单独订阅位置流。
      listenable: notifier.readAloudPosition,
      resolve: () {
        final position = notifier.readAloudPosition.value;
        return position?.bookUrl == audio.bookUrl &&
                position?.chapterIndex == audio.currentIndex
            ? position!.paragraphIndex
            : notifier.currentParagraphIndex;
      },
      builder: (context, activeIndex) {
        return ReadAloudChapterText(
          key: ValueKey(('text', audio.bookUrl, audio.currentIndex)),
          active: _page == 2,
          onUserScrollChanged: _onTextScroll,
          paragraphs: paragraphs,
          activeIndex: activeIndex,
          onSeek: enabled
              ? (index) => _run(() => notifier.seekToParagraph(index))
              : null,
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder(
              valueListenable: notifier.readAloudPosition,
              builder: (context, position, _) => ReadAloudProgressSlider(
                bookUrl: audio.bookUrl,
                chapterIndex: audio.currentIndex,
                sourceText: audio.currentChapter?.text ?? '',
                position: position,
                enabled: enabled && paragraphs.isNotEmpty,
                onSeek: (offset) => unawaited(
                  _run(() async {
                    final current = ref.read(audioNotifierProvider);
                    if (current.bookUrl != audio.bookUrl ||
                        current.currentIndex != audio.currentIndex ||
                        current.isLoading ||
                        current.isStreamMode) {
                      return;
                    }
                    await notifier.seekToChapterPosition(
                      audio.currentIndex,
                      offset,
                    );
                  }),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: strings.previousChapter,
                  icon: const Icon(Icons.skip_previous),
                  onPressed: enabled && audio.hasPrevious
                      ? () => _run(notifier.previous)
                      : null,
                ),
                IconButton(
                  tooltip: strings.readAloudPreviousParagraph,
                  icon: const Icon(Icons.fast_rewind),
                  onPressed:
                      enabled &&
                          paragraphs.isNotEmpty &&
                          (notifier.hasPrevParagraph || audio.hasPrevious)
                      ? () => _run(notifier.prevParagraph)
                      : null,
                ),
                ReadAloudPlayPauseButton(
                  playing: audio.isPlaying,
                  tooltip: audio.isPlaying ? strings.pause : strings.play,
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
                  tooltip: strings.readAloudNextParagraph,
                  icon: const Icon(Icons.fast_forward),
                  onPressed:
                      enabled &&
                          paragraphs.isNotEmpty &&
                          (notifier.hasNextParagraph || audio.hasNext)
                      ? () => _run(notifier.nextParagraph)
                      : null,
                ),
                IconButton(
                  tooltip: strings.nextChapter,
                  icon: const Icon(Icons.skip_next),
                  onPressed: enabled && audio.hasNext
                      ? () => _run(notifier.next)
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
                Flexible(child: _speedButton(enabled)),
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

  Widget _speedButton(bool enabled) {
    final preferences = ref.watch(readAloudPreferencesProvider);
    return TextButton.icon(
      onPressed: enabled ? () => showReadAloudSpeedSheet(context) : null,
      icon: const Icon(Icons.speed),
      label: Text('${preferences.effectiveSpeed.toStringAsFixed(2)}×'),
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

/// 正文只在段落索引变化时重建；段内位置更新只影响进度条，不重建整章列表。
class _ParagraphScope extends StatefulWidget {
  const _ParagraphScope({
    required this.listenable,
    required this.resolve,
    required this.builder,
  });

  final Listenable listenable;
  final int Function() resolve;
  final Widget Function(BuildContext context, int index) builder;

  @override
  State<_ParagraphScope> createState() => _ParagraphScopeState();
}

class _ParagraphScopeState extends State<_ParagraphScope> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.resolve();
    widget.listenable.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _ParagraphScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.listenable, widget.listenable)) {
      oldWidget.listenable.removeListener(_onChanged);
      widget.listenable.addListener(_onChanged);
    }
    // 父级重建已经带来新参数，直接取最新段落，不额外触发一次刷新。
    _index = widget.resolve();
  }

  void _onChanged() {
    final next = widget.resolve();
    if (next != _index && mounted) setState(() => _index = next);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _index);
}

/// 段落高度只在正文或排版参数改变时测量；播放范围回调复用缓存。
