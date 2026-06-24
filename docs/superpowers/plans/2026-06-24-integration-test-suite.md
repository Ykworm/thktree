# 集成测试补充实现计划

&gt; **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 补充项目缺失的集成测试，覆盖核心功能、边界情况、异常场景，确保应用稳定性。

**优先级：**
- **P0（最高）**：搜索模块、LLM 配置、断网场景、并发操作、笔记关联对话
- **P1（次高）**：补全现有测试骨架（chat_streaming、branch_creation TODO、node_reorder、backup_restore）
- **P2（增强）**：边界情况、国际化、主题、性能

**技术栈：** Flutter 3.x / integration_test / Riverpod / Cupertino UI

**前置约束：**
- ThkTree 项目禁用单测（AGENTS.md + flutter-add-widget-test 规则），本计划的"测试"专指集成测试
- LLM 配置已通过 `build/dart_define.json` 注入（`dart run tools/gen_dart_define.dart` 产物）
- 现有测试框架已可用：`integration_test/` 目录 + `_support/` 辅助文件 + `lib/main_test.dart` 入口

---

## 文件结构

| 状态 | 路径 | 职责 |
|---|---|---|
| 新增 | `integration_test/search_test.dart` | 搜索模块集成测试 |
| 新增 | `integration_test/llm_config_test.dart` | LLM 配置集成测试 |
| 新增 | `integration_test/offline_test.dart` | 断网场景集成测试 |
| 新增 | `integration_test/note_chat_link_test.dart` | 笔记关联对话集成测试 |
| 新增 | `integration_test/concurrent_test.dart` | 并发操作集成测试 |
| 修改 | `integration_test/chat_streaming_test.dart` | 补全现有 TODO 测试 |
| 修改 | `integration_test/branch_creation_test.dart` | 补全 3 个 TODO 测试 |
| 修改 | `integration_test/node_reorder_test.dart` | 补全并实现节点重排测试 |
| 修改 | `integration_test/backup_restore_test.dart` | 补全备份恢复测试 |

---

## P0 优先级任务

---

### 任务 1：搜索模块集成测试

**文件：**
- 新增：`integration_test/search_test.dart`
- 参考：`lib/ui/features/search/search_screen.dart`

**测试用例设计：**

#### Test 1.1：搜索有结果
```dart
testWidgets('搜索有结果时正确显示', (tester) async {
  final app = await createTestApp(locale: const Locale('zh'));
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // 1. 创建测试数据
  // - 创建主题 → 创建节点 → 发送包含特定关键词的消息（例如"Flutter"）
  // - 创建笔记 → 包含相同关键词

  // 2. 导航到搜索页面
  // 底部 tab 切换到搜索

  // 3. 输入搜索词
  final searchInput = find.byType(CupertinoSearchTextField);
  await tester.enterText(searchInput, 'Flutter');
  await tester.pump(const Duration(milliseconds: 300)); // debounce

  // 4. 验证结果
  // - 验证消息结果存在
  // - 验证笔记结果存在
  // - 验证主题标题、节点标题正确显示
  // - 验证摘要显示
});
```

#### Test 1.2：搜索无结果
```dart
testWidgets('搜索无结果时正确显示空状态', (tester) async {
  // 类似上面，但搜索不存在的词（如"不存在的关键词12345"）
  // 验证空状态 UI 正确显示
});
```

#### Test 1.3：搜索索引错误修复
```dart
testWidgets('搜索索引错误时显示修复对话框', (tester) async {
  // 模拟搜索索引损坏
  // 输入搜索词
  // 验证错误提示显示
  // 点击"立即修复"
  // 验证修复完成提示
});
```

#### Test 1.4：搜索结果点击跳转
```dart
testWidgets('点击搜索结果正确跳转', (tester) async {
  // 创建测试数据
  // 搜索并找到结果
  // 点击消息结果 → 验证跳转到对应聊天页面
  // 返回 → 点击笔记结果 → 验证跳转到笔记详情
});
```

**验收：**
- [ ] 4 个 testWidgets 全绿
- [ ] 无需真实 LLM（仅测试搜索功能，不测试 LLM 响应）

---

### 任务 2：LLM 配置集成测试

**文件：**
- 新增：`integration_test/llm_config_test.dart`
- 参考：`lib/ui/features/llm/`、`lib/ui/features/settings/`

**测试用例设计：**

#### Test 2.1：配置新 Provider
```dart
testWidgets('配置新 Provider 并保存', (tester) async {
  final app = await createTestApp(locale: const Locale('zh'));
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // 导航到设置页面 → LLM 配置
  // 选择一个 Provider（如 DeepSeek）
  // 输入 API Key
  // 保存
  // 验证配置正确持久化（可通过重新进入页面验证）
});
```

