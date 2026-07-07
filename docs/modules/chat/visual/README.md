# 聊天模块视觉设计

> 与 [`../../../_shared/design-system.md`](../../../_shared/design-system.md) 配套阅读。

---

## 屏幕地图

```
┌─────────────────────────────────────────────────────┐
│  TabBar:  主题   笔记   搜索   设置                    │
└─────────────────────────────────────────────────────┘
                    │
                    │ /themes/:themeId/nodes/:nodeId
                    ▼
┌─────────────────────────────────────────────────────┐
│  ChatScreen                                          │
│  ─────────────────────────────────────────────────── │
│  NavBar: ← 节点标题           模型名(副标题)    🌿    │
│          back              modelSubtitle      branch │
│  ─────────────────────────────────────────────────── │
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │  ChatListView（消息列表）                         │ │
│  │  ┌──────────────────────────────────────────┐   │ │
│  │  │ MessageBubble (user)              [📋][📤]│   │ │
│  │  │ 用户消息文本                               │   │ │
│  │  └──────────────────────────────────────────┘   │ │
│  │  ┌──────────────────────────────────────────┐   │ │
│  │  │ MessageBubble (assistant)         [🔊][📋][📤]│   │ │
│  │  │ GptMarkdown 渲染                          │   │ │
│  │  │ [🔊] [📋] [📤] [🔄]  ← 操作栏            │   │ │
│  │  └──────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │ ChatComposer（输入框）                           │ │
│  │ [消息输入...                    ] [发送↑] │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
                    │
                    │ 点击 ModelSelectorPanel
                    ▼
┌─────────────────────────────────────────────────────┐
│  ModelSelectorPanel（底部弹出抽屉）                   │
│  ─────────────────────────────────────────────────── │
│  Provider A                                          │
│    ├─ model-1                                        │
│    └─ model-2                                        │
│  Provider B                                          │
│    └─ model-3                                        │
└─────────────────────────────────────────────────────┘
```

---

## 1. ChatScreen 布局

```dart
CupertinoPageScaffold(
  backgroundColor: AppColors.pageBg,
  navigationBar: ThkNavBar.inline(...),
  child: Column(
    children: [
      Expanded(child: ChatListView(...)),  // 消息列表
      ChatComposer(...),                    // 底部输入框
    ],
  ),
)
```

### NavBar

| 元素 | 内容 | 颜色 |
|------|------|------|
| leading | `AppIcons.back` → `context.pop()` 或 `context.go('/themes/:themeId/tree')` | — |
| middle | 节点标题（单行省略）+ 模型名副标题（12pt, `textSecondary`） | — |
| trailing | `AppIcons.branch` → 创建分支（streaming 时 disabled，`textTertiary`） | `AppColors.accent` |

### ContextUsageBar

当对话有上下文长度信息时，NavBar 下方显示进度条指示 context 使用量。

---

## 2. MessageBubble

两种样式，由 `SessionMessage.role` 决定：

### User 消息

| 属性 | 值 |
|------|-----|
| 背景 | `AppColors.accentLight` |
| 文字色 | `AppColors.textPrimary` |
| 对齐 | 右侧 |
| 字体 | `AppTheme.body` (17pt) |

### Assistant 消息

| 属性 | 值 |
|------|-----|
| 背景 | `AppColors.surface` |
| 文字色 | `AppColors.textPrimary` |
| 对齐 | 左侧 |
| 渲染器 | `GptMarkdown`（支持代码高亮、表格、列表） |
| 字体 | `AppTheme.body` (17pt, height 1.6) |

### 操作栏（仅 assistant 消息）

