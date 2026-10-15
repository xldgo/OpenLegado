import 'dart:convert';

import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/data/repositories/mock_backup_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_backup_repository.dart';
import 'package:flutter_legado/src/data/services/mock_webdav_service.dart';
import 'package:flutter_legado/src/data/services/rust_webdav_service.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';
import 'package:flutter_legado/src/providers/backup_provider.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('目录响应在数据边界解码，坏容器拒绝且原非对象项跳过', () {
    expect(decodeWebDavDirectory('[null,{"name":"book.txt","size":1}]'), [
      {'name': 'book.txt', 'size': 1},
    ]);
    expect(() => decodeWebDavDirectory('{}'), throwsFormatException);
    expect(() => decodeWebDavDirectory('['), throwsFormatException);
  });
  test('配置编码保留密码和Rust字段，默认目录补斜线，自定义根目录保持空', () {
    const connection = WebDavConnection(
      url: 'https://dav',
      username: 'u',
      password: ' p ',
      remoteDir: '/books',
    );
    expect(jsonDecode(encodeWebDavConfig(connection)), {
      'url': 'https://dav',
      'username': 'u',
      'password': ' p ',
      'remote_dir': '/books/',
    });
    expect(
      jsonDecode(
        encodeWebDavConfig(const WebDavConnection(remoteDir: '')),
      )['remote_dir'],
      '',
    );
  });
  test('正式与Mock根只装配共享能力，Provider跟随根替换', () {
    final production = createBookApi(useMock: false);
    expect(production.webDavService, isA<RustWebDavService>());
    expect(production.backupRepository, isA<RustBackupRepository>());
    expect(
      identical(production.webDavService, production.webDavService),
      isTrue,
    );
    final first = MockBookApi();
    final second = MockBookApi();
    expect(first.webDavService, isA<MockWebDavService>());
    expect(first.backupRepository, isA<MockBackupRepository>());
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    expect(container.read(webDavServiceProvider), same(first.webDavService));
    expect(
      container.read(backupRepositoryProvider),
      same(first.backupRepository),
    );
    container.updateOverrides([bookApiProvider.overrideWithValue(second)]);
    expect(container.read(webDavServiceProvider), same(second.webDavService));
    expect(
      container.read(backupRepositoryProvider),
      same(second.backupRepository),
    );
  });
}