#### Test 2.2：切换默认模型
```dart
testWidgets('切换默认模型并在聊天中生效', (tester) async {
  // 配置好 LLM
  // 切换默认模型
  // 进入聊天 → 发送消息
  // 验证使用了新模型（通过检查 response header 或日志）
});
```

#### Test 2.3：删除 Provider
```dart
testWidgets('删除 Provider 后聊天正确回退', (tester) async {
  // 配置 Provider A → 删除
  // 尝试聊天 → 验证提示配置模型
  // 配置 Provider B → 验证可用
});
```

#### Test 2.4：LLM 未配置时分支创建拦截
```dart
testWidgets('LLM 未配置时分支创建被正确拦截', (tester) async {
  // 不配置 LLM
  // 尝试创建分支（summarize 模式）
  // 验证三层防御拦截：
  // - L1：入口拦截
  // - L2：初始化拦截
  // - L3：弹窗引导到配置页
});
```

**验收：**
- [ ] 4 个 testWidgets 全绿

---

### 任务 3：断网场景集成测试

**文件：**
- 新增：`integration_test/offline_test.dart`
- 参考：`lib/data/services/llm_client.dart`、`lib/ui/features/chat/chat_controller.dart`

**测试用例设计：**

#### Test 3.1：发送消息时断网
```dart
testWidgets('发送消息时断网显示正确错误提示', (tester) async {
  final app = await createTestApp(...);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // 注入 mock LLM client，模拟网络错误（DioException.connectionError）
  // 进入聊天 → 发送消息
  // 验证错误提示正确显示（网络连接中断，请检查后重试）
  // 验证有"重试"按钮
});
```

#### Test 3.2：流式传输中断网
```dart
testWidgets('流式传输中断网显示错误并可重试', (tester) async {
  // mock LLM 在流式中途抛出网络错误
  // 发送消息 → 流式开始 → 断网错误
  // 验证错误提示正确
  // 点击重试 → 验证重新发送成功
});
```

#### Test 3.3：网络恢复后重试
```dart
testWidgets('网络恢复后重试成功', (tester) async {
  // mock 第一次失败，第二次成功
  // 发送 → 失败 → 网络恢复 → 重试 → 成功
});
```

**验收：**
- [x] 3 个 testWidgets 全绿
- [x] 使用 mock LLM client，不真实发网请求

**实现备注（已落地）**：
- 文件：`integration_test/offline_test.dart`
- Mock 方式：override `llmClientProvider` 注入会抛 `DioExceptionType.connectionError` 的 `LlmClient`
- UI 断言：`MessageBubble` 顶部状态行显示 `错误：network`，并出现 `重试` 按钮
- 重试验证：点击 `重试` 后重新发起请求（flaky client 第 2 次返回成功 token）
- 运行命令：`flutter test integration_test/offline_test.dart`（不需要真实 API / 不需要 dart-define）

---

### 任务 4：笔记关联对话集成测试

**文件：**
- 新增：`integration_test/note_chat_link_test.dart`
- 参考：`lib/ui/features/notes/`、`lib/ui/features/chat/`

**测试用例设计：**

#### Test 4.1：从笔记创建对话节点
```dart
testWidgets('从笔记创建对话节点，笔记内容正确注入上下文', (tester) async {
  // 1. 创建笔记（包含特定内容，如"机器学习笔记"）
  // 2. 从笔记创建对话节点
  // 3. 进入聊天 → 验证首条消息是笔记内容或笔记摘要
  // 4. 发送消息 → 验证 LLM 能参考笔记内容回复
});
```

#### Test 4.2：从对话选择位置创建笔记
```dart
testWidgets('从对话树选择位置创建笔记，笔记位置正确关联', (tester) async {
  // 1. 创建主题 → 创建节点 → 聊天
  // 2. 从对话树特定节点位置创建笔记
  // 3. 验证笔记属于该主题
  // 4. 在笔记列表中验证笔记存在
});
```

**验收：**
- [ ] 2 个 testWidgets 全绿

---

### 任务 5：并发操作集成测试

**文件：**
- 新增：`integration_test/concurrent_test.dart`

**测试用例设计：**

#### Test 5.1：快速切换对话
```dart
testWidgets('快速在不同对话间切换，状态正确无竞态', (tester) async {
  // 创建多个节点 → 快速点击切换
  // 验证没有崩溃
  // 验证每个对话的状态正确
});
```

#### Test 5.2：同时多个操作
```dart
testWidgets('同时多个操作无崩溃', (tester) async {
  // 同时（或快速依次）：
  // - 创建主题
  // - 创建笔记
  // - 发送消息
  // 验证无崩溃，操作都完成
});
```

**验收：**
- [ ] 2 个 testWidgets 全绿

---

## P1 优先级任务

---

### 任务 6：补全 chat_streaming_test.dart

**文件：**
- 修改：`integration_test/chat_streaming_test.dart`

**现有 TODO：**
1. 发送消息并等待流式回复
2. 发送空消息
3. 快速连续发送消息

