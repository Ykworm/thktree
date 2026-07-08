# 分享卡片缺失图片修复

## 现象

`session.md` 中正确记录了用户消息的图片（`image:chat_images/msg_xxx.jpg`），但点击「分享整个聊天」生成的图片里，这两张图都没有出现。

## 根因

1. `chat_screen.dart` 的 `_shareEntireChat` 把全部消息拼成纯文本 `'$role: ${m.body}'` 作为 `assistantAnswer` 传给 `ShareService.shareAsImage`，**完全丢弃了每条消息的 `imagePath` / `imageData`**。
2. `ShareCardWidget` 只支持单个 `userQuestionImage`（`Image.memory`），不渲染整段聊天的图片。
3. `image:chat_images/...` 是消息头元数据，不在 `body` 文本里，所以 `GptMarkdown` 也渲染不出图片。

结论：整段聊天分享路径压根没有把图片数据传进去。

## 修复方案

### 1. 新增共享数据结构 `ShareMessage`
在 `share_card_widget.dart` 中定义：
```dart
class ShareMessage {
  final SessionRole role;      // user / assistant
  final String text;           // 该消息正文
  final Uint8List? image;      // 可选图片字节（本地已加载）
  ShareMessage({required this.role, required this.text, this.image});
}
```

### 2. 重构 `ShareCardWidget`
- 入参由 `userQuestion / userQuestionImage / assistantAnswer` 改为 `List<ShareMessage> messages`。
- 逐条渲染：
  - user：浅色容器，正文用普通 `Text`；若有 `image` 则在正文上方用 `ClipRRect + Image.memory`（圆角、限高 ~200、`BoxFit.cover`）展示。
  - assistant：用 `GptMarkdown` 渲染正文。
- 保留顶部 "ThkTree" 品牌条与底部 "Shared from ThkTree"。

### 3. 重构 `ShareService.shareAsImage`
- 入参改为 `List<ShareMessage> messages`，offscreen 构建 `ShareCardWidget(messages: messages)`。
- 其余截图→PNG→临时文件→系统分享流程不变。

### 4. 更新调用方
- `message_bubble.dart _shareAsImage`：构造列表 `[user(question+image), assistant(answer)]`，保持原有单条问答分享行为。
- `chat_screen.dart _shareEntireChat`：
  - 遍历全部 `SessionMessage` 构造 `ShareMessage` 列表；
  - 对 `imageData == null && imagePath != null` 的消息，按 `themeId/nodeId/images/<fileName>` 从磁盘同步读取字节补上（`appPathsProvider` + `nodeStoreProvider` 已在 `ref` 中可用）；
  - 传给 `ShareService.shareAsImage(messages: ...)`。

### 5. 边界
- 单条消息最多一张图（现有数据模型如此），`Image.memory` 即可。
- 限高 + `BoxFit.cover`，避免超长图撑爆卡片。
- 磁盘读取包在 try/catch，单张失败不影响整体。

## 验收
- 含 2 张用户图的会话，点「分享整个聊天」→ 生成的图片中应出现这 2 张图 + 对应问答文本。
- 单条问答分享仍正常显示问题图。
- `flutter analyze` 无新增错误。

## 状态：已实现（2026-07-08，freemode 直接改 dev）
- 改动文件：session_markdown.dart（ShareMessage）、share_service.dart、share_card_widget.dart、chat_screen.dart、message_bubble.dart。
- 提交/合并由用户控制。
