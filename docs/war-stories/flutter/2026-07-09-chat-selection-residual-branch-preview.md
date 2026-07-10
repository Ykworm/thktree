# 复制 / 选区文本在「创建分支」预览里残留（选区工具栏分支 + 选区消费即清除）

**日期**：2026-07-09  
**模块**：chat / 创建分支（选区预览）  
**标签**：Flutter, SelectionArea, Riverpod 3.0, NotifierProvider, 选区残留, 分支, contextMenuBuilder

## 现象

在 chat 里选中一段文字 → 点「复制」（或「放入抽屉」）→ 之后点「更多 → 分支」或选区工具栏，
「选择创建方式」sheet（`showBranchModeSheet`）里仍预览着那段**已经不处于选中态**的文本。

用户的预期（原话）：
> 本来选择的 text，当然在这时候点击创建分支是能看到预览，但是当选择状态消失时候，这个预览就应该是空的。

即：**预览 = 活跃选区**。选区活跃时点击分支能看到预览；选区状态消失后，预览应为空。

## 根因分析

### 1. `currentSelectionProvider` 故意"保留上次有效选区"（双刃剑）

`selection_state.dart` 里 `currentSelectionProvider` 的约定是：只在有真实选区时更新，
**收到空选区不清空**（保留上次有效选区）。这是为了支持"选中 → 分享为图片"等
选区收起后仍要用的场景（见 [`2026-07-08-nested-selectionarea-branch-preview.md`](2026-07-08-nested-selectionarea-branch-preview.md)）。

副作用：复制 / 放入抽屉「消费」了选区后，全局选区状态没被清，
后续分支流程读到的还是旧文本 → 表现为"残留"。

### 2. 原「更多 → 分支」从全局残留状态读预览

`_onCreateBranchFromMenu` 读 `ref.read(currentSelectionProvider)` 作为预览源，
拿到的是残留值（哪怕选区早已收起）。

### 3. 第一版思路对、架构错

第一反应"复制那行清掉选区就好"——方向对（消费即清），
但**分支架构**应该"从活跃选区即时触发"，而不是"从全局残留状态读"。
否则：复制后仍可能残留、且选区收起后也无法可靠拿到文本。

## 解决方案

### 1. 新增 `branchFromSelectionProvider`（选区工具栏分支的回调持有者）

`selection_state.dart`：

```dart
/// 从「活跃选区」直接分支的回调持有者。
/// 由 chat_screen 挂载时写入（指向其 _branchFromSelection），卸载时清空。
/// 选区工具栏「分支」按钮读取它，从活跃选区即时分支，
/// 不经过 currentSelectionProvider 的残留值。
final branchFromSelectionProvider =
    NotifierProvider<BranchFromSelectionNotifier, void Function(String)?>(
  BranchFromSelectionNotifier.new,
);

class BranchFromSelectionNotifier extends Notifier<void Function(String)?> {
  @override
  void Function(String)? build() => null;
}
```

- chat_screen 挂载时注册 `_branchFromSelection` 回调，卸载时清空（见下方生命周期注意）。
- 选区工具栏「分支」按钮读它：此刻选区一定还在，直接消费，**不经过残留状态**。
- 用 provider 而非向嵌套 `SelectionArea` 的 `const` 子 widget 透传函数字段
  （消息体 / 推理区 / 表格等子 widget 是 `const` 构造，持有函数字段会破坏 `const`）。

### 2. 选区菜单改为 4 项 + 消费即清除

`clips_context_menu.dart` 的 `buildClipsContextMenu`：复制 / 全选 / **分支** / 放入抽屉。
复制、放入抽屉、分支三个"消费选区"的动作，执行后都 `currentSelectionProvider.notifier.state = null`
清除全局选区状态，避免后续分支流程误用残留：

```dart
ContextMenuButtonItem(
  label: CupertinoLocalizations.of(context).copyButtonLabel,
  onPressed: () {
    Clipboard.setData(ClipboardData(text: selectedText));
    selectableRegionState.hideToolbar();
    // 复制即表示选区已消费，清除全局选区状态
    container.read(currentSelectionProvider.notifier).state = null;
  },
),
if (onBranch != null)
  ContextMenuButtonItem(
    label: '分支',
    onPressed: () {
      selectableRegionState.hideToolbar();
      // 从活跃选区即时分支：此刻选区一定还在，直接消费并清除全局状态
      container.read(currentSelectionProvider.notifier).state = null;
      onBranch(selectedText);
    },
  ),
ContextMenuButtonItem(
  label: '放入抽屉',
  onPressed: () {
    selectableRegionState.hideToolbar();
    container.read(currentSelectionProvider.notifier).state = null;
    _addToClips(context, selectedText);
  },
),
```

### 3. 「更多 → 分支」改传 `selectedText: null`

`_onCreateBranchFromMenu` 不再读全局残留选区：

