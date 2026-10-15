// rust_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 RustApiMediaFormat mixin：规则解析 / 网络 / JS 引擎 / 服务器 / 格式解析 / 音频播放。
// RustApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 解码辅助来自 RustApiDecode（on 约束），同一 library 内私有成员可直接访问。
part of 'rust_api.dart';

mixin RustApiMediaFormat on RustApiDecode implements BookApi {
  // ========== 规则解析 ==========

  /// 使用规则解析内容
  @override
  Future<String> parseRule(String content, String rule, String ruleType) =>
      bridge.parseRule(content: content, rule: rule, ruleType: ruleType);

  // ========== 网络操作 ==========

  /// HTTP GET 请求
  @override
  Future<String> httpGet(String url) => bridge.httpGet(url: url);

  /// HTTP GET 二进制响应
  @override
  Future<String> httpGetBytes(String url, {String headersJson = ''}) =>
      bridge.httpGetBytes(url: url, headersJson: headersJson);

  /// HTTP POST 请求
  @override
  Future<String> httpPost(String url, String body) =>
      bridge.httpPost(url: url, body: body);

  /// 图片下载 + imageDecode 解码（返回 JSON：{ base64, len }）— Reasonix
  @override
  Future<String> fetchImageWithDecode(String url, String sourceJson) =>
      bridge.fetchImageWithDecode(url: url, sourceJson: sourceJson);

  /// 读取本地 cbz 漫画单页图片字节（返回 JSON：{ base64, len }）
  ///
  /// [cbz 批 D | 2026-10-03] 与 FFI `cbz_read_page` 对齐：漫画阅读器对
  /// `cbz://<条目名>` 伪 URL 逐页调用本方法取图（zip 条目读取在 Rust 侧）。
  @override
  Future<String> cbzReadPage({required String path, required String entry}) =>
      bridge.cbzReadPage(path: path, entry: entry);

  // ========== JS 引擎 ==========

  /// 执行 JS 脚本
  @override
  Future<String> evalJs(String script) async =>
      // 平台桥接拦截：书源调试中 webView 类调用由此真实执行（Task #114）— QoderCN
      PlatformBridgeService.instance.interceptResult(
        await bridge.jsEval(script: script),
      );

  /// 获取 JS 引擎版本（通过 jsEval 查询）
  @override
  Future<String> getJsEngineVersion() async {
    try {
      return await bridge.jsEval(
        script:
            'typeof QuickJS !== "undefined" ? QuickJS.version : "quickjs-ng"',
      );
    } catch (_) {
      return 'unknown';
    }
  }

  // ========== 服务器管理 ==========

  /// 启动服务器（委托 Rust server_start 真实启动 Web 服务）
  @override
  Future<void> startServer({int port = 1122}) async {
    await bridge.serverStart(port: port);
  }

  /// 停止服务器（委托 Rust server_stop）
  @override
  Future<void> stopServer() async {
    await bridge.serverStop();
  }

  /// 获取服务器状态
  ///
  /// Rust 返回 JSON `{running: bool, port: int}`，转换为统一描述串
  ///（与既有 UI/测试语义一致：`running on port X` / `stopped`）。
  @override
  Future<String> getServerStatus() async {
    final raw = await bridge.serverStatus();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['running'] == true) {
        return 'running on port ${m['port'] ?? 1122}';
      }
    } catch (_) {
      // 解析失败按停止处理
    }
    return 'stopped';
  }

  /// 设置服务器端口（记录用户选择，下次 startServer 生效）
  @override
  Future<void> setServerPort(int port) async {
    await bridge.configSet(key: 'server_port', value: port.toString());
  }

  /// 设置自定义 hosts 映射（契约 §2.20.3，Task #74）
  @override
  Future<void> setCustomHosts(String hostsJson) =>
      bridge.setCustomHosts(hostsJson: hostsJson);

  /// 设置独立 MCP 服务端口（契约 §2.22.5，Task #74）
  @override
  Future<void> setMcpPort(int port) => bridge.setMcpPort(port: port);

  /// 封面规则测试搜索（契约 §2.4.8，Task #74）
  ///
  /// Rust 返回裸 JSON Array（§1.4 铁律），解析为字符串列表；
  /// 空结果 `[]` 解析为空列表（非异常）。
  @override
  Future<List<String>> searchCoverRules(String name) async {
    final json = await bridge.searchCoverRules(name: name);
    final decoded = jsonDecode(json);
    if (decoded is! List) return [];
    return decoded.map((e) => e.toString()).toList();
  }

  @override
  Future<Map<String, dynamic>> getCoverRule() async {
    final json = await bridge.getCoverRule();
    return _decodeMap(json, 'getCoverRule');
  }

  @override
  Future<bool> saveCoverRule(Map<String, dynamic> rule) =>
      bridge.saveCoverRule(ruleJson: jsonEncode(rule));

  @override
  Future<bool> deleteCoverRule() => bridge.deleteCoverRule();

  // ========== 书籍格式解析 ==========

  /// 解析 TXT 文件（按章节标题模式分割）
  ///
  /// ⚠️ 死代码标注（批次3治理 Task #118）：此 Dart 纯正则 fallback 在全工程
  /// 已无任何调用点（TXT 章节解析已由 Rust 侧接管）。仅为保持 [BookApi]
  /// 契约面不变而保留，勿删除；后续如需清理须同步 book_api.dart /
  /// mock_book_api.dart 声明。
  @override
  Future<List<BookChapter>> parseTxt(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw RustApiException(
        'File not found: $filePath',
        operation: 'parseTxt',
      );
    }
    final content = await file.readAsString();
    final lines = content.split('\n');
    final chapterPattern = RegExp(
      r'^\s*(第[\d零一二三四五六七八九十百千万]+[章节回卷集部篇]|[\d]+[\.、]|[Chapter]+\s*[\d]+)',
      caseSensitive: false,
    );
    final chapters = <BookChapter>[];
    var currentTitle = '序章';
    var startIndex = 0;
    for (var i = 0; i < lines.length; i++) {
      if (chapterPattern.hasMatch(lines[i])) {
        if (i > startIndex) {
          chapters.add(
            BookChapter(
              title: currentTitle,
              bookUrl: filePath,
              index: chapters.length,
              start: startIndex,
              end: i,
            ),
          );
        }
        currentTitle = lines[i].trim();
        startIndex = i;
      }
    }
    // 添加最后一章
    chapters.add(
      BookChapter(
        title: currentTitle,
        bookUrl: filePath,
        index: chapters.length,
        start: startIndex,
        end: lines.length,
      ),
    );
    return chapters;
  }

  /// 解析 EPUB 文件（通过 importLocalBook 解析后获取章节）
  @override
  Future<List<BookChapter>> parseEpub(String filePath) async {
    // 先导入书籍，然后获取章节列表
    final bookJson = await bridge.importLocalBook(filePath: filePath);
    final resultMap = jsonDecode(bookJson) as Map<String, dynamic>;
    final bookMap = resultMap['book'] as Map<String, dynamic>?;
    final bookUrl = bookMap?['bookUrl'] as String? ?? filePath;
    final chaptersJson = await bridge.readerGetChapters(bookUrl: bookUrl);
    final decodedChapters = jsonDecode(chaptersJson);
    // 兼容 Rust 侧返回 ChapterListResponse { total, chapters } 对象格式
    final List<dynamic> list;
    if (decodedChapters is Map<String, dynamic>) {
      list = (decodedChapters['chapters'] as List<dynamic>?) ?? [];
    } else if (decodedChapters is List<dynamic>) {
      list = decodedChapters;
    } else {
      list = [];
    }
    return list
        .map((e) => BookChapter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 导出书籍（将章节内容写入文件）
  @override
  Future<String> exportBook(
    String bookUrl,
    String format,
    String outDir,
  ) async {
    final book = await bookshelfRepository.getBook(bookUrl);
    final bookName = book?.name ?? 'export';
    final chapters = await readingRepository.getChapters(bookUrl);
    final dir = Directory(outDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName = '$bookName.${format == 'txt' ? 'txt' : 'json'}';
    final filePath = '$outDir${Platform.pathSeparator}$fileName';
    final file = File(filePath);
    if (format == 'txt') {
      final buffer = StringBuffer();
      for (final chapter in chapters) {
        buffer.writeln(chapter.title);
        buffer.writeln();
        try {
          final content = await readingRepository.getChapterContent(
            bookUrl,
            chapter.index,
          );
          buffer.writeln(content);
        } catch (_) {
          buffer.writeln('[内容获取失败]');
        }
        buffer.writeln();
      }
      await file.writeAsString(buffer.toString());
    } else {
      final data = {
        'book': book?.toJson(),
        'chapters': chapters.map((e) => e.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data));
    }
    return filePath;
  }

  // ========== 音频播放 ==========

  /// 获取章节媒体信息（音频书取址，契约 §2.26）
  ///
  /// 对齐原版 `AudioPlay` → `WebBook.getContent`：经 FFI `audioGetChapterMedia`
  /// 解析可播 `mediaUrl`。返回含 `mediaUrl` / `url` / `isVolume` / `fromCache` 等。
  @override
  Future<Map<String, dynamic>> getAudioChapterMedia(
    String bookUrl,
    int chapterIndex,
  ) async {
    final json = await bridge.audioGetChapterMedia(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
    );
    return (jsonDecode(json) as Map<String, dynamic>).cast<String, dynamic>();
  }

  /// 获取音频播放进度
  @override
  Future<Map<String, dynamic>?> getAudioProgress(
    String bookUrl,
    int chapterIndex,
  ) async {
    final pos = await bridge.audioGetProgress(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
    );
    return {'position': pos.toInt(), 'chapterIndex': chapterIndex};
  }

  /// 保存音频播放进度
  @override
  Future<void> saveAudioProgress(
    String bookUrl,
    int chapterIndex,
    int positionMs,
  ) async {
    await bridge.audioSaveProgress(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
      position: positionMs,
    );
  }
}
