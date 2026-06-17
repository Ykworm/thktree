import 'package:flutter/cupertino.dart';
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
              tooltip: '粗体',
              onPressed: () => _wrapSelection('**', '**', '粗体'),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_italic,
              tooltip: '斜体',
              onPressed: () => _wrapSelection('_', '_', '斜体'),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_strikethrough,
              tooltip: '删除线',
              onPressed: () => _wrapSelection('~~', '~~', '删除线'),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_textformat_size,
              tooltip: '标题',
              onPressed: _toggleHeading,
            ),
            const _Divider(),
            _ToolbarButton(
              icon: SFIcons.sf_list_bullet,
              tooltip: '无序列表',
              onPressed: () => _insertAtLineStart('- ', ''),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_list_number,
              tooltip: '有序列表',
              onPressed: () => _insertAtLineStart('1. ', ''),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_checklist_unchecked,
              tooltip: '复选框',
              onPressed: () => _insertAtLineStart('- [ ] ', ''),
            ),
            const _Divider(),
            _ToolbarButton(
              icon: SFIcons.sf_curlybraces,
              tooltip: '代码',
              onPressed: () => _wrapSelection('`', '`', 'code'),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_quote_closing,
              tooltip: '引用',
              onPressed: () => _insertAtLineStart('> ', ''),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_link,
              tooltip: '链接',
              onPressed: () => _wrapSelection('[', '](url)', '链接文字'),
            ),
            _ToolbarButton(
              icon: SFIcons.sf_ruler,
              tooltip: '分隔线',
              onPressed: () => _insertText('\n---\n'),
            ),
            const _Divider(),
            _ToolbarButton(
              icon: SFIcons.sf_tablecells,
              tooltip: '表格',
              onPressed: _insertTable,
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
  void _insertTable() {
    final table = '\n| 列1 | 列2 | 列3 |\n| --- | --- | --- |\n|  |  |  |\n|  |  |  |\n';
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
