# Chat 模块

> ⚠️ **AI 改模块前必读**
> 1. **SSE 流式是核心体验**——事件顺序/心跳/`[DONE]` 终止/错误重连都在 `ChatController` + `LlmApiClient`；不要在 widget 里裸用 `http.Client`。
> 2. **节点作用域**——对话只挂在某个 `Node.id` 下，换节点要重建 controller；别跨节点共享消息流。
> 3. **Provider 解耦**——`ChatScreen` 只读 `chatControllerProvider(family: nodeId)`，不要传 controller 实例；交由 Riverpod 生命周期管。
> 4. **分层：UI 同步层 vs 服务层**——`ChatController` 只负责 watch Riverpod state 与绑定 Widget；**后台中断恢复 / 串行重发 / bridge.begin-end 包裹** 在 `ChatTaskService`（`lib/data/services/chat_task_service.dart`）里。续传/重发决策**不下沉到 widget**。变更前必读 [ADR-015](../../DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界)。
> 5. **标题自动建议**（`TitleSuggestionService`）的触发时机未决策，**别预设自动调用**，要加问用户。
> 6. **空白分支自动 title 持久化靠 `AutoTitleController` + `ref.keepAlive()`**（2026-06-29）—— 空白分支 chat 流式结束后，title 生成、DB 写、tree refresh 全在 Notifier 内执行，与 widget 生命周期完全解耦。**禁止把 title 生成任务重新绑回 widget**（user pop 后 task 会跟着 dispose，DB 不写 + tree 不刷；详见 [ADR-018](../../DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式) + [war-story](../../war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md)）。改了 `autoDispose` 范式前先查下面 "关键设计原则"里的 双标记范式说明。

## 职责

对话模块。承载 LLM 多轮对话的完整交互：消息流渲染、流式响应、模型选择、消息编辑/重试、笔记→对话的自动续聊、iOS 后台中断恢复。

## 功能列表

- 流式对话（SSE）：打字机效果逐字渲染 LLM 回复
- 多消息分支：单节点内可编辑/重试生成新回复
- 模型选择：对话页内切换 LLM（panel 抽屉），从导航栏 middle（当前模型名 + ▾）点击触发
- 自动续聊：从笔记节点跳入对话时，自动用笔记内容作为上下文发起新对话
- 消息编辑：编辑用户消息后重发，仅影响当前节点
- 消息复制：长按复制单条消息
- **空白分支自动 title 持久化**（2026-06-29）：空白分支（A 模式）chat 流式结束后由 `AutoTitleController`（`lib/ui/features/chat/auto_title_controller.dart`，按 `nodeId` family）自动 LLM 生成 title 并写入 DB + refresh tree；`ref.keepAlive()` 保活，user 提前 pop 也能后台跑完（详见 [ADR-018](../../DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式)）
- iOS 后台中断恢复：App 切后台时 `beginBackgroundTask` 续命 30s；切回扫描磁盘 `<!-- streaming -->` 标记触发自动重发，串行排队（仅 iOS，详见 [ADR-015](../../DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界)）
- 联网搜索开关（`ChatComposer`）：落在**独立工具毛玻璃 pill** 内（与深度思考并列），禁止裸字叠气泡
  - 参数：`webSearchEnabled`（bool，当前开关状态）、`webSearchSupported`（bool，当前模型是否支持）、`onWebSearchToggle`（VoidCallback?，null 时不显示按钮）
  - 图标：地球图标，开启时蓝色、关闭时灰色；不支持时灰色不可点击，tooltip 提示"当前模型不支持联网搜索"
