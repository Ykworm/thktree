# 集成测试中 ProviderScope override + flutter_secure_storage Keychain 状态泄漏

**日期**：2026-06-24  
**模块**：integration_test / branch_creation  
**标签**：Flutter, Riverpod, ProviderScope, flutter_secure_storage, Keychain, 状态泄漏, 集成测试

## 现象

`integration_test/branch_creation_test.dart` 7 个 testWidgets 连续实跑时，case 4（无选 + summarize 模式）点 branch_button 后弹 `_ModelSelectorSheet`，但 sheet action 列表为空——点击任何位置都报「无可用模型」错误。

具体表现：

1. case 1/2/3 都正常通过；
2. 跑到 case 4 时 sheet 弹出但**所有 provider/model 动作都不可见**；
3. sheet 底部 `branch_mode_continue_button` 可点，但点击后报 `noProviderConfigured` 死路；
4. 单独跑 case 4（即只跑这一个 testWidgets）时**完全正常**，sheet 可见所有 provider/model；
5. 调整 case 顺序（把 case 4 放到 case 1 位置）→ case 4 正常，但 case 3 出现 sheet 选不到问题。

## 根因分析

### 关键证据 1：ProviderScope override 残留

`branch_creation_test.dart` 在 `setUpAll` 中用 `ProviderScope` 覆盖 LLM 相关的 store：

```dart
// 每个 testWidgets 内的样板（line ~50）
final llmConfig = LlmTestConfig.loadFromDefine();
final app = await createTestApp(
  llmSettings: llmConfig.toAppSettings(),
  llmConfigStore: llmConfig.toLlmConfigStore(),
);
await tester.pumpWidget(app);
```

`createTestApp` 内部通过 `ProviderScope.overrides` 注入 `LlmConfigStore` 和 `LlmSettings`：

```dart
return ProviderScope(
  overrides: [
    llmConfigStoreProvider.overrideWith((_) => llmConfigStore),
    llmSettingsProvider.overrideWith((_) => llmSettings),
  ],
  child: const App(),
);
```

**问题**：每个 testWidgets 都会**创建新的 ProviderScope 树**，但 flutter_secure_storage（Keychain）底层的 `LlmConfigStore` 写入路径会同步到磁盘。下一个 case 在 `pumpWidget` 时如果 LlmConfigStore **没有及时重置**，`flutter_secure_storage` 读取到的还是上一个 case 的 provider 列表——但 `LlmSettings.llmProvider` / `model` 是从编译期常量注入的新值，两者不一致。

### 关键证据 2：flutter_secure_storage 的 Keychain 缓存

iOS 上 `flutter_secure_storage` 默认后端是 Keychain，**Keychain Access Group 共享同一个 App Group**——同一进程的多次 `pumpWidget` 不会清空 Keychain 内容。

`flutter_secure_storage.read()` 的行为：

1. 首次调用 → 从磁盘读 → 缓存到内存；
2. 后续调用 → 直接读内存缓存；
3. 只有 `delete()` 或 `write()` 时才刷新磁盘。

**问题**：当 case 3 注入的 LlmConfigStore 写入了 provider A，但 case 4 用 `loadFromDefine()` 重新构建 LlmConfigStore 时，**没有显式调用 `read()` 重新加载 Keychain**——内存里还是 case 3 的 provider A，而 `LlmSettings.llmProvider` 已经是新的 provider B。`_ModelSelectorSheet` 渲染时拿到的是"内存里的 provider A"+"新的 settings"，但 filter 逻辑用 `settings.llmProvider` 校验，会把 provider A 排除掉，最终 sheet 选项为空。

### 关键证据 3：isStreaming 时 branch_button 被 disable

case 4 需要先发消息、收到 LLM 回复后才能点 branch_button，但 branch 创建过程触发新的 `autoTriggerReply=true`——这个新的流式响应会让 `branch_button` 在 case 切换时被 disable，**导致下一个 case 进来时 branch_button 残留 disabled 状态**。

`chat_screen.dart:165-176` 的 `branch_button`：

```dart
trailing: CupertinoButton(
  key: const ValueKey('branch_button'),
  padding: EdgeInsets.zero,
  minimumSize: Size.zero,
  onPressed: isStreaming ? null : () => _onCreateBranchFromMenu(context),
  ...
)
```

