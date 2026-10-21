import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/reader/layout_diagnostics.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';
import 'package:flutter_legado/src/widgets/reader/text_layout_environment.dart';
import 'package:flutter_legado/src/widgets/reader/reader_title_layout.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_chrome.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';

const _label = String.fromEnvironment(
  'LAYOUT_PROFILE_LABEL',
  defaultValue: 'dart',
);
const _revision = String.fromEnvironment('LAYOUT_PROFILE_REVISION');
const _width = 320.0;
const _height = 580.0;
const _profileTitle = ReaderTitleLayout(
  text: '性能采样章节标题',
  chrome: ReaderPageChromeConfig(),
);
const _warmups = 2;
const _rounds = 7;

/// 使用真实正文渲染器；不初始化数据库、不访问书源、不改用户阅读进度。
Future<void> main() async {
  if (!kProfileMode) throw StateError('性能采样入口只允许 profile 模式');
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery.withNoTextScaling(child: const _ProfileScreen()),
    ),
  );
}

class _Sample {
  final String name;
  final String source;
  final bool reviews;
  const _Sample(this.name, this.source, {this.reviews = false});
}

List<_Sample> _samples() => [
  _Sample(
    'short-chapter',
    List.generate(120, (i) => '这是排版性能固定样本的第${i + 1}段正文。' * 3).join('\n'),
  ),
  _Sample(
    'mixed-long-chapter',
    List.generate(
      400,
      (i) =>
          '“第${i + 1}段开始了。”他问：「真的可以吗？」'
              'English words stay together, including café and e\u0301. '
              '😀𠮷👨‍👩‍👧‍👦 这是固定的中英混排样本。' *
          2,
    ).join('\n'),
  ),
  _Sample('single-long-paragraph', '他推开门，走进房间，窗外的风吹动树叶。English text 😀。' * 300),
  _Sample(
    'inline-reviews',
    List.generate(120, (i) => '段末评论固定样本${i + 1}。他推开门，走进了房间。' * 3).join('\n'),
    reviews: true,
  ),
];

int _recordId = 0;
void _emit(Map<String, Object?> value) {
  // Flutter Android stdout 在本机按约 1 KB 截断，传输包控制在该上限以内。
  final encoded = base64Encode(utf8.encode(jsonEncode(value)));
  final total = (encoded.length / 800).ceil();
  for (var offset = 0; offset < encoded.length; offset += 800) {
    debugPrint(
      'READER_LAYOUT_PROFILE ${jsonEncode({'record': _recordId, 'chunk': offset ~/ 800, 'total': total, 'payload': encoded.substring(offset, math.min(offset + 800, encoded.length))})}',
      wrapWidth: null,
    );
  }
  _recordId++;
}

