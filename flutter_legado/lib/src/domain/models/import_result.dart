/// 书源导入结果
class ImportResult {
  /// 总数
  final int total;

  /// 成功导入数
  final int success;

  /// 失败数
  final int failed;

  /// 跳过数（重复或无效）
  final int skipped;

  /// 错误信息列表
  final List<String> errors;

  /// 单位名（如「书源」「替换规则」），用于汇总文案
  final String unit;

  const ImportResult({
    required this.total,
    required this.success,
    required this.failed,
    required this.skipped,
    required this.errors,
    this.unit = '书源',
  });

  /// 是否有错误
  bool get hasErrors => errors.isNotEmpty;

  /// 汇总信息
  String get summary {
    final parts = <String>[];
    if (success > 0) parts.add('成功 $success');
    if (failed > 0) parts.add('失败 $failed');
    if (skipped > 0) parts.add('跳过 $skipped');
    return '共 $total 个$unit：${parts.join('，')}';
  }
}
