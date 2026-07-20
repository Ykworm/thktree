import 'package:flutter/cupertino.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

/// Cupertino 风格的 Markdown 格式化工具栏。
///
/// 在选中文本时自动包裹 Markdown 语法；无选中时插入示例文本。
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            _ToolbarButton(
              icon: SFIcons.sf_bold,
              tooltip: l10n.markdownBold,
              onPressed: () => _wrapSelection('**', '**', l10n.markdownBoldPlaceholder),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_italic,
              tooltip: l10n.markdownItalic,
              onPressed: () => _wrapSelection('_', '_', l10n.markdownItalicPlaceholder),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_strikethrough,
              tooltip: l10n.markdownStrikethrough,
              onPressed: () => _wrapSelection('~~', '~~', l10n.markdownStrikethroughPlaceholder),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_textformat_size,
              tooltip: l10n.markdownHeading,
              onPressed: _toggleHeading,
            ),
            const _Divider(),
            _ToolbarButton(
              icon: SFIcons.sf_list_bullet,
              tooltip: l10n.markdownBulletList,
              onPressed: () => _insertAtLineStart('- ', ''),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_list_number,
              tooltip: l10n.markdownNumberedList,
              onPressed: () => _insertAtLineStart('1. ', ''),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_checklist_unchecked,
              tooltip: l10n.markdownCheckbox,
              onPressed: () => _insertAtLineStart('- [ ] ', ''),
            ),
            const _Divider(),
            _ToolbarButton(
              icon: SFIcons.sf_curlybraces,
              tooltip: l10n.markdownCode,
              onPressed: () => _wrapSelection('`', '`', 'code'),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_quote_closing,
              tooltip: l10n.markdownQuote,
              onPressed: () => _insertAtLineStart('> ', ''),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_link,
              tooltip: l10n.markdownLink,
              onPressed: () => _wrapSelection('[', '](url)', l10n.markdownLinkPlaceholder),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_ruler,
              tooltip: l10n.markdownDivider,
              onPressed: () => _insertText('\n---\n'),
            ),
            const _Divider(),
            _ToolbarButton(
              icon: SFIcons.sf_tablecells,
              tooltip: l10n.markdownTable,
              onPressed: () => _insertTable(l10n),
            ),
          ],
        ),
      ),
    );
  }

  /// 标题级别循环切换：无 → h2 → h3 → h1 → 无
  void _toggleHeading() {
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.start : text.length;

    // 找到当前行起止位置
    int lineStart = offset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    int lineEnd = offset;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final line = text.substring(lineStart, lineEnd);

    // 检测当前行的标题前缀
    String newLine;
    if (line.startsWith('### ')) {
      // h3 → h1
      newLine = '# ${line.substring(4)}';
    } else if (line.startsWith('## ')) {
      // h2 → h3
      newLine = '### ${line.substring(3)}';
    } else if (line.startsWith('# ') && !line.startsWith('## ')) {
      // h1 → 取消
      newLine = line.substring(2);
    } else {
      // 无前缀 → h2
      newLine = '## $line';
    }

    final before = text.substring(0, lineStart);
    final after = text.substring(lineEnd);
    controller.text = '$before$newLine$after';
    controller.selection = TextSelection.collapsed(
      offset: lineStart + newLine.length,
    );
  }

  /// 插入 3x3 markdown 表格模板
  void _insertTable(AppLocalizations l10n) {
    final table = '\n| ${l10n.markdownTableHeader1} | ${l10n.markdownTableHeader2} | ${l10n.markdownTableHeader3} |\n| --- | --- | --- |\n|  |  |  |\n|  |  |  |\n';
    _insertText(table);
  }

  /// 在选中文本两侧插入 [left] 和 [right]。
  /// 无选中时插入 [placeholder] 并选中它。
  void _wrapSelection(String left, String right, String placeholder) {
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isValid && !selection.isCollapsed) {
      // 有选中文本：包裹
      final selected = text.substring(selection.start, selection.end);
      final before = text.substring(0, selection.start);
      final after = text.substring(selection.end);
      controller.text = '$before$left$selected$right$after';
      controller.selection = TextSelection(
        baseOffset: selection.start + left.length,
        extentOffset: selection.start + left.length + selected.length,
      );
    } else {
      // 无选中：插入占位符并选中
      final offset = selection.isValid ? selection.start : text.length;
      final before = text.substring(0, offset);
      final after = text.substring(offset);
      controller.text = '$before$left$placeholder$right$after';
      controller.selection = TextSelection(
        baseOffset: offset + left.length,
        extentOffset: offset + left.length + placeholder.length,
      );
    }
  }

  /// 在当前行首插入 [prefix]。
  void _insertAtLineStart(String prefix, String _) {
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.start : text.length;

    // 找到当前行起始位置
    int lineStart = offset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final before = text.substring(0, lineStart);
    final afterLineStart = text.substring(lineStart);
    controller.text = '$before$prefix$afterLineStart';
    controller.selection = TextSelection.collapsed(
      offset: offset + prefix.length,
    );
  }

  /// 在光标位置直接插入文本。
  void _insertText(String insertion) {
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.start : text.length;

    final before = text.substring(0, offset);
    final after = text.substring(offset);
    controller.text = '$before$insertion$after';
    controller.selection = TextSelection.collapsed(
      offset: offset + insertion.length,
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(36, 36),
      onPressed: onPressed,
      child: Icon(icon, size: 18, color: AppColors.textPrimary),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.border,
    );
  }
}
