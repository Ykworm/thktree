# 聊天图片功能设计

## 背景

用户需要在艺术展场景中使用 ThkTree，拍照后让 AI 解读作品。需要支持在聊天中发送图片给多模态 LLM。

## 交互设计

### 布局

```
┌─────────────────────────────────────────────┐
│  [请输入消息...              ] [发送] [✨]     │
│  [🌐联网搜索] [🖼️添加图片]                    │
└─────────────────────────────────────────────┘
```

### 交互流程

1. 点击 [🖼️添加图片] → 弹出 ActionSheet：
   - 拍照
   - 从相册选择

2. 选中图片后，布局变为：

```
┌─────────────────────────────────────────────┐
│  [缩略图预览 ✕]                              │
│  [请输入消息...              ] [发送] [✨]     │
│  [🌐联网搜索] [🖼️添加图片]                    │
└─────────────────────────────────────────────┘
```

3. 发送时，图片 + 文本一起发送给 LLM

### 状态逻辑

| 状态 | 图片按钮 |
|------|---------|
| 当前模型支持多模态 | 可点击，正常颜色 |
| 当前模型不支持多模态 | 灰色，点击提示"当前模型不支持图片" |
| 已选图片 | 按钮高亮，显示预览条 |
| 流式输出中 | 禁用 |

## 技术方案

### 1. 数据层

**SessionMessage 扩展**
- 新增 `imagePath: String?` 字段
- 新增 `imageData: Uint8List?` 字段（Base64 用于发送给 LLM）

**LlmModelConfig 扩展**
- 新增 `capabilities: Set<ModelCapability>` 字段
- `ModelCapability` 枚举：`text`, `vision`, `audio`

### 2. LLM 客户端层

**消息格式统一**
```dart
class ContentPart {
  final String type; // 'text' | 'image'
  final String? text;
  final Uint8List? imageData;
  final String? mimeType;
}
```

**各客户端适配**
- OpenAI 兼容：`content` 变为数组，图片用 `image_url` + base64
- Claude：`content` 变为数组，图片用 `image` + base64
- Gemini：`parts` 数组，图片用 `inlineData` + base64

### 3. UI 层

**ChatComposer 改动**
- 添加图片按钮（在联网搜索旁边）
- 添加图片预览条（输入框上方）
- 图片选择逻辑（拍照/相册）

**MessageBubble 改动**
- 支持渲染图片（缩略图 + 点击全屏）

**ChatScreen 改动**
- 传递图片数据给 ChatController
- 处理图片模型能力检测

## 实现步骤

1. 扩展数据模型（SessionMessage, LlmModelConfig）
2. 扩展 LLM 客户端（支持多模态消息）
3. 实现图片选择和预览 UI
4. 实现消息气泡图片渲染
5. 集成测试

## 验收方式

- 集成测试：拍照/选图 → 发送 → AI 回复包含图片分析
- 手工验证：艺术展场景实际测试
