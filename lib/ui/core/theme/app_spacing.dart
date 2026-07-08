// Design System — 间距/圆角/尺寸 token
// 与 docs/_shared/design-tokens.yaml spacing 段保持一致
// 修改前请先阅读 docs/_shared/design-system.md

/// 间距、圆角、尺寸常量。
///
/// 命名规则：
/// - 布局间距：screenPadding / listItemGap
/// - 圆角：xxxRadius（cardRadius / buttonRadius / chatBubbleRadius）
/// - 尺寸比例：xxxHeight / xxxWidth（sheetHeight / chatBubbleMaxWidth）
/// - 量化约束：xxxMin / xxxMax / xxxTolerance
class AppSp {
  AppSp._();

  // ── 布局间距 ──────────────────────────────────────────────────
  static const screenPadding = 16.0;
  static const listItemVerticalPadding = 12.0;
  static const titleToContentGap = 16.0;

  // ── 圆角 ──────────────────────────────────────────────────────
  static const cardRadius = 12.0;
  static const buttonRadius = 10.0;
  static const dragBubbleRadius = 10.0;
  static const chatBubbleRadius = 12.0;
  static const modelPillRadius = 6.0;
  static const sheetTopRadius = 14.0;

  // ── 尺寸（px）─────────────────────────────────────────────────
  static const touchTarget = 44.0;
  static const dragHandle = 52.0;
  static const treeIndent = 28.0;
  static const treeRowHeight = 56.0;
  static const imagePreviewHeight = 80.0;

  // ── 分隔线 ────────────────────────────────────────────────────
  static const dividerThickness = 0.5;

  // ── 比例约束 ──────────────────────────────────────────────────
  /// 消息气泡最大宽度占屏幕比例
  static const chatBubbleMaxWidth = 0.85;

  /// Sheet 高度占屏幕比例
  static const sheetHeightSm = 0.45;
  static const sheetHeightMd = 0.65;
  static const sheetHeightLg = 0.88;

  // ── 输入区 ────────────────────────────────────────────────────
  static const messageInputMinLines = 1;
  static const messageInputMaxLines = 6;

  // ── 滚动容差 ──────────────────────────────────────────────────
  static const bottomTolerance = 24.0;
}
