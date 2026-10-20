import 'dart:async';
import 'dart:convert';

import 'package:flutter_legado/src/domain/contracts/cloud_tts_voice_catalog.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_engine_sheet.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_voice_sheet.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/bottom_sheet_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const chinese = CloudTtsVoiceDescriptor(
    id: 'zh-CN-XiaoxiaoNeural',
    name: '晓晓',
    locale: 'zh-CN',
    styles: ['cheerful'],
    roles: ['Girl'],
  );
  const english = CloudTtsVoiceDescriptor(
    id: 'en-US-JennyNeural',
    name: 'Jenny',
    locale: 'en-US',
    styles: ['chat'],
  );
  ReadAloudVoice? saved, preview;
  Future<void> openVoice(
    WidgetTester tester,
    Future<List<CloudTtsVoiceDescriptor>> Function(HttpTtsCancellation) load,
  ) async {
    saved = null;
    preview = null;
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await AppBottomSheet.showContent<ReadAloudVoice>(
                  context: context,
                  builder: (_) => ReadAloudVoiceSheet(
                    source: VoiceEditorSource(
                      kind: 'cloud_tts',
                      id: 'azure',
                      name: 'Azure',
                      provider: 'azure_speech',
                      voices: const [],
                      loadCatalog: load,
                    ),
                    onPreview: (v, text) async {
                      preview = v;
                    },
                    onStop: () async {},
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Azure 引擎区域校验并保存，不展示模型或导出密钥', (tester) async {
    CloudTtsEditResult? result;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) => TextButton(
                onPressed: () async {
                  result = await showCloudTtsEngineEditor(context, ref);
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
    await tester.tap(find.byKey(const ValueKey('cloud-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Azure Speech').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cloud-model')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-apiKey')),
      'fixture-private',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('cloud-region')),
      ' eastasia ',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result!.engine.provider, 'azure_speech');
    expect(result!.engine.region, 'eastasia');
    expect(result!.engine.model, '');
    expect(result!.key, 'fixture-private');
    expect(
      jsonEncode(result!.engine.toJson()),
      isNot(contains('fixture-private')),
    );
  });
  testWidgets('目录选择携带语言、风格和角色，试听与保存只包含请求参数', (tester) async {
    await openVoice(tester, (_) async => [chinese, english]);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('voice-locale')))
          .controller!
          .text,
      'zh-CN',
    );
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'cheerful'));
    await tester.tap(find.widgetWithText(ActionChip, 'cheerful'));
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Girl'));
    await tester.tap(find.widgetWithText(ActionChip, 'Girl'));
    await tester.ensureVisible(find.text('试听'));
    await tester.tap(find.text('试听'));
    await tester.pumpAndSettle();
    final options = jsonDecode(preview!.traitsJson) as Map;
    expect(options, {
      'locale': 'zh-CN',
      'style': 'cheerful',
      'role': 'Girl',
      'speed': 1.0,
      'pitch': 1.0,
      'volume': 1.0,
      'format': 'mp3',
    });
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved!.traitsJson, preview!.traitsJson);
    expect(saved!.speakerId, chinese.id);
    expect(options.containsKey('styles'), isFalse);
  });
  testWidgets('切换候选音色更新语言及可选风格角色，清除上一音色选择', (tester) async {
    await openVoice(tester, (_) async => [chinese, english]);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'cheerful'));
    await tester.tap(find.widgetWithText(ActionChip, 'cheerful'));
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Girl'));
    await tester.tap(find.widgetWithText(ActionChip, 'Girl'));
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Jenny'));
    await tester.tap(find.widgetWithText(ActionChip, 'Jenny'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'cheerful'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Girl'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'chat'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(jsonDecode(saved!.traitsJson)['locale'], 'en-US');
    expect(jsonDecode(saved!.traitsJson)['style'], '');
    expect(jsonDecode(saved!.traitsJson)['role'], '');
  });
  testWidgets('目录失败时允许手动填写音色保存，再次打开可获取目录', (tester) async {
    var calls = 0;
    await openVoice(tester, (_) async {
      calls++;
      if (calls == 1) throw StateError('fixture');
      return [chinese];
    });
    await tester.pumpAndSettle();
    expect(find.text('重试获取音色'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('voice-speaker')),
      'zh-CN-YunxiNeural',
    );
    await tester.enterText(find.byKey(const ValueKey('voice-name')), '手动音色');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved!.speakerId, 'zh-CN-YunxiNeural');
    await openVoice(tester, (_) async {
      calls++;
      return [chinese];
    });
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.widgetWithText(ActionChip, '晓晓'), findsOneWidget);
  });
  testWidgets('目录失败在当前编辑器重试，手动输入不被迟到目录覆盖', (tester) async {
    var calls = 0;
    final result = Completer<List<CloudTtsVoiceDescriptor>>();
    await openVoice(tester, (_) async {
      if (++calls == 1) throw StateError('fixture');
      return result.future;
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试获取音色'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('voice-speaker')),
      'custom',
    );
    await tester.enterText(find.byKey(const ValueKey('voice-name')), '手动');
    result.complete([chinese]);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('重试获取音色'), findsNothing);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved!.speakerId, 'custom');
    expect(saved!.displayName, '手动');
  });
  testWidgets('关闭编辑器取消目录查询，迟到结果不修改页面或保存音色', (tester) async {
    final result = Completer<List<CloudTtsVoiceDescriptor>>();
    late HttpTtsCancellation cancellation;
    await openVoice(tester, (c) {
      cancellation = c;
      return result.future;
    });
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(cancellation.isCancelled, isTrue);
    result.complete([chinese]);
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.widgetWithText(ActionChip, '晓晓'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
