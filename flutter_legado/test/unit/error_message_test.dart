library;

/// errorMessage 统一错误文案提取器单元测试
///
/// Rust桥接错误在数据边界转换为AppException。本测锁定领域消息、空消息兜底、
/// 普通异常原样展示及书源登录引导。— Codex + UI

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/domain/errors/app_exception.dart';
import 'package:flutter_legado/src/utils/error_message.dart';
import 'package:flutter_legado/src/utils/source_login_prompt.dart';

void main() {
  group('errorMessage', () {
    test('AppException 提取 message（不再是 Instance of）', () {
      const e = AppException(
        '独立 MCP 服务启动失败：请先在「设置 → 高级 → 其他设置」配置'
        '「Web 书源访问令牌」（config:jsSourceApiToken）',
      );

      final text = errorMessage(e);

      expect(text, contains('MCP 服务启动失败'));
      expect(text, contains('Web 书源访问令牌'));
      expect(text, isNot(contains('Instance of')));
    });

    test('AppException message 为空/全空白 → 兜底文案（不留空文案）', () {
      expect(errorMessage(const AppException('')), kUnknownErrorMessage);
      expect(errorMessage(const AppException('   ')), kUnknownErrorMessage);
    });

    test('非 AppException 异常保持 toString（含类型信息，便于排障）', () {
      expect(errorMessage(StateError('boom')), contains('boom'));
      expect(errorMessage(const FormatException('bad')), contains('bad'));
      expect(errorMessage('plain'), 'plain');
    });

    test('空 message 兜底文案本身非空且不含 Instance of', () {
      expect(kUnknownErrorMessage.trim(), isNotEmpty);
      expect(kUnknownErrorMessage, isNot(contains('Instance of')));
    });
  });

  test('领域错误保留登录识别及非中文提示，普通错误沿用原回退', () {
    for (final message in [
      '书源需要登录，请重试',
      'LoginRequired',
      'login_required',
      '1012',
    ]) {
      final error = AppException(message);
      expect(isSourceLoginRequiredError(error), isTrue);
      expect(sourceLoginRequiredMessage(error), message);
    }
    expect(isSourceLoginRequiredError(null), isFalse);
    expect(isSourceLoginRequiredError(StateError('普通失败')), isFalse);
    expect(isSourceLoginRequiredError(StateError('1012')), isTrue);
    expect(
      sourceLoginRequiredMessage(const AppException(''), fallback: '请登录'),
      '请登录',
    );
    expect(
      sourceLoginRequiredMessage(StateError('普通失败'), fallback: '请登录'),
      '请登录',
    );
  });
}
