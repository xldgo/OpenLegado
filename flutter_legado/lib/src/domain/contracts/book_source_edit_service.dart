import '../../models/book_source.dart';
import '../models/source_syntax_result.dart';

/// 编辑辅助与书源持久化分离；不保存或自动修正脚本。— Codex + Bridge
abstract interface class BookSourceEditService {
  Future<bool> looksLikeCurl(String text);
  Future<String> curlToAnalyzeUrl(String text);
  Future<String> analyzeUrlToCurl(String text);
  Future<BookSource> extractJsSource(String content);
  Future<SourceSyntaxResult> checkJsSourceSyntax(String content);
}
