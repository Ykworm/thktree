# 2026-07-05 — 豆包模型白名单 + 模型搜索焦点修复

| 日期 | 模块 | 类型 |
|------|------|------|
| 2026-07-05 | llm / chat | 功能增强 + bug fix |

## 改动概览

1. 豆包（火山方舟 ARK）模型白名单过滤
2. 模型选择面板搜索空结果时焦点丢失修复
3. 豆包 Seed 系列模型 vision 能力精确映射

## 详细描述

### 1. 豆包模型白名单

**文件**：`lib/data/services/model_fetcher.dart`

豆包模型数量庞大（大量 ep-* endpoint + 各类模型），从 `/models` API 全量拉取用户体验差。新增 `_fetchDoubaoModels()` 方法，返回硬编码白名单，只展示经过验证的支持深度思考 + 多模态的 Seed 系列模型：

- `doubao-seed-2-1-pro-260628`（Doubao-Seed-2.1-pro）— 旗舰思考模型
- `doubao-seed-2-1-turbo-260628`（Doubao-Seed-2.1-turbo）— 低成本思考模型
- `doubao-seed-2-0-lite-250528`（Doubao-Seed-2.0-lite）— 轻量多模态模型

`fetchModels()` 的 switch 中为 `LlmProviderType.doubao` 新增专属分支，不再走 OpenAI 兼容的 `/models` API。

### 2. 模型搜索焦点修复

**文件**：`lib/ui/features/chat/widgets/model_selector_panel.dart`

**问题**：`ModelSelectorPanel` 的 `CupertinoSearchTextField` 在搜索无结果时，整个 panel 的 `build` 方法直接返回了一个只含空状态文字的 `Center` widget，导致搜索 TextField 被从 widget 树中卸载，焦点丢失，Flutter 自动将焦点转移到下方仍挂载的 message input box。

**修复**：将空状态从"替换整个 panel"改为"只替换列表区域"——标题栏和搜索栏始终挂载，仅在 `Flexible` 的列表区域根据 `configuredProviders.isEmpty` 切换显示空状态文字或模型列表。

### 3. 豆包 Seed 模型 vision 能力

**文件**：`lib/data/models/model_capabilities.dart`

为三个 Seed 模型显式添加 `{text, vision}` 能力标记（之前只有通用的 `'doubao'` 和 `'ep-'` 前缀匹配），确保图片选择按钮对这些模型正确启用。

## 关于思考模式

豆包 Seed 2.1 Pro/Turbo 的流式 Chat Completions API 已通过 `reasoning_content` 字段返回思考过程，app 现有代码 `llm_client.dart` 的 `_extractDeltaFromMap` 已正确解析该字段，UI 中的"思考过程"折叠块也已适配，无需额外改动。深度思考默认开启，无需额外传参。

## 影响文档

- `docs/FEATURES.md` — 第 5 节 LLM 模型列表获取状态更新 + 最近变更新增条目
- `docs/modules/llm/README.md` — 联网搜索支持新增豆包白名单段落
- `docs/modules/chat/README.md` — 图片上传 vision 模型列表补充豆包
