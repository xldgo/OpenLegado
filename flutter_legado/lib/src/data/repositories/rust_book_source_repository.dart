import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_source_repository.dart';
import '../../models/book_source.dart';
import '../bridge/entity_dto_mapping.dart';

/// 直接复用现有 FRB；变更后通知由装配点提供。— Codex + Bridge
final class RustBookSourceRepository implements BookSourceRepository {
  const RustBookSourceRepository({required this._onSourcesChanged});
  final void Function() _onSourcesChanged;

  /// 获取所有书源
  @override
  Future<List<BookSource>> getBookSources() async {
    return (await rustFuture(
      () => bridge.sourceList(),
      operation: 'sourceList',
    )).map(bookSourceFromDto).toList();
  }

  /// 获取所有启用的书源
  @override
  Future<List<BookSource>> getEnabledBookSources() async {
    return (await rustFuture(
      () => bridge.sourceListEnabled(),
      operation: 'sourceListEnabled',
    )).map(bookSourceFromDto).toList();
  }

  /// 添加书源
  @override
  Future<BookSource> addBookSource(BookSource source) async {
    final value = await rustFuture(
      () => bridge.sourceAdd(source: bookSourceToDto(source)),
      operation: 'sourceAdd',
    );
    _onSourcesChanged();
    return bookSourceFromDto(value);
  }

  /// 更新书源
  @override
  Future<void> updateBookSource(BookSource source) async {
    await rustFuture(
      () => bridge.sourceUpdate(source: bookSourceToDto(source)),
      operation: 'sourceUpdate',
    );
    _onSourcesChanged();
  }

  /// 设置书源自定义变量（契约 §2.3，台账 §5.11-3，Task #65）
  ///
  /// 直通 set_source_variable FFI（单列 UPDATE，空串=清除）；
  /// 书源不存在/写入失败由 Rust 侧抛 BridgeError — Qoder
  @override
  Future<void> setSourceVariable(String sourceUrl, String variable) async {
    await rustFuture(
      () => bridge.setSourceVariable(sourceUrl: sourceUrl, variable: variable),
      operation: 'setSourceVariable',
    );
    _onSourcesChanged();
  }

  /// 删除书源
  @override
  Future<void> deleteBookSource(String sourceUrl) async {
    await rustFuture(
      () => bridge.sourceDelete(sourceUrl: sourceUrl),
      operation: 'sourceDelete',
    );
    _onSourcesChanged();
  }

  /// 启用书源
  @override
  Future<void> enableBookSource(String sourceUrl) async {
    await rustFuture(
      () => bridge.sourceEnable(sourceUrl: sourceUrl),
      operation: 'sourceEnable',
    );
    _onSourcesChanged();
  }

  /// 禁用书源
  @override
  Future<void> disableBookSource(String sourceUrl) async {
    await rustFuture(
      () => bridge.sourceDisable(sourceUrl: sourceUrl),
      operation: 'sourceDisable',
    );
    _onSourcesChanged();
  }

  /// 批量导入书源，返回成功导入的数量
  @override
  Future<int> importBookSources(String jsonArray) async {
    final count = await rustFuture(
      () => bridge.sourceImport(jsonArray: jsonArray),
      operation: 'sourceImport',
    );
    _onSourcesChanged();
    return count;
  }

  /// 导出所有书源为 JSON 数组
  @override
  Future<String> exportBookSources() =>
      rustFuture(() => bridge.sourceExport(), operation: 'sourceExport');

  /// 书源排序（将排序偏好存入配置）
  @override
  Future<void> sortBookSources(int sortKey, bool ascending) async {
    await rustFuture(
      () => bridge.configSet(key: 'source_sort_key', value: sortKey.toString()),
      operation: 'configSet',
    );
    await rustFuture(
      () => bridge.configSet(
        key: 'source_sort_ascending',
        value: ascending.toString(),
      ),
      operation: 'configSet',
    );
  }
}