- 深度思考开关（`ChatComposer`，2026-07-06）：与联网搜索 chip 完全镜像的模式，紧挨在联网搜索右侧。两种形态互斥显示：
  - **opt-in**（`ModelCapability.deepThinking`）：显示可点击的"深度思考"chip，离散色 + brain icon (AppIcons.brain)，点开变紫。命中模型：DeepSeek V4-Pro / V4-Flash / `deepseek-reasoner` / KIMI k2.6 / k2.5 / MiniMax-M3。M3 必须显式传 `thinking: true`（MiniMax-M3 默认**不**输出 `reasoning_content`，user 不开 toggle 就看不到思考）；KIMI 关闭时显式发 `thinking: {type: 'disabled'}`。
  - **always-on**（`ModelCapability.alwaysThinking`）：服务端锁定默认开，user 关不掉。UI 显示只读灰色"深度思考（默认）"chip，按下无响应。命中模型：豆包 Seed 2.1-pro / 2.1-turbo（方舟 ARK 服务端默认开启 thinking 且无法关闭）。
  - 不支持 toggle 的模型（gpt-4o / claude-3 / claude-3.5 / mimo / gemini / custom）chip 不显示——既不浪费横向空间也不误导用户以为"关掉了"实际根本没开。
  - 协议层：OpenAI 兼容路径 `deepThinking && !hasImage` 时按 provider 走不同 `thinking` 字段形态（豆包 `{type: 'enabled'}` / MiniMax `true` 布尔 / KIMI `{type: 'enabled'}`）；关闭时 KIMI 显式下发 `{type: 'disabled'}`；Claude / Anthropic 路径（DeepSeek）走 `ClaudeClient`，开启注入 `{type: 'enabled'}`、关闭显式注入 `{type: 'disabled'}`。**思考与图片互斥**：含图片的请求自动关 thinking（图片优先），避免 MiniMax-M3 / KIMI 思考+图片同请求 4xx。stream 解析端 `_extractClaudeDelta` 显式判断 `delta.type` 分支：`thinking_delta` 读 `delta.thinking` 进 `reasoning`、`text_delta` 读 `delta.text`、`content_block_start` 同步处理 `type=thinking` block（见 [ADR-021](DECISIONS.md#adr-021-claudeclient-流式响应补全-thinking_delta-解析) 与 [ADR-022](DECISIONS.md#adr-022-per-session-深度思考开关--双-modelcapability-区分)）。
  - 状态：per-session in-memory、**不持久化**——关闭聊天页或切换模型自动重置为 false。
- 图片上传（`ChatComposer`，2026-07-05；2026-07-17 布局）：**`+` 在输入 pill 内侧最左**（prefix），支持的模型可点；不支持 / 流式中弱化
  - 参数：`onImagePick`（VoidCallback?，null 时不显示）、`imageSupported`（bool，模型是否支持 vision）、`selectedImageData`/`selectedImageMimeType`（已选图片）
  - 点击弹出 CupertinoActionSheet：拍照（`ImageSource.camera`）/ 从相册选择（`ImageSource.gallery`）
  - 选中后输入 pill **上方**独立预览玻璃条（`_ImagePreview`），支持移除
  - 发送时 `imageData`/`imageMimeType` 随消息传入 `ChatController.sendUserMessage` → `ChatTaskService.startTask` → `_buildMessages` 构建多模态 content（按 client 类型生成对应协议格式：OpenAI `image_url` / Anthropic `image` / 豆包 Responses `input_image`）
  - 空文本兜底：只发图片不写文字时，`sendUserMessage` 自动填充默认提示 `'描述这张图片'`；`buildMultimodalContent` 也做同样兜底，避免豆包等模型因空 `input_text` 返回 400
  - 模型 vision 能力自动检测：`ModelCapability.vision` + `model_capabilities.dart` 推断（gpt-4o / claude-3 / gemini / kimi-k2.5 / kimi-k2.6 / minimax-m3 / mimo-v2.5 / doubao-seed-2-1-pro / doubao-seed-2-1-turbo 等）；UI 与发送侧均有 `inferCapabilities` fallback，**DeepSeek V4 公开 API 不支持视觉**，不在 vision 列表内
  - iOS 权限：`NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription`
- 消息时间戳（2026-07-04）：assistant 消息气泡上方显示人类可读时间，`formatMessageTime` 支持 4 级格式（今天 `HH:mm` / 昨天 / 月日 / 跨年全日期）
- Chat-to-Note（2026-07-04）：assistant 消息"存为笔记"按钮（`MessageBubble.onSaveToNote` 回调），自动用当前主题创建笔记并跳转 `NoteEditorScreen`
- 查看原始 Markdown（2026-07-05）：更多菜单入口，底部 sheet 展示当前对话的 `session.md` 原始文件内容（等宽字体），支持一键复制到剪贴板
- 模型名显示（2026-07-06）：assistant 消息气泡标题显示 LLM 模型名（如 `助手 · gpt-4o`），同对话内切换模型后每条回复标注实际使用的模型；`session.md` 消息头新增可选 `· modelId` 字段，向后兼容旧消息
- **聊天页祖先链面包屑**（2026-07-09）：节点深埋树里、导航栏只显当前节点标题，不知在第几层。聊天页消息列表顶部加面包屑 `主题 / 主题名 / 祖先1 / … / 当前节点`，沿 `parentId` 回溯（`_buildCrumbs` 读 `themeDetailControllerProvider(themeId).nodes`），点任意祖先段经 `GoRouter.go(path)` 声明式跳回。末段（当前节点）不可点。**不放**主题详情页（tree 页平铺无层级，面包屑无意义）。涉及 4 个运行时崩溃修复（initState/dispose 改 provider 断言、go_router 栈摘空、暴露内部 ULID），详见 [spec](specs/chat-breadcrumb-nav.md) + [war-story](../../war-stories/flutter/2026-07-09-chat-breadcrumb-nav-crashes.md）。
- **选区工具栏分支 + 复制即清选区**（2026-07-09）：选区菜单（复制 / 全选 / 分支 / 放入抽屉）新增「分支」按钮，从活跃选区即时分支——读取 `branchFromSelectionProvider`（chat_screen 挂载时注册 `_branchFromSelection` 回调，卸载时清空），此刻选区一定还在，直接消费，不经过全局残留选区。复制 / 放入抽屉 / 分支三个"消费选区"的动作执行后清除全局选区状态（`currentSelectionProvider`），避免分支预览残留已取消的选区；「更多 → 分支」改传 `selectedText: null`，不再读残留选区。根因与修法见 [war-story](../../war-stories/flutter/2026-07-09-chat-selection-residual-branch-preview.md）。
- **分享问答对为图片**（2026-07-17 分片改进）：`ShareService`（`lib/data/services/share_service.dart`）将对话消息构建 `ShareCardWidget` → overlay 布局 → 高清截图。超 GPU 纹理上限（4096px）时自动纵向分片 + `package:image` 软件拼接，避免长聊截断。清晰度下限 1.5（不再压到 0.2 糊字），最终输出长边上限 24576px 防 OOM。`RepaintBoundary` 在 Opacity 内侧保证导出图不受 0.02 透明度影响。
- **碎片系统完整国际化**（2026-07-21）：`clips_sheet.dart`、`clips_management_screen.dart`、`clips_context_menu.dart` 所有硬编码中文替换为 l10n 调用（`clipsTitle`/`clipsManage`/`clipsEmpty`/`clipsClearAll`/`clipsBranch`/`clipsSaveToDrawer` 等）。

## 代码文件

| 文件 | 角色 | 行数 |
|------|------|------|
| `lib/ui/features/chat/chat_screen.dart` | 对话页主屏幕（消息列表 + 输入框） | 930 |
| `lib/ui/features/chat/chat_controller.dart` | UI 同步层 StateNotifier：watch Riverpod state / 绑定 Widget / 发送触发委托给 ChatTaskService | 重构后缩减 |
| `lib/ui/features/chat/chat_screen_launch_params.dart` | 启动参数（autoTriggerReply 等） | 16 |
| `lib/ui/features/chat/widgets/model_selector_panel.dart` | 模型选择抽屉 | - |
| `lib/data/services/chat_task_service.dart` | 服务层调度器：串行重发 queue + generation token + bridge.begin/end 包裹 + resumeInterrupted / cancelResumeQueue 入口 | 新增 |
| `lib/data/services/background_task_bridge.dart` | iOS `beginBackgroundTask` MethodChannel 客户端（`begin()` / `end(taskId)`），可注入 | 新增 |
| `ios/Runner/BackgroundTaskHandler.swift` | Swift MethodChannel handler + `UIApplication.beginBackgroundTask` 调用 + `expirationHandler` 释放 | 新增 |
| `lib/ui/core/shared/chat_composer.dart` | 双条毛玻璃底栏：输入 pill（+ / 文本）+ 右侧圆钮（碎片/发送）+ 工具 pill（联网/深度思考） | - |
| `lib/ui/core/shared/chat_list_view.dart` | 消息列表；不铺实心 pageBg；`bottomContentInset` 给浮层 composer 留白 | - |
| `lib/ui/core/shared/message_bubble.dart` | 消息气泡（user + assistant，GptMarkdown 渲染 + LaTeX 注入 + 每张表格独立工具栏：复制/全屏按钮） | 388 |
| `lib/ui/features/chat/widgets/chat_markdown_sheet.dart` | 查看原始 Markdown 底部 sheet（展示 session.md 内容 + 复制按钮） | 135 |
| `lib/ui/core/shared/markdown_builders.dart` | GptMarkdown 自定义构建器（含 `buildLatex`——`FittedBox(scaleDown)` 包裹 `Math.tex`） | 61 |
| `lib/ui/features/chat/auto_title_controller.dart` | 空白分支流式结束后后台补 title：3 次重试（指数退避 1s/2s/4s）+ 调 LLM + 写 DB + refresh tree；`ref.keepAlive()` 保活（2026-06-29 新增） | 新增 |
| `integration_test/chat_async_recovery_test.dart` | 后台中断恢复集成测试（4 个 testWidgets：findInterrupted / resumeInterrupted / cancelResumeQueue / bridge.begin-end 配对） | 新增 |
| `lib/ui/core/widgets/thk_breadcrumb_nav.dart` | 通用面包屑组件：`BreadcrumbSegment`（label + 可选 goPath / routeName）+ `ThkBreadcrumbRow`（分隔符 `/`、末段不可点）；`_popToRoute` 按 goPath 走 `GoRouter.go()` / 否则 `popUntil` | 复用 |
| `integration_test/chat_breadcrumb_test.dart` | 面包屑回归测试：进聊天页不崩 + 逐段点击回跳正确 + 全程无 provider/go_router 崩溃（纯导航、不依赖 LLM） | 新增 |

## 子文档

- 集成测试 — 对话流式（含流式边界用例 / 空消息 / 快速连续发送）：[docs/_shared/integration-testing/chat-streaming.md](../../_shared/integration-testing/chat-streaming.md)
- 集成测试 — 空白分支自动 title 持久化（case 9.4 DB check / 9.5 空白 E2E / 9.6 提前 pop 后台完成，归属 [branch-creation 测试矩阵](../../_shared/integration-testing/branch-creation.md) 第 3.5 节，2026-06-29）：[docs/_shared/integration-testing/branch-creation.md](../../_shared/integration-testing/branch-creation.md)
- 集成测试 — 后台中断恢复（iOS only，ChatTaskService + BackgroundTaskBridge）：[docs/_shared/integration-testing/chat-async-recovery.md](../../_shared/integration-testing/chat-async-recovery.md)
- 集成测试总论 / fixtures / helpers：[docs/_shared/integration-testing/README.md](../../_shared/integration-testing/README.md)
- 聊天页祖先链面包屑（spec）：[specs/chat-breadcrumb-nav.md](specs/chat-breadcrumb-nav.md)

## 关键设计原则

- **流式优先**：所有 LLM 调用走 SSE，UI 不阻塞；失败可重试且断点续传
- **节点作用域**：消息编辑/重试只影响当前节点，不污染父节点（参考 storage-format 双向链）
- **autoTriggerReply 启动参数**：笔记详情跳对话时携带笔记内容，controller 初始化时自动发起一轮
- **Provider 解耦**：模型配置由 LLM 模块提供，chat 模块只读不写
- **聊天记录持久化**：通过 ChatRepository（domain 层）写入 SQLite，会话元数据 + 消息按节点 ID 索引
- **分层：UI 同步层 vs 服务层**：`ChatController` 只负责 watch Riverpod state / 绑定 Widget；后台中断恢复（串行重发 / bridge.begin-end 包裹 / generation token）在 `ChatTaskService` 里。续传/重发决策**不下沉到 widget**。
- **disk-first 中断恢复**：磁盘 `session.md` 的 `<!-- streaming -->` 标记是中断判定唯一真相源。`SessionStore.findInterrupted()` 扫描 → `ChatTaskService.resumeInterrupted()` 入队 → 串行重发。`ChatTaskService` 不自维护"中断状态"。
- **session.md 缺失自愈（2026-07-17）**：`getSessionPathForNode` 发现节点目录有匹配的 `node.meta.json` 但无 `session.md` 时（例如导出时跳过带 `<!-- streaming -->` 的会话后再恢复），调用 `NodeStore.ensureSessionMarkdownIfMissing` 按 meta 写入最小空会话并继续，避免 `Session path not found`。**不恢复历史消息**。日志：`get_session_path.auto_healed`。
- **autoDispose + keepAlive 双标记范式**（2026-06-29）：任何"与 widget 生命周期无关、需后台跑完任务"的 Notifier，用 `AsyncNotifierProvider.autoDispose.family<...>` + `build()` 内调 `ref.keepAlive()`。只走 `autoDispose` 不行——widget unmount 时 Notifier 被 dispose，正在跑的 Future 被取消。`keepAlive()` 不是替代 autoDispose，而是补充："我声明自己保持 alive"。适用对象：`AutoTitleController` 类后台任务 Notifier。**不适用对象**：UI 同步层 controller（`ChatController`）、树形数据 controller（`ThemeDetailController`）——它们应当进入时构造、离开时销毁。详见 [ADR-018](../../DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式)。
- **30s 边界**：短回复（< 30s）由 iOS `beginBackgroundTask` 真在后台跑完、切回时流仍存活 → 无缝接续渲染；长回复（≥ 30s）iOS 挂起 process、流被冻 → 检测到流已关闭 → 自动重发。**桥接可注入**（`BackgroundTaskBridge` 可 override，test 用 `_CountingBridge` 计数验证 begin/end 配对）。
- **串行排队**：切回时扫到 N 个未完成 → 一次 1 个重发，跑完/失败/用户停止 才下一个。`generation` token 自增保证 cancel 后正在跑的任务能被 loop 退出条件识别。

## 维护要点

- 改 chat_screen 布局前必读 [notes 模块 README](../notes/README.md)，两者 UI 风格共用 Large Title + slivers
- **键盘与底栏空隙（2026-07-16）**：iOS `_MainShell` / Android `AndroidNavigationShell` 在键盘弹起时**隐藏底部 tab**，让 shell 内页面用真实 `viewInsets` 贴键盘。**禁止**在 `ChatScreen` 里用 `View.viewInsets` 覆盖恢复完整键盘高度——Chat 在 shell `Expanded` 内时会与 tab 占位叠加，在联网搜索等工具行下方挤出 tab 高空白。详见 [CHANGELOG/2026-07-16](../../CHANGELOG/2026-07-16-ios-chat-keyboard-gap.md)。
- **Warm Paper 毛玻璃输入（2026-07-17）**：`ChatScreen` 用 **Stack** 铺满 `ChatListView` + 底部浮层 `ChatComposer`；列表不铺不透明 `pageBg`，才能 `BackdropFilter` 磨到气泡。composer = **输入 pill**（更透）+ 右侧独立圆钮 + **工具 pill**（芯片落在玻璃上）。顶栏保持不透明 `AppGlass.navBarBackground`。详见 [CHANGELOG/2026-07-17](../../CHANGELOG/2026-07-17-warm-paper-glass.md) 与 [design-system](../../_shared/design-system.md)。
- 新增 LLM provider 时，模型选择 panel 会自动出现（无需改 chat 代码），但要在 llm 模块注册 provider
- 流式断网/超时处理：参考 `integration_test/chat_streaming_test.dart` 的边界用例
- 注意 `autoTriggerReply` 启动参数与 notes 模块的"从笔记续聊"按钮联动
- **LaTeX 公式渲染**：assistant 消息走 `lib/ui/core/shared/markdown_builders.dart` 的 `buildLatex`（`SelectableAdapter` + `Math.tex` + `FittedBox(scaleDown)`，解决 `flutter_math_fork 0.7.4` 的 `RenderLine` 溢出）。其他 4 处 `GptMarkdown` 调用（`lib/main.dart`、`lib/ui/features/notes/note_detail_screen.dart`、`lib/ui/core/shared/share_card_widget.dart`、`lib/ui/features/settings/tts_player_screen.dart`）暂未注入 `latexBuilder`，新增 LaTeX 上下文时需主动复测。详见 [war-story](../../war-stories/ui-ux/2026-06-18-gptmarkdown-latex-renderline-overflow.md) 与 [CHANGELOG/2026-06-18](../../CHANGELOG/2026-06-18-latex-overflow-fix.md)。

## 相关历史

- 2026-05：聊天流式响应首次落地（SSE + Riverpod AsyncNotifier）
- 2026-05：模型选择 panel 加入，支持运行期切换
- 2026-05：与笔记模块打通双向跳转（笔记→自动续聊、对话→引用笔记）
- 2026-06：消息编辑/重试功能上线
- 2026-06-22：`ChatController` 重构为 UI 同步层（移除流式状态机）+ `ChatTaskService` 服务层承担后台中断恢复（iOS only）——参见 [ADR-015](../../DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界) + [集成测试 spec](../../_shared/integration-testing/chat-async-recovery.md)
- 2026-06-29：`AutoTitleController` 上线（`lib/ui/features/chat/auto_title_controller.dart`，246 行）—— 空白分支流式结束后自动 LLM 补 title 并持久化，与 widget 生命周期解耦（`ref.keepAlive()`），user 提前 back 回 tree 也能后台完成。3 层守卫防 LLM 覆盖手动 title。集成测试 case 9.4 (DB check) / 9.5 (E2E) / 9.6 (提前 pop 后台完成) 加到 [branch-creation](../../_shared/integration-testing/branch-creation.md) 第 3.5 节。详见 [ADR-018](../../DECISIONS.md#adr-018-Notifier-后台任务保活autoDispose--build-内-refkeepalive-双标记范式) + [war-story](../../war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md) + [CHANGELOG/2026-06-29](../../CHANGELOG/2026-06-29-auto-title-persistence.md)。
- 2026-07-06：模型名显示——`SessionMessage` 新增 `modelId` 字段，`session.md` 消息头扩展可选 `· modelId`，`MessageBubble` 从 `llmProvidersProvider` 查模型名并显示在 assistant 标题后。详见 [CHANGELOG/2026-07-06](../../CHANGELOG/2026-07-06-chat-model-in-bubble.md)。
- 2026-07-06：DeepSeek / MiniMax 思维链输出 + Per-session 深度思考开关 + 重发 bug 修复——`_extractClaudeDelta` 补全 `thinking_delta` 解析（修复 DeepSeek-reasoner / V4 等看不见 thinking 的零回报 bug，见 [ADR-021](../../DECISIONS.md#adr-021-claudeclient-流式响应补全-thinking_delta-解析)）；新增 `ModelCapability.deepThinking` / `ModelCapability.alwaysThinking` 双 cap 区分（opt-in / 服务端锁定默认开），ChatComposer 加深度思考 chip 镜像 web search 模式；`retryLastMessage` 抽 `_triggerLlmStream` helper，**重发不再重复追加 user 消息**（修复 session.md 每次重发多一份 user 的 bug，见 [ADR-023](../../DECISIONS.md#adr-023-retrylastmessage-重构避免重发重复追加-user-消息)）。详见 [CHANGELOG/2026-07-06](../../CHANGELOG/2026-07-06-deepthinking-toggle.md)。
- 2026-07-08：模型能力集中校正——KIMI k2.6/k2.5 加入深度思考（关闭显式 `disabled`）；DeepSeek 关闭思考显式发 `disabled`；MiniMax-M3 / KIMI 思考+图片互斥（`!hasImage` 守卫）；KIMI 白名单收窄到 k2.6/k2.5、MiniMax 到 M3；Seed-2.0-pro 联网模型级屏蔽；UI/发送侧 vision 加 `inferCapabilities` fallback；DeepSeek V4 公开 API 不支持视觉已回退视觉代码。详见 [CHANGELOG/2026-07-08](../../CHANGELOG/2026-07-08-model-capabilities-and-thinking-fixes.md)。
- 2026-07-08（补丁）：Seed-2.0-pro 模型 ID 修正——白名单 `doubao-seed-2-0-pro` → `doubao-seed-2-0-pro-260215`（ARK API 要求带日期后缀，旧 ID 调用失败）；`isModelWebSearchUnsupported` 改为仅屏蔽无日期后缀的旧模型（有后缀的 `260215` 版本支持联网）；新模型走 Responses API（`DoubaoResponsesClient`）而非 legacy Chat Completions。
- 2026-07-09：聊天页祖先链面包屑——消息列表顶部加 `主题 / 主题名 / 祖先 / 当前` 面包屑，沿 `parentId` 回溯（[spec](specs/chat-breadcrumb-nav.md)）。修 4 个运行时崩溃：①initState 同步写 provider（`addPostFrameCallback` 延迟）②dispose finalize 期改 provider（`Future.microtask` 延迟 + 闭包守卫）③go_router 路由误用 `popUntil` 摘空栈（改 `GoRouter.go(path)` 声明式回跳）④面包屑 `go()` 不传 extra 导致 `widget.title` 回退成 `$id/$id` 暴露内部 ULID（当前节点优先用 `current!.title`，去掉 `/` 误检）。集成测试 `chat_breadcrumb_test.dart` 逐段点击验证。`+1: All tests passed!`。详见 [war-story](../../war-stories/flutter/2026-07-09-chat-breadcrumb-nav-crashes.md) + [CHANGELOG](../../CHANGELOG/2026-07-09-chat-breadcrumb-nav.md)。
- 2026-07-09：选区文本在「创建分支」预览残留修复——选中文字→复制 / 放入抽屉后，点「更多 → 分支」仍预览旧文本。`currentSelectionProvider` 故意保留上次选区（支持"选中 → 分享为图片"），但消费选区后未清除导致残留。新增选区工具栏「分支」按钮（读 `branchFromSelectionProvider`，chat_screen 挂载时注册 `_branchFromSelection`，从活跃选区即时分支）；复制 / 放入抽屉 / 分支消费即清 `currentSelectionProvider`；「更多 → 分支」改传 `selectedText: null`。`branchFromSelectionProvider` 的注册 / 清空复用面包屑崩溃的 `addPostFrameCallback` / `Future.microtask` 延迟修法（initState / dispose 同步写 provider 会触发 Riverpod 构建期断言）。详见 [war-story](../../war-stories/flutter/2026-07-09-chat-selection-residual-branch-preview.md)。
- 2026-07-17：Warm Paper Glass 壳层 + 双条毛玻璃 composer（P2）——见 [CHANGELOG/2026-07-17-warm-paper-glass.md](../../CHANGELOG/2026-07-17-warm-paper-glass.md)。
- 2026-07-17：分享图片超长分片拼接——`ShareService` 单次 `toImage` 超 GPU 纹理上限（4096px）时自动纵向分片 + `OffsetLayer.toImage(rect)` + `package:image` 软件拼接；清晰度下限从 0.2 提升到 1.5，最终输出长边上限 24576px 防 OOM。详见 `lib/data/services/share_service.dart`。
- 2026-07-17：session.md 缺失自愈——`ensureSessionMarkdownIfMissing` + `getSessionPathForNode`；meta 在、session 丢时补空会话（见上文维护要点）。
