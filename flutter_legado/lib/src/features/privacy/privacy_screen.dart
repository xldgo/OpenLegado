import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';
import '../../widgets/settings_widgets.dart';
import 'privacy_controller.dart';
import '../../platform/privacy/privacy_platform.dart';
import 'privacy_password_dialog.dart';
import 'privacy_settings.dart';
import 'privacy_unlock_dialog.dart';

/// 上游三组隐私页；只呈现已接通的能力。— Codex + UI
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});
  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _verified = false, _verifying = false, _saving = false;
  Future<void> _verify() async {
    if (_verifying) return;
    _verifying = true;
    final result = await showPrivacyUnlock(context, ref, verifyOnly: true);
    if (mounted) {
      setState(() => _verified = result);
      if (!result) Navigator.maybePop(context);
    }
    _verifying = false;
  }

  Future<void> _save(PrivacySettings settings) async {
    setState(() => _saving = true);
    try {
      await ref.read(privacyControllerProvider.notifier).update(settings);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _password() async {
    final controller = ref.read(privacyControllerProvider.notifier);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => PrivacyPasswordDialog(
        hasPassword: ref.read(privacyControllerProvider).hasPassword,
        save: controller.changePassword,
      ),
    );
    if (mounted && result == true) setState(() => _verified = true);
  }

  Future<void> _openPermission(bool battery) async {
    try {
      final platform = ref.read(privacyPlatformProvider);
      final opened = battery
          ? await platform.openBatterySettings()
          : await platform.openNotificationSettings();
      if (!opened) throw StateError('系统设置不可用');
      if (mounted) ref.invalidate(privacyPermissionsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法打开系统设置')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(privacyControllerProvider);
    Widget body;
    if (state.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.error != null) {
      body = Center(
        child: TextButton(
          onPressed: () => ref.read(privacyControllerProvider.notifier).retry(),
          child: Text(state.error!),
        ),
      );
    } else if (state.settings.enabled && state.hasPassword && !_verified) {
      body = Center(
        child: TextButton(onPressed: _verify, child: const Text('验证后进入隐私设置')),
      );
    } else {
      final settings = state.settings;
      const scopeLabels = {
        PrivacyUnlockScope.everyTime: '每次都验证',
        PrivacyUnlockScope.appSession: '本次应用会话有效',
        PrivacyUnlockScope.untilBackground: '离开应用前有效',
      };
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroup(
            title: '解锁凭据',
            children: [
              SettingSwitchRow(
                title: '启用私密内容',
                subtitle: '关闭后保留密码及书籍、分组的私密标记',
                value: settings.enabled,
                onChanged: !state.hasPassword || _saving
                    ? null
                    : (v) => _save(settings.copyWith(enabled: v)),
              ),
              SettingTile(
                title: state.hasPassword ? '修改隐私密码' : '设置隐私密码',
                subtitle: state.hasPassword ? '私密书籍与分组需验证后查看' : '请先设置密码',
                onTap: _password,
              ),
              SettingSwitchRow(
                title: '生物识别快捷解锁',
                subtitle: !state.hasPassword
                    ? '请先设置隐私密码'
                    : switch (state.biometricStatus) {
                        'available' => '使用设备生物识别验证，仍可输入隐私密码',
                        'notEnrolled' => '请先在系统设置录入指纹或面容',
                        'noHardware' => '设备没有可用的生物识别硬件',
                        _ => '当前平台生物识别不可用',
                      },
                value: settings.biometricEnabled && state.biometricEnrolled,
                onChanged:
                    !state.hasPassword ||
                        state.biometricStatus != 'available' ||
                        _saving
                    ? null
                    : (enabled) async {
                        setState(() => _saving = true);
                        try {
                          await ref
                              .read(privacyControllerProvider.notifier)
                              .setBiometric(enabled);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('生物识别设置未完成')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroup(
            title: '验证时机',
            children: [
              SettingSwitchRow(
                title: '进入私密分组时验证',
                value: settings.verifyOnEnterGroup,
                onChanged: !state.hasPassword || _saving
                    ? null
                    : (v) => _save(settings.copyWith(verifyOnEnterGroup: v)),
              ),
              SettingSwitchRow(
                title: '打开私密书籍时验证',
                value: settings.verifyOnOpenBook,
                onChanged: !state.hasPassword || _saving
                    ? null
                    : (v) => _save(settings.copyWith(verifyOnOpenBook: v)),
              ),
              SettingSwitchRow(
                title: '启动应用时验证',
                value: settings.verifyOnAppStart,
                onChanged: !state.hasPassword || _saving
                    ? null
                    : (v) => _save(settings.copyWith(verifyOnAppStart: v)),
              ),
              SettingTile(
                title: '验证有效期',
                value: scopeLabels[settings.scope],
                onTap: _saving
                    ? null
                    : () async {
                        final scope = await showDialog<PrivacyUnlockScope>(
                          context: context,
                          builder: (ctx) => SimpleDialog(
                            title: const Text('验证有效期'),
                            children: [
                              for (final entry in scopeLabels.entries)
                                SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(ctx, entry.key),
                                  child: Text(entry.value),
                                ),
                            ],
                          ),
                        );
                        if (scope != null) {
                          await _save(settings.copyWith(scope: scope));
                        }
                      },
              ),
              if (settings.scope == PrivacyUnlockScope.untilBackground)
                SettingTile(
                  title: '离开后重新验证',
                  value: switch (settings.graceSeconds) {
                    0 => '立即',
                    30 => '30秒',
                    final n => '${n ~/ 60}分钟',
                  },
                  onTap: _saving
                      ? null
                      : () async {
                          final seconds = await showDialog<int>(
                            context: context,
                            builder: (ctx) => SimpleDialog(
                              title: const Text('离开后重新验证'),
                              children: [
                                for (final n in const [0, 30, 120, 180, 300])
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(ctx, n),
                                    child: Text(
                                      n == 0
                                          ? '立即'
                                          : n == 30
                                          ? '30秒'
                                          : '${n ~/ 60}分钟',
                                    ),
                                  ),
                              ],
                            ),
                          );
                          if (seconds != null) {
                            await _save(
                              settings.copyWith(graceSeconds: seconds),
                            );
                          }
                        },
                ),
            ],
          ),
          if (ref.watch(privacyPlatformProvider).supportsPermissions) ...[
            const SizedBox(height: 16),
            SettingsGroup(
              title: '权限与数据',
              children: [
                SettingTile(
                  title: '通知权限',
                  value: ref
                      .watch(privacyPermissionsProvider)
                      .when(
                        data: (p) => p['notifications'] == true ? '已允许' : '未允许',
                        loading: () => '读取中',
                        error: (_, _) => '状态不可用',
                      ),
                  subtitle: '用于下载进度与后台播放通知',
                  onTap: () => _openPermission(false),
                ),
                if (ref.watch(privacyPlatformProvider).supportsBatterySettings)
                  SettingTile(
                    title: '后台运行权限',
                    value: ref
                        .watch(privacyPermissionsProvider)
                        .when(
                          data: (p) => p['batteryUnrestricted'] == true
                              ? '不受电池优化限制'
                              : '受系统电池策略管理',
                          loading: () => '读取中',
                          error: (_, _) => '状态不可用',
                        ),
                    subtitle: '打开系统电池设置管理后台运行',
                    onTap: () => _openPermission(true),
                  ),
              ],
            ),
          ],
        ],
      );
    }
    return AppScaffold(
      topBar: const LegadoAppBar(title: Text('隐私'), showBack: true),
      body: body,
    );
  }
}