| 按钮 | 图标 | 行为 | 条件 |
|------|------|------|------|
| 朗读 | `AppIcons.ttsSpeak` → `AppIcons.ttsPause` | 点击 push TtsPlayerScreen（独立播放器页面，ADR-012）；playing 时按钮变 ttsPause + systemBlue | 仅 assistant 消息，非 streaming/error（iOS only） |
| 复制 | `AppIcons.copy` → `AppIcons.checkCircle` | 复制原始 Markdown，icon 变绿 2s | 始终 |
| 分享 | `AppIcons.share` | 截图生成分享卡片图片 | 始终 |
| 重试 | `AppIcons.refresh` | 重新生成 assistant 回复 | 仅 `onRetry != null` |

---

## 3. ChatComposer

底部输入框，包含文本输入 + 发送/停止按钮（模型选择入口已移至导航栏 middle）。

| 元素 | 行为 |
|------|------|
| 输入框 | `ThkTextField`，placeholder 由 `hintText` 控制 |
| 发送按钮 | `AppIcons.send`，`onSend(text)` 回调 |
| 停止按钮 | `AppIcons.stop`，`isStreaming` 为 true 时替换发送按钮 |
| 模型选择 | 导航栏 middle（当前模型名 + ▾）点击弹出 `ModelSelectorPanel` |
| 键盘 | 点击消息列表区域 `FocusScope.unfocus()` 收起键盘 |

---

## 4. ChatListView

消息列表容器。

| 属性 | 值 |
|------|-----|
| 消息源 | `List<SessionMessage>` |
| 构建器 | `MessageBuilder` 回调 |
| 空状态 | `Center(Text(l10n.noMessagesYet))` |
| 滚动 | 底部粘性（`_bottomTolerance: 24.0`），新消息自动滚到底部 |
| 文本选择 | `SelectionArea` 包裹，支持系统级复制 |

---

## 5. ModelSelectorPanel

底部弹出抽屉，列出所有可用 Provider + 模型。

| 属性 | 值 |
|------|-----|
| 触发 | 导航栏 middle（当前模型名）点击 |
| 内容 | Provider 分组，每组下列出模型列表 |
| 选择 | 点击模型 → 更新当前对话的 providerId + modelId |
| 显示 | 当前选中模型高亮 |
| 关闭 | **点击 panel 外部关闭**（消息列表 / context bar / 输入框 / 标题栏空白），panel 内模型项点击由自身消化不触发 dismiss；panel 不再提供关闭按钮 |

### 关闭行为约束（2026-06-26 更新）

- 外部 tap：消息列表 / context bar / ChatComposer 区域 / 标题栏空白 → 关闭 panel
- 内部 tap：模型项 → 选中并关闭 panel（已有逻辑）
- 导航栏 middle 再次点击：切换 panel 显隐（已有逻辑）
- 输入框 tap：用 `Listener(onPointerDown)` 拦截，避免与 TextField 的 `TapGestureRecognizer` 在 arena 中冲突导致外层 GestureDetector 失效
- 透明遮罩：`Positioned.fill(GestureDetector(behavior: translucent))`，子节点 `_ModelItem` 的 `GestureDetector(opaque)` 在 arena 中胜出

---

## 6. TitleSuggestionScreen

标题建议弹层，用于智能命名节点。

| 属性 | 值 |
|------|-----|
| 文件 | `lib/ui/core/shared/title_suggestion_screen.dart` |
| 入参 | `TitleSuggestionRequest(sourceLabel, sourceContent, currentProviderId, currentModelId)` |
| 触发 | 从 themes 模块的重命名/创建节点时调用 |
| 行为 | 调用 LLM 生成标题建议，用户可选择或自定义 |

---

## 7. SSE 流式渲染

| 属性 | 值 |
|------|-----|
| 协议 | SSE (Server-Sent Events) |
| 渲染 | 逐 token 渲染（打字机效果） |
| 心跳 | 保活连接 |
| 终止 | `[DONE]` 事件 |
| 错误 | 断网/超时自动重连 |
| 状态 | `SessionMessageStatus.streaming` / `completed` / `error` |
| 取消 | 用户点停止 → `chatController.cancel()` |
