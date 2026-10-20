import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_legado/src/data/services/file_directory_service.dart';
import 'package:flutter_legado/src/features/files/presentation/file_manage_screen.dart';

class _Paths extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      'C:${Platform.pathSeparator}root';
}

class _Directories extends FileDirectoryService {
  int reads = 0;
  final delayed = Completer<List<FileEntrySnapshot>>();
  @override
  Future<List<FileEntrySnapshot>> load(Directory directory) async {
    reads++;
    if (directory.path.endsWith('child')) return delayed.future;
    return [
      FileEntrySnapshot(
        path: 'C:${Platform.pathSeparator}root${Platform.pathSeparator}child',
        type: FileSystemEntityType.directory,
      ),
      FileEntrySnapshot(
        path:
            'C:${Platform.pathSeparator}root${Platform.pathSeparator}book.txt',
        type: FileSystemEntityType.file,
        size: 10,
      ),
    ];
  }
}

void main() {
  testWidgets('目录旧结果不覆盖返回后的根目录，重建不重复读取', (tester) async {
    final old = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths();
    addTearDown(() => PathProviderPlatform.instance = old);
    final service = _Directories();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fileDirectoryServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: FileManageScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('book.txt'), findsOneWidget);
    expect(find.text('10 B'), findsOneWidget);
    await tester.pump();
    expect(service.reads, 1);
    await tester.tap(find.text('child'));
    await tester.pump();
    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();
    service.delayed.complete([
      const FileEntrySnapshot(
        path: '/root/child/old.txt',
        type: FileSystemEntityType.file,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('old.txt'), findsNothing);
    expect(find.text('book.txt'), findsOneWidget);
    expect(service.reads, 3);
  });
}
