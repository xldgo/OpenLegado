import 'dart:io';

/// 可见设备名之外加入本安装身份，清理不会触及同名设备或上游包。
final class BackupFilePolicy {
  BackupFilePolicy(String deviceName, String deviceId) {
    var label = deviceName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|.\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    if (label.isEmpty) label = Platform.operatingSystem;
    label = String.fromCharCodes(label.runes.take(32));
    prefix = 'openlegado_${label}_${deviceId}_';
    _owned = RegExp(
      '^openlegado_.+_${RegExp.escape(deviceId)}_[0-9]+\\.zip'
      r'$',
    );
  }
  late final String prefix;
  String name(DateTime time) => '$prefix${time.microsecondsSinceEpoch}.zip';
  late final RegExp _owned;
  bool owns(String name) => _owned.hasMatch(name);
  static int timestamp(String name) =>
      int.tryParse(
        RegExp(r'_([0-9]+)\.zip$').firstMatch(name)?.group(1) ?? '',
      ) ??
      0;
  static String scope(String url, String username, String directory) =>
      [url, username, directory].map(Uri.encodeComponent).join('|');
}
