import '../../../data/services/file_metadata.dart';
import '../../../app/routing/app_navigation.dart';
import '../../bookshelf/bookshelf_repositories.dart';

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../constants/pref_keys.dart';
import '../../../models/book.dart';
import '../../../app/routing/route_names.dart';
import '../../../domain/models/welcome_settings.dart';
import '../../../providers/welcome_settings_provider.dart';
import '../../../app/routing/startup_reading_navigation.dart';
import '../../../widgets/app_scaffold.dart';

/// 启动闪屏（对齐原版 WelcomeActivity + activity_welcome.xml）
///
/// 结构：竖排「阅读」标题 + 副标、书图标、底部文案；按 [PrefKeys.welcomeShowTime]
/// 延时后进入主页（0 则立即进入）。支持自定义欢迎图与日/夜显隐偏好。
/// 非三页功能介绍轮播（审计 D2 / P2-11）。
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _navigating = false;

  // 本次启动的展示快照，设置页变化不会重启计时与淡入动画。
  WelcomeSettings _welcome = const WelcomeSettings();
  String? get _bgImageDay =>
      _welcome.customWelcome && _welcome.imageDay.isNotEmpty
      ? _welcome.imageDay
      : null;
  String? get _bgImageNight =>
      _welcome.customWelcome && _welcome.imageNight.isNotEmpty
      ? _welcome.imageNight
      : null;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    WelcomeSettings settings;
    try {
      settings = await ref.read(welcomeSettingsRepositoryProvider).load();
    } catch (error) {
      debugPrint('欢迎页设置读取失败，沿用默认展示：$error');
      settings = const WelcomeSettings();
    }
    if (!mounted) return;
    setState(() => _welcome = settings);
    final showTime = settings.showTime;
    _fade.forward();

    if (showTime <= 0) {
      await _goNext();
      return;
    }
    _timer = Timer(Duration(milliseconds: showTime.clamp(0, 800)), _goNext);
  }

  Future<void> _goNext() async {
    if (_navigating || !mounted) return;
    _navigating = true;
    _timer?.cancel();

    Book? lastRead;
    final defaultToRead = ref
        .read(welcomeSettingsRepositoryProvider)
        .current
        .defaultToRead;
    if (defaultToRead) {
      try {
        final books = await ref.read(bookshelfRepositoryProvider).getBooks();
        if (books.isNotEmpty) {
          lastRead = books.reduce(
            (a, b) => a.durChapterTime >= b.durChapterTime ? a : b,
          );
          if (lastRead.durChapterTime <= 0) lastRead = null;
        }
      } catch (_) {
        lastRead = null;
      }
    }

    if (!mounted) return;
    // 交接给应用作用域；替换Future代表主页关闭，不能把它当作入场完成。
    if (lastRead != null) {
      ref.read(startupReadingNavigationProvider).request(lastRead);
    }
    unawaited(GoRouter.of(context).replaceAppRoute(AppRoutes.home));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final showIcon = isDark ? _welcome.showIconDark : _welcome.showIcon;
    final showText = isDark ? _welcome.showTextDark : _welcome.showText;
    final path = isDark ? _bgImageNight : _bgImageDay;

    DecorationImage? bgImage;
    if (_welcome.customWelcome &&
        path != null &&
        ref.watch(fileMetadataProvider(path)).value != null) {
      bgImage = DecorationImage(
        image: FileImage(File(path)),
        fit: BoxFit.cover,
      );
    }

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    // 背景色/背景图语义保留：surface 作闪屏底色，body 内 DecoratedBox 叠加背景图
    return AppScaffold(
      backgroundColor: theme.colorScheme.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          image: bgImage,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _opacity,
            child: Stack(
              children: [
                // 标题区（约垂直偏上，对齐原版 bias 0.4）
                Align(
                  alignment: const Alignment(0, -0.35),
                  child: showText
                      ? _WelcomeTitle(accent: accent)
                      : const SizedBox.shrink(),
                ),
                // 书图标
                Align(
                  alignment: const Alignment(0, 0.35),
                  child: showIcon
                      ? Icon(
                          Symbols.menu_book_rounded,
                          size: 120,
                          color: accent,
                        )
                      : const SizedBox.shrink(),
                ),
                // 底部文案
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: showText
                        ? Text(
                            '品读万千故事',
                            style: TextStyle(
                              fontSize: 16,
                              letterSpacing: 1.6,
                              color: accent,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 竖排「阅读」+ 横排副标（结构对齐 activity_welcome.xml；视觉偏系统字重）
class _WelcomeTitle extends StatelessWidget {
  final Color accent;

  const _WelcomeTitle({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 120,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 竖排「阅读」
            Text(
              '阅\n读',
              style: TextStyle(
                fontSize: 48,
                height: 1.05,
                fontWeight: FontWeight.w600,
                color: accent,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 58),
          child: Text(
            '享\n受\n美\n好\n时\n光',
            style: TextStyle(
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w400,
              color: accent.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}
