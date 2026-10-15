import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/dictionary_service.dart';
import '../../models/misc.dart' show DictEntry;
import '../bridge/rust_json_decode.dart';

/// 类型化现有查询响应，坏结果不作为未收录。— Codex + Bridge
final class RustDictionaryService implements DictionaryService {
  const RustDictionaryService();

  @override
  Future<DictEntry> dictLookup(String word) async {
    final json = decodeRustJsonMap(
      await bridge.dictLookup(word: word),
      'dictLookup',
    );
    final definitions = json['definitions'];
    if (json['word'] is! String ||
        json['phonetic'] is! String ||
        definitions is! List ||
        definitions.any((item) => item is! String)) {
      throw const FormatException('词典查询响应字段类型无效');
    }
    return DictEntry.fromJson(json);
  }
}
