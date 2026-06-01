import 'package:flutter/services.dart';

class HapticService {
  /// 选中项目时（如列表选中、tab 切换）
  static void selection() => HapticFeedback.selectionClick();

  /// 确认操作（如保存成功）
  static void lightImpact() => HapticFeedback.lightImpact();

  /// 重要操作（如删除）
  static void mediumImpact() => HapticFeedback.mediumImpact();

  /// 错误/警告
  static void notification() => HapticFeedback.heavyImpact();
}
