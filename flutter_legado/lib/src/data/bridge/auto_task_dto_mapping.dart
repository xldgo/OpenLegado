import '../../bridge/automation_dto.dart' as dto;
import '../../models/misc.dart';
import 'business_dto_mapping.dart' show businessI32;

// 完整自动任务逐字段映射，不经传输JSON。— Codex + Bridge
AutoTaskRule autoTaskFromDto(dto.AutoTaskRuleDto v) => AutoTaskRule(
  id: v.id,
  name: v.name,
  enable: v.enable,
  cron: v.cron,
  loginUrl: v.loginUrl,
  loginUi: v.loginUi,
  loginCheckJs: v.loginCheckJs,
  comment: v.comment,
  script: v.script,
  header: v.header,
  jsLib: v.jsLib,
  concurrentRate: v.concurrentRate,
  enabledCookieJar: v.enabledCookieJar,
  customOrder: v.customOrder,
  lastRunAt: v.lastRunAt,
  lastResult: v.lastResult,
  lastError: v.lastError,
  lastLog: v.lastLog,
);
dto.AutoTaskRuleDto autoTaskToDto(AutoTaskRule v) => dto.AutoTaskRuleDto(
  id: v.id,
  name: v.name,
  enable: v.enable,
  cron: v.cron,
  loginUrl: v.loginUrl,
  loginUi: v.loginUi,
  loginCheckJs: v.loginCheckJs,
  comment: v.comment,
  script: v.script,
  header: v.header,
  jsLib: v.jsLib,
  concurrentRate: v.concurrentRate,
  enabledCookieJar: v.enabledCookieJar,
  customOrder: businessI32(v.customOrder),
  lastRunAt: v.lastRunAt,
  lastResult: v.lastResult,
  lastError: v.lastError,
  lastLog: v.lastLog,
);
