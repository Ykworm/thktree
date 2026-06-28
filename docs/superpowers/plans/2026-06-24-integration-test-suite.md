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

## 📊 进度总表（一目了然）

| 优先级 | 任务 | 文件 | 状态 |
|--------|------|------|------|
| P0 | 搜索模块集成测试 | `search_test.dart` | ✅ 已完成 |
| P0 | LLM 配置集成测试 | `llm_config_test.dart` | 待做 |
| P0 | 断网场景集成测试 | `offline_test.dart` | ✅ 已完成 |
| P0 | 笔记关联对话集成测试 | `note_chat_link_test.dart` | 待做 |
| P0 | 并发操作集成测试 | `concurrent_test.dart` | 待做 |
| P1 | 补全 chat_streaming_test.dart | `chat_streaming_test.dart` | 🟡 部分完成（TODO占位） |
| P1 | 补全 branch_creation_test.dart | `branch_creation_test.dart` | 🟡 部分完成（前4个已实现） |
| P1 | 补全 node_reorder_test.dart | `node_reorder_test.dart` | 🟡 部分完成（TODO占位） |
| P1 | 补全 backup_restore_test.dart | `backup_restore_test.dart` | 🟡 部分完成（TODO占位） |
| P2 | 边界情况测试 | `edge_cases_test.dart` | 待做 |
| P2 | 国际化测试 | `i18n_test.dart` | 待做 |
| P2 | 主题相关测试 | `theme_crud_test.dart` | 待做 |

> **额外补充的测试文件**（计划外已实现）：
> - `llm_error_retry_test.dart` - LLM 错误重试测试（5个测试 ✅ 已完成）
> - `chat_async_recovery_test.dart` - 聊天异步恢复测试（4个测试 ✅ 已完成）
> - `note_search_test.dart` - 笔记搜索测试（4个测试 ✅ 已完成）
> - `chat_latex_overflow_test.dart` - 聊天 LaTeX 溢出测试
> - `theme_chat_e2e_test.dart` - 主题聊天端到端测试（✅ 已完成）
> - `note_crud_test.dart` - 笔记 CRUD 测试（✅ 已完成）

---

## 🎯 集成测试任务难度排行

| 难度 | 优先级 | 任务 | 状态 | 主要挑战 | 建议顺序 |
|------|--------|------|------|----------|----------|
| ⭐ 简单 | P0 | node_reorder_test.dart - 节点拖拽重排序 | 🟡 部分完成 | ValueKey已存在，只需获取真实nodeId | 1 |
| ⭐ 简单 | P1 | chat_streaming_test.dart - 聊天流式测试 | 🟡 部分完成 | 复用现有helper，补全导航逻辑 | 2 |
| ⭐⭐ 中等 | P1 | branch_creation_test.dart - 补全剩余3个TODO | 🟡 部分完成 | SelectionArea选区模拟、LLM Mock | 3 |
| ⭐⭐⭐ 较难 | P1 | backup_restore_test.dart - 备份恢复测试 | 🟡 部分完成 | Share/FilePicker平台通道处理 | 4 |
| ⭐⭐⭐ 较难 | P0 | llm_config_test.dart - LLM配置集成测试 | ❌ 待做 | 配置持久化验证、Keychain状态隔离 | 5 |
| ⭐⭐⭐⭐ 困难 | P0 | note_chat_link_test.dart - 笔记关联对话测试 | ❌ 待做 | 双向关联验证、上下文注入 | 6 |
| ⭐⭐⭐⭐ 困难 | P0 | concurrent_test.dart - 并发操作测试 | ❌ 待做 | 竞态条件模拟、状态一致性验证 | 7 |

---

### 📈 实施建议

**第一阶段（简单，高优先级）**：
1. 补全 `node_reorder_test.dart` - ValueKey已存在，只需实现真实nodeId获取
2. 补全 `chat_streaming_test.dart` - 复用theme_chat_e2e的helper

**第二阶段（中等）**：
3. 补全 `branch_creation_test.dart` 剩余3个TODO

**第三阶段（较难）**：
4. 补全 `backup_restore_test.dart`
5. 新增 `llm_config_test.dart`

