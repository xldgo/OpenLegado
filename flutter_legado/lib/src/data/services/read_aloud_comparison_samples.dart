import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/contracts/tts_cache_repository.dart';
import '../../platform/app_environment.dart';
import '../../services/read_aloud_comparison.dart';

/// 复制现有缓存，不通过合成接口取音频，不改动原缓存。— Codex + UI
final class ReadAloudComparisonSamples {
  ReadAloudComparisonSamples({
    required this.repository,
    AppEnvironment? environment,
    Future<Directory> Function()? temporaryDirectory,
  }) : environment = environment ?? const NativeAppEnvironment(),
       temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final TtsCacheRepository repository;
  final AppEnvironment environment;
  final Future<Directory> Function() temporaryDirectory;
  Directory? _fixture;

  Future<ComparisonFixture> prepare() async {
    if (!repository.supportsAudioFiles) throw StateError('当前环境不支持真实音频对照');
    final groups =
        <(String, int), Map<int, (TtsCacheEntry, TtsCacheContext)>>{};
    for (final entry in await repository.list()) {
      if (entry.sizeBytes <= 0) continue;
      for (final context in entry.contexts) {
        final group = groups[(context.bookUrl, context.chapterIndex)] ??= {};
        final previous = group[context.paragraphIndex];
        if (previous == null ||
            entry.modifiedAtMs > previous.$1.modifiedAtMs ||
            (entry.modifiedAtMs == previous.$1.modifiedAtMs &&
                entry.name.compareTo(previous.$1.name) < 0)) {
          group[context.paragraphIndex] = (entry, context);
        }
      }
    }
    final eligible =
        groups.values
            .where(
              (group) => group.values.map((v) => v.$1.name).toSet().length >= 6,
            )
            .toList()
          ..sort(
            (a, b) => b.values
                .map((v) => v.$1.modifiedAtMs)
                .reduce((a, b) => a > b ? a : b)
                .compareTo(
                  a.values
                      .map((v) => v.$1.modifiedAtMs)
                      .reduce((a, b) => a > b ? a : b),
                ),
          );
    if (eligible.isEmpty) throw StateError('请先朗读同一章节并缓存至少6段音频，再准备对照');
    final candidates = eligible.first.values.toList()
      ..sort((a, b) {
        final order = a.$2.paragraphIndex.compareTo(b.$2.paragraphIndex);
        return order == 0 ? a.$1.name.compareTo(b.$1.name) : order;
      });
    final names = <String>{};
    final selected = candidates
        .where((v) => names.add(v.$1.name))
        .take(8)
        .toList();
    final cache = Directory(await environment.cacheDirectory(RuntimeCache.tts));
    final root = Directory(
      '${(await temporaryDirectory()).path}/read_aloud_comparison',
    );
    await root.create(recursive: true);
    final next = await root.createTemp('samples-');
    final audio = <ComparisonAudio>[];
    try {
      for (final (entry, _) in selected) {
        final name = entry.name;
        if (name.isEmpty ||
            name == '.' ||
            name == '..' ||
            name.contains('/') ||
            name.contains('\\')) {
          throw StateError('缓存文件名无效，请重新准备');
        }
        final copy = await File('${cache.path}/$name')
            .copy('${next.path}/$name');
        final size = await copy.length();
        if (size <= 0) throw StateError('缓存音频已失效，请重新准备');
        audio.add(
          ComparisonAudio(
            path: copy.path,
            sha256: (await sha256.bind(copy.openRead()).first).toString(),
            bytes: size,
          ),
        );
      }
    } catch (_) {
      await next.delete(recursive: true);
      rethrow;
    }
    final previous = _fixture;
    _fixture = next;
    if (previous != null && await previous.exists()) {
      await previous.delete(recursive: true);
    }
    return ComparisonFixture(
      label:
          '${selected.first.$2.bookName} · ${selected.first.$2.chapterTitle}',
      identity: sha256
          .convert(utf8.encode(audio.map((a) => a.sha256).join('\n')))
          .toString(),
      audio: audio,
    );
  }

  Future<File> saveReport(
    File report,
    ReadAloudComparisonMode mode,
  ) async => report.copy(
    '${(await temporaryDirectory()).path}/read_aloud_comparison_${mode.name}.jsonl',
  );

  Future<void> close() async {
    final fixture = _fixture;
    _fixture = null;
    if (fixture != null && await fixture.exists()) {
      await fixture.delete(recursive: true);
    }
  }
}
