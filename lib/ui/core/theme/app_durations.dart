// Design System — 动效时长与曲线 token
// 与 docs/_shared/design-tokens.yaml durations 段保持一致
// 修改前请先阅读 docs/_shared/design-system.md

import 'package:flutter/animation.dart';

/// 动效时长与曲线常量。
///
/// 命名规则：场景名 + 类型（如 sheetScroll / copyFeedback）
class AppDur {
  AppDur._();

  // ── Sheet / 浮层 ─────────────────────────────────────────────
  /// Sheet 滑出
  static const sheetScroll = Duration(milliseconds: 200);
  static const sheetScrollCurve = Curves.easeInOut;

  /// Sheet 遮罩淡入
  static const scrimFade = Duration(milliseconds: 120);
  static const scrimFadeCurve = Curves.easeOut;

  // ── Toast / 反馈 ──────────────────────────────────────────────
  /// 复制成功反馈
  static const copyFeedback = Duration(milliseconds: 200);
  static const copyFeedbackCurve = Curves.easeInOut;

  /// 弹层出现
  static const modal = Duration(milliseconds: 250);
  static const modalCurve = Curves.easeOut;

  // ── 流式响应 ──────────────────────────────────────────────────
  /// 流式 indicator 闪烁周期
  static const streamingIndicator = Duration(milliseconds: 2000);

  // ── 列表滚动 ──────────────────────────────────────────────────
  /// 列表 animateTo
  static const listScroll = Duration(milliseconds: 300);
  static const listScrollCurve = Curves.easeOut;

  // ── 骨架屏 ────────────────────────────────────────────────────
  /// 骨架 shimmer 周期
  static const shimmer = Duration(milliseconds: 1500);
  static const shimmerCurve = Curves.easeInOut;
}
