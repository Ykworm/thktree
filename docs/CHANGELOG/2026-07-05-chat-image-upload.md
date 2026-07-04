# Chat 图片上传功能

> 日期：2026-07-05

## 概述

聊天输入框新增图片上传功能，用户可通过拍照或相册选择图片发送给 LLM，支持 vision 能力的模型会自动识别图片内容。

## 改动文件

- `lib/ui/core/shared/chat_composer.dart` — `_ImageButton` 颜色修复（supported 时显示蓝色）+ 移除未使用的 `hasImage` 参数
- `lib/ui/features/chat/chat_screen.dart` — `_showImagePicker` 实现：`image_picker` 集成，支持 camera + gallery 两种来源
- `lib/ui/features/chat/chat_controller.dart` — `sendUserMessage` 转发 `imageData`/`imageMimeType`；`_read()` 新增 `_mergeImageData()` 合并 in-memory 图片数据；`_startStreamingWithConfig` 新增 `currentMessages` 参数
- `lib/data/models/model_capabilities.dart` — 新文件，`ModelCapability` 枚举 + 模型 ID 前缀自动推断 vision 能力
- `pubspec.yaml` — 新增 `image_picker: ^1.1.2` 依赖
- `ios/Runner/Info.plist` — 新增 `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` 权限描述

## 技术细节

### 图片选择流程

1. 用户点击图片按钮 → `_showImagePicker` 弹出 CupertinoActionSheet
2. 选择"拍照"（`ImageSource.camera`）或"从相册选择"（`ImageSource.gallery`）
3. `ImagePicker.pickImage` 获取 `XFile` → `readAsBytes()` + `mimeType`
4. 设置到 `_selectedImageData` / `_selectedImageMimeType` → UI 显示预览条

### 图片发送流程

1. `ChatComposer._send()` 将 `imageData`/`imageMimeType` 传给 `onSend` 回调
2. `ChatController.sendUserMessage` 创建含图片的 `SessionMessage`（乐观追加 in-memory state）
3. `currentMessages`（in-memory）传入 `_startStreamingWithConfig` → `ChatTaskService.startTask`
4. `_buildMessages` 检测 `msg.imageData != null` → 构建多模态 content（base64 `image_url`）
5. `LlmClient.streamChatCompletion` 发送到 LLM API

### 图片数据持久化策略

- 磁盘（session.md）不存储图片二进制数据（仅文本）
- `_mergeImageData()` 在 `_read()` 时将 in-memory 的 `imageData` 按 `msgId + role` 合并回磁盘消息
- 轮询定时器（500ms）和 `chatTaskService` 监听器刷新 state 时不会丢失图片

### 模型 vision 能力检测

- `ModelCapability.vision` 枚举标记支持图片的模型
- `inferCapabilities()` 根据模型 ID 前缀自动推断（gpt-4o / claude-3 / gemini / kimi-k2.5 / mimo-v2.5 等）
- 不支持 vision 的模型：图片按钮变灰不可点击

## Bug 修复

本次实现过程中修复了两个关键 bug：

1. **imageData 未转发到 LLM**：`sendUserMessage` 调用 `_startStreamingWithConfig` 时遗漏 `imageData`/`imageMimeType` 参数
2. **轮询刷新丢失图片**：`_read()` 从磁盘读取后覆盖 in-memory state，新增 `_mergeImageData()` 合并图片数据
