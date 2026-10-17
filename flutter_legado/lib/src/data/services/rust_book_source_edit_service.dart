import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/book_source_edit_service.dart';
import '../../domain/models/source_syntax_result.dart';
import '../../models/book_source.dart';
import '../bridge/entity_dto_mapping.dart';

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
    return bookSourceFromDto(await bridge.jsSourceExtract(content: content))
        .copyWith(mainJs: content);
  }

  @override
  Future<SourceSyntaxResult> checkJsSourceSyntax(String content) async {
    final result = await bridge.jsSourceSyntaxCheck(content: content);
    return SourceSyntaxResult(
      valid: result.valid,
      message: result.message,
      line: result.line,
    );
  }
}
