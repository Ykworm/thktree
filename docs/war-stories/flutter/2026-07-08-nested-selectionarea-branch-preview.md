# 嵌套 SelectionArea 导致外层 onSelectionChanged 收不到选区（分支预览文字消失）

**日期**：2026-07-08  
**模块**：chat / 创建分支（选区预览）  
**标签**：Flutter, SelectionArea, 嵌套选择容器, riverpod 3.0, StateProvider 移除, GptMarkdown, 选区捕获

## 现象

chat 页选中一段文字 → 点「更多」→「分支」，弹出的「选择创建方式」sheet（`showBranchModeSheet`）
本应预览选中的文本，但实际没有。

调试日志：
```
flutter: [ChatScreen] _onCreateBranchFromMenu: selectedText=null chars
```
即进入分支流程时，「选中文本」字段是 null，sheet 里的预览框（`if (hasSelectionPreview)`）整个跳过。

## 根因分析

### 1. 嵌套 SelectionArea（核心根因）

- `chat_screen.dart` 在消息列表外层包了一个 `SelectionArea`（~419 行）。
- `message_bubble.dart` 里**每条消息自己又包了一个 `SelectionArea`**（586 / 777 / 993 三处）。
  原因是 `GptMarkdown` 自身渲染的富文本不可选，必须靠内层 `SelectionArea` 才能让文字被选中。
- 这是**嵌套选择容器**。Flutter 的 `SelectionArea` 内部是 `SelectionContainer`，嵌套时
  **外层 `onSelectionChanged` 收不到子选区的变化**——选区完全发生在某条消息的内层容器里，
  外层永远感知不到。

所以外层 `onSelectionChanged` 在用户选消息文本时**根本不回调**，
分支入口读 `_currentSelectedText` 时它从未被赋值（一直初始 null）。

### 2. 前两轮误诊

- 第一轮以为是「选区收起时 `onSelectionChanged(null)` 把字段清空」→ 改成"收到 null 不清空"。
  无效：字段从没被赋值过，无所谓清不清空。
- 第二轮怀疑 Hot Reload 没生效 → 让用户 Hot Restart。仍 null：确认是外层收不到选区，不是时序问题。
- 试过用 `contextMenuBuilder` 双保险，但 Flutter 3.44 的 `SelectableRegionState`
  **没有** `selectedContent` / `getSelectedContent()`（那只是内部 `Selectable` delegate 的方法），
  拿不到选区文本，放弃。

### 3. riverpod 3.0 的版本陷阱（顺带踩到）

项目用 `flutter_riverpod: ^3.0.0`，**riverpod 3.0 已移除 `StateProvider`**。
最初想用 `final x = StateProvider(...)` 做共享选区状态，直接报 `undefined_function`。
3.0 里统一改用 `NotifierProvider`（`final x = NotifierProvider<XNotifier, T>(XNotifier.new)`）。

## 解决方案

引入一个共享 provider，让**真正能拿到选区的那一层**（内层 SelectionArea）把文本写进去，
分支流程和「分享为图片」都从它读：

1. 新建 `lib/ui/core/shared/selection_state.dart`：
   - `currentSelectionProvider = NotifierProvider<CurrentSelectionNotifier, String?>(...)`（riverpod 3.0 写法）。
   - 顶层函数 `syncSelection(BuildContext context, dynamic value)`：
     用 `ProviderScope.containerOf(context).read(currentSelectionProvider.notifier).state = text`
     写入，**不依赖某个 State 的 `ref`**，这样 message_bubble 内部表格组件等任意类都能调用。
   - 约定：只在有真实选区时更新；收到空选区**不清空**（保留上次有效选区）。

2. `message_bubble.dart`：
   - 三处内层 `SelectionArea.onSelectionChanged` 改为 `(v) => syncSelection(context, v)`。
   - 移除原局部 `_selectedText` 字段及其 `setState` 逻辑；「分享为图片」改读 `currentSelectionProvider`。

