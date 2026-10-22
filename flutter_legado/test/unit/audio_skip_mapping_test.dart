import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';
import 'package:flutter_legado/src/models/book.dart';

void main() {
  test('书籍配置经JSON及DTO往返保留全局跳过作用域', () {
    final original = Book(
      bookUrl: 'audio-book',
      readConfig: const ReadConfig(
        useGlobalAudioSkip: true,
        openCredits: 0,
        closeCredits: 0,
      ),
    );
    final restored = bookFromDto(bookToDto(Book.fromJson(original.toJson())));
    expect(restored.readConfig, original.readConfig);
  });
}
