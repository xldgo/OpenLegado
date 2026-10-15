// mock_book_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 MockBookApiContentExt mixin：音频播放模式。
// MockBookApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 内存存储字段来自 MockBookApiStore（on 约束），同一 library 内私有成员可直接访问。
part of 'mock_book_api.dart';

mixin MockBookApiContentExt on MockBookApiStore implements BookApi {
  // ========== 音频播放模式 ==========

  @override
  Future<String> audioWithPlayMode({
    String? readConfig,
    required int playMode,
  }) async {
    final config = readConfig != null && readConfig.isNotEmpty
        ? (jsonDecode(readConfig) as Map<String, dynamic>)
        : <String, dynamic>{};
    // 键名对齐 Rust `with_audio_play_mode` 与 ReadConfig.playMode
    config['playMode'] = playMode;
    return jsonEncode(config);
  }

  @override
  Future<Map<String, dynamic>?> audioResolvePlayBook({
    String? requestedBookUrl,
    String? cachedBookJson,
  }) async {
    if (requestedBookUrl == null || requestedBookUrl.isEmpty) {
      if (cachedBookJson != null && cachedBookJson.isNotEmpty) {
        return jsonDecode(cachedBookJson) as Map<String, dynamic>;
      }
      return null;
    }
    final book = await bookshelfRepository.getBook(requestedBookUrl);
    return book?.toJson();
  }
}