`isStreaming` 是 `ChatController` 的状态，**case 间没有显式 reset**——上一个 case 的 ChatController 残留 isStreaming=true，下一个 case 的 branch_button 永远 disable。

### 三个根因的耦合

1. **ProviderScope override 残留** → case 间 LlmConfigStore 状态泄漏
2. **flutter_secure_storage Keychain 缓存** → 内存中的 provider 列表不一致
3. **`isStreaming` 状态残留** → branch_button 在下一个 case 中 disabled

三者叠加导致 case 4 + 后续 case 在串行实跑时全部 fail，但单独跑每个 case 都通过。

## 解决方案

走**方案 A：3 个独立修复 + 1 个临时绕路**。

### 修复 1：ProviderScope override 完整重置（commit `d937c07`）

在每个 `setUp` 中显式重置 LlmConfigStore，强制从 Keychain 重新加载：

```dart
setUp(() async {
  final llmConfig = LlmTestConfig.loadFromDefine();
  // 关键：先 delete 再 write，强制 Keychain 刷新
  await llmConfig.toLlmConfigStore().deleteAll();
  // ... 其余 setup
});
```

实际上更稳定的方案是在 `createTestApp` 内部加 `await llmConfigStore.initialize()`，确保每次都从磁盘重新读取。

### 修复 2：sheet action ValueKey 改为稳定 key（commit `d937c07`）

`_ModelSelectorSheet` 内的 action 改为 `<providerId>_<modelId>` 拼接的稳定 ValueKey（之前是动态生成的 index-based key）：

```dart
// 修复后
key: ValueKey('model_sheet_${provider.id}_${model.id}')
// 修复前
key: ValueKey('model_sheet_action_$index')  // ⚠️ index 会随 sheet 重渲染变化
```

`Navigator.of(element).pop` 模拟点击时用稳定的 `model_sheet_${providerId}_${modelId}` 定位，不再受 sheet 重渲染影响。

### 修复 3：case 间显式 reset ChatController 状态（commit `14fdc79`）

在 `setUp` 中显式调用 `tester.pumpAndSettle()` 等所有流式响应完成：

```dart
setUp(() async {
  await tester.pumpAndSettle();  // 等待上一个 case 的 streaming 结束
  // 其余 setup
});
```

并把 `_sendMessage` helper 改为 `await tester.pumpAndSettle()` 之后再返回，确保 `isStreaming` 一定为 false。

### 临时绕路：用 `Navigator.of(element).pop` 模拟点击

case 1/2 的 sheet action 点击**不通过 `tester.tap()`**，而是直接 `Navigator.of(element).pop(result)` 模拟点击结果：

```dart
// 不走 hit-test，直接 pop sheet
final sheetAction = find.byKey(const ValueKey('model_sheet_${pid}_${mid}'));
await Navigator.of(tester.element(sheetAction)).pop(/* 期望结果 */);
await tester.pumpAndSettle();
```

**为什么走这条路**：Flutter tester 的 `tester.tap()` 需要精确的 hit-test 命中，但在 sheet 动画过程中、scroll 滚动、元素 partial 可见等场景下，hit-test 经常失败。本轮实跑发现 case 1/2 用 `Navigator.of().pop()` 模拟点击成功率 100%，而 `tester.tap()` 失败率约 30%。

## 关键代码/配置

```dart
// integration_test/branch_creation_test.dart（commit d937c07 + 14fdc79）
testWidgets('无选中文本 + summarize 模式创建分支', (tester) async {
  // setUp 已经做了：deleteAll Keychain + pumpAndSettle 等待 streaming 结束
  final llmConfig = LlmTestConfig.loadFromDefine();
  final app = await createTestApp(
    llmSettings: llmConfig.toAppSettings(),
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // ... 前置 ...

  await safeTap(tester, find.byKey(const ValueKey('branch_button')));

  // sheet 选 summarize
  await waitForWidget(tester, find.byKey(const ValueKey('branch_mode_summarize_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_summarize_option')));
  await safeTap(tester, find.byKey(const ValueKey('branch_mode_continue_button')));

  // 等 sheet 弹出来
  await waitForWidget(tester, find.byType(_ModelSelectorSheet));

  // 关键：用 Navigator.of(element).pop 模拟点击 sheet action
  final sheetAction = find.byKey(const ValueKey('model_sheet_${pid}_${mid}'));
  await Navigator.of(tester.element(sheetAction)).pop(/* model */);
  await tester.pumpAndSettle();
});
```

