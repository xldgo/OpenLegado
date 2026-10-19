import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:share_plus/share_plus.dart';

import '../application/bottom_bar_skin_notifier.dart';
import '../../../services/bottom_bar_skin_format.dart';
import '../../../services/bottom_bar_skin_service.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/bottom_sheet_widget.dart';
import 'bottom_bar_skin_assign_screen.dart';

/// 底栏皮肤管理（对齐 BottomBarSkinActivity）
///
/// 导入 zip → 分配页选槽位 → 启用/删除/编辑/导出/分享；底栏读 PrefKeys.bottomBarSkin 换图标。
class BottomBarSkinScreen extends ConsumerWidget {
  const BottomBarSkinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bottomBarSkinProvider);
    final notifier = ref.read(bottomBarSkinProvider.notifier);
    final preview = ref.watch(bottomBarSkinPreviewProvider);
    ref.listen(bottomBarSkinPreviewProvider, (_, next) {
      // 同名皮肤覆盖文件后清除旧解码图像，不在普通重建时重复读取。— Codex + UI
      next.whenData((items) {
        for (final item in items) {
          if (item.path != null) FileImage(File(item.path!)).evict();
        }
      });
    });

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: const Text('底部操作栏皮肤'),
        actions: [
          IconButton(
            tooltip: '导入',
            icon: const Icon(Symbols.file_upload_rounded),
            onPressed: () => _import(context, notifier),
          ),
        ],
      ),
      body: SettingsBody(
        child: ListView(
          children: [
            const SettingsSectionHeader('皮肤'),
            SettingsGroup(
              flat: true, // [LAYOUT_MOTION_AUDIT L2] 设置拆扁平
              children: [
                ListTile(
                  leading: Icon(
                    state.active.isEmpty
                        ? Symbols.radio_button_checked_rounded
                        : Symbols.radio_button_unchecked_rounded,
                  ),
                  title: const Text('系统默认'),
                  onTap: () => notifier.setActive(''),
                ),
                for (final name in state.skins)
                  ListTile(
                    leading: Icon(
                      state.active == name
                          ? Symbols.radio_button_checked_rounded
                          : Symbols.radio_button_unchecked_rounded,
                    ),
                    title: Text(name),
                    trailing: IconButton(
                      icon: const Icon(Symbols.more_horiz_rounded),
                      onPressed: () => _showItemMenu(context, notifier, name),
                    ),
                    onTap: () => notifier.setActive(name),
                    onLongPress: () => _showItemMenu(context, notifier, name),
                  ),
              ],
            ),
            const SettingsSectionFooter(
              '导入 zip 后进入分配页：为书架/发现/订阅/我的各选「选中」图'
              '（「未选」可空）。若文件名已是 bookshelf_selected 等，将自动预填。',
            ),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (state.active.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsSectionHeader('预览'),
                  preview.when(
                    skipLoadingOnRefresh: false,
                    data: (items) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final item in items) _previewItem(item),
                        ],
                      ),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => ListTile(
                      title: Text('预览加载失败：$error'),
                      trailing: TextButton(
                        onPressed: () =>
                            ref.invalidate(bottomBarSkinPreviewProvider),
                        child: const Text('重试'),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewItem(BottomBarSkinPreview item) => Column(
    children: [
      if (item.path != null)
        Image.file(File(item.path!), width: 28, height: 28, fit: BoxFit.contain)
      else
        const Icon(Symbols.image_not_supported_rounded, size: 28),
      const SizedBox(height: 4),
      Text(
        BottomBarSkinFormat.slotLabels[item.slot] ?? item.slot,
        style: const TextStyle(fontSize: 10),
      ),
    ],
  );

  Future<void> _import(
    BuildContext context,
    BottomBarSkinNotifier notifier,
  ) async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.path;
    if (path == null) return;
    final zip = File(path);
    String? sessionId;
    try {
      sessionId = await BottomBarSkinService.instance.extractZipToSession(zip);
      final preferred = zip.uri.pathSegments.last.replaceAll(
        RegExp(r'\.zip$', caseSensitive: false),
        '',
      );
      if (!context.mounted) {
        await BottomBarSkinService.instance.discardSession(sessionId);
        return;
      }
      final name = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => BottomBarSkinAssignScreen(
            sessionId: sessionId!,
            preferredName: preferred,
          ),
        ),
      );
      sessionId = null; // Assign 屏负责 discard 或已保存
      if (name != null) {
        await notifier.reload();
        await notifier.setActive(name);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('已保存并启用：$name')));
        }
      } else {
        await notifier.reload();
      }
    } catch (e) {
      if (sessionId != null) {
        await BottomBarSkinService.instance.discardSession(sessionId);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    }
  }

  Future<void> _showItemMenu(
    BuildContext context,
    BottomBarSkinNotifier notifier,
    String name,
  ) async {
    // [统一壳 B2a] 伪标题 ListTile 改统一壳标题（对齐 AppModalBottomSheet 语义）
    final action = await AppBottomSheet.show<String>(
      context: context,
      title: name,
      children: [
        ListTile(
          leading: const Icon(Symbols.edit_rounded),
          title: const Text('编辑'),
          onTap: () => Navigator.pop(context, 'edit'),
        ),
        ListTile(
          leading: const Icon(Symbols.file_download_rounded),
          title: const Text('导出'),
          onTap: () => Navigator.pop(context, 'export'),
        ),
        ListTile(
          leading: const Icon(Symbols.share_rounded),
          title: const Text('分享'),
          onTap: () => Navigator.pop(context, 'share'),
        ),
        ListTile(
          leading: const Icon(Symbols.delete_rounded),
          title: const Text('删除'),
          onTap: () => Navigator.pop(context, 'delete'),
        ),
      ],
    );
    if (!context.mounted) return;
    if (action == 'delete') {
      await _confirmDelete(context, notifier, name);
    } else if (action == 'edit') {
      await _edit(context, notifier, name);
    } else if (action == 'export') {
      await _exportSkin(context, name);
    } else if (action == 'share') {
      await _shareSkin(context, name);
    }
  }

  /// 导出图集为 zip（对齐 BottomBarSkinActivity.exportSkin）
  Future<void> _exportSkin(BuildContext context, String name) async {
    try {
      final bytes = await BottomBarSkinService.instance.buildZipBytes(name);
      final savePath = await FilePicker.saveFile(
        dialogTitle: '导出底栏皮肤',
        fileName: '$name.zip',
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (savePath != null) {
        final location = savePath.scheme == 'file'
            ? savePath.toFilePath()
            : savePath.toString();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('已导出到: $location')));
        }
        return;
      }
      // 平台无保存对话框时走分享
      final file = await BottomBarSkinService.instance.cacheShareZip(name);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: name,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    }
  }

  /// 分享图集 zip（对齐 BottomBarSkinActivity.shareSkin）
  Future<void> _shareSkin(BuildContext context, String name) async {
    try {
      final file = await BottomBarSkinService.instance.cacheShareZip(name);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: name,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('分享失败：$e')));
      }
    }
  }

  Future<void> _edit(
    BuildContext context,
    BottomBarSkinNotifier notifier,
    String name,
  ) async {
    String? sessionId;
    try {
      sessionId = await BottomBarSkinService.instance.stageExisting(name);
      if (!context.mounted) {
        await BottomBarSkinService.instance.discardSession(sessionId);
        return;
      }
      final saved = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => BottomBarSkinAssignScreen(
            sessionId: sessionId!,
            preferredName: name,
            editName: name,
          ),
        ),
      );
      sessionId = null;
      await notifier.reload();
      if (saved != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已更新：$saved')));
      }
    } catch (e) {
      if (sessionId != null) {
        await BottomBarSkinService.instance.discardSession(sessionId);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('无法编辑：$e')));
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BottomBarSkinNotifier notifier,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除皮肤'),
        content: Text('确定删除「$name」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) await notifier.delete(name);
  }
}
