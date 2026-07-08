# Title bar 显示模型与实际调用模型不一致（两套独立 fallback 逻辑）

**日期**：2026-07-08
**模块**：chat / 模型解析
**标签**：Flutter, chat_controller, resolveChatModel, fallback, 数据源分裂, 空白分支

---

## 现象

用户从已有 chat 创建**空白分支**后进入新对话，发现：

- title bar 显示的模型 = 模型 A（例如全局默认 ProviderA/ModelX）
- 实际 LLM 调用使用的模型 = 模型 B（另一个 provider 的 `models.first`）
- 两条流独立运行，用户无感知，直到发现回复风格 / 上下文窗口与预期不符才察觉

非空白分支（summary / raw / 选中文本）在父对话已存模型时理论一致，但若父对话本身也没存模型且 `resolveChatModel` 兜底失败，同样命中。

---

## 根因分析

**显示侧**与**调用侧**各自维护了一套独立的模型解析逻辑，优先级不一致。

### 显示侧（`chat_screen.dart` build → `resolveChatModel`，`llm_setup_check.dart:236-274`）

4 级优先级，在 build 中同步执行：

```
1. session.providerId / modelId
2. settings.lastUsedChatProviderId / lastUsedChatModelId
3. settings.chatDefaultProviderId / chatDefaultModelId
4. 兜底：providers 中第一个 models.isNotEmpty 的（不查 apiKey）
```

### 调用侧（`chat_controller.dart` 旧代码）

`_triggerLlmStream` / `_triggerAssistantReply` / `_currentModelSupportsVision` 各自内嵌了**只 2 级**的 fallback：

```
1. session._providerId / _modelId（session 级别）
2. 兜底：providers 中第一个 apiKey 非空 && models.isNotEmpty 的
```

### 三个不一致点

1. **优先级缺失（主因）**：调用侧跳过了 `lastUsedChat` 和 `chatDefault` 两级——用户设了全局默认模型，但空白分支 session 没存模型时，显示侧走第 3 级显示全局默认，调用侧直接跳到第 4 级用另一个 provider
2. **兜底条件不同**：显示侧 `models.isNotEmpty`（不查 key），调用侧 `apiKey + model` 都要
3. **异步竞态**：`chat_screen.dart:277-282` 在 build 时用 `PostFrameCallback` 异步 `switchModel` 回写 session，但发消息时 `_triggerLlmStream` 读 `_providerId/_modelId` 可能还没写完

### 为什么空白分支 100% 命中

`_createBlankBranch`（`title_suggestion_screen.dart:1057-1117`）创建新分支时：

- `createChatNode`（`node_store.dart:171-267`）**不带 model 参数**，初始 `session.md` 的 providerId/modelId 为空
- `_createBlankBranch` **完全不调 `updateSessionModel`**

→ 新分支 session 无模型 → `_loadSessionModel`（`chat_controller.dart:152-175`）读到 `_providerId/_modelId = null` → 直接命中两套 fallback 的分歧区。

---

## 解决方案

**核心思路：让显示和调用走同一份数据源。**

新增 `_resolveChatModelForLlm()`（`chat_controller.dart:355-412`）作为调用侧统一入口，复用 `resolveChatModel` 的 1-3 级优先级，自行做第 4 级兜底：

```
1-3 级：复用 resolveChatModel（session → lastUsedChat → chatDefault）
  ↓ 解析出模型 → 验证 provider 存在 + apiKey 非空 + model 在列表中
  ↓ 验证失败 → 不降级，返回 null 让调用方报错提示用户手动切换
4. 兜底：第一个有 apiKey + model 的 provider（仅 1-3 级完全落空时触发）
```

**关键设计决策：不传 `providers` 给 `resolveChatModel`。**

`resolveChatModel` 的第 4 级是同步兜底（不查 apiKey——它是同步函数，无法 await）。如果传 `providers`，1-3 级解析出模型但验证失败时会静默降级到第 4 级（可能选了一个没 key 的 provider）。不传 `providers` 意味着只用 1-3 级，第 4 级由 `_resolveChatModelForLlm` 自行做（查 apiKey），这样 1-3 级验证失败返回 null，让调用方报错而非静默用错模型。

三处调用统一改造：

| 方法 | 改动 | 行数变化 |
|------|------|---------|
| `_triggerAssistantReply` | 删 if/fallback 两套分支 → 调 `_resolveChatModelForLlm` | 40 → 10 |
| `_triggerLlmStream` | 删 if/else + 内嵌 fallback → 调 `_resolveChatModelForLlm` | 70 → 25 |
| `_currentModelSupportsVision` | 删内嵌 fallback → 调 `_resolveChatModelForLlm` | 30 → 12 |

---

## 相关文件

- `lib/ui/features/chat/chat_controller.dart` — 新增 `_resolveChatModelForLlm`（:355-412）+ 三处调用统一改造
- `lib/ui/core/shared/llm_setup_check.dart:236-274` — `resolveChatModel`（未改动，被复用）
- `lib/ui/features/chat/chat_screen.dart:250-282` — 显示侧 build 调 `resolveChatModel` + 异步回写 session（未改动，显示侧本就是正确的数据源）
- `lib/ui/core/shared/title_suggestion_screen.dart:1057-1117` — `_createBlankBranch`（空白分支入口，不写模型的根源）

---

## 参考链接

- [DECISIONS.md ADR-026](../DECISIONS.md) — 统一模型解析为单一数据源
- [war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md](flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md) — 同为空白分支场景的 Riverpod 保活问题

---

## 复盘

### 为什么一开始没发现

1. **两套逻辑各自独立发展**：显示侧 `resolveChatModel` 是后来为 title bar 抽取的，调用侧的 fallback 是更早的代码，两边没有共享数据源的意识
2. **非空白分支不命中**：summary/raw 分支若父对话有模型，创建时 `showBranchFlow` 会用 `resolveChatModel` 解析并写入新分支 session，两套逻辑的第 1 级（session 级别）就命中了，走不到分歧区
3. **兜底条件差异隐蔽**：显示侧不查 apiKey 是因为它是同步函数，调用侧查 apiKey 是因为要实际发请求——这个差异在"恰好第一个有 model 的 provider 也有 key"时不会暴露
4. **没有跨显示/调用的集成测试**：现有测试分别验证"title bar 显示正确"和"消息发送成功"，但没有"显示的模型 == 实际调用的模型"的交叉断言

### 以后如何避免同类问题

1. **任何"同一概念的两条数据流"必须共享解析逻辑**——显示和调用是同一个"当前模型"概念的两种消费者，不应该各写一套 fallback
2. **新增 fallback 级别时，同步检查所有消费方**——`resolveChatModel` 加了 lastUsedChat/chatDefault 两级时，应该同步检查调用侧是否也需要
3. **集成测试加"显示 == 调用"交叉断言**——创建空白分支后，断言 title bar 显示的 providerId/modelId 与 `_triggerLlmStream` 实际使用的 provider/modelId 相同
4. **同步函数的兜底限制要文档化**——`resolveChatModel` 不查 apiKey 不是疏忽而是同步约束，调用侧（async）需要自行补查，这个约束应该在函数文档里显式说明
