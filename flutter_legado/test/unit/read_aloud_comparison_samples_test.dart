import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/services/read_aloud_comparison_samples.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';
import 'package:flutter_legado/src/services/read_aloud_comparison.dart';

class _Cache extends Fake implements TtsCacheRepository {
  final entries = <TtsCacheEntry>[];
  @override
  bool get supportsAudioFiles => true;
  @override
  Future<List<TtsCacheEntry>> list() async => entries;
}

class _Environment extends Fake implements AppEnvironment {
  _Environment(this.path);
  final String path;
  @override
  Future<String> cacheDirectory(RuntimeCache cache) async => path;
}

void main() {
  late Directory root, original;
  late _Cache cache;
  late ReadAloudComparisonSamples samples;
  Future<void> add(int paragraph, {String? name, int modified = 1}) async {
    final filename = name ?? '$paragraph.wav';
    final bytes = [paragraph, modified];
    await File('${original.path}/$filename').writeAsBytes(bytes);
    cache.entries.add(
      TtsCacheEntry(
        name: filename,
        sizeBytes: bytes.length,
        modifiedAtMs: modified,
        protected: false,
        contexts: [
          TtsCacheContext(
            bookUrl: 'book',
            bookName: '测试书',
            chapterIndex: 1,
            chapterTitle: '测试章',
            paragraphIndex: paragraph,
            text: '不进入诊断日志的正文',
          ),
        ],
      ),
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tts-samples-');
    original = await Directory('${root.path}/cache').create();
    cache = _Cache();
    samples = ReadAloudComparisonSamples(
      repository: cache,
      environment: _Environment(original.path),
      temporaryDirectory: () async => root,
    );
  });
  tearDown(() async {
    await samples.close();
    await root.delete(recursive: true);
  });

  test('按段落去重并排序、取最多八个独立副本，摘要基于实际字节', () async {
    for (var i = 8; i >= 0; i--) await add(i);
    await add(2, name: 'new2.wav', modified: 2);
    final fixture = await samples.prepare();
    expect(fixture.audio.length, 8);
    expect(fixture.audio.map((a) => File(a.path).uri.pathSegments.last), [
      '0.wav',
      '1.wav',
      'new2.wav',
      '3.wav',
      '4.wav',
      '5.wav',
      '6.wav',
      '7.wav',
    ]);
    for (final audio in fixture.audio) {
      final data = await File(audio.path).readAsBytes();
      expect(audio.sha256, sha256.convert(data).toString());
      expect(audio.bytes, data.length);
      expect(File(audio.path).parent.path, isNot(original.path));
    }
    await File('${original.path}/0.wav').writeAsBytes([255]);
    expect(await File(fixture.audio.first.path).readAsBytes(), [0, 1]);
    await samples.close();
    expect(await File(fixture.audio.first.path).exists(), isFalse);
    expect(await File('${original.path}/0.wav').exists(), isTrue);
  });

  test('同段多个版本不凑足六段，无足够样本时明确失败', () async {
    for (var i = 0; i < 8; i++) await add(0, name: 'voice$i.wav');
    await expectLater(samples.prepare(), throwsStateError);
    expect(await original.list().length, 8);
  });

  test('原缓存缺失不替换其他样本，失败副本清除', () async {
    for (var i = 0; i < 6; i++) await add(i);
    await File('${original.path}/4.wav').delete();
    await expectLater(samples.prepare(), throwsA(isA<FileSystemException>()));
    final copied = Directory('${root.path}/read_aloud_comparison');
    expect(await copied.list().length, 0);
  });

  test('A与B日志独立保存，下一轮导出和样本清理不覆盖A', () async {
    final source = await File('${root.path}/export.jsonl').writeAsString('A');
    final a = await samples.saveReport(source, ReadAloudComparisonMode.fixed);
    await source.writeAsString('B');
    final b = await samples.saveReport(source, ReadAloudComparisonMode.dynamic);
    await samples.close();
    expect(await a.readAsString(), 'A');
    expect(await b.readAsString(), 'B');
  });
}