**第四阶段（困难）**：
6. 新增 `note_chat_link_test.dart`
7. 新增 `concurrent_test.dart`

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

### 任务 1：搜索模块集成测试 ✅ 已完成

**文件**：
- `integration_test/search_test.dart`
- `integration_test/note_search_test.dart` (额外补充)
- 参考：`lib/ui/features/search/search_screen.dart`

**已实现的测试用例**：

#### search_test.dart
- **Test 1.1：搜索有结果** - 通过 UI 创建笔记后搜索验证 ✅
- **Test 1.2：搜索无结果** - 空状态文案验证 ✅
- **Test 1.3：搜索索引错误修复** - 修复对话框与完成验证 ✅

#### note_search_test.dart
- **Test 1：笔记 tab 搜索命中** - 命中新建笔记并跳转 ✅
- **Test 2：空查询态** - 主题分组占位正常渲染 ✅
- **Test 3：搜索无结果** - 空态文案 ✅
- **Test 4：搜索 tab 与笔记 tab 一致性** - 结果数量一致验证 ✅

**验收**：
- [x] 7 个 testWidgets 全绿
- [x] 无需真实 LLM（仅测试搜索功能，不测试 LLM 响应）

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

### 任务 3：断网场景集成测试 ✅ 已完成

**文件**：
- `integration_test/offline_test.dart`
- 参考：`lib/data/services/llm_client.dart`、`lib/ui/features/chat/chat_controller.dart`

**已实现的测试用例**：

#### Test 3.1：发送消息时断网 ✅
- 模拟网络错误（DioExceptionType.connectionError）
- 验证错误提示正确显示
- 验证有"重试"按钮

#### Test 3.2：流式传输中断网 ✅
- Mock LLM 在流式中途抛出网络错误
- 验证错误提示正确
- 验证 partial 回复可见

#### Test 3.3：网络恢复后重试 ✅
- Mock 第一次失败，第二次成功
- 验证重试验证逻辑

**验收**：
- [x] 3 个 testWidgets 全绿
- [x] 使用 mock LlmClient，不真实发网请求

---

### 额外补充的 P0 任务：LLM 错误重试测试 ✅ 已完成

**文件**：`integration_test/llm_error_retry_test.dart`

**已实现的测试用例**：
- **Test 1**：4 个场景错误态展示 + i18n 文案
- **Test 2**：重试按钮触发新请求
- **Test 3**：日志上报链路
- **Test 4**：cancelled 错误不渲染错误卡 + 不上报
- **Test 5**：中文 locale 文案正确

---

### 额外补充的 P0 任务：聊天异步恢复测试 ✅ 已完成

**文件**：`integration_test/chat_async_recovery_test.dart`

**已实现的测试用例**：
- **Test 1**：findInterrupted 返回含 streaming 标记的 node（focused 测试）
- **Test 2**：resumeInterrupted 把磁盘中断 node 入队 + 启动串行 loop
- **Test 3**：cancelResumeQueue 清空 queue + generation 自增让 loop 退出
- **Test 4**：startTask → onDone 期间 bridge.begin/end 各 1 次

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

### 任务 7：补全 branch_creation_test.dart 的 3 个 TODO 🟡 部分完成

**文件**：
- 修改：`integration_test/branch_creation_test.dart`

**已完成的测试**：
1. ✅ 选中文本 + raw 模式创建分支
2. ✅ 选中文本 + summarize 模式创建分支
3. ✅ 无选中文本 + raw 模式创建分支
4. ✅ 无选中文本 + summarize 模式创建分支

**待完成的 TODO**：
5. ❌ 模式选择取消
6. ❌ 标题选择取消
7. ❌ LLM 失败 fallback

**实现要点**：
- 模式选择取消：点击分支 → 选择模式 → 点击取消 → 验证返回
- 标题选择取消：进入标题页面 → 点击取消 → 验证返回
- LLM 失败 fallback：mock LLM 失败 → 验证 fallback 路径

**验收**：
- [x] 4 个 testWidgets 已实现并可运行
- [ ] 3 个 TODO testWidgets 待完成

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
