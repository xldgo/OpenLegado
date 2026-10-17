import 'package:flutter_legado/src/bridge/file_dto.dart';
import 'package:flutter_legado/src/data/bridge/file_dto_mapping.dart';
import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import 'dart:convert';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_backup_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_backup_repository.dart';
import 'package:flutter_legado/src/data/services/mock_webdav_service.dart';
import 'package:flutter_legado/src/data/services/rust_webdav_service.dart';
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';
import 'package:flutter_legado/src/providers/backup_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('目录元数据逐字段映射，精确大小与空值保留', () {
    expect(
      webDavFileFromDto(
        WebDavFileDto(
          name: 'book.txt',
          path: '/book.txt',
          size: BigInt.from(9007199254740993),
          isDir: false,
        ),
      ),
      {
        'name': 'book.txt',
        'path': '/book.txt',
        'size': 9007199254740993,
        'last_modified': null,
        'etag': null,
        'is_dir': false,
      },
    );
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
    final production = createTestApplication(useMock: false);
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
      overrides: mergeTestOverrides([
        webDavServiceProvider.overrideWithValue(first.webDavService),
        backupRepositoryProvider.overrideWithValue(first.backupRepository),
      ]),
    );
    addTearDown(container.dispose);
    expect(container.read(webDavServiceProvider), same(first.webDavService));
    expect(
      container.read(backupRepositoryProvider),
      same(first.backupRepository),
    );
    container.updateOverrides(
      mergeTestOverrides([
        webDavServiceProvider.overrideWithValue(second.webDavService),
        backupRepositoryProvider.overrideWithValue(second.backupRepository),
      ]),
    );
    expect(container.read(webDavServiceProvider), same(second.webDavService));
    expect(
      container.read(backupRepositoryProvider),
      same(second.backupRepository),
    );
  });
}
