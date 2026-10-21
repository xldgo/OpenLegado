import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_chrome.dart';

void main() {
  for (final hideStatus in [false, true]) {
    for (final hideNavigation in [false, true]) {
      for (final avoid in [false, true]) {
        test('状态栏隐藏$hideStatus、导航栏隐藏$hideNavigation、缺口避让$avoid分开计算', () {
          final actual = readerContentInsets(
            systemInsets: const EdgeInsets.only(top: 24, bottom: 34),
            cutoutInsets: const EdgeInsets.fromLTRB(7, 40, 8, 12),
            hideStatusBar: hideStatus,
            hideNavigationBar: hideNavigation,
            avoidDisplayCutouts: avoid,
          );
          expect(
            actual.top,
            avoid
                ? 40
                : hideStatus
                ? 0
                : 24,
          );
          expect(actual.bottom, hideNavigation ? (avoid ? 12 : 0) : 34);
          expect(actual.left, avoid ? 7 : 0);
          expect(actual.right, avoid ? 8 : 0);
        });
      }
    }
  }
  test('无真实缺口时，隐藏状态栏完全释放顶部区域', () {
    expect(
      readerContentInsets(
        systemInsets: const EdgeInsets.only(top: 24, bottom: 34),
        cutoutInsets: EdgeInsets.zero,
        hideStatusBar: true,
        hideNavigationBar: true,
        avoidDisplayCutouts: true,
      ),
      EdgeInsets.zero,
    );
  });
  test('横屏只避开实际侧边缺口，不把顶部状态栏高度当侧边缺口', () {
    expect(
      readerContentInsets(
        systemInsets: const EdgeInsets.only(top: 24, bottom: 20),
        cutoutInsets: const EdgeInsets.only(left: 44),
        hideStatusBar: true,
        hideNavigationBar: true,
        avoidDisplayCutouts: true,
      ),
      const EdgeInsets.only(left: 44),
    );
  });
}
