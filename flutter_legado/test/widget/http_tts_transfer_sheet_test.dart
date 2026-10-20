import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_legado/src/data/repositories/mock_http_tts_repository.dart';
import 'package:flutter_legado/src/data/services/http_tts_transfer_service.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/network_service.dart';
import 'package:flutter_legado/src/domain/models/http_response.dart';
import 'package:flutter_legado/src/features/read_aloud/http_tts_export_sheet.dart';
import 'package:flutter_legado/src/features/read_aloud/http_tts_import_sheet.dart';
import 'package:flutter_legado/src/features/read_aloud/http_tts_transfer_provider.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/platform/files/http_tts_file_service.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/bottom_sheet_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Network extends Mock implements NetworkService {}

class _Repository extends Mock implements HttpTtsRepository {}

class _Files extends HttpTtsFileService {
  String? input, written;
  bool saved = true;
  @override
  Future<String?> read() async => input;
  @override
  Future<bool> write(String document) async {
    written = document;
    return saved;
  }
}

void main() {
  late MockHttpTtsRepository storage;
  late _Repository repository;
  late _Network network;
  late _Files files;
  late HttpTtsTransferService service;
  String? clipboard;
  Object? result;
  bool failSave = false;
  var nextId = 1;
  const document =
      '[{"id":1,"name":"旧项","url":"https://old","lastUpdateTime":1},{"id":2,"name":"新项","url":"https://new"}]';

  setUp(() {
    nextId = 1;
    result = null;
    clipboard = null;
    failSave = false;
    storage = MockHttpTtsRepository(nextId: () => nextId++);
    repository = _Repository();
    network = _Network();
    files = _Files();
    service = HttpTtsTransferService(repository, network);
    when(() => repository.getHttpTts()).thenAnswer((_) => storage.getHttpTts());
    when(() => repository.exportHttpTts())
        .thenAnswer((_) => storage.exportHttpTts());
    when(() => repository.importHttpTts(any())).thenAnswer((call) {
      if (failSave) throw StateError('模拟写入失败');
      return storage.importHttpTts(call.positionalArguments.single as String);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return clipboard == null ? null : {'text': clipboard};
          }
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<void> open(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpTtsTransferProvider.overrideWithValue(service),
          httpTtsFileServiceProvider.overrideWithValue(files),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await AppBottomSheet.showContent<Object>(
                    context: context,
                    isDismissible: false,
                    enableDrag: false,
                    builder: (_) => child,
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('剪贴板预览默认排除已有项，勾选确认只保存所选记录', (tester) async {
    await storage.addHttpTts(
      const HttpTts(
        id: 1,
        name: '本地旧项',
        url: 'https://local',
        lastUpdateTime: 2,
      ),
    );
    clipboard = document;
    await open(tester, const HttpTtsImportSheet());
    await tester.tap(find.text('从剪贴板导入'));
    await tester.pumpAndSettle();
    expect(find.text('导入（1）'), findsOneWidget);
    expect(find.text('已有 · 勾选后覆盖'), findsOneWidget);
    verifyNever(() => repository.importHttpTts(any()));
    await tester.tap(find.text('导入（1）'));
    await tester.pumpAndSettle();
    expect(result, 1);
    final rows = await storage.getHttpTts();
    expect(rows.map((e) => e.name), ['本地旧项', '新项']);
    expect(rows.map((e) => e.id), [1, 2]);
  });

  testWidgets('手动勾选已有项允许覆盖，但保留引擎 ID', (tester) async {
    await storage.addHttpTts(
      const HttpTts(id: 1, name: '本地', url: 'https://local', lastUpdateTime: 2),
    );
    clipboard = document;
    await open(tester, const HttpTtsImportSheet());
    await tester.tap(find.text('从剪贴板导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '旧项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入（2）'));
    await tester.pumpAndSettle();
    expect((await storage.getHttpTts()).first.name, '旧项');
    expect((await storage.getHttpTts()).first.id, 1);
    expect(result, 2);
  });

  testWidgets('取消预览与迟到网络结果不写库、不关闭后续页面', (tester) async {
    final pending = Completer<HttpTextResponse>();
    when(() => network.httpGet('https://rules.test'))
        .thenAnswer((_) => pending.future);
    await open(tester, const HttpTtsImportSheet());
    await tester.enterText(find.byType(TextField), 'https://rules.test');
    await tester.tap(find.text('预览规则'));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    pending.complete(const HttpTextResponse(statusCode: 200, body: document));
    await tester.pumpAndSettle();
    verifyNever(() => repository.importHttpTts(any()));
    expect(result, isNull);
    expect(find.text('打开'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('坏文件无写入，重新选择有效文件后可以预览并取消', (tester) async {
    files.input = '[null]';
    await open(tester, const HttpTtsImportSheet());
    await tester.tap(find.text('从文件导入'));
    await tester.pumpAndSettle();
    expect(find.textContaining('第 1 项无效'), findsOneWidget);
    files.input = document;
    await tester.tap(find.text('从文件导入'));
    await tester.pumpAndSettle();
    expect(find.text('导入（2）'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.importHttpTts(any()));
    expect(await storage.getHttpTts(), isEmpty);
  });

  testWidgets('保存失败保留勾选状态并能重试，不报告导入成功', (tester) async {
    clipboard = document;
    failSave = true;
    await open(tester, const HttpTtsImportSheet());
    await tester.tap(find.text('从剪贴板导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入（2）'));
    await tester.pumpAndSettle();
    expect(find.textContaining('模拟写入失败'), findsOneWidget);
    expect(find.text('导入（2）'), findsOneWidget);
    expect(result, isNull);
    failSave = false;
    await tester.tap(find.text('导入（2）'));
    await tester.pumpAndSettle();
    expect(result, 2);
  });

  testWidgets('大字窄屏能够查看规则并清除预览后重新输入', (tester) async {
    clipboard = document;
    await open(tester, const HttpTtsImportSheet(), scale: 1.5);
    await tester.tap(find.text('从剪贴板导入'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('查看规则').first);
    await tester.tap(find.byTooltip('查看规则').first);
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '[]');
    await tester.pumpAndSettle();
    expect(find.text('导入（0）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单条导出初始只选目标，复制不包含未选引擎', (tester) async {
    await storage.importHttpTts(document);
    await open(
      tester,
      HttpTtsExportSheet(
        engines: await storage.getHttpTts(),
        initialIds: const {2},
      ),
    );
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.text('复制规则'));
    await tester.pumpAndSettle();
    expect(result, '已复制规则');
    final rows = jsonDecode(clipboard!) as List;
    expect(rows, hasLength(1));
    expect(rows.single['id'], 2);
  });

  testWidgets('文件导出取消留在弹层，重试保存成功才退出', (tester) async {
    await storage.importHttpTts(document);
    files.saved = false;
    await open(tester, HttpTtsExportSheet(engines: await storage.getHttpTts()));
    await tester.tap(find.text('导出文件'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('导出文件'), findsOneWidget);
    expect(jsonDecode(files.written!), hasLength(2));
    files.saved = true;
    await tester.tap(find.text('导出文件'));
    await tester.pumpAndSettle();
    expect(result, '导出成功');
  });

  testWidgets('打开导出后源被删除，明确报错且不写文件', (tester) async {
    await storage.importHttpTts(document);
    await open(tester, HttpTtsExportSheet(engines: await storage.getHttpTts()));
    await storage.deleteHttpTts(2);
    await tester.tap(find.text('导出文件'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已被删除'), findsOneWidget);
    expect(files.written, isNull);
    expect(result, isNull);
  });
}
