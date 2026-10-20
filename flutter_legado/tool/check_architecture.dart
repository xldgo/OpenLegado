import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// 静态依赖门禁；通过语法树检查真实指令，覆盖条件导入和转导出。— Codex + UI
List<String> checkDependencies(String source, String code) {
  final unit = parseString(content: code, throwIfDiagnostics: false).unit;
  final issues = <String>[];
  final ui =
      source.startsWith('src/features/') ||
      source.startsWith('src/widgets/') ||
      source.startsWith('src/providers/');
  final domain = source.startsWith('src/domain/');
  for (final directive in unit.directives) {
    if (directive is! UriBasedDirective) continue;
    final uris = <String?>[directive.uri.stringValue];
    if (directive is ImportDirective) {
      uris.addAll(directive.configurations.map((c) => c.uri.stringValue));
    }
    if (directive is ExportDirective) {
      uris.addAll(directive.configurations.map((c) => c.uri.stringValue));
    }
    for (final uri in uris.whereType<String>()) {
      final parsed = Uri.tryParse(uri);
      if (parsed == null) continue;
      String? target;
      if (parsed.scheme == 'package' &&
          parsed.path.startsWith('flutter_legado/')) {
        target = parsed.normalizePath().path.substring(
          'flutter_legado/'.length,
        );
      } else if (parsed.scheme.isEmpty) {
        target = Uri(path: '/$source')
            .resolveUri(parsed)
            .normalizePath()
            .path
            .substring(1);
      }
      final bridge =
          target?.startsWith('src/bridge/') == true ||
          uri.startsWith('package:flutter_rust_bridge/');
      if (ui && bridge) {
        issues.add(
          '$source:${unit.lineInfo.getLocation(directive.offset).lineNumber} 界面不能直接依赖生成桥接：$uri',
        );
      }
      if (domain &&
          ((target != null &&
                  [
                    'src/features/',
                    'src/data/',
                    'src/providers/',
                    'src/widgets/',
                    'src/app/',
                    'src/bridge/',
                    'src/services/',
                    'src/platform/',
                  ].any(target.startsWith)) ||
              [
                'dart:ui',
                'package:flutter/',
                'package:material_ui/',
                'package:cupertino_ui/',
                'package:flutter_riverpod/',
                'package:flutter_rust_bridge/',
              ].any(uri.startsWith))) {
        issues.add(
          '$source:${unit.lineInfo.getLocation(directive.offset).lineNumber} 领域层不能依赖界面或具体实现：$uri',
        );
      }
    }
  }
  return issues;
}

Future<void> main(List<String> args) async {
  final lib = Directory.fromUri(Platform.script.resolve('../lib/'));
  final issues = <String>[];
  await for (final file in lib.list(recursive: true, followLinks: false)) {
    if (file is! File ||
        !file.path.endsWith('.dart') ||
        file.path.endsWith('.g.dart') ||
        file.path.endsWith('.freezed.dart')) {
      continue;
    }
    final relative = file.uri.path.substring(lib.uri.path.length);
    if (!relative.startsWith('src/domain/') &&
        !relative.startsWith('src/features/') &&
        !relative.startsWith('src/widgets/') &&
        !relative.startsWith('src/providers/')) {
      continue;
    }
    issues.addAll(checkDependencies(relative, await file.readAsString()));
  }
  if (issues.isNotEmpty) {
    stderr.writeln(issues.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln('架构静态依赖检查通过。');
  }
}
