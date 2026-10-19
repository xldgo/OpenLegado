import '../../application/reader_presentation_provider.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localization.dart';
import '../../../audio/application/audio_notifier.dart';
import '../../../audio/application/read_aloud_capsule.dart';
import '../../application/reader_state.dart';
import '../../../../app/routing/route_names.dart';
import '../../../../widgets/reader/read_aloud_bar.dart';
import 'reader_menu_panel.dart';
import '../../../../widgets/reader/reader_menu_theme.dart';
import 'reader_settings_sheet.dart';

/// 组合阅读菜单与朗读控制，位置计算及阅读动作由页面回调提供。— Codex + UI
class ReaderControlsOverlay extends ConsumerWidget {
  const ReaderControlsOverlay({
    super.key,
    required this.state,
    required this.imageDominant,
    required this.progressBehavior,
    required this.onAddBookmark,
    required this.onOpenCatalog,
    required this.onOpenContentSearch,
    required this.onReadAloud,
    required this.onToggleAutoPage,
    required this.onReadFromVisiblePage,
    required this.onSeekPage,
  });

  final ReaderState state;
  final bool imageDominant;
  final String progressBehavior;
  final VoidCallback onAddBookmark;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenContentSearch;
  final VoidCallback onReadAloud;
  final VoidCallback onToggleAutoPage;
  final Future<void> Function() onReadFromVisiblePage;
  final ValueChanged<int> onSeekPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (isStreamMode, isLoading) = ref.watch(
      audioNotifierProvider.select((a) => (a.isStreamMode, a.isLoading)),
    );
    final classicExpanded = ref.watch(
      readAloudCapsuleProvider.select((s) => s.classicExpanded),
    );
    final aloudActive = ref.watch(readerReadAloudActiveProvider);
    return ReaderMenuTheme(
      builder: (context) => aloudActive && classicExpanded
          ? ReadAloudBar(
              onDismiss: () => ref
                  .read(readAloudCapsuleProvider.notifier)
                  .showClassic(false),
              onOpenCatalog: onOpenCatalog,
              onBackstage: () {
                ref.read(readAloudCapsuleProvider.notifier).showClassic(false);
                Navigator.of(context).maybePop();
              },
            )
          : ReaderMenuPanel(
              visible: state.showControls,
              bottomAccessory: aloudActive && !isStreamMode && !imageDominant
                  ? ValueListenableBuilder<bool>(
                      valueListenable: ref
                          .read(audioNotifierProvider.notifier)
                          .followReadAloud,
                      builder: (context, following, _) {
                        if (following) {
                          return const SizedBox.shrink();
                        }
                        return SafeArea(
                          top: false,
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: 16,
                              bottom: 8,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _readAloudPositionChip(
                                  context,
                                  icon: Icons.my_location,
                                  label: context.l10n.readAloudReturnToPosition,
                                  onPressed: isLoading
                                      ? null
                                      : ref
                                            .read(
                                              audioNotifierProvider.notifier,
                                            )
                                            .restoreReadAloudFollow,
                                ),
                                _readAloudPositionChip(
                                  context,
                                  icon: Icons.play_arrow,
                                  label: context.l10n.readAloudFromThisPage,
                                  onPressed: state.isLoading || isLoading
                                      ? null
                                      : () =>
                                            unawaited(onReadFromVisiblePage()),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : null,
              onBack: () => Navigator.of(context).maybePop(),
              onAddBookmark: onAddBookmark,
              onOpenCatalog: onOpenCatalog,
              onOpenSettings: () => ReaderSettingsSheet.show(context),
              onOpenContentSearch: onOpenContentSearch,
              onReadAloud: onReadAloud,
              onToggleAutoPage: onToggleAutoPage,
              onOpenReplaceRules: () =>
                  Navigator.pushNamed(context, AppRoutes.replaceRules),
              progressBehavior: progressBehavior,
              onSeekPage: onSeekPage,
            ),
    );
  }

  Widget _readAloudPositionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => ActionChip(
    avatar: Icon(
      icon,
      size: 16,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    label: Text(label),
    labelStyle: Theme.of(context).textTheme.labelMedium,
    side: BorderSide.none,
    shape: const StadiumBorder(),
    onPressed: onPressed,
  );
}
