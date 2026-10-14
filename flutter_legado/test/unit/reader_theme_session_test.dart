import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/app/session/reader_theme_session.dart';
import 'package:flutter_legado/src/domain/models/reader_theme_mode.dart';

void main() {
  test('新会话跟随应用，手动覆盖只在当前实例有效', () async {
    final session = ReaderThemeSession();
    final reopened = ReaderThemeSession();
    addTearDown(session.dispose);
    addTearDown(reopened.dispose);
    expect(session.isNightOverride, isNull);
    session.setMode(ReaderThemeMode.night);
    expect(session.isNightOverride, isTrue);
    expect(reopened.mode, ReaderThemeMode.followApp);
    session.setMode(ReaderThemeMode.day);
    expect(session.isNightOverride, isFalse);
    session.reset();
    expect(session.mode, ReaderThemeMode.followApp);
    expect(session.isNightOverride, isNull);
  });

  test('订阅收到当前模式、后续切换及退出复位，取消不影响其他订阅', () async {
    final session = ReaderThemeSession();
    addTearDown(session.dispose);
    session.setMode(ReaderThemeMode.night);
    final events = <ReaderThemeMode>[];
    final subscription = session.watch().listen(events.add);
    final observer = session.watch().listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await observer.cancel();
    session.setMode(ReaderThemeMode.day);
    session.setMode(ReaderThemeMode.day);
    session.reset();
    await Future<void>.delayed(Duration.zero);
    expect(events, [
      ReaderThemeMode.night,
      ReaderThemeMode.day,
      ReaderThemeMode.followApp,
    ]);
    await subscription.cancel();
  });
}
