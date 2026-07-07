# 浏览对话历史 — 用户提问索引（设计草稿 v1）

> 状态：✅ 已实现（2026-07-08，freemode 下由 AI 直接落地代码，未建 worktree / 未 commit，由用户在 dev 分支把控）
> 日期：2026-07-07 · 实现：2026-07-08

## 0. 实现落点

- 入口：`lib/ui/features/chat/chat_screen.dart` 的 `_showMoreActions` 宫格新增「我的提问」`GridAction`（橙色 `AppIcons.chat`），push 列表页
- 列表页 / 回复页 / 全屏图片预览：`lib/ui/features/chat/user_questions.dart`
  - `UserQuestionsListPage`（读 live `chatControllerProvider(_args)`，按 `groupUserTurns` 分组，空状态 `myQuestionsEmpty`）
  - `UserQuestionReplyPage`（复用 `MessageBubble` 渲染单 turn，纯阅读态）
  - `UserQuestionImagePreview` + `ResolvedImage`（缩略图与全屏，兼容 `imageData` / `imagePath`）
- l10n：`app_zh.arb` / `app_en.arb` 新增 `myQuestions` / `myQuestionsTitle` / `myQuestionsEmpty`，已 `flutter gen-l10n` 重新生成
- 静态检查：`flutter analyze` 通过，无新增 error


## 1. 背景与动机

在长对话中，用户想回溯「自己上次问了什么」时，只能反复上下滑动聊天记录。人对「我上次问了啥」的记忆远强于「消息在第几屏」——用 user input 作为导航锚点，比时间戳或滚动条更直觉。

本功能从**当前会话**抽取所有 user message，按时间排序成独立列表，让用户通过「我问过什么」直接定位历史问答。

## 2. 目标

- **快速回溯**：长对话中一键定位某次问答，不无脑滑屏
- **按用户记忆索引**：以 user input 为导航锚点
- **问答对隔离**：每条 user input 对应一个独立回复页，避免原 chat 中「问 + 答 + 追问 + 再答」交错造成的阅读混乱

## 3. 关键约束（已验证，不可绕开）

**「回跳联动」（从回复页返回 Chat Page 并滚动到该消息 + 高亮）不可行。**

- 原因：曾尝试实现，无法计算某条消息在 Chat Page 中的滚动位置（列表虚拟化 / 变高 item / 懒加载，缺少可靠的 scroll-to-index 能力），跳不过去。
- 结论：因此采用**隔离 Reply Page** 方案——回复页独立渲染一个 turn，完全不依赖 Chat Page 的滚动状态。该增强项**永久砍掉**，非可选。

## 4. 交互流程

```
Chat Page（根）
  └─ 点击左上角 more 按钮
       └─ 弹出 Sheet（现有更多菜单）
            └─ 新增宫格项：我的提问（入口短标签；进入后 List 标题为「我问过的问题」，见 §9）
                 └─ Push 新视图：User Input List
                      ├─ 点击 Item 右侧 chevron / 整行
                      │    └─ Push 隔离 LLM 回复页（展示对应 turn）
                      └─ 点击 Item 左侧图片缩略图（仅含图时显示）
                           └─ Push 全屏图片预览（X 关闭，回到 List）
```

## 5. 视图设计

### 5.1 User Input List

- **导航栏**：标题 + 返回按钮
- **列表**：所有 user message，自顶向下按时间从旧到新
  - 左：图片缩略图（仅消息含图片时显示），可点击 → 全屏预览
  - 中：user input 文本（单行截断预览 + ellipsis）
  - 右：chevron（替代原 enter 按钮，整行可点进入回复页）

### 5.2 隔离 LLM 回复页（Reply Page）

- 展示一个 **turn**（定义见 §6）
- 纯展示，不依赖 Chat Page 滚动状态
- 返回：回到 User Input List

## 6. 数据模型 / turn 定义（已确认）

**turn = 一条 user message + 其后的所有 assistant 消息，直到下一条 user message 为止。**

回复页渲染该 turn 内的全部消息。这样既不丢追问上下文，又实现问答对隔离。

> 编码视角说明：实际 LLM 对话多为「一问一答」，此定义看似冗余。其作用是给代码一个**确定性分组不变量**——以「下一条 user message」作为 turn 的结束边界，无论中间有 1 条还是 N 条 assistant 消息都成立；在遇到重试残留、工具调用多轮、流式分片等导致单 turn 内出现多条 assistant 消息时，分组规则不崩、无需特判。ThkTree 当前 store 实际接近 1:1（`retryLastMessage` 替换末条 assistant 消息），故 UI 上几乎总是「一问一答」。

## 7. 窄屏列表项方案

问题：缩略图 + 文字 + enter 按钮三者在窄行互挤。

解法：
- enter 按钮 → 行尾 **chevron**（几乎不占宽），整行可点进入
- 缩略图留 leading，无图也留同等占位保持行对齐
- 文字 `maxLines=1` + ellipsis
- 缩略图单独可点开全屏预览，行整体可点进回复页 → 两个 tap zone 互不冲突

## 8. 范围与增强项

- **应有（低成本）**：空状态（会话 0 条 user message 时的占位文案）
- **未来增强（MVP 后可加）**：列表顶部搜索框，按关键词过滤提问
- **已砍**：回跳联动（见 §3）

## 9. 命名（已确认）

入口位于 chat 的「更多」**宫格菜单**（`ThkGridBottomSheet` / `_MoreActionsOverlayPanel`）：圆形图标在上，下方 11px 单行标签、cell 宽约 80–84pt，超长省略号。

- **长度核查（已读代码确认）**：现有菜单项已存在 5 字标签——「提交树结构」「查看整棵树」。因此长文案在宫格内也不会换行 / 截断。
- **采用解耦方案（已定）**：
  - 宫格入口标签：**「我的提问」**（4 字，节奏与现有短项一致）
  - 进入后的 User Input List **导航栏标题**：**「我问过的问题」**（大标题位，承载完整语义）
- 避免：浏览对话历史（易与跨会话历史混淆）

## 10. 待确认事项

1. turn 定义（§6）确认无误

## 11. 验收方式

Flutter UI 功能，采用「编译通过 + 关键路径手工验证」：

- `flutter analyze` 无新增 error
- 手工验证路径：
  1. 进入任意含多轮对话的会话
  2. more → 「我的提问」→ 看到按时间排序的 user message 列表（List 标题为「我问过的问题」）
  3. 含图消息显示缩略图；点击缩略图 → 全屏预览 → X 关闭回 List
  4. 点击某 Item → 进入隔离回复页，展示该 user message 及其后 assistant 回复（含追问）
  5. 返回 → 回到 List；再返回 → 回到 Chat Page（位置不变）
  6. 空会话时列表显示空状态文案