```dart
Future<void> _onCreateBranchFromMenu(BuildContext context) async {
  final mode = await showBranchModeSheet(context); // 不传 selectedText
  if (mode == null) return;
  if (!context.mounted) return;
  await _showBranchFlow(context, mode: mode, selectedText: null);
}
```

此时活跃选区已随浮层打开而收起，不应再用全局残留选区，故预览为空。

## 关键代码/配置

- `lib/ui/core/shared/selection_state.dart` — `branchFromSelectionProvider` + `BranchFromSelectionNotifier`
- `lib/ui/core/shared/clips_context_menu.dart` — `buildClipsContextMenu` 4 项菜单 + 消费即清除
- `lib/ui/features/chat/chat_screen.dart` —
  - `initState` `addPostFrameCallback` 注册回调 / `dispose` `Future.microtask` 清空（见下方）
  - `_branchFromSelection(context, selectedText)`：选区工具栏分支入口
  - `_onCreateBranchFromMenu(context)`：更多菜单分支入口，`selectedText: null`
  - `_showBranchFlow(context, mode, selectedText)`：构造 parentTranscript + 解析模型 + 调 `showBranchFlow`

## 生命周期注意（联动面包屑崩溃）

注册 / 清空 `branchFromSelectionProvider` **不能在 `initState` / `dispose` 同步写**——
会触发 Riverpod `_debugCanModifyProviders` 断言
（`Tried to modify a provider while the widget tree was building`）。

复用 [`2026-07-09-chat-breadcrumb-nav-crashes.md`](2026-07-09-chat-breadcrumb-nav-crashes.md) 的修法：

```dart
@override
void initState() {
  super.initState();
  _args = ChatControllerParams(nodeId: widget.nodeId, title: widget.title, ...);
  // 读 notifier 引用是安全的（不修改 provider），缓存供 dispose 用
  _branchNotifier = ref.read(branchFromSelectionProvider.notifier);
  // 必须延迟到首帧构建完成后再写 provider
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final cb = (text) => unawaited(_branchFromSelection(context, text));
    _branchCallback = cb;
    _branchNotifier?.state = cb;
  });
}

@override
void dispose() {
  // 不能在 dispose 同步改 provider（finalize 期断言）。延迟到微任务，
  // 并用闭包引用做守卫：只清我们自己设的值，避免误清后挂载聊天页写入的新值。
  final notifier = _branchNotifier;
  final cb = _branchCallback;
  Future.microtask(() {
    if (notifier?.state == cb) notifier?.state = null;
  });
  super.dispose();
}
```

> "缓存 notifier 引用避免 dispose 用 ref"只解决了 `Bad state: using ref after unmount`，
> **没解决** finalize 期改 provider 的断言——断言看"时期"不看"是否用 ref"。真正解法是延迟执行。

## 相关文件

- `lib/ui/core/shared/selection_state.dart`
- `lib/ui/core/shared/clips_context_menu.dart`
- `lib/ui/features/chat/chat_screen.dart`
- （联动）[`2026-07-09-chat-breadcrumb-nav-crashes.md`](2026-07-09-chat-breadcrumb-nav-crashes.md)
- （前置）[`2026-07-08-nested-selectionarea-branch-preview.md`](2026-07-08-nested-selectionarea-branch-preview.md)

## 验收

1. **选区工具栏分支**：选中文本 → 选区工具栏出现「分支」→ 点 → 预览即选中文本、分支正确生成。
2. **复制后不残留**：选中文本 → 复制 → 选区收起 → 点「更多 → 分支」→ 预览为空（不再残留）。
3. **放入抽屉后不残留**：同上，放入抽屉后也不再残留。
4. **重复进出聊天页不崩**：`initState` / `dispose` 的 provider 写入已延迟到帧后 / 微任务。

## 复盘

- **全局选区状态"保留上次"是双刃剑**：对"选中 → 分享为图片"友好，但任何"消费选区"的动作
  （复制 / 分支 / 放入抽屉）都必须显式清除，否则就会在别处作为残留出现。约定：**消费即清**。
- **分支应从「活跃选区」即时触发**（选区工具栏按钮 + provider 回调），而不是从全局残留状态读——
  这样选区和分支解耦，复制后不再影响分支预览。
- **嵌套 SelectionArea + const 子 widget 的坑**：选区捕获在最内层，要把"当前选区"透给外层分支流程，
  不能靠 widget 函数字段（破坏 `const`），用 Riverpod provider。
- **`initState` / `dispose` 写 provider 必须用 `addPostFrameCallback` / `Future.microtask` 移出生命周期回调**
  （与面包屑崩溃同源，同一套修法）。
- **先验证行为再定架构**：第一反应"复制清选区"只是止血；真正的修复是让分支走活跃选区，
  残留问题随之消失——不要只修表象。
