import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/data/services/book_source_export_service.dart';

import '../mocks/mocks.dart';

void main() {
  late MockRustApi mockApi;
  late BookSourceExportService service;
  setUpAll(registerFallbacks);
  setUp(() {
    mockApi = MockRustApi();
    service = BookSourceExportService(mockApi.bookSourceRepository);
  });
  group('BookSourceExportService exportSelectedSources', () {
    test('导出选中的书源', () async {
      when(() => mockApi.bookSourceRepository.getBookSources()).thenAnswer(
        (_) async => [
          const BookSource(
            bookSourceUrl: 'http://s1.com',
            bookSourceName: '源1',
          ),
          const BookSource(
            bookSourceUrl: 'http://s2.com',
            bookSourceName: '源2',
          ),
          const BookSource(
            bookSourceUrl: 'http://s3.com',
            bookSourceName: '源3',
          ),
        ],
      );

      final result = await service.exportSelectedSources([
        'http://s1.com',
        'http://s3.com',
      ]);
      final decoded = jsonDecode(result) as List;

      expect(decoded.length, equals(2));
    });

    test('选中为空时返回空数组', () async {
      when(() => mockApi.bookSourceRepository.getBookSources()).thenAnswer(
        (_) async => [
          const BookSource(
            bookSourceUrl: 'http://s1.com',
            bookSourceName: '源1',
          ),
        ],
      );

      final result = await service.exportSelectedSources([]);
      expect(result, equals('[]'));
    });

    test('选中的 URL 不存在时返回空数组', () async {
      when(() => mockApi.bookSourceRepository.getBookSources()).thenAnswer(
        (_) async => [
          const BookSource(
            bookSourceUrl: 'http://s1.com',
            bookSourceName: '源1',
          ),
        ],
      );

      final result = await service.exportSelectedSources(['http://nope.com']);
      expect(result, equals('[]'));
    });
  });

  group('BookSourceExportService exportAllSourcesFormatted', () {
    test('导出全部书源为格式化 JSON', () async {
      when(() => mockApi.bookSourceRepository.getBookSources()).thenAnswer(
        (_) async => [
          const BookSource(
            bookSourceUrl: 'http://s1.com',
            bookSourceName: '源1',
          ),
        ],
      );

      final result = await service.exportAllSourcesFormatted();

      // 格式化 JSON 包含缩进
      expect(result, contains('  '));
      expect(result, contains('源1'));
    });
  });
}
