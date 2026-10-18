import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/dictionary_service.dart';
import '../../models/misc.dart' show DictEntry;
import '../bridge/business_dto_mapping.dart';

/// 类型化现有查询响应，坏结果不作为未收录。— Codex + Bridge
final class RustDictionaryService implements DictionaryService {
  const RustDictionaryService();

  @override
  Future<DictEntry> dictLookup(String word) async {
    return dictEntryFromDto(
      await rustFuture(
        () => bridge.dictLookup(word: word),
        operation: 'dictLookup',
      ),
    );
  }
}
