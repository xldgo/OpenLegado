import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_reader_font_repository.dart';
import 'package:flutter_legado/src/domain/models/reader_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> raw;
  late bool fail;
  late AppReaderFontRepository repository;
  setUp(() {
    raw = [];
    fail = false;
    repository = AppReaderFontRepository(
      read: () async => List.of(raw),
      write: (next) async {
        if (fail) throw StateError('目录保存失败');
        raw = List.of(next);
      },
    );
  });
  tearDown(() => repository.dispose());

  test('目录按family和相对路径恢复，快照不可修改，字体文件不进入存储', () async {
    raw = ['Custom_宋体|fonts/song.ttf'];
    final fonts = await repository.load();
    expect(fonts.single.family, 'Custom_宋体');
    expect(fonts.single.path, 'fonts/song.ttf');
    expect(fonts.single.label, '宋体');
    expect(() => fonts.clear(), throwsUnsupportedError);
    expect(fonts.single.encode(), raw.single);
  });

  test('重复导入更新同一字体族，不产生重复项；其他字体保持', () async {
    raw = [
      'Custom_A|fonts/a.ttf',
      'Custom_B|fonts/b.ttf',
      'Custom_A|fonts/a.ttf',
    ];
    await repository.add(
      const ReaderFont(family: 'Custom_A', path: 'fonts/a2.ttf'),
    );
    expect(raw, ['Custom_A|fonts/a2.ttf', 'Custom_B|fonts/b.ttf']);
    expect(repository.current, hasLength(2));
  });

  test('目录保存失败不发布未保存字体，后续重试与外部恢复仍可用', () async {
    raw = ['Custom_A|fonts/a.ttf'];
    await repository.load();
    fail = true;
    const font = ReaderFont(family: 'Custom_B', path: 'fonts/b.ttf');
    await expectLater(repository.add(font), throwsStateError);
    expect(repository.current.single.family, 'Custom_A');
    expect(raw, ['Custom_A|fonts/a.ttf']);
    fail = false;
    await repository.add(font);
    expect(repository.current, hasLength(2));
    final observed = <List<ReaderFont>>[];
    final subscription = repository.watch().listen(observed.add);
    addTearDown(subscription.cancel);
    raw = ['Custom_C|fonts/c.ttf'];
    await repository.reload();
    await Future<void>.delayed(Duration.zero);
    expect(observed.last.single.family, 'Custom_C');
  });

  test('真实偏好仍保存StringList，重新装配可恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final actual = AppReaderFontRepository();
    addTearDown(actual.dispose);
    await actual.add(
      const ReaderFont(family: 'Custom_宋', path: 'fonts/song.ttf'),
    );
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        'reader_custom_fonts',
      ),
      ['Custom_宋|fonts/song.ttf'],
    );
    final reopened = AppReaderFontRepository();
    addTearDown(reopened.dispose);
    expect((await reopened.load()).single, actual.current.single);
  });
}
