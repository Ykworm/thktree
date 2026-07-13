import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show SelectableText, SelectionArea;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:gpt_markdown/custom_widgets/selectable_adapter.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:thk_tree/ui/core/shared/clips_context_menu.dart';
import 'package:thk_tree/ui/core/shared/link_launcher.dart';
import 'package:thk_tree/ui/core/shared/selection_state.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// Markdown 渲染相关的 builder 集合，集中放在这个文件以便复用和测试。

/// 单元格文本中的 HTML 换行标签，统一替换为真实换行。
final _htmlBreakPattern = RegExp(r'<br\s*/?>', caseSensitive: false);

/// LaTeX 渲染 builder：在 gpt_markdown 默认实现（Math.tex + SelectableAdapter）
/// 外面包一层 FittedBox(scaleDown)，让含大符号（\frac/\sum/\int）的公式超宽时
/// 等比缩放避开 flutter_math_fork 0.7.4 的 RenderLine 宽度计算溢出。
Widget buildLatex(
  BuildContext context,
  String tex,
  TextStyle textStyle,
  bool inline,
) {
  final rendered = SelectableAdapter(
    selectedText: tex,
    child: Math.tex(
      tex,
      textStyle: textStyle,
      mathStyle: MathStyle.display,
      textScaleFactor: 1,
      settings: const TexParserSettings(strict: Strict.ignore),
      options: MathOptions(
        sizeUnderTextStyle: MathSize.large,
        color: textStyle.color ?? AppColors.textPrimary,
        fontSize: textStyle.fontSize,
        mathFontOptions: FontOptions(
          fontFamily: 'Main',
          fontWeight: textStyle.fontWeight ?? FontWeight.normal,
          fontShape: FontStyle.normal,
        ),
        textFontOptions: FontOptions(
          fontFamily: 'Main',
          fontWeight: textStyle.fontWeight ?? FontWeight.normal,
          fontShape: FontStyle.normal,
        ),
        style: MathStyle.display,
      ),
      onErrorFallback: (err) {
        return Text(
          tex,
          textDirection: TextDirection.ltr,
          style: textStyle,
        );
      },
    ),
  );

  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: rendered,
  );
}

/// 标记 LatexBuilder 签名（防止以后 gpt_markdown 升级时类型签名变化导致静默断链）。
// ignore: unused_element
LatexBuilder _ensureSignature = buildLatex;

/// 代码块 builder（非交互）：淡灰底 + 边框，在白色聊天气泡与白色分享卡片上都清晰可见。
///
/// 之前聊天界面用 `AppColors.surface`（白）作底、分享卡片未传 codeBuilder 而回退到
/// gpt_markdown 默认 `CodeField`（`Theme.onInverseSurface` = 亮色下深色块），导致分享图里
/// 代码块变成不可见的暗色矩形。这里统一用 [AppColors.markdownCodeBg] + [AppColors.border]。
Widget buildCodeBlock(
  BuildContext context,
  String name,
  String code,
  bool closed,
) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.markdownCodeBg,
      border: Border.all(color: AppColors.border, width: 1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: SelectableText(
      code,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
      ),
    ),
  );
}

/// 非交互表格视图：用于分享卡片截图（offscreen）与全屏展开。
///
/// 复用设计 token（border / surfaceMuted / textPrimary），不依赖 gpt_markdown 默认暗色渲染，
/// 因此在亮色主题下表格边框清晰、表头有淡底，不会变成不可见色块。
class MarkdownTableView extends StatelessWidget {
  const MarkdownTableView({
    super.key,
    required this.tableRows,
    required this.textStyle,
    this.expanded = false,
  });

  final List<CustomTableRow> tableRows;
  final TextStyle textStyle;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final columnCount = tableRows.fold<int>(
      0,
      (maxColumns, row) => math.max(maxColumns, row.fields.length),
    );
    if (columnCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = MediaQuery.of(context).size.width - 48;
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : fallbackWidth;
        final columnWidth = resolveTableColumnWidth(
          availableWidth: availableWidth,
          columnCount: columnCount,
          expanded: expanded,
        );

        final table = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(
              color: AppColors.border,
              width: 1,
            ),
            defaultColumnWidth: FixedColumnWidth(columnWidth),
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: tableRows.map((row) {
              return TableRow(
                decoration: row.isHeader
                    ? BoxDecoration(color: AppColors.surfaceMuted)
                    : null,
                children: row.fields.map((cell) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: GptMarkdown(
                      normalizeTableCellText(cell.data),
                      style: row.isHeader
                          ? textStyle.copyWith(fontWeight: FontWeight.w600)
                          : textStyle,
                      textAlign: cell.alignment,
                      onLinkTap: (url, _) => openMarkdownLink(context, url),
                      latexBuilder: buildLatex,
                      useDollarSignsForLatex: true,
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        );

        // Android 不包 SelectionArea（无文本选择菜单）；其余平台支持选择。
        return defaultTargetPlatform == TargetPlatform.android
            ? table
            : SelectionArea(
                onSelectionChanged: (v) => syncSelection(context, v),
                contextMenuBuilder: (context, editableTextState) =>
                    buildClipsContextMenu(context, editableTextState),
                child: table,
              );
      },
    );
  }
}

double resolveTableColumnWidth({
  required double availableWidth,
  required int columnCount,
  required bool expanded,
}) {
  const cellHorizontalPadding = 16.0;
  final minColumnWidth = expanded ? 180.0 : 120.0;
  final maxColumnWidth = expanded ? 420.0 : 280.0;
  final usableWidth = math.max(
    minColumnWidth,
    availableWidth - (columnCount * cellHorizontalPadding),
  );
  final targetWidth = usableWidth / columnCount;
  return targetWidth.clamp(minColumnWidth, maxColumnWidth).toDouble();
}

String normalizeTableCellText(String value) {
  return value.replaceAll(_htmlBreakPattern, '\n').trim();
}
