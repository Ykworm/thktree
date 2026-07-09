# 多对话合并 — Loading 卡死 & 内容乱 修复

## 任务类型

Bug 修复

## Bug 1：按钮一直 loading

### 根因

导航方式混用：`FullTreeScreen` 和 `MergeChatConfirmScreen` 都用原生 `Navigator.push` 推入，但 `_submit` 用 go_router 的 `context.pushReplacement` 导出。go_router 不认识原生 push 的页面，`pushReplacement` 无法替换它，导致 `MergeChatConfirmScreen` 留在栈底，`_isSubmitting = true` 永不重置。

### 修复方案（方案 A：全程 go_router）

1. **router.dart** — 注册两个路由
   - `/themes/:themeId/full-tree` → `FullTreeScreen`（query params: `currentNodeId`, `initialMultiSelect`）
   - `/themes/:themeId/merge-confirm` → `MergeChatConfirmScreen`（`extra` 传 `selectedNodes`）

2. **入口改导航**（3 处 `Navigator.push` → `context.push`）
   - `theme_detail_screen.dart:76` — FullTreeScreen 入口
   - `chat_screen.dart:808` — FullTreeScreen 入口
   - `full_tree_screen.dart:127` — MergeChatConfirmScreen 入口

3. **返回按钮**（2 处 `Navigator.of(context).pop()` → `context.pop()`）
   - `full_tree_screen.dart:199`
   - `merge_chat_confirm_screen.dart:127`

4. `_submit` 的 `context.pushReplacement` 保持不变 — 现在能正确替换 MergeChatConfirmScreen

## Bug 2：内容超级乱

### 根因

`buildMergedTranscript` 把多个对话的全部历史拼成一条 user message，MessageBubble 对 user/assistant 统一用 GptMarkdown 渲染，导致 assistant 回复里的代码块、表格、标题等 markdown 结构互相干扰。

### 修复方案：逐条消息写入，保持原始 role

不再合并为一个超大 content，而是遍历每个来源对话的消息，逐条写入新 session，保持原始 role（user/assistant），让 MessageBubble 按角色正常渲染。

#### 改动

1. **SessionStore 新增 `importMessages` 方法**
   - 一次性读取新 session.md → 追加所有消息 → 一次写入（O(n)，不重复读写）
   - 保持每条消息的 role 和 body
   - assistant 消息保留 modelId（扩展 `_appendMessage` 或在 `importMessages` 内直接构建）

2. **`_appendMessage` 扩展**：加可选 `modelId` 参数，传给 `formatMessageHeader`

3. **`merge_chat_confirm_screen.dart` `_submit`** 改为：
   - 遍历 sources，收集所有 SessionMessage（按来源顺序）
   - 调 `sessionStore.importMessages(nodeId, messages)`

4. **`buildMergedTranscript`** — 保留但不再用于此场景（`buildConversationTranscript` 等其他调用者不受影响）

#### 细节决策

- **图片消息**：跳过 imagePath（图片指向原 session 目录，跨 node 无效），body 保持原样
- **来源标记**：不加额外分隔标记，消息按来源顺序排列，user/assistant 正常渲染
- **时间戳**：用 `DateTime.now()` 递增（消息按文件顺序排列，不依赖时间戳排序）
- **system 消息**：正常写入（保持 role）
- **reasoning**：不导入（合并场景只关心 body 内容）

## 验收方式

1. 编译通过 + diagnostics 无新增错误
2. 关键路径手工验证：
   - 多选 2-3 个对话 → 合并创建 → 新 chat 打开，按钮不卡 loading
   - 新 chat 里每个对话的消息正常显示（user 气泡 + assistant 气泡，markdown 正确渲染）
   - 从新 chat 返回 → 回到 FullTreeScreen（不是 MergeChatConfirmScreen）
   - FullTreeScreen 返回 → 回到正确的上一页
3. 从 chat 页和 theme 详情页两个入口都能正常进入合并流程
