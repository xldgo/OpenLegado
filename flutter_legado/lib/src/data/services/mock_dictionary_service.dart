import '../../domain/contracts/dictionary_service.dart';
import '../../models/misc.dart' show DictEntry;

/// 无网络Mock查询，保留原静态示例数据。— Codex + Bridge
final class MockDictionaryService implements DictionaryService {
  const MockDictionaryService();

  /// 内置 Mock 词典（占位数据，字段对齐 Rust `DictEntry`）
  static const _mockDict = <String, Map<String, dynamic>>{
    'chapter': {
      'word': 'chapter',
      'phonetic': '/ˈtʃæptə(r)/',
      'definitions': ['n. 章，章节', 'n. （人生的）一段时期'],
    },
    'novel': {
      'word': 'novel',
      'phonetic': '/ˈnɒvl/',
      'definitions': ['n. 长篇小说', 'adj. 新奇的，异常的'],
    },
    'library': {
      'word': 'library',
      'phonetic': '/ˈlaɪbrəri/',
      'definitions': ['n. 图书馆，藏书室', 'n. 文库，（软件）库'],
    },
  };

  @override
  Future<DictEntry> dictLookup(String word) async {
    // 模拟查询延迟
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final key = word.trim().toLowerCase();
    final hit = _mockDict[key];
    if (hit != null) return DictEntry.fromJson(hit);
    // 未收录词：返回空 definitions（非异常，对齐契约）
    return DictEntry(word: key);
  }
}
