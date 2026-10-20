import 'package:flutter_legado/src/domain/contracts/book_group_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Shelf extends Mock implements BookshelfRepository {}

class _Groups extends Mock implements BookGroupRepository {}

void main() {
  late _Shelf shelf;
  late _Groups groups;
  const group = BookGroup(groupId: 16, groupName: '接口测试分组', cover: null);
  setUpAll(() => registerFallbackValue(const BookGroup()));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    shelf = _Shelf();
    groups = _Groups();
    when(() => shelf.getBooks()).thenAnswer((_) async => const []);
    when(() => groups.getBookGroups()).thenAnswer((_) async => [group]);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookshelfRepositoryProvider.overrideWithValue(shelf),
          bookGroupRepositoryProvider.overrideWithValue(groups),
        ],
        child: const MaterialApp(home: BookGroupScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('分组页只依赖窄接口，显隐操作保留完整对象及原调用方式', (tester) async {
    BookGroup? saved;
    when(() => groups.updateBookGroup(any())).thenAnswer((invocation) async {
      saved = invocation.positionalArguments.single as BookGroup;
    });
    await open(tester);
    expect(find.text(group.groupName), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(saved, group.copyWith(show: false));
    verify(() => groups.updateBookGroup(any())).called(1);
    // 结构迁移不能顺便改成另一条显隐 API；其原能力差异另行处理。
    verifyNever(() => groups.bookGroupSetShow(any(), any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('分组读取失败显示原错误，重试仍使用同一窄接口', (tester) async {
    when(() => groups.getBookGroups()).thenThrow(StateError('分组读失败'));
    await open(tester);
    expect(find.textContaining('分组读失败'), findsOneWidget);
    when(() => groups.getBookGroups()).thenAnswer((_) async => [group]);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(group.groupName), findsOneWidget);
    expect(find.textContaining('分组读失败'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
