import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_legado/src/domain/models/source_action_result.dart';
import 'package:flutter_legado/src/providers/reading_content_provider.dart';
import 'package:flutter_legado/src/providers/source_action_provider.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Mock繁简与根配置共享值，非法设置归零且不创建额外偏好', () async {
    final api = MockBookApi();
    final content = api.readingContentService;
    await content.setChineseConvertType(2);
    expect(await api.configRepository.getConfig('chineseConverterType'), '2');
    expect(await content.getChineseConvertType(), 2);
    await api.configRepository.setConfig('chineseConverterType', '1');
    expect(await content.getChineseConvertType(), 1);
    await content.setChineseConvertType(-1);
    expect(await content.getChineseConvertType(), 0);
    expect(await api.configRepository.getAllConfigs(), {
      'chineseConverterType': '0',
    });
  });
  test('Mock章级去重按书籍/章节隔离，重新启用恢复默认；试算不修改状态', () async {
    final content = MockBookApi().readingContentService;
    expect(await content.getSameTitleRemoved('a', 1), isTrue);
    await content.toggleSameTitleRemoved('a', 1, false);
    expect(await content.getSameTitleRemoved('a', 1), isFalse);
    expect(await content.getSameTitleRemoved('a', 2), isTrue);
    expect(await content.getSameTitleRemoved('b', 1), isTrue);
    expect(await content.canRemoveSameTitle('第一章', ' \n第一章\n正文'), isTrue);
    expect(await content.canRemoveSameTitle('第一章', '正文'), isFalse);
    expect(await content.getSameTitleRemoved('a', 1), isFalse);
    await content.toggleSameTitleRemoved('a', 1, true);
    expect(await content.getSameTitleRemoved('a', 1), isTrue);
  });
  test('Mock动作保持无购买与未接管，不模拟真实脚本', () async {
    final service = MockBookApi().sourceActionService;
    final purchase = await service.chapterPayAction(
      bookUrl: 'b',
      chapterIndex: 1,
    );
    expect(purchase.kind, ChapterPurchaseKind.none);
    final callback = await service.sourceCallBackBtn(
      event: 'event',
      bookUrl: 'b',
    );
    expect(callback.handled, isFalse);
    expect(callback.actions, isEmpty);
  });
  test('窄Provider可独立替换，根与Mock构造器保持实例共享', () {
    final api = MockBookApi();
    final root = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(root.dispose);
    expect(
      root.read(readingContentServiceProvider),
      same(api.readingContentService),
    );
    expect(
      root.read(sourceActionServiceProvider),
      same(api.sourceActionService),
    );
    final content = ReadingContentServiceMock();
    final actions = SourceActionServiceMock();
    final isolated = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWith((ref) => throw StateError('不应访问根实例')),
        readingContentServiceProvider.overrideWithValue(content),
        sourceActionServiceProvider.overrideWithValue(actions),
      ],
    );
    addTearDown(isolated.dispose);
    expect(isolated.read(readingContentServiceProvider), same(content));
    expect(isolated.read(sourceActionServiceProvider), same(actions));
    final injected = MockBookApi(
      readingContentService: content,
      sourceActionService: actions,
    );
    expect(injected.readingContentService, same(content));
    expect(injected.sourceActionService, same(actions));
  });
}
