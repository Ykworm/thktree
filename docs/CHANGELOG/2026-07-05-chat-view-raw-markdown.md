# Chat 查看原始 Markdown

> 日期：2026-07-05

## 概述

聊天页"更多"菜单新增"原始 Markdown"入口，底部 sheet 展示当前对话的 `session.md` 文件原始内容，支持一键复制到剪贴板。

## 改动文件

- `lib/ui/features/chat/widgets/chat_markdown_sheet.dart` — 新文件，底部 sheet（`showCupertinoModalPopup`），80% 屏幕高度，等宽字体显示原始 Markdown，右上角复制按钮（2 秒反馈）
- `lib/data/stores/session_store.dart` — 新增 `readSessionRaw(nodeId)` 方法，直接读取 session.md 原始文本
- `lib/ui/features/chat/chat_screen.dart` — 更多菜单新增"原始 Markdown"action（teal 文档图标，排在"分支"和"查看整棵树"之间）
- `lib/l10n/app_en.arb` / `lib/l10n/app_zh.arb` — 新增 `chatMarkdown` / `chatMarkdownEmpty` 文案

## 技术细节

### 数据读取

`SessionStore.readSessionRaw(nodeId)` 绕过 `parseSessionMarkdown`，直接读取磁盘文件原文。文件不存在时返回空字符串。

### UI 展示

- 使用 `showCupertinoModalPopup` 渲染 overlay sheet（非路由）
- 手动 Row 布局（左"关闭" + 中标题 + 右复制），避免 `CupertinoNavigationBar` 在 overlay 中自动生成 back 按钮导致意外 pop
- 字体：`monospace`，12pt，行高 1.4，背景色 `AppColors.surface`
