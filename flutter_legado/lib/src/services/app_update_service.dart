import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/pref_keys.dart';

/// CI与客户端共用附件格式，渠道由Release标签及prerelease标志确定。
enum AppUpdateTarget {
  androidArm64('android-arm64-v8a.apk'),
  androidArmv7('android-armeabi-v7a.apk'),
  androidX64('android-x86_64.apk'),
  windowsX64('windows-x64.zip');

  const AppUpdateTarget(this.assetSuffix);
  final String assetSuffix;
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.tagName,
    required this.version,
    required this.buildNumber,
    required this.isPrerelease,
    required this.updateLog,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.fileName,
  });

  final String tagName;
  final String version;
  final int buildNumber;
  final bool isPrerelease;
  final String updateLog;
  final String downloadUrl;
  final String releaseUrl;
  final String fileName;
}

/// 项目自身的分发更新；不涉及阅读业务或FFI。
class AppUpdateService {
  AppUpdateService({http.Client? client})
    : _ownsClient = client == null,
      _client = client ?? http.Client();

  static const projectUrl = 'https://github.com/xldgo/OpenLegado';
  static const releasesUrl =
      'https://api.github.com/repos/xldgo/OpenLegado/releases?per_page=100';
  static const buildChannel = String.fromEnvironment(
    'OPENLEGADO_CHANNEL',
    defaultValue: 'development',
  );
  static PackageInfo? _cachedPackage;
  final http.Client _client;
  final bool _ownsClient;

  static Future<PackageInfo> resolveCurrentPackage() async =>
      _cachedPackage ??= await PackageInfo.fromPlatform();

  static Future<String> resolveCurrentVersionName() async {
    final version = (await resolveCurrentPackage()).version.trim();
    if (version.isEmpty) throw StateError('无法读取应用版本号');
    return version;
  }

  Future<bool> acceptsPrereleases() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefKeys.acceptPrereleaseUpdates) ??
        (buildChannel != 'stable');
  }

  Future<void> setAcceptsPrereleases(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(PrefKeys.acceptPrereleaseUpdates, enabled)) {
      throw StateError('测试版更新设置保存失败');
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  static Future<AppUpdateTarget> resolveTarget() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
      // 按设备声明的优先顺序选择，模拟器不能误选ARM翻译包。
      for (final abi in abis) {
        switch (abi) {
          case 'arm64-v8a':
            return AppUpdateTarget.androidArm64;
          case 'armeabi-v7a':
            return AppUpdateTarget.androidArmv7;
          case 'x86_64':
            return AppUpdateTarget.androidX64;
        }
      }
      throw UnsupportedError('尚无适用于当前Android架构的安装包');
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return AppUpdateTarget.windowsX64;
    }
    throw UnsupportedError('当前平台请通过项目发布页检查更新');
  }

  Stream<Map<String, dynamic>> _releases(String version) async* {
    Uri? next = Uri.parse(releasesUrl);
    while (next != null) {
      final response = await _client
          .get(
            next,
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'OpenLegado/$version',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw StateError('获取发布信息失败（HTTP ${response.statusCode}）');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) throw const FormatException('发布信息不是列表');
      for (final release in decoded) {
        if (release is Map<String, dynamic>) yield release;
      }
      // Alpha较多时正式版可能位于下一页，不能只查第一页后报告无正式版。
      final link = RegExp(r'<([^>]+)>;\s*rel="next"')
          .firstMatch(response.headers['link'] ?? '');
      next = link == null ? null : Uri.parse(link.group(1)!);
    }
  }

  /// 无更新返回null；缺少当前平台包及网络/响应错误分别明确报告。
  Future<AppUpdateInfo?> check({
    String? currentVersion,
    int? currentBuildNumber,
    bool? includePrereleases,
    AppUpdateTarget? target,
  }) async {
    final package = currentVersion == null || currentBuildNumber == null
        ? await resolveCurrentPackage()
        : null;
    final version = currentVersion ?? package!.version;
    final build = currentBuildNumber ?? int.parse(package!.buildNumber);
    final selectedTarget = target ?? await resolveTarget();
    final includeAlpha = includePrereleases ?? await acceptsPrereleases();
    AppUpdateInfo? selected;
    var hasProjectRelease = false;
    var hasPlatformAsset = false;
    await for (final release in _releases(version)) {
      if (release['draft'] == true) continue;
      final tag = release['tag_name'];
      if (tag is! String) continue;
      final metadata = RegExp(r'^v(\d+\.\d+\.\d+)(?:-alpha\.(\d+))?$')
          .firstMatch(tag);
      if (metadata == null) continue;
      final alpha = metadata.group(2) != null;
      if (release['prerelease'] != alpha || (alpha && !includeAlpha)) continue;
      hasProjectRelease = true;
      final assets = release['assets'];
      if (assets is! List) continue;
      for (final asset in assets) {
        if (asset is! Map<String, dynamic> || asset['state'] != 'uploaded') {
          continue;
        }
        final name = asset['name'];
        if (name is! String) continue;
        final artifact = RegExp(r'^OpenLegado-(\d+\.\d+\.\d+)\+(\d+)-(.+)$')
            .firstMatch(name);
        if (artifact == null ||
            artifact.group(1) != metadata.group(1) ||
            artifact.group(3) != selectedTarget.assetSuffix) {
          continue;
        }
        final candidateBuild = int.parse(artifact.group(2)!);
        if (alpha && candidateBuild != int.parse(metadata.group(2)!)) continue;
        final downloadUrl = asset['browser_download_url'];
        final releaseUrl = release['html_url'];
        if (downloadUrl is! String || releaseUrl is! String) continue;
        hasPlatformAsset = true;
        final candidateVersion = artifact.group(1)!;
        final comparison = compareReleaseVersions(candidateVersion, version);
        if (comparison < 0 || candidateBuild <= build) {
          continue;
        }
        if (selected != null) {
          final order = compareReleaseVersions(
            candidateVersion,
            selected.version,
          );
          if (order < 0 ||
              (order == 0 && candidateBuild <= selected.buildNumber)) {
            continue;
          }
        }
        selected = AppUpdateInfo(
          tagName: tag,
          version: candidateVersion,
          buildNumber: candidateBuild,
          isPrerelease: alpha,
          updateLog: release['body'] as String? ?? '',
          downloadUrl: downloadUrl,
          releaseUrl: releaseUrl,
          fileName: name,
        );
      }
    }
    if (hasProjectRelease && !hasPlatformAsset) {
      throw StateError('尚无当前平台/架构的发布包，请查看项目发布页');
    }
    // 项目尚未发布正式版时，不将“无正式版”误报为“当前最新版”。
    if (!hasProjectRelease) {
      throw StateError(includeAlpha ? '暂无可用的项目发布版本' : '暂无正式版，可开启接收测试版更新');
    }
    return selected;
  }
}

int compareReleaseVersions(String left, String right) {
  final a = left.split('.').map(int.parse).toList();
  final b = right.split('.').map(int.parse).toList();
  for (var index = 0; index < 3; index++) {
    final order = a[index].compareTo(b[index]);
    if (order != 0) return order;
  }
  return 0;
}