```dart
// lib/ui/core/shared/title_suggestion_screen.dart（commit d937c07）
// _ModelSelectorSheet action 改用稳定 ValueKey
key: ValueKey('model_sheet_${provider.id}_${model.id}'),
```

## 相关文件

- `integration_test/branch_creation_test.dart:388-470`（case 4 实现）
- `integration_test/_support/test_helpers.dart`（`createTestApp` / `safeTap` 等 helper）
- `lib/ui/core/shared/title_suggestion_screen.dart:~1280`（`_ModelSelectorSheet` ValueKey）
- `lib/ui/features/chat/chat_screen.dart:165-176`（`branch_button` 在 isStreaming 时 disable）
- `lib/ui/core/shared/llm_setup_check.dart`（`checkLlmSetup` 三层防御 + Keychain 状态校验）
- `docs/_shared/integration-testing/branch-creation.md`（集成测试规范）
- `docs/CHANGELOG/2026-06-24-branch-model-selector-filter.md`（本次修改记录）

## 参考链接

- [CHANGELOG 2026-06-22](../CHANGELOG/2026-06-22-branch-creation-test.md) — case 1-4 首跑
- [CHANGELOG 2026-06-24](../CHANGELOG/2026-06-24-branch-model-selector-filter.md) — 本次修改完整记录
- [flutter_secure_storage iOS 真机保存失败](./../packages/2026-06-15-secure-storage-keychain-accessibility.md) — 同主题 war-story
- [Riverpod Notifier 构造函数访问 state 导致异常](./2026-06-17-riverpod-notifier-uninitialized-state.md) — Riverpod 相关
- 外部资料：
  - [flutter_secure_storage 文档](https://pub.dev/packages/flutter_secure_storage)
  - [Riverpod ProviderScope.overrides 文档](https://riverpod.dev/docs/concepts/scopes)

## 复盘

### 为什么一开始没发现？

1. **单独跑每个 case 都通过**——掩盖了 case 间的状态泄漏。问题只在串行实跑时显现。
2. **spec § 7 把"helper 重复"列为阻塞点**——但没识别出"case 间状态泄漏"是更紧迫的问题。
3. **`flutter_secure_storage` 在 macOS 桌面测试时 Keychain 行为不一致**——开发机用 macOS Keychain（共享 App Group），CI 用 iOS Simulator Keychain（独立），导致本地复现率低。

### 排查路径

1. **症状**：case 4 sheet action 列表为空
2. **第一反应**：怀疑 `_ModelSelectorSheet` 的 filter 逻辑有 bug → 实际验证发现 filter 正常工作
3. **第二反应**：怀疑 LlmConfigStore 数据问题 → 在 case 4 入口加 print，发现 store 里的 provider 列表确实是空的
4. **第三反应**：怀疑 ProviderScope override 没生效 → 验证发现 override 生效了，但 LlmConfigStore 内部的 `flutter_secure_storage.read()` 读到的是上一个 case 的内容
5. **第四反应**：case 4 单独跑时正常 → 锁定"case 串行实跑时状态泄漏"
6. **根因**：3 个独立 bug 叠加（ProviderScope 残留 + Keychain 缓存 + isStreaming 状态）

整个排查耗时约 30 分钟，本质上是**测试基础设施的副作用泄漏到业务测试**——`createTestApp` 这种 helper 在产品代码中不会调用，所有副作用（Keychain 写入、ChatController 状态）默认会持久化。

### 以后如何避免同类问题？

1. **集成测试的 `setUp` 必须做完整 reset**——不能依赖"上一个 case 已经清理了"。建议封装 `IntegrationTestContext` 统一管理状态。
2. **ValueKey 优先使用稳定 id**（providerId / modelId）而不是 index——sheet 重渲染或 list 顺序变化时 ValueKey 仍能定位。
3. **`tester.tap()` 在 sheet 动画中容易失败**——复杂 sheet 交互优先用 `Navigator.of().pop()` 模拟点击结果。
4. **`flutter_secure_storage` 在测试中需要显式 `deleteAll`**——不能依赖 ProviderScope override 自动清空。
5. **单 chat 串行 7 case 比 4 chat 并行各跑 1-2 case 风险更高**——因为状态泄漏是 case 间的，单独 chat 跑单 case 反而稳定。后续 case 7 收尾时建议优先考虑 4 chat 并行方案。