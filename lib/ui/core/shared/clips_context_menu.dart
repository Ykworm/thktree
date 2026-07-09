import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show AdaptiveTextSelectionToolbar;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/shared/selection_state.dart';

/// 构建带"放入抽屉"的选区右键菜单。
///
/// 在原有"复制""全选"基础上追加"放入抽屉"按钮，点击后把选中文本
/// 存入 [clipStorageProvider]。
///
/// 使用方式：在 `SelectionArea.contextMenuBuilder` 中调用：
/// ```dart
/// SelectionArea(
///   contextMenuBuilder: (context, selectableRegionState) =>
///       buildClipsContextMenu(context, selectableRegionState),
///   ...
/// )
/// ```
///
/// **选中文本来源**：从 [currentSelectionProvider] 读取，该 provider
/// 由各 SelectionArea 的 `onSelectionChanged` → `syncSelection()` 实时同步。
/// 当选区为空（光标定位）时回退到默认菜单。
Widget buildClipsContextMenu(
  BuildContext context,
  SelectableRegionState selectableRegionState,
) {
  final container = ProviderScope.containerOf(context);
  final selectedText = container.read(currentSelectionProvider);

  // 无有效选区 → 回退到默认菜单（光标定位场景）
  if (selectedText == null || selectedText.trim().isEmpty) {
    return AdaptiveTextSelectionToolbar.selectableRegion(
      selectableRegionState: selectableRegionState,
    );
  }

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: selectableRegionState.contextMenuAnchors,
    buttonItems: [
      ContextMenuButtonItem(
        label: CupertinoLocalizations.of(context).copyButtonLabel,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: selectedText));
          selectableRegionState.hideToolbar();
        },
      ),
      ContextMenuButtonItem(
        label: CupertinoLocalizations.of(context).selectAllButtonLabel,
        onPressed: () {
          selectableRegionState.selectAll(SelectionChangedCause.toolbar);
        },
      ),
      ContextMenuButtonItem(
        label: '放入抽屉',
        onPressed: () {
          selectableRegionState.hideToolbar();
          _addToClips(context, selectedText);
        },
      ),
    ],
  );
}

Future<void> _addToClips(BuildContext context, String text) async {
  final container = ProviderScope.containerOf(context);
  final storage = await container.read(clipStorageProvider.future);
  await storage.add(text);
  await HapticFeedback.lightImpact();
}