int _percentile(List<int> values, double fraction) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  return sorted[(sorted.length * fraction).ceil().clamp(1, sorted.length) - 1];
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen>
    with SingleTickerProviderStateMixin {
  PageInfo? _page;
  String _status = '准备性能采样';
  final List<FrameTiming> _frames = [];
  late final void Function(List<FrameTiming>) _timings = _frames.addAll;
  late final Ticker _heartbeat;
  final List<int> _frameGaps = [];
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _heartbeat = createTicker((_) {
      final now = developer.Timeline.now;
      _frameGaps.add(now - _lastTick);
      _lastTick = now;
    });
    WidgetsBinding.instance.addTimingsCallback(_timings);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_timings);
    _heartbeat.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final samples = _samples();
      _emit({
        'kind': 'environment',
        'schema': 1,
        'label': _label,
        'revision': _revision,
        'mode': 'profile',
        'os': Platform.operatingSystemVersion,
        'processors': Platform.numberOfProcessors,
        'devicePixelRatio': View.of(context).devicePixelRatio,
        'displayRefreshRate': View.of(context).display.refreshRate,
        'width': _width,
        'height': _height,
        'chapterTitle': _profileTitle.text,
        'titleLayout': 'contentBlock',
        'fontSize': 18,
        'lineHeight': 1.6,
        'paragraphSpacing': 8,
        'indent': 36,
        'textScale': 1,
        'warmups': _warmups,
        'rounds': _rounds,
        'cases': samples.map((sample) => sample.name).toList(),
      });
      for (final sample in samples) {
        // 夹具自身留指纹输入供采集端验证，不把整章正文塞进单条日志。
        final encoded = base64Encode(utf8.encode(sample.source));
        _emit({
          'kind': 'fixture',
          'case': sample.name,
          'utf16': sample.source.length,
          'chunks': (encoded.length / 2000).ceil(),
        });
        for (var offset = 0; offset < encoded.length; offset += 2000) {
          _emit({
            'kind': 'fixtureChunk',
            'case': sample.name,
            'index': offset ~/ 2000,
            'base64': encoded.substring(
              offset,
              math.min(offset + 2000, encoded.length),
            ),
          });
        }
        await debugPrintDone;
        for (var round = -_warmups; round < _rounds; round++) {
          await _measure(sample, round);
          await debugPrintDone;
        }
      }
      _emit({'kind': 'complete', 'label': _label, 'revision': _revision});
      if (mounted) setState(() => _status = '性能采样完成');
    } catch (error, stack) {
      _emit({'kind': 'error', 'error': '$error', 'stack': '$stack'});
      if (mounted) setState(() => _status = '性能采样失败：$error');
    }
  }

  Future<void> _measure(_Sample sample, int round) async {
    setState(() {
      _page = null;
      _status = '${sample.name} / ${round < 0 ? '预热' : round + 1}';
    });
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) throw StateError('性能采样页面已关闭');
    _frames.clear();
    final diagnostics = ReaderLayoutDiagnostics();
    final engine = ParagraphLayoutEngine(
      context: context,
      diagnostics: diagnostics,
      config: ParagraphConfig(
        fontSize: 18,
        lineHeight: 1.6,
        paragraphSpacing: 8,
        indent: 36,
        useZhLayout: true,
        backgroundColor: Colors.white,
        textColor: Colors.black,
        textEnvironment: TextLayoutEnvironment.of(context),
      ),
    );
    final reviews = <int, InlineReview>{};
    if (sample.reviews) {
      final paragraphs = splitChapterParagraphs(sample.source);
      for (var i = 0; i < paragraphs.length; i++) {
        reviews[i + 1] = InlineReview(
          paragraphId: i + 1,
          reviewKey: i + 1,
          sourceAnchor: paragraphs[i].endIndex,
          count: 23,
          size: const Size(50, 24),
          compactSize: const Size(24, 24),
          baseline: 18,
        );
      }
    }
    final rssBefore = ProcessInfo.currentRss;
    var sampledPeakRss = rssBefore;
    final start = developer.Timeline.now;
    _frameGaps.clear();
    _lastTick = start;
    _heartbeat.start();
    final wall = Stopwatch()..start();
    final active = Stopwatch()..start();
    final session = engine.startChapter(
      sample.source,
      _width,
      _height,
      title: _profileTitle,
      paragraphReviews: reviews,
    );
    active.stop();
    int? firstReadyUs;
    int? firstFrameSubmittedUs;
    while (!session.complete) {
      active.start();
      await session.advance(maxParagraphs: session.pages.isEmpty ? 16 : 8);
      final pages = session.pages;
      active.stop();
      sampledPeakRss = math.max(sampledPeakRss, ProcessInfo.currentRss);
      if (pages.isNotEmpty && firstReadyUs == null) {
        firstReadyUs = wall.elapsedMicroseconds;
        setState(() => _page = pages.first);
        await WidgetsBinding.instance.endOfFrame;
        // 这是框架提交首屏帧的时间，显示器呈现时间不在此值中。
        firstFrameSubmittedUs = wall.elapsedMicroseconds;
      } else if (!session.complete) {
        // 与正式阅读器相同，在分批边界让出 UI 线程。
        await WidgetsBinding.instance.endOfFrame;
      }
    }
    final chapterUs = wall.elapsedMicroseconds;
    wall.stop();
    final end = developer.Timeline.now;
    _heartbeat.stop();
    final pages = session.pages;
    final shown = pages
        .expand((page) => page.paragraphs)
        .where((paragraph) => !paragraph.isTitle)
        .expand((paragraph) => paragraph.lines)
        .map((line) => line.selectableText)
        .join();
    if (shown != sample.source.replaceAll('\n', '')) {
      throw StateError('${sample.name} 出现重复或遗漏正文');
    }
    // 等待引擎批量投递帧耗时，仅统计实际采样时间窗口内的帧。
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) throw StateError('性能采样页面已关闭');
    final frames = _frames.where((frame) {
      final timestamp = frame.timestampInMicroseconds(FramePhase.buildStart);
      return timestamp >= start && timestamp <= end;
    }).toList();
    final refreshRate = View.of(context).display.refreshRate;
    final frameBudgetUs = (1000000 / refreshRate).round();
    if (frames.isEmpty) throw StateError('未收到采样窗口内的 FrameTiming');
    if (round >= 0) {
      final build = frames
          .map((frame) => frame.buildDuration.inMicroseconds)
          .toList();
      final raster = frames
          .map((frame) => frame.rasterDuration.inMicroseconds)
          .toList();
      _emit({
        'kind': 'sample',
        'case': sample.name,
        'round': round + 1,
        'utf16': sample.source.length,
        'firstPageReadyUs': firstReadyUs,
        'firstPageFrameSubmittedUs': firstFrameSubmittedUs,
        'chapterWallUs': chapterUs,
        'activeLayoutUs': active.elapsedMicroseconds,
        'measuredPathUs': diagnostics.measurementMicroseconds,
        'unattributedActiveUs':
            active.elapsedMicroseconds - diagnostics.measurementMicroseconds,
        'measurementCalls': diagnostics.measurementCalls,
        'pages': pages.length,
        'frames': frames.length,
        'buildP50Us': _percentile(build, 0.5),
        'buildP95Us': _percentile(build, 0.95),
        'buildMaxUs': build.reduce(math.max),
        'rasterP95Us': _percentile(raster, 0.95),
        'rasterMaxUs': raster.reduce(math.max),
        'frameSpanP95Us': _percentile(
          frames.map((frame) => frame.totalSpan.inMicroseconds).toList(),
          0.95,
        ),
        'frameGapP95Us': _percentile(_frameGaps, 0.95),
        'frameGapMaxUs': _frameGaps.isEmpty ? 0 : _frameGaps.reduce(math.max),
        'longFrameGaps': _frameGaps
            .where((gap) => gap > frameBudgetUs * 1.5)
            .length,
        'frameBudgetUs': frameBudgetUs,
        'overBudgetFrames': frames
            .where(
              (frame) =>
                  frame.buildDuration.inMicroseconds > frameBudgetUs ||
                  frame.rasterDuration.inMicroseconds > frameBudgetUs,
            )
            .length,
        'rssBeforeBytes': rssBefore,
        'rssAfterBytes': ProcessInfo.currentRss,
        'sampledPeakRssBytes': sampledPeakRss,
        // 保留真实边界耗时；调用包含排队，Rust 计时是其中的子区间。
        'ffi': {
          'calls': diagnostics.ffiCalls,
          'encodingUs': diagnostics.encodingMicroseconds,
          'callUs': diagnostics.callMicroseconds,
          'decodingUs': diagnostics.decodingMicroseconds,
          'rustUs': diagnostics.rustMicroseconds,
        },
      });
      for (final frame in frames) {
        _emit({
          'kind': 'frame',
          'case': sample.name,
          'round': round + 1,
          'buildUs': frame.buildDuration.inMicroseconds,
          'rasterUs': frame.rasterDuration.inMicroseconds,
          'totalSpanUs': frame.totalSpan.inMicroseconds,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: SizedBox(
        width: _width,
        height: _height,
        child: _page == null
            ? Text(_status)
            : ReaderTextContent(
                pageInfo: _page!,
                fontSize: 18,
                lineHeight: 1.6,
                paragraphSpacing: 8,
                textColor: Colors.black,
              ),
      ),
    ),
  );
}
