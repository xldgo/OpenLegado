import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/services/deep_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('注销后迟到的初始链接不回调旧宿主', () async {
    const channel = MethodChannel('legado/deep_link');
    final initial = Completer<String?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => initial.future);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final service = DeepLinkService.instance;
    await service.detach();
    var imports = 0;
    final attached = service.attach(
      GlobalKey<NavigatorState>(),
      onImport: () => imports++,
    );
    await Future<void>.delayed(Duration.zero);
    await service.detach();
    initial.complete('legado://import/bookSource?src=https://example.com');
    await attached;
    expect(imports, 0);
    expect(service.navigatorKey, isNull);
  });
}
