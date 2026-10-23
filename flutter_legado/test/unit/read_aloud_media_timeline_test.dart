import '../fixtures/read_aloud_planner.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/models/read_aloud_media_timeline.dart';
import 'package:flutter_legado/src/utils/read_aloud_text.dart';

void main() {
  test('时间轴与上游4字每秒及语速换算一致', () {
    expect(readAloudMediaTime(40, 1), 10000);
    expect(readAloudMediaTime(40, 2), 5000);
    expect(readAloudMediaTime(1, 1.5), 166);
    expect(readAloudMediaTime(0, 1), 0);
    expect(readAloudMediaTime(20, double.nan), 0);
    expect(readAloudMediaOffset(2500, 100, 2), 20);
    expect(readAloudMediaOffset(999999, 10, 1), 9);
    expect(readAloudMediaOffset(-1, 10, 1), 0);
  });
  test('暂停冻结、恢复不跳变，字符回调落后时单调推进', () {
    final clock = ReadAloudMediaClock();
    int step(int estimate, int now, bool playing) => clock.update(
      estimate: estimate,
      duration: 10000,
      playing: playing,
      now: now,
    );
    expect(step(2000, 0, true), 2000);
    expect(step(2000, 1000, true), 3000);
    expect(step(2500, 1500, false), 3500);
    expect(step(4000, 6000, false), 3500);
    expect(step(4000, 7000, true), 3500);
    expect(step(6000, 8000, true), 6000);
    expect(step(6000, 20000, true), 10000);
  });
  test('重置允许向后定位，原文定位不会切开emoji和组合字符', () async {
    const text = '甲👨‍👩‍👧‍👦é乙';
    final units = await FixtureReadAloudPlanner().plan(text);
    final requested = readAloudMediaOffset(750, text.length, 1);
    expect(readAloudStartAt(units, requested), (paragraph: 0, offset: 1));
    final clock = ReadAloudMediaClock();
    expect(
      clock.update(estimate: 1000, duration: 5000, playing: true, now: 100),
      1000,
    );
  });
}
