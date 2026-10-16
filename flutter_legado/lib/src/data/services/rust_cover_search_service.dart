import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/cover_search_service.dart';
import '../../models/cover_candidate.dart';
import '../bridge/rust_json_decode.dart';

/// 封面JSON在数据层解码，不过滤损坏条目冒充成功。— Codex + Bridge
final class RustCoverSearchService implements CoverSearchService {
  const RustCoverSearchService();
  @override
  Future<List<CoverCandidate>> searchCover(String bookName) async {
    final list = decodeRustJsonList(
      await bridge.searchCover(bookName: bookName),
      'searchCover',
    );
    return list.map((value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('封面候选必须是对象');
      }
      return CoverCandidate.fromJson(value);
    }).toList();
  }

  @override
  Future<List<String>> searchCoverRules(String name) async {
    final list = decodeRustJsonList(
      await bridge.searchCoverRules(name: name),
      'searchCoverRules',
    );
    return list.map((value) {
      if (value is! String) throw const FormatException('封面地址必须是字符串');
      return value;
    }).toList();
  }
}
