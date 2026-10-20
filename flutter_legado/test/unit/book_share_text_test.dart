import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/utils/share_utils.dart';

void main() {
  group('buildBookShareText 分享文案拼接', () {
    test('包含书名、作者、来源', () {
      const book = Book(
        name: '斗破苍穹',
        author: '天蚕土豆',
        bookUrl: 'https://www.example.com/book/1',
      );
      final text = buildBookShareText(book);
      expect(text, contains('《斗破苍穹》'));
      expect(text, contains('作者：天蚕土豆'));
      expect(text, contains('来源：https://www.example.com/book/1'));
    });

    test('作者为空时不包含作者字段', () {
      const book = Book(
        name: '未知书籍',
        author: '',
        bookUrl: 'https://www.example.com/book/2',
      );
      final text = buildBookShareText(book);
      expect(text, contains('《未知书籍》'));
      expect(text, isNot(contains('作者：')));
      expect(text, contains('来源：https://www.example.com/book/2'));
    });

    test('bookUrl 为空时不包含来源字段', () {
      const book = Book(name: '本地书籍', author: '某作者', bookUrl: '');
      final text = buildBookShareText(book);
      expect(text, contains('《本地书籍》'));
      expect(text, contains('作者：某作者'));
      expect(text, isNot(contains('来源：')));
    });

    test('作者和 bookUrl 均为空时仅包含书名', () {
      const book = Book(name: '纯书名', author: '', bookUrl: '');
      final text = buildBookShareText(book);
      expect(text, '《纯书名》');
    });

    test('完整文案格式符合预期', () {
      const book = Book(
        name: '遮天',
        author: '辰东',
        bookUrl: 'https://book.qidian.com/info/123',
      );
      final text = buildBookShareText(book);
      expect(text, '《遮天》 作者：辰东\n来源：https://book.qidian.com/info/123');
    });
  });
}
