import '../../bridge/task_dto.dart' as dto;
import '../../domain/models/cache_download_task.dart';
import '../../domain/models/verification_request.dart';
import '../../domain/models/webview_request.dart';

// 事件字段只在数据边界映射，业务键与正文协议保持原值。— Codex + Bridge
CacheDownloadTask cacheTaskFromDto(dto.CacheDownloadTaskDto v) =>
    CacheDownloadTask(
      taskId: v.taskId.toInt(),
      bookUrl: v.bookUrl,
      status: v.status.name,
      total: v.total,
      completed: v.completed,
      failed: v.failed,
    );
VerificationRequest verificationFromDto(dto.VerificationRequestDto v) {
  if (v.key.isEmpty) throw const FormatException('通道请求缺少有效key');
  return VerificationRequest(
    key: v.key,
    sourceUrl: v.sourceUrl,
    sourceName: v.sourceName,
    imageUrl: v.imageUrl,
    title: v.title,
    useBrowser: v.useBrowser,
    createdAtMs: v.createdAtMs.toInt(),
  );
}

WebViewRequest webViewFromDto(dto.WebViewRequestDto v) {
  if (v.key.isEmpty) throw const FormatException('通道请求缺少有效key');
  return WebViewRequest(
    key: v.key,
    action: v.action,
    html: v.html,
    url: v.url,
    js: v.js,
    sourceRegex: v.sourceRegex,
    overrideUrlRegex: v.overrideUrlRegex,
    cacheFirst: v.cacheFirst,
    delayTime: v.delayTime,
    isRule: v.isRule,
    result: v.result,
    sourceKey: v.sourceKey,
    cookie: v.cookie,
    createdAtMs: v.createdAtMs.toInt(),
  );
}

BigInt downloadTaskId(int value) {
  if (value < 0) throw RangeError.value(value, 'taskId', '任务编号不能为负数');
  return BigInt.from(value);
}

int chapterIndex32(int value) {
  if (value < -2147483648 || value > 2147483647) {
    throw RangeError.value(value, 'chapterIndex');
  }
  return value;
}
