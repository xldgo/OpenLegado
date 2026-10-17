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
    return (await bridge.sourceList()).map(bookSourceFromDto).toList();
  }

  /// 获取所有启用的书源
  @override
  Future<List<BookSource>> getEnabledBookSources() async {
    return (await bridge.sourceListEnabled()).map(bookSourceFromDto).toList();
  }

  /// 添加书源
  @override
  Future<BookSource> addBookSource(BookSource source) async {
    final value = await bridge.sourceAdd(source: bookSourceToDto(source));
    _onSourcesChanged();
    return bookSourceFromDto(value);
  }

  /// 更新书源
  @override
  Future<void> updateBookSource(BookSource source) async {
    await bridge.sourceUpdate(source: bookSourceToDto(source));
    _onSourcesChanged();
  }

  /// 设置书源自定义变量（契约 §2.3，台账 §5.11-3，Task #65）
  ///
  /// 直通 set_source_variable FFI（单列 UPDATE，空串=清除）；
  /// 书源不存在/写入失败由 Rust 侧抛 BridgeError — Qoder
  @override
  Future<void> setSourceVariable(String sourceUrl, String variable) async {
    await bridge.setSourceVariable(sourceUrl: sourceUrl, variable: variable);
    _onSourcesChanged();
  }

  /// 删除书源
  @override
  Future<void> deleteBookSource(String sourceUrl) async {
    await bridge.sourceDelete(sourceUrl: sourceUrl);
    _onSourcesChanged();
  }

  /// 启用书源
  @override
  Future<void> enableBookSource(String sourceUrl) async {
    await bridge.sourceEnable(sourceUrl: sourceUrl);
    _onSourcesChanged();
  }

  /// 禁用书源
  @override
  Future<void> disableBookSource(String sourceUrl) async {
    await bridge.sourceDisable(sourceUrl: sourceUrl);
    _onSourcesChanged();
  }

  /// 批量导入书源，返回成功导入的数量
  @override
  Future<int> importBookSources(String jsonArray) async {
    final count = await bridge.sourceImport(jsonArray: jsonArray);
    _onSourcesChanged();
    return count;
  }

  /// 导出所有书源为 JSON 数组
  @override
  Future<String> exportBookSources() => bridge.sourceExport();

  /// 书源排序（将排序偏好存入配置）
  @override
  Future<void> sortBookSources(int sortKey, bool ascending) async {
    await bridge.configSet(key: 'source_sort_key', value: sortKey.toString());
    await bridge.configSet(
      key: 'source_sort_ascending',
      value: ascending.toString(),
    );
  }
}
