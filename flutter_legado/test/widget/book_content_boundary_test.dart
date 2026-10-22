import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'dart:io';

import 'package:flutter_legado/src/domain/models/review.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/providers/book_content_provider.dart';
import 'package:flutter_legado/src/features/imports/presentation/archive_import_dialog.dart';
import 'package:flutter_legado/src/features/reader/widgets/review_detail_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
// path_provider的测试替身仅通过传递平台接口注入，不增加应用依赖。
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('段评详情与按需回复通过窄服务加载，不需要根接口', (tester) async {
    final service = ReviewServiceMock();
    when(() => service.reviewGetDetail('s', any(), 1)).thenAnswer(
      (_) async => ReviewPage(
        items: [
          const ReviewDetailItem(
            id: 'r',
            name: '读者',
            content: '首条段评',
            replyCount: 1,
          ),
        ],
        hasReplyUrl: true,
      ),
    );
    when(() => service.reviewGetReplies('s', any(), 1)).thenAnswer(
      (_) async => ReviewPage(items: [const ReviewDetailItem(content: '按需回复')]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewDetailSheet(
            service: service,
            sourceJson: 's',
            bookUrl: 'b',
            chapterUrl: 'c',
            chapterIndex: 0,
            paragraphIndex: 3,
            paragraphData: 'para',
            totalCount: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('首条段评'), findsOneWidget);
    await tester.tap(find.text('查看回复 (1)'));
    await tester.pumpAndSettle();
    expect(find.text('按需回复'), findsOneWidget);
    final request =
        verify(() => service.reviewGetReplies('s', captureAny(), 1))
                .captured
                .single
            as Map<String, dynamic>;
    expect(request['reviewId'], 'r');
    expect(request['paraData'], 'para');
    expect(request['paraIndex'], 3);
    await tester.tap(find.text('收起回复'));
    await tester.pumpAndSettle();
    expect(find.text('按需回复'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('段评加载失败显示错误，不显示暂无评论', (tester) async {
    final service = ReviewServiceMock();
    when(() => service.reviewGetDetail('s', any(), 1))
        .thenThrow(StateError('段评请求失败'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewDetailSheet(
            service: service,
            sourceJson: 's',
            bookUrl: 'b',
            chapterUrl: 'c',
            chapterIndex: 0,
            paragraphIndex: 0,
            paragraphData: '',
            totalCount: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('段评请求失败'), findsOneWidget);
    expect(find.text('暂无评论'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('压缩包列表失败可重试，取消不解包', (tester) async {
    final archive = BookArchiveServiceMock();
    when(() => archive.archiveListZipFiles(zipPath: 'books.zip'))
        .thenThrow(StateError('压缩包损坏'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bookArchiveServiceProvider.overrideWithValue(archive)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      const ArchiveImportDialog(archivePath: 'books.zip'),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.textContaining('压缩包损坏'), findsOneWidget);
    when(() => archive.archiveListZipFiles(zipPath: 'books.zip'))
        .thenAnswer((_) async => ['book.txt']);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('book.txt'), findsOneWidget);
    expect(find.text('导入 (1)'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    verifyNever(
      () => archive.archiveImportZip(
        zipPath: any(named: 'zipPath'),
        outputDir: any(named: 'outputDir'),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('压缩包导入只统计成功的书籍，不把失败项算成功', (tester) async {
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('book_content_widget_'),
    ))!;
    final old = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temp.path);
    addTearDown(() async {
      PathProviderPlatform.instance = old;
      await temp.delete(recursive: true);
    });
    final archive = BookArchiveServiceMock();
    final local = LocalBookServiceMock();
    when(() => archive.archiveListZipFiles(zipPath: 'books.zip'))
        .thenAnswer((_) async => ['成功.txt', '失败.txt']);
    when(
      () => archive.archiveImportZip(
        zipPath: 'books.zip',
        outputDir: any(named: 'outputDir'),
      ),
    ).thenAnswer((call) async {
      final dir = call.namedArguments[#outputDir] as String;
      return [
        '$dir${Platform.pathSeparator}成功.txt',
        '$dir${Platform.pathSeparator}失败.txt',
      ];
    });
    when(() => local.importLocalBook(any())).thenAnswer((call) async {
      final path = call.positionalArguments.single as String;
      if (path.endsWith('失败.txt')) throw StateError('导入失败');
      return const Book(bookUrl: '成功', name: '成功');
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...MockBookApi().overrides,
          bookArchiveServiceProvider.overrideWithValue(archive),
          localBookServiceProvider.overrideWithValue(local),
        ]),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      const ArchiveImportDialog(archivePath: 'books.zip'),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入 (2)'));
    for (var i = 0; i < 20 && find.text('成功导入 1 本书籍').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('成功导入 1 本书籍'), findsOneWidget);
    expect(find.text('成功导入 2 本书籍'), findsNothing);
    verify(() => local.importLocalBook(any())).called(2);
    expect(tester.takeException(), isNull);
  });
}
