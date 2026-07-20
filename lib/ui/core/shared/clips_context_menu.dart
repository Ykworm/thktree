import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show AdaptiveTextSelectionToolbar;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/shared/selection_state.dart';

/// 构建带"放入抽屉"与"分支"的选区右键菜单。
///
/// 在原有"复制""全选"基础上追加：
/// - "放入抽屉"：把选中文本存入 [clipStorageProvider]。
/// - "分支"：当 [branchFromSelectionProvider] 已注册回调时显示，点击后从
///   **活跃选区**即时分支（选区工具栏弹出时选区一定还在，直接消费，不经过
///   [currentSelectionProvider] 的残留值）。
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
  final onBranch = container.read(branchFromSelectionProvider);

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
          // 复制即表示选区已消费，清除全局选区状态，
          // 避免之后从「更多 → 分支」误把这段文本当成"当前选中文本"残留。
          container.read(currentSelectionProvider.notifier).state = null;
        },
      ),
      ContextMenuButtonItem(
        label: CupertinoLocalizations.of(context).selectAllButtonLabel,
        onPressed: () {
          selectableRegionState.selectAll(SelectionChangedCause.toolbar);
        },
      ),
      if (onBranch != null)
        ContextMenuButtonItem(
          label: AppLocalizations.of(context)!.clipsBranch,
          onPressed: () {
            selectableRegionState.hideToolbar();
            // 从活跃选区即时分支：此刻选区一定还在，直接消费并清除全局状态。
            container.read(currentSelectionProvider.notifier).state = null;
            onBranch(selectedText);
          },
        ),
      ContextMenuButtonItem(
        label: AppLocalizations.of(context)!.clipsSaveToDrawer,
        onPressed: () {
          selectableRegionState.hideToolbar();
          // 同理：选区已消费，清除全局选区状态，防止后续分支流程误用残留。
          container.read(currentSelectionProvider.notifier).state = null;
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
