import '../bridge/rust_errors.dart';
import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/book_source_edit_service.dart';
import '../../domain/models/source_syntax_result.dart';
import '../../models/book_source.dart';
import '../bridge/entity_dto_mapping.dart';

/// 保留原生转换和QuickJS语义，不在Dart复制解析算法。— Codex + Bridge
class RustBookSourceEditService implements BookSourceEditService {
  const RustBookSourceEditService();
  @override
  Future<bool> looksLikeCurl(String text) => rustFuture(
    () => bridge.looksLikeCurl(text: text),
    operation: 'looksLikeCurl',
  );
  @override
  Future<String> curlToAnalyzeUrl(String text) => rustFuture(
    () => bridge.curlToAnalyzeUrl(text: text),
    operation: 'curlToAnalyzeUrl',
  );
  @override
  Future<String> analyzeUrlToCurl(String text) => rustFuture(
    () => bridge.analyzeUrlToCurl(text: text),
    operation: 'analyzeUrlToCurl',
  );
  @override
  Future<BookSource> extractJsSource(String content) async {
    return bookSourceFromDto(
      await rustFuture(
        () => bridge.jsSourceExtract(content: content),
        operation: 'jsSourceExtract',
      ),
    ).copyWith(mainJs: content);
  }

  @override
  Future<SourceSyntaxResult> checkJsSourceSyntax(String content) async {
    final result = await rustFuture(
      () => bridge.jsSourceSyntaxCheck(content: content),
      operation: 'jsSourceSyntaxCheck',
    );
    return SourceSyntaxResult(
      valid: result.valid,
      message: result.message,
      line: result.line,
    );
  }

  /// 契约 SOURCE-PARSE-FFI-20261022：只读解析，直连 Rust 统一实现。
  @override
  Future<BookSource> parseSource(String json) async {
    return bookSourceFromDto(
      await rustFuture(
        () => bridge.sourceParse(sourceJson: json),
        operation: 'sourceParse',
      ),
    );
  }
}
