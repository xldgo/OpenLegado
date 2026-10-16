// mock_book_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件保留章节购买与书源回调；发现及在线查询已由独立服务负责。
// MockBookApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 内存存储字段来自 MockBookApiStore（on 约束），同一 library 内私有成员可直接访问。
part of 'mock_book_api.dart';

mixin MockBookApiDiscoveryCache on MockBookApiStore implements BookApi {
  // ========== 章节购买 ==========

  @override
  Future<({String kind, String value})> chapterPayAction({
    required String bookUrl,
    required int chapterIndex,
  }) async => (kind: 'none', value: '');

  @override
  Future<Map<String, dynamic>> sourceCallBackBtn({
    required String event,
    required String bookUrl,
    int? chapterIndex,
    String? result,
    int bookType = 0,
  }) async => {
    'invoked': false,
    'jsTrue': false,
    'raw': '',
    'actions': <dynamic>[],
  };
}
