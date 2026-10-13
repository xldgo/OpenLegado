import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/widgets/reader/reader_page_chrome.dart';

void main() {
  test('隐藏导航栏并填充刘海，无底部缺口时不保留导航栏占位', () {
    expect(
      readerContentBottomInset(
        systemBottomInset: 24,
        cutoutBottomInset: 0,
        hideNavigationBar: true,
        paddingDisplayCutouts: true,
      ),
      0,
    );
  });

  test('隐藏导航栏但有真实底部缺口时只保留缺口高度', () {
    expect(
      readerContentBottomInset(
        systemBottomInset: 34,
        cutoutBottomInset: 12,
        hideNavigationBar: true,
        paddingDisplayCutouts: true,
      ),
      12,
    );
  });

  test('关闭填充刘海后不额外预留真实缺口', () {
    expect(
      readerContentBottomInset(
        systemBottomInset: 34,
        cutoutBottomInset: 12,
        hideNavigationBar: true,
        paddingDisplayCutouts: false,
      ),
      0,
    );
  });

  test('显示导航栏时保留安全边距，不重复叠加已经包含的缺口', () {
    expect(
      readerContentBottomInset(
        systemBottomInset: 34,
        cutoutBottomInset: 12,
        hideNavigationBar: false,
        paddingDisplayCutouts: true,
      ),
      34,
    );
  });
}
