import '../../models/book_source.dart';
import '../models/source_syntax_result.dart';

/// 编辑辅助与书源持久化分离；不保存或自动修正脚本。— Codex + Bridge
abstract interface class BookSourceEditService {
  Future<bool> looksLikeCurl(String text);
  Future<String> curlToAnalyzeUrl(String text);
  Future<String> analyzeUrlToCurl(String text);
  Future<BookSource> extractJsSource(String content);
  Future<SourceSyntaxResult> checkJsSourceSyntax(String content);

  /// 解析原始书源 JSON 为书源实体（契约 SOURCE-PARSE-FFI-20261022）。
  ///
  /// 只读：不写数据库、不写限速表、不修改任何既有记录。解析规则由 Rust
  /// 统一实现，Dart 侧不做 `jsonDecode` 语法预检，避免两套语法接受范围。
  Future<BookSource> parseSource(String json);
}
