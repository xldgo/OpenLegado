import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/book_source_edit_service.dart';
import '../../domain/models/source_syntax_result.dart';
import '../../models/book_source.dart';
import '../bridge/rust_json_decode.dart';

/// 保留原生转换和QuickJS语义，不在Dart复制解析算法。— Codex + Bridge
class RustBookSourceEditService implements BookSourceEditService {
  const RustBookSourceEditService();
  @override
  Future<bool> looksLikeCurl(String text) => bridge.looksLikeCurl(text: text);
  @override
  Future<String> curlToAnalyzeUrl(String text) =>
      bridge.curlToAnalyzeUrl(text: text);
  @override
  Future<String> analyzeUrlToCurl(String text) =>
      bridge.analyzeUrlToCurl(text: text);
  @override
  Future<BookSource> extractJsSource(String content) async {
    final map = decodeRustJsonMap(
      await bridge.jsSourceExtract(content: content),
      'jsSourceExtract',
    );
    if (map['bookSourceUrl'] is! String || map['bookSourceName'] is! String) {
      throw const FormatException('JS书源配置缺少bookSourceUrl或bookSourceName');
    }
    return BookSource.fromJson({...map, 'mainJs': content});
  }

  @override
  Future<SourceSyntaxResult> checkJsSourceSyntax(String content) async {
    final map = decodeRustJsonMap(
      await bridge.jsSourceSyntaxCheck(content: content),
      'jsSourceSyntaxCheck',
    );
    final valid = map['valid'];
    if (valid is! bool) throw const FormatException('语法检查缺少valid');
    return SourceSyntaxResult(
      valid: valid,
      message: map['message']?.toString() ?? '语法错误',
      line: int.tryParse(map['line']?.toString() ?? ''),
    );
  }
}
