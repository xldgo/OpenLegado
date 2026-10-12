import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_legado/src/services/reader_layout_service.dart';

/// 挂载真实阅读器的 Widget 测试统一接入 Rust 核心测试宿主。
Widget readerLayoutTestBuilder(BuildContext context, Widget? child) =>
    ReaderLayoutTransportScope(
      transport: RustLayoutTestTransport.instance,
      child: child ?? const SizedBox.shrink(),
    );

/// 测试调用独立 Rust 核心宿主；不复制断行算法，也不加载应用数据库。
class RustLayoutTestTransport implements ReaderLayoutTransport {
  static final instance = RustLayoutTestTransport();
  final Map<String, Map<String, dynamic>> _sessions = {};
  int _sequence = 0;
  static String get executable {
    final configured = Platform.environment['LEGADO_LAYOUT_TEST_HOST'];
    final path =
        configured ??
        '../rust/target/debug/examples/test_host${Platform.isWindows ? '.exe' : ''}';
    if (!File(path).existsSync()) {
      throw StateError(
        '缺少 Rust 排版测试宿主，请先在 rust/ 执行 cargo build -p legado-layout --example test_host',
      );
    }
    return File(path).absolute.path;
  }

  @override
  Future<String> begin(String configJson) async {
    final id = 'test-${_sequence++}';
    _sessions[id] = {
      'config': jsonDecode(configJson)['config'],
      'blocks': <dynamic>[],
      'emitted': 0,
    };
    return jsonEncode({
      'schemaVersion': 1,
      'sessionId': id,
      'pages': [],
      'rustMicros': 0,
      'textStyles': [],
      'glyphs': {
        'count': 0,
        'text': '',
        'geometry': '',
        'positions': '',
        'extras': {},
      },
    });
  }

  String _run(String id, bool finish) {
    final state = _sessions[id]!;
    final directory = Directory.systemTemp.createTempSync(
      'legado-layout-test-',
    );
    try {
      final input = File('${directory.path}/input.json');
      input.writeAsStringSync(
        jsonEncode({
          'config': state['config'],
          'blocks': state['blocks'],
          'finish': finish,
        }),
      );
      final result = Process.runSync(
        executable,
        [input.path],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) {
        throw StateError('Rust 排版宿主失败：${result.stderr}');
      }
      final reply = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final pages = reply['pages'] as List;
      reply['sessionId'] = id;
      reply['pages'] = pages.skip(state['emitted'] as int).toList();
      state['emitted'] = pages.length;
      return jsonEncode(reply);
    } finally {
      directory.deleteSync(recursive: true);
    }
  }

  @override
  Future<String> push(String sessionId, String blocksJson) async {
    (_sessions[sessionId]!['blocks'] as List).addAll(
      jsonDecode(blocksJson)['blocks'] as List,
    );
    return _run(sessionId, false);
  }

  @override
  Future<String> finish(String sessionId) async {
    try {
      return _run(sessionId, true);
    } finally {
      _sessions.remove(sessionId);
    }
  }

  @override
  Future<void> cancel(String sessionId) async => _sessions.remove(sessionId);
}

/// 异步排版之后再挂载原测试界面，不把 Future 当成同步页面列表。
class LayoutTestBuilder extends StatefulWidget {
  final Future<Widget> Function(BuildContext) builder;
  const LayoutTestBuilder({super.key, required this.builder});
  @override
  State<LayoutTestBuilder> createState() => _LayoutTestBuilderState();
}

class _LayoutTestBuilderState extends State<LayoutTestBuilder> {
  Future<Widget>? _result;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _result ??= widget.builder(context);
  }

  @override
  void didUpdateWidget(LayoutTestBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.builder != oldWidget.builder) _result = widget.builder(context);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _result,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        Error.throwWithStackTrace(snapshot.error!, snapshot.stackTrace!);
      }
      return snapshot.data ?? const SizedBox.shrink();
    },
  );
}
