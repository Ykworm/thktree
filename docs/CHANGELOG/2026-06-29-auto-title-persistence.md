# 2026-06-29 自动标题持久化修复

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-29 |
| 范围 | `lib/ui/features/chat/auto_title_controller.dart`（新增）+ `lib/ui/features/chat/chat_screen.dart` + `integration_test/branch_creation_test.dart`（新增 case 9.5/9.6 + 激活 case 9.4）|
| 设计文档 | [`docs/superpowers/plans/2026-06-29-auto-title-persistence.md`](../superpowers/plans/2026-06-29-auto-title-persistence.md) |
| 上游 brainstorming | [`docs/_tmp/auto-title-persistence.md`](../_tmp/auto-title-persistence.md) |
| 状态 | 🟡 代码完成，集成测试留给用户跑（用户反馈：测试案例太多，自己测） |

## 背景

2026-06-28 引入 P.9-A "空白分支"（A 模式）后出现新 bug：**新建空白对话后，LLM 自动生成的 title 没有持久化**——从 tree 视角或第二次打开 chat_screen 时，标题仍是占位"临时会话"。

## 根因

`chat_screen._triggerBlankAutoTitle` 把 title 生成任务**绑死在 widget 内部**：

1. 任务完成后只调了 `nodeStore.updateNodeTitle` 写 DB，没调 `themeDetailControllerProvider(themeId).notifier).refresh()` 刷 tree
2. `themeDetailControllerProvider` 是 `AsyncNotifierProvider.autoDispose.family`，push chat_screen 时 tree 页面 listener 被覆盖（chat_screen 是新 listen 目标），chat_screen 期间 tree 不重新加载，title 变化不传到 tree
3. 用户在 LLM 流式结束后、title 生成完成前退出/切换页面 → 整个任务被 widget dispose 打断
4. 用户手动改 DB title（如 node rename），widget 构造时拿的还是旧 title，LLM 流程会**覆盖**手动改的 title（无 DB 兜底守卫）

## 修复

把 title 生成任务从 widget 抽到 Riverpod `AutoTitleController`（按 `nodeId` family 维度），任务在 Notifier 内执行，与 widget 生命周期解耦。

**核心改动：**

1. **新增 `lib/ui/features/chat/auto_title_controller.dart`** —— `AsyncNotifierProvider.autoDispose.family` 范式
   - `runIfNeeded()` 方法：3 次重试（指数退避 1s/2s/4s）+ 调 LLM + 写 DB + refresh tree
   - 写 DB 前查 `nodeStore.getNodeRow(nodeId).title` 兜底：DB 已被改则跳过 LLM 流程
   - Notifier 用自己的 `ref`，widget dispose 后任务仍能继续
2. **`chat_screen.dart`** ——
   - 删除 3 个 `_` 私有方法（`_triggerBlankAutoTitle` / `_generateTitleWithRetry` / `_callTitleLlm`）
   - 边沿检测触发逻辑改为调 `autoTitleControllerProvider(nodeId).notifier.runIfNeeded(...)`
   - 加 `ref.listen<AsyncValue<AutoTitleState>>` 同步 `_displayedTitle`，监听 `failed + error=='noModel'` 弹 `showLlmSetupAlert`
3. **`llm_setup_check.dart`** —— 提取 `resolveModelForTitleCore` 纯函数（容器版本保留 wrapper），方便 Notifier 调用
4. **集成测试** ——
   - 新增 case 9.5（基础流程三重断言：DB / tree state / nav bar）
   - 新增 case 9.6（提前 pop：流式刚启动就 pop，后台任务仍能跑完）
   - 激活 case 9.4（用户预改 title 不被 LLM 覆盖，移除 `skip: true`）

## 文件变更

**新增（1 个）：**
- `lib/ui/features/chat/auto_title_controller.dart`（246 行）—— Notifier：任务生命周期 + LLM 调用 + DB 写 + tree refresh

**修改（4 个）：**
- `lib/ui/features/chat/chat_screen.dart` — 删除 3 个私有方法；改触发逻辑；加 `ref.listen`
- `lib/ui/core/shared/llm_setup_check.dart` — 提取 `resolveModelForTitleCore` 纯函数
- `integration_test/branch_creation_test.dart` — 新增 case 9.5/9.6；激活 case 9.4
- `lib/l10n/app_en.arb` / `app_zh.arb` / `generated/*` — 新增 l10n keys

## 验证

| 类别 | 状态 |
|---|---|
| `flutter analyze` | ✅ 无新增 error（任务 7 完成）|
| 集成测试全绿 | ⚠️ 留给用户跑（用户决定不再依赖 AI 跑测试） |
| 手工验证 | 见下方"手工验证步骤" |

## 手工验证步骤（iOS sim）

1. **正常持久化**：chat → branch → "空白分支" → 发消息 → LLM 回复 → 等流式结束 → pop 回 tree → **tree 显示新 title** → 重新点入 → **nav bar 显示新 title**
2. **提前 pop 后台完成**：chat → branch → "空白分支" → 发消息 → **立刻** back 回 tree → 等 30s → **tree 仍显示新 title**
3. **用户手动改 title 不被覆盖**：通过 node rename 把 DB title 改成自定义值 → 在 chat_screen 发消息 → 流式结束 → **title 仍是手动改的**
4. **raw 模式回归**：chat → branch → "使用原始上下文创建" → 行为跟之前一致
5. **summarize 模式回归**：chat → branch → "总结后创建" → 行为跟之前一致

## 已知风险

- **集成测试未实跑**：用户决定自己测，AI 不再跑测试套件。如果 case 9.4 / 9.5 / 9.6 实际跑失败，可能是：
  - timing 问题（LLM 调用慢于 60s 轮询）→ 调整 `for (var i = 0; i < 60; i++)` 的 60s 超时
  - `Navigator.of(...).pop()` 在集成测试中可能与 go_router 冲突 → 改用 `context.pop()`
  - LLM title 生成结果与 placeholder 字符串比对逻辑 → 确认 placeholder 字符串是 `"临时会话"`
- **~~`AutoTitleController` 与 chat_screen 生命周期解耦依赖于 `autoDispose` 行为~~**（已修复）：早期实现用 `autoDispose.family`，chat_screen unmount 时 Notifier 被 dispose，Future 被取消 → 提前 pop 后 DB 不写、tree 不刷。修复方案：`build()` 内加 `ref.keepAlive()`，Notifier 永不被自动 dispose。需要清理时显式 `container.invalidate(autoTitleControllerProvider(nodeId))`。

## 关联

- [上游 brainstorming](../_tmp/auto-title-persistence.md) — 4 节用户确认设计
- [实现计划](../superpowers/plans/2026-06-29-auto-title-persistence.md) — 13 任务详细说明
- 2026-06-28 P.9-A 引入 "空白分支" 功能（产生本 bug）
- 2026-06-22 branch-creation-test — 集成测试套件基础