**实现要点：**
- 复用 `_support/test_helpers.dart` 的 `enterTextAndWait`、`waitForWidget`
- 使用 `ValueKey('chat_input')`、`ValueKey('send_button')`、`ValueKey('stop_button')`

**验收：**
- [ ] 3 个 testWidgets 全绿

---

### 任务 7：补全 branch_creation_test.dart 的 3 个 TODO

**文件：**
- 修改：`integration_test/branch_creation_test.dart`

**现有 TODO（line 606-650）：**
1. 模式选择取消
2. 标题选择取消
3. LLM 失败 fallback

**实现要点：**
- 模式选择取消：点击分支 → 选择模式 → 点击取消 → 验证返回
- 标题选择取消：进入标题页面 → 点击取消 → 验证返回
- LLM 失败 fallback：mock LLM 失败 → 验证 fallback 路径

**验收：**
- [ ] 3 个 TODO testWidgets 全绿

---

### 任务 8：补全 node_reorder_test.dart

**文件：**
- 修改：`integration_test/node_reorder_test.dart`
- 参考：`lib/ui/features/themes/theme_detail_screen.dart`（DragTarget、_DragHandle）

**现有 TODO：**
1. 同层节点拖拽重排序
2. 跨层拖拽应被禁止
3. 拖拽后刷新保持顺序

**实现要点：**
- 验证 `ValueKey('drag_handle_${nodeId}')` 确实存在
- 使用 `tester.longPress` + `tester.drag` 模拟拖拽
- 验证 `onWillAcceptWithDetails` 正确禁止跨层

**验收：**
- [ ] 3 个 testWidgets 全绿

---

### 任务 9：补全 backup_restore_test.dart

**文件：**
- 修改：`integration_test/backup_restore_test.dart`

**现有 TODO（4 个空 testWidgets）：**
1. 完整备份和恢复往返测试
2. 备份文件格式验证
3. 恢复冲突处理测试
4. 恢复覆盖模式测试

**实现前准备：**
- 先确认备份/恢复功能 UI 入口（设置页面）
- 确认备份文件格式、位置

**验收：**
- [ ] 4 个 testWidgets 全绿

---

## P2 优先级任务（可选，后续迭代）

---

### 任务 10：边界情况测试

**文件：**
- 新增：`integration_test/edge_cases_test.dart`

**测试用例：**
- 数据损坏恢复
- 存储空间满
- 大量数据（100+ 主题/节点/笔记）性能
- 应用重启后状态恢复

---

### 任务 11：国际化测试

**文件：**
- 新增：`integration_test/i18n_test.dart`

**测试用例：**
- 切换中文/英文 → UI 正确渲染
- RTL 语言（如阿拉伯语）布局正确（如支持）

---

### 任务 12：主题相关测试

**文件：**
- 新增：`integration_test/theme_crud_test.dart`

**测试用例：**
- 主题完整生命周期：创建 → 重命名 → 编辑 → 删除
- 主题固定/取消固定
- 主题列表排序

---

## 验收总览

| 层级 | 方式 | 目标 |
|------|------|------|
| P0 | 集成测试 | 5 个新测试文件（search/llm_config/offline/note_chat_link/concurrent）全绿 |
| P1 | 集成测试 | 4 个现有测试文件补全后全绿 |
| 静态检查 | `dart analyze` | 无新增 error/warning |

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 部分 UI 缺少 ValueKey | 先检查现有代码，缺少的先补上 ValueKey |
| mock LLM client 复杂 | 参考 `chat_async_recovery_test.dart` 的 `_NoopLlmClient` 模式 |
| 备份/恢复功能不明确 | 先确认功能 UI 和逻辑，再写测试 |

---

## 涉及文件汇总

**新增**（9 个）：
- `integration_test/search_test.dart`
- `integration_test/llm_config_test.dart`
- `integration_test/offline_test.dart`
- `integration_test/note_chat_link_test.dart`
- `integration_test/concurrent_test.dart`
- `integration_test/edge_cases_test.dart`（可选）
- `integration_test/i18n_test.dart`（可选）
- `integration_test/theme_crud_test.dart`（可选）
- `docs/superpowers/plans/2026-06-24-integration-test-suite.md`（本文件）

**修改**（4 个）：
- `integration_test/chat_streaming_test.dart`
- `integration_test/branch_creation_test.dart`
- `integration_test/node_reorder_test.dart`
- `integration_test/backup_restore_test.dart`

**worktree：**
```bash
git worktree add ../ThkTree-worktrees/integration-test-suite -b codex/integration-test-suite
```

---

## 引用

- 集成测试总论：`docs/_shared/integration-testing/README.md`
- 现有测试示例：`integration_test/theme_chat_e2e_test.dart`、`integration_test/note_crud_test.dart`
- mock LLM 示例：`integration_test/chat_async_recovery_test.dart`
