import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/errors/app_exception.dart';
import '../../domain/contracts/source_checker.dart';
import '../../models/book_source.dart';
import '../bridge/entity_dto_mapping.dart';
import '../bridge/transport_request_mapping.dart';
import '../bridge/stream_dto_mapping.dart';
import '../bridge/managed_rust_stream.dart';

/// 直接使用现有 FRB；不创建数据库或另一份校验任务。— Codex + Bridge
final class RustSourceChecker implements SourceChecker {
  const RustSourceChecker();

  // ========== 书源校验（Task #87） ==========

  /// 校验单个书源（搜索→详情→目录→正文四步 + 验证码/重定向检测）
  ///
  /// Rust 返回 CheckResultDto，在数据边界映射现有领域字段，见 [SourceChecker.checkSource]。
  @override
  Future<Map<String, dynamic>> checkSource(
    BookSource source, {
    String? configJson,
  }) async {
    final config = () {
      try {
        return sourceCheckConfig(configJson);
      } catch (error, stack) {
        throw AppException(
          '校验配置 JSON 解析失败: $error',
          cause: error,
          sourceStackTrace: stack,
        );
      }
    }();
    return checkResultFromDto(
      await rustFuture(
        () =>
            bridge.sourceCheck(source: bookSourceToDto(source), config: config),
        operation: 'sourceCheck',
      ),
    );
  }

  /// 批量校验书源（串行逐个回推进度）
  ///
  /// 每完成一个书源推送一条进度 Map，字段见 [SourceChecker.checkSourcesStream]。
  @override
  Stream<Map<String, dynamic>> checkSourcesStream(
    List<String> sourceUrls, {
    String? configJson,
  }) {
    return managedRustStream(
      (request) => rustStream(
        () => bridge.sourceCheckStream(
          sourceUrls: sourceUrls,
          config: sourceCheckConfig(configJson, fallbackOnError: true),
          request: request,
        ),
        operation: 'sourceCheckStream',
      ),
    ).map(checkProgressFromDto);
  }

  /// 取消正在进行的批量书源校验
  @override
  Future<void> cancelCheckSources() => rustFuture(
    () => bridge.sourceCheckCancel(),
    operation: 'sourceCheckCancel',
  );
}
