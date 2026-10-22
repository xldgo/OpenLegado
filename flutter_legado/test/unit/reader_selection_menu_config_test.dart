import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/reader/selection/reader_selection_menu_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('排序、隐藏和展示偏好在重新读取后保持一致', () async {
    final config = ReaderSelectionMenuConfig()
        .reorder(SelectionMenuGroup.primary, 0, 2)
        .moveToGroup(ReaderSelectionAction.bookmark, SelectionMenuGroup.hidden)
        .copyWith(expanded: true, showIcons: false);
    await config.save();
    final restored = await ReaderSelectionMenuConfig.load();
    expect(restored.encode(), config.encode());
    expect(
      restored.inGroup(SelectionMenuGroup.primary).map((item) => item.action),
      [
        ReaderSelectionAction.share,
        ReaderSelectionAction.browser,
        ReaderSelectionAction.copy,
        ReaderSelectionAction.aloud,
      ],
    );
    expect(
      restored.visibleItems.any(
        (item) => item.action == ReaderSelectionAction.bookmark,
      ),
      isFalse,
    );
    expect(restored.expanded, isTrue);
    expect(restored.showIcons, isFalse);
  });

  test('未保存的管理草稿不修改已保存配置，隐藏动作可以恢复', () async {
    final saved = ReaderSelectionMenuConfig();
    await saved.save();
    final hidden = saved.moveToGroup(
      ReaderSelectionAction.copy,
      SelectionMenuGroup.hidden,
    );
    final restoredDraft = hidden.moveToGroup(
      ReaderSelectionAction.copy,
      SelectionMenuGroup.primary,
    );
    expect(restoredDraft.encode(), saved.encode());
    expect((await ReaderSelectionMenuConfig.load()).encode(), saved.encode());
    expect(
      saved.inGroup(SelectionMenuGroup.primary).first.action,
      ReaderSelectionAction.copy,
    );
  });
}