3. `chat_screen.dart`：
   - 分支入口 `_onCreateBranchFromMenu` 读 `ref.read(currentSelectionProvider)`（替代原 `_currentSelectedText`）。
   - 外层 `SelectionArea.onSelectionChanged` 保留写 provider 作兜底（嵌套下实际不回调，无害）。
   - 移除 `_currentSelectedText` 字段。

## 关键代码/配置

```dart
// selection_state.dart（riverpod 3.0 写法）
final currentSelectionProvider =
    NotifierProvider<CurrentSelectionNotifier, String?>(
  CurrentSelectionNotifier.new,
);

class CurrentSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;
}

// 顶层函数，避免依赖某个 State 的 ref
void syncSelection(BuildContext context, dynamic value) {
  final text = value?.plainText as String?;
  if (text != null && text.trim().isNotEmpty) {
    ProviderScope.containerOf(context)
        .read(currentSelectionProvider.notifier)
        .state = text;
  }
}
```

```dart
// message_bubble.dart 三处内层 SelectionArea
SelectionArea(
  onSelectionChanged: (v) => syncSelection(context, v),
  child: GptMarkdown(...),
),
```

```dart
// chat_screen.dart 分支入口
final selected = ref.read(currentSelectionProvider);
debugPrint('[ChatScreen] _onCreateBranchFromMenu: selectedText=${selected?.length ?? 'null'} chars');
```

## 相关文件

- `lib/ui/core/shared/selection_state.dart`（新增）
- `lib/ui/features/chat/chat_screen.dart`
- `lib/ui/core/shared/message_bubble.dart`
- `lib/ui/core/shared/title_suggestion_screen.dart`（`showBranchModeSheet` 的预览框渲染点）

## 参考链接

- Flutter `SelectionArea` / `SelectionContainer` 嵌套行为：framework 内部 `_updateSelectedContentIfNeeded`
  只把选区变化回调到**最近一层** `SelectionContainer` 的 `onSelectionChanged`。
- 选型设计见 `title_suggestion_screen.dart` 的 `showBranchFlow` / `showBranchModeSheet`。

## 复盘

- **为什么一开始没发现**：嵌套 `SelectionArea` 编译不报错、运行也不报错，只是外层收不到选区，
  表现很隐蔽；前两轮都顺着"字段被清空"的直觉排查，没怀疑到嵌套结构本身。
- **以后如何避免同类问题**：
  1. 一个子树只应有一个"管理选区"的 `SelectionArea`。若子 widget 因文本不可选必须自包
     `SelectionArea`（如 GptMarkdown），要意识到外层拿不到其选区，需用共享状态把选区从内层透出来。
  2. 调试选区捕获：直接在 `onSelectionChanged` 打日志确认**是否真的回调**，
     比"猜被清空"快得多——本问题本质是"从不回调"而非"被清空"。
  3. riverpod 升级到 3.0 后，`StateProvider` 已移除，新状态统一用 `NotifierProvider`；
     看到 `undefined_function: StateProvider` 别犹豫，直接改写法。

## 更新日志（2026-07-09）

本文记录的"选区捕获透出"方案保留，但**分支入口的消费侧行为已演进**，避免残留文本：

- **「更多 → 分支」不再读全局残留选区**：原"解决方案 #3"写的 `_onCreateBranchFromMenu` 读
  `ref.read(currentSelectionProvider)` 已改为 `selectedText: null`。原因见
  [`2026-07-09-chat-selection-residual-branch-preview.md`](2026-07-09-chat-selection-residual-branch-preview.md)——
  `currentSelectionProvider` 故意"保留上次有效选区"以支持"选中 → 分享为图片"，
  但复制 / 放入抽屉消费选区后不清，会导致分支预览残留用户已取消的选区。
- **新增「选区工具栏分支」按钮**：选区菜单追加「分支」项，读取新增的
  `branchFromSelectionProvider`（chat_screen 挂载时注册 `_branchFromSelection` 回调），
  从**活跃选区**即时分支，不经过残留状态。
- **消费即清**：复制 / 放入抽屉 / 分支三个消费选区的动作执行后都 `currentSelectionProvider.notifier.state = null`。
- 选区菜单现为 4 项：复制 / 全选 / 分支 / 放入抽屉（`buildClipsContextMenu`）。
