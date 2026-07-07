# 架构决策

> **本文件定位**：项目的"架构 DNA"——记录所有 high-level 的技术决策及理由。
> **维护者**：人类 + AI 共同维护。任何重大技术变更（换框架、换状态管理、换存储）必须先在这里记录决策。
> **目录树**部分由人类 + AI 共同维护；其他部分同样由人/AI 维护。

---

## 1. 技术决策（高优先级）

**所有架构决策的完整理由、影响范围、实施步骤见 [`docs/DECISIONS.md`](DECISIONS.md)——用 `## ADR-NNN` 编号定位（格式约定见 [ADR-011](DECISIONS.md#adr-011-文档治理单一全局决策文件--纯文段格式)）。**

本节只列"选型类别"作为锚点（AI 接到任务时用来 cross-check "这事跟哪个 ADR 相关"），决策内容一律跳到 DECISIONS.md：

- 状态管理 → ADR-001（Riverpod）
- 路由 → ADR-002（go_router）
- UI 框架 → ADR-003（纯 Cupertino）
- 存储分层 → ADR-004（Markdown 正文 + SQLite 元数据）
- 写入队列 → ADR-005（FileWriteQueue 单写者）
- LLM 调用 + 密钥 → ADR-006（SSE + flutter_secure_storage）
- Markdown 渲染 → ADR-007（gpt_markdown）
- 国际化 → ADR-008（flutter_localizations + intl）
- 本地搜索 → ADR-009（SQLite FTS5 + BM25）
- 节点色与主题色解耦 → ADR-010
- DB 一致性保障 → ADR-014（disk-first + 启动同步）
- iOS 后台中断恢复 → ADR-015（disk-first + 自动重发 + 30s 边界）

> **决策变更流程**：新增 → DECISIONS.md 追加新 ADR；推翻旧决策 → 旧 ADR 加"已取代"段 + 新开 ADR，**不原地改**（详细理由见 ADR-011）。

---

## 2. 文档地图（AI 工作前必读）

> **新进入项目的 AI**：按下面顺序读，5 分钟建立项目全貌。
> **`pubspec.yaml` 是什么**：Flutter 项目的依赖清单（相当于 npm 的 `package.json` / iOS 的 `Podfile`），项目名/版本/三方库/字体/资产都在这里。

### 第一步：项目元信息（1 分钟）
- [`docs/PROJECT.md`](PROJECT.md) — 项目名/平台/构建命令/存储方式/LLM
- [`docs/FEATURES.md`](FEATURES.md) — 所有功能状态一览（一行一个功能，跳转到 README/Visual/代码）

### 第二步：架构 DNA（2 分钟）
- 本文件 § 1 选型类别锚点 + [`docs/DECISIONS.md`](DECISIONS.md) 完整决策（每个 ADR 一节文段，rg `## ADR-` 定位）
- 本文件 § 4 关键依赖（与 `pubspec.yaml` 同步）
- 本文件 § 3 代码结构 - 关键类型子段（领域实体/数据模型/服务/控制器四类）

### 第二步半：硬性必读清单（AI 改模块前必读）

> **防偷懒原则**：单靠 README 顶部提示不能 100% 防 AI 漏读。**真正起作用**的是：AI 接下任务后，**主动** cross-check 下面的清单。

| 要改这个 | 必读 | 为什么 |
|----------|------|--------|
| 主题/节点色/调色板 | [`docs/modules/themes/README.md`](modules/themes/README.md) + [`docs/_shared/design-system.md`](_shared/design-system.md) | 节点色与主题色完全解耦，改色不是改一个变量 |
| 笔记读写/存储/刷新 | [`docs/modules/notes/README.md`](modules/notes/README.md) + [`docs/modules/notes/CHANGELOG.md`](modules/notes/CHANGELOG.md) § 3 | `NoteStore` 是唯一写盘入口；全局版本号机制不能动 |
| 对话/流式回复 | [`docs/modules/chat/README.md`](modules/chat/README.md) + [DECISIONS.md ADR-006](DECISIONS.md#adr-006-llm-调用-sse-流式--api-key-走-flutter_secure_storage) | SSE 事件顺序/心跳处理有约束 |
| LLM Provider/Key | [`docs/modules/llm/README.md`](modules/llm/README.md) + [DECISIONS.md ADR-006](DECISIONS.md#adr-006-llm-调用-sse-流式--api-key-走-flutter_secure_storage) | API Key 必走 secure storage，不能落地明文 |
| 全文搜索/跳转 | [`docs/modules/search/README.md`](modules/search/README.md) | 跨模块跳转靠 `routeName + args`，不能直接 import UI |
| 设置/生物认证/TTS/分享 | [`docs/modules/settings/README.md`](modules/settings/README.md) + `docs/modules/settings/specs/2026-06-05-语音播放功能-design.md` | TTS 是 iOS 原生通道；`AuthGate` 未上线前不要提交 Face ID 启用代码 |

> **AI 接到任务后的第一动作**：识别任务涉及哪些模块 → 交叉对上表 → 读对应 README 顶部"AI 工作前必读"段 → 再动手。

### 第三步：按需钻入
- **想了解某个模块的功能/代码/视觉** → `docs/modules/<name>/README.md`
- **遇到设计/视觉问题**（颜色/字体/组件用法）→ [`docs/_shared/design-system.md`](_shared/design-system.md)
- **遇到存储/i18n/分支流程等横向问题** → `docs/_shared/`
- **遇到某个功能的设计/迁移历史** → `docs/CHANGELOG/YYYY-MM-DD-简述.md`
- **遇到技术债** → `docs/TECH-DEBT.md`

### 第四步：跨 IDE 知识
- **`.qoder/`、`/.agents/`、`.cursor/`**：IDE/Qoder 的元信息目录
  - `.qoder/repowiki/` = AI 自动生成的项目 wiki（**docs/ 的镜像缓存，AI 不手改**）
  - `.qoder/rules/` `.qoder/skills/` = AI 行为规则 + 可调用技能（横切，AI 工作流）
  - `.agents/skills/` = 项目级 skills（跟仓库走，全员共享——只留项目相关的）
  - `.cursor/rules.md` = 旧机制，**已删除**（2026-06-10）
  - **不要手改 .qoder/ 下的内容**——这些是 IDE 自动管理的

---

## 3. 代码结构

```
lib/
  domain/                    # 领域实体：Theme, Node, ids
  data/
    models/                  # 数据模型：LLM 配置、Meta 序列化
    services/                # 核心服务：LLM 客户端、文件写入、搜索、数据库
    stores/                  # Riverpod StateNotifier：Theme/Node/Session/Note 状态管理
  ui/
    core/
      shared/                # ChatComposer, ChatListView, MessageBubble（对话 UI 组件）
      widgets/               # ThkButton, ThkAlert, ThkTextField 等基础组件
      theme/                 # AppColors, AppIcons, AppTheme（设计系统）
    features/
      themes/                # ThemeListScreen, ThemeDetailScreen（主题列表 + 树视图）
      chat/                  # ChatScreen, ChatController（对话 + 流式回复）
      notes/                 # NoteBrowseScreen, NoteEditorScreen, NoteDetailScreen, NoteSelectScreen, NodeLocationPicker, GenerateTitleScreen（笔记）
      lab/                   # LabPlaceholderScreen + KeywordRanking + ThinkingCollision + UserInputSummary（实验室功能）
      llm/                   # LlmProvidersScreen, LlmProviderDetailScreen（LLM 配置）
      settings/              # SettingsScreen（设置页，通过搜索页齿轮按钮进入，非 tab）
      search/                # SearchScreen（全文搜索）
      doc_split/             # DocSplitInputScreen（文档拆分工具，独立入口）
  l10n/
    generated/               # 自动生成的国际化文件
```

### Tab 结构（4 tab）

底部 tab bar 共 4 项：搜索 / 主题 / 笔记 / Lab。Settings 从 tab 移至搜索页顶栏右上角齿轮按钮（`context.push('/settings')`），作为外层 `GoRoute` 与 `/llm-providers` 同层。

### 模块职责（精简版，详细见 `docs/modules/<name>/README.md`）

| 模块 | 代码路径 | 文档路径 | 职责 |
|------|----------|----------|------|
| Domain | `lib/domain/` | (无独立 README) | Theme / Node 实体、ID 生成 |
| Data Services | `lib/data/services/` | (无独立 README) | LLM 客户端、文件写入、搜索、数据库 |
| Data Stores | `lib/data/stores/` | (无独立 README) | Riverpod StateNotifier 状态管理 |
| UI Core | `lib/ui/core/` | (无独立 README) | 共享组件、widgets、主题、路由 |
| Themes | `lib/ui/features/themes/` | `docs/modules/themes/` | 主题列表 + 树视图 |
| Chat | `lib/ui/features/chat/` | `docs/modules/chat/` | 对话 + 流式回复 |
| Notes | `lib/ui/features/notes/` | `docs/modules/notes/` | 笔记浏览/编辑/详情 |
| Lab | `lib/ui/features/lab/` | `docs/modules/lab/` | 实验室功能（关键词排行榜、输入摘要等） |
| LLM | `lib/ui/features/llm/` | `docs/modules/llm/` | LLM Provider 配置 |
| Settings | `lib/ui/features/settings/` | `docs/modules/settings/` | 设置页（通过搜索页齿轮进入，非 tab） |
| Search | `lib/ui/features/search/` | `docs/modules/search/` | 全文搜索 |
| DocSplit | `lib/ui/features/doc_split/` | (无) | 文档拆分工具（独立入口） |

### 关键类型

> "角色" 分为：领域实体 / 数据模型 / 服务 / 控制器。详细类型请用 codegraph 查询，本表只列"锚点"。

| 类型 | 角色 | 文件 | 说明 |
|------|------|------|------|
| `Theme` | 领域实体 | `lib/domain/theme.dart` | 一个"主题"=一棵节点树（id, title, createdAt, rootNodeId） |
| `Node` | 领域实体 | `lib/domain/node.dart` | 树上一个节点=一条对话（id, parentId, title, themeId, isNote） |
| `LlmProviderConfig` | 数据模型 | `lib/data/models/llm_provider_config.dart` | LLM Provider（API Key、Base URL、Model ID） |
| `AppDatabase` | 服务 | `lib/data/services/app_database.dart` | SQLite 数据库单例（关系/索引/FTS5 搜索） |
| `FileWriteQueue` | 服务 | `lib/data/services/file_write_queue.dart` | 单写者队列（并发写盘安全、流式追加原子化） |
| `ChatController` | 控制器 | `lib/ui/features/chat/chat_controller.dart` | 对话页 StateNotifier（消息列表/流式订阅/重试/图片数据转发） |
| `ChatTaskService` | 服务 | `lib/data/services/chat_task_service.dart` | 后台中断恢复调度器（串行重发 queue + generation token + bridge.begin/end 包裹） |
| `BackgroundTaskBridge` | 服务 | `lib/data/services/background_task_bridge.dart` | iOS `beginBackgroundTask` MethodChannel 客户端（可注入，test 用 `_CountingBridge` 计数验证） |
| `ThemeDetailController` | 控制器 | `lib/ui/features/themes/theme_detail_controller.dart` | 树视图 StateNotifier（节点展开/选中/拖拽） |

> **代码级查询**：跨模块的符号/调用关系请用 codegraph 工具查询，本表只列"锚点"。

---

## 4. 关键依赖

> 与 `pubspec.yaml` 同步；这里只列**有架构影响的**依赖。

| 依赖 | 用途 | 架构影响 |
|------|------|----------|
| `flutter_riverpod` | 状态管理 | 全局依赖 |
| `go_router` | 路由 | 声明式路由，deep linking |
| `sqflite` | SQLite | 本地数据库 + FTS5 |
| `flutter_markdown` / `gpt_markdown` | Markdown 渲染 | UI 层 |
| `flutter_math_fork` | LaTeX 公式渲染 | UI 层（chat 模块 `message_bubble.dart` 注入 `latexBuilder`——`FittedBox(scaleDown)` 包裹避免 `RenderLine` 溢出；详见 [CHANGELOG/2026-06-18](CHANGELOG/2026-06-18-latex-overflow-fix.md) 与 [war-story/ui-ux/2026-06-18](war-stories/ui-ux/2026-06-18-gptmarkdown-latex-renderline-overflow.md)） |
| `shared_preferences` | 轻量 KV | LLM Provider / 设置项 |
| `flutter_secure_storage` | 安全存储 | API Key、Face ID 相关 |
| `image_picker` | 拍照/相册选择图片 | chat 模块图片上传（iOS `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription`） |

---

## 5. 维护约定

- **新增技术决策**：在 [`docs/DECISIONS.md`](DECISIONS.md) 追加新 ADR（`## ADR-NNN` 格式），按时间顺序编号，不删旧条目。
- **推翻旧决策**：旧 ADR 加"已取代"段（写明"已被 ADR-XXX 取代"），新开 ADR 写新方案，**不原地改**。详见 ADR-011。
- **目录树/职责表**：人类 + AI 共同维护（不要每次重写，结构稳定时直接复制）。
- **关键类型表**：可以手动维护（仅列锚点类型，详细类型请用 codegraph 查询）。
- **AI 维护时机**：AI 修改代码时，若涉及以下情形**应主动询问用户是否在 DECISIONS.md 新增/追加 ADR**：
  - 新增/移除主要依赖
  - 替换状态管理/路由/存储方案
  - 引入新的架构模式（如 BLoC、MVI）
  - 关键库替换（如 ADR-007 的 Markdown 渲染库迁移）
