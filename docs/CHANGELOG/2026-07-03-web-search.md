# 联网搜索功能上线

> 日期：2026-07-03

## 变更内容

- 新增联网搜索功能，KIMI、MIMO、DeepSeek 三个提供商支持原生联网搜索
- 聊天输入框底部新增联网搜索开关按钮（地球图标）
- 支持的提供商默认开启，用户可手动关闭，偏好持久化
- 不支持的提供商按钮变灰不可点击
- 设置页面提供商列表过滤为只显示 KIMI、MiniMax、MIMO、DeepSeek 四个

## 技术实现

- KIMI：`builtin_function.$web_search` + tool_calls 多轮交互
- MIMO：`web_search` function 工具
- DeepSeek：Anthropic 兼容接口 `web_search_20260209`
- MiniMax：待实现（Assistants API 架构差异）

## 改动文件

- lib/data/models/llm_provider_config.dart
- lib/data/services/settings_store.dart
- lib/data/services/llm_client.dart
- lib/data/services/chat_task_service.dart
- lib/ui/core/shared/chat_composer.dart
- lib/ui/core/theme/app_icons.dart
- lib/ui/features/chat/chat_controller.dart
- lib/ui/features/chat/chat_screen.dart
- lib/ui/features/llm/llm_providers_screen.dart
- lib/ui/features/settings/settings_controller.dart
