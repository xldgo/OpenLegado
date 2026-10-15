import '../../models/misc.dart' show DictEntry;

/// 委托现有Rust词典查询，结果与未命中语义由既有契约决定。— Codex + Bridge
abstract interface class DictionaryService {
  Future<DictEntry> dictLookup(String word);
}
