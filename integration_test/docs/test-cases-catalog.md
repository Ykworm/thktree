# ThkTree 集成测试用例目录（人话版 · 跨端：iOS / Android / macOS）

> **本文件就是 test case 本身（规范真源）**。每条 case = 人类级描述（前置 / 步骤 / 预期 / 边界 / 断言），Dart 是其实现（`integration_test/` 内对应文件），必须忠实于此。
> **开发者即需求方**：任何人可改本文件提交到主仓库，不必会写 Dart。改完本文件后，对应的 Dart 由实现者同步更新。
> **平台覆盖**用 ✅（可跑）/ ⚠️（能跑但桌面交互需适配或待测）/ ❌（该端无对应实现）。交互差异只在「差异」注一行，不另起一条。
> **设备**：iOS 用真机/模拟器 id；Android 用 emulator（如 `emulator-5554` / Pixel_8）；macOS 用 `-d macos`。
> **真实 LLM（强制）**：所有 case 必须注入真实 LLM key（`--dart-define-from-file=build/dart_define.json`）。**LLM 绝对禁止 mock**，无 key 不跑（runner 会拒绝）。
> **范围**：覆盖 `common/`（三端共用脚本）+ `platform/android/`（Android 独占）+ `platform/desktop/`（macOS 独占）+ `platform/recovery/`（iOS 独占）。
> **已知编译债**：`llm_error_retry / offline / theme_chat_e2e` 继承 `LlmClient` mock 历史债（`streamChatCompletion` 新增 `deepThinking/webSearch` 形参未跟上 → `invalid_override`），`flutter test` 编译失败，暂不能跑。这些是真实 case，修 mock 即可恢复（见末尾「别跑」段）。

---

## 零、测试数据：主题 + 文章（必读）

> **是什么**：`TREE-1`（3 主题 × 3 root × 3 分支 × 最深 4 层）跑的就是它——3 个主题，每个带 3 个 root chat、每条 root 一条分支链，每步有真实「文章/prompt」和期望回复，外加笔记 seed。
> **完整内容（人话 prose，人+LLM 可读可改）**：`test-data/topics.md`。
> **运行时真源**：`_support/topic_library.dart`（Dart 常量，TREE-1 实际加载它）。`topics.md` 是其可读镜像，两处同步。
> **3 主题速览**：① 深海科考：马里亚纳 ② 火星殖民：阿瑞斯一号 ③ 智网核心：赛博安全。
> ⚠️ **BC-1..BC-13（分支创建）不消费本数据**：它们用硬编码 prompt「请用一句话介绍你自己」，与主题库无关。只有 TREE-1 跑主题 + 文章。

---

## 一、分支创建（common/branch_creation_test.dart）

> 整文件 13 个 case，统一在 group `分支创建流程测试` 下，全部需真实 LLM（`--dart-define-from-file`）。
> **共同前置**：主题 tab → 建主题 → 建节点 → 进 chat → 发消息等流式回复完成。
> **平台覆盖**：iOS ✅（SelectionArea 长按选词）/ Android ✅（点 `branch_button`，B4 后不依赖 SelectionArea）/ macOS ❌（桌面端分支触发尚未实现，见 DESK 段 comprehensive B 为 TODO）。
> **差异（选区方式）**：
> - iOS：长按消息文本 → SelectionArea 选中词 + 弹上下文菜单 → 点「全选」选中全部。
> - Android：直接点 `branch_button`（无需 SelectionArea 长按）。
> - macOS：暂不支持（桌面分支入口未实现）。

### BC-1 · 选中文本 + raw 模式创建分支
- **Test case（人话）**：
  - 前置：注入真实 LLM 配置，需 `--dart-define-from-file`。
  - 步骤：主题 tab → 建主题 → 建节点 → 进 chat → 发「请用一句话介绍你自己」→ 等流式回复完成 → **选中消息文本**（iOS 长按+全选 / Android 点 branch_button）→ 选 `branch_mode_raw_option`（raw 模式）→ 点 `branch_mode_continue_button` → 进 TitleSuggestionScreen → 点「生成标题」等 LLM 候选（30s 内未出则手动填「Branch Title」）→ 点 `confirm_button`。
  - 预期：跳转到**新分支 ChatScreen**（出现 `branch_button` + `chat_input`）；新分支自动触发流式回复（等 `send_button` 回来，最多 120s）。
  - 边界/断言：raw 模式 = 分支直接以选中文本为起点，不摘要；标题候选是 `ThkListTile`（无固定文本，靠 `byType` 找第一个点）；若没配默认 title model 会弹 `model_sheet_*` action sheet 需点选一个。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：
  - iOS：`flutter test integration_test/common/branch_creation_test.dart -d <ios> --dart-define-from-file=build/dart_define.json --plain-name "选中文本 + raw 模式创建分支"`
  - Android：`flutter test integration_test/common/branch_creation_test.dart -d <android> --dart-define-from-file=build/dart_define.json --plain-name "选中文本 + raw 模式创建分支"`

### BC-2 · 选中文本 + summarize 模式创建分支
- **Test case（人话）**：同 BC-1 前置与选区，模式选 `branch_mode_summarize_option`（summarize：LLM 把选中文本**摘要**后作为分支起点）。预期：跳转新分支 ChatScreen，确认起点内容是摘要而非原文；摘要至少不报错、内容非空。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：iOS/Android 同 BC-1，仅 `--plain-name "选中文本 + summarize 模式创建分支"`

### BC-3 · 无选中文本 + raw 模式创建分支
- **Test case（人话）**：不选中文本，直接点 `branch_button` → raw 模式 → 继续 → 标题建议 → 确认。预期：空选区也能进分支（起点为空，靠后续对话填充）。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "无选中文本 + raw 模式创建分支"`

### BC-4 · 无选中文本 + summarize 模式创建分支
- **Test case（人话）**：不选中文本 + summarize 模式。预期：空选区下 summarize 仍走通（摘要对象为空时的兜底）。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "无选中文本 + summarize 模式创建分支"`

### BC-5 · 模式选择取消
- **Test case（人话）**：进到模式选择 sheet 后取消。预期：回到 chat、未创建分支、无残留 UI（不泄漏状态、不误建节点）。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "模式选择取消"`

### BC-6 · 标题选择取消
- **Test case（人话）**：进到标题建议页后取消。预期：回到 chat、未创建分支。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "标题选择取消"`

### BC-7 · LLM 失败 fallback
- **Test case（人话）**：用 mock / 失败 client 模拟 LLM 异常。预期：分支流程对 LLM 失败的兜底（不崩溃、给错误态或可重试）。测试点：异常路径稳定性（happy path 通过不代表异常路径稳）。本 case 用 mock，不强制真实 key，但文件顶层仍 `loadFromDefine`，保留 dart-define 更稳。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "LLM 失败 fallback"`

### BC-8 · A 模式：创建空 node（验证 DB 字段）
- **Test case（人话）**：A 模式 = 不设显式标题、由系统自动生成 title 的分支。预期：空 node 落库时 DB 字段完整（parentId / 层级 / 时间戳等）。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "A 模式：创建空 node（验证 DB 字段）"`

### BC-9 · A 模式：流式回复结束后自动生成 title
- **Test case（人话）**：分支创建后流式回复结束，系统自动 LLM 补 title 并持久化（与 widget 生命周期解耦，`ref.keepAlive`）。预期：auto-title 触发时机（流式 done 后）、标题非空。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "A 模式：流式回复结束后自动生成 title"`

### BC-10 · A 模式：自动 title 防抖只触发一次
- **Test case（人话）**：多次事件下 auto-title 只生成一次（防抖），不产生重复标题或重复 LLM 调用。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "A 模式：自动 title 防抖只触发一次"`

### BC-11 · A 模式：自动 title 持久化
- **Test case（人话）**：auto-title 生成后：tree 列表刷新能看到新标题；退出再进该 chat 仍显示新标题（已落库）。预期：标题持久化跨页面/跨进入有效。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "A 模式：自动 title 持久化（tree 刷新 + 第二次进入显示新 title）"`

### BC-12 · A 模式：提前 pop chat 后后台 title 任务仍能跑完
- **Test case（人话）**：流式未完/刚完时用户提前 back 回 tree，后台 auto-title 任务不被取消，能跑完并落库（ADR-018：`autoDispose` + `ref.keepAlive` 双标记）。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "A 模式：提前 pop chat 后后台 title 任务仍能跑完"`

### BC-13 · A 模式：用户预改 title 后跳过自动生成
- **Test case（人话）**：若用户在 auto-title 完成前手动改了 title，系统跳过自动生成、保留手动 title（3 层守卫防 LLM 覆盖手动 title）。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ❌
- **Related script**：`common/branch_creation_test.dart`
- **Run**：`--plain-name "A 模式：用户预改 title 后跳过自动生成"`

---

## 二、话题库树结构（common/topic_library_tree_note_test.dart）

### TREE-1 · 话题库 3×3×3×4 树生成 + 笔记写入
- **Test case（人话）**：
  - **结构**：3 主题 × 每主题 3 root chat × 每 root 一条分支链（深度 `MAX_DEPTH`，默认 2 = root→child）。完整 fixture 定义到 **3×3×3×4**（3 主题 / 3 root / 3 分支 / 最深 4 层）。env 可覆盖：`MAX_THEMES`(3) / `MAX_ROOTS`(3) / `MAX_DEPTH`(2)。
  - **每步**：建主题 → 建 root → 进 chat → 发消息等流式回复 → 选中文本 → 点 branch → raw 模式 → 生成标题 → 选候选 → 确认 → 进子 chat → 递归建下一层 → 返回上一层。
  - **预期/断言**：每主题 root 数 = `MAX_ROOTS`；派生节点数 = `MAX_ROOTS × MAX_DEPTH`；每个父节点恰好 1 子节点；所有 session **无 LLM error**；每 root 至少 1 条 assistant `done` 消息；总 chat 数 = `MAX_THEMES × MAX_ROOTS × (1 + MAX_DEPTH)`。
  - **笔记**：每主题下建笔记（`noteSeed.title/body` + 来源主题）并验证出现在笔记浏览。
  - **数据**：主题+文章+笔记 seed 见 `test-data/topics.md`（运行时真源 `_support/topic_library.dart`）。
  - **LLM**：默认真实 LLM（需 dart-define）；`MOCK_LLM=true` 可用 fake key 跑（只验结构/持久化）。超时 20 分钟。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅（桌面可跑 common/ 脚本）
- **差异**：三端共用同一脚本；iOS 选区用长按、Android 用 branch_button、macOS 桌面分支未实现故 TREE-1 在 macOS 实际走「不选区直接建子节点」路径（待确认 desktop 分支触发）。
- **Related script**：`common/topic_library_tree_note_test.dart`
- **Run**：
  - iOS/Android：`flutter test integration_test/common/topic_library_tree_note_test.dart -d <ios/android> --dart-define-from-file=build/dart_define.json --plain-name "话题库：3 主题 × 3 root chat × 3 分支（共 27 个子 chat）+ 笔记写入"`
  - macOS：`flutter test integration_test/common/topic_library_tree_note_test.dart -d macos --dart-define-from-file=build/dart_define.json --plain-name "话题库：3 主题 × 3 root chat × 3 分支（共 27 个子 chat）+ 笔记写入"`

### DEPTH-1 · 节点最大深度 4 层限制（边界）
- **Test case（人话）**：产品约束节点最大深度 4 层（theme→chat→sub→sub-sub）。深度 4 的节点**不应出现 branch 入口**（无法再分支）。
- **状态**：⚠️ 待补——`integration_test/` 目前无显式断言「第 4 层节点无 branch 入口」的 case。TREE-1 用 `MAX_DEPTH` 控制深度但未触达边界断言。建议落点：新建 `common/depth_limit_test.dart` 或并入 TREE-1。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅（逻辑测试，与 UI 无关）
- **Related script**：（建议 `common/depth_limit_test.dart`，待建）
- **Run**：（待实现 case 后填）

---

## 三、其他共用 common 用例（三端共用脚本）

### REORDER-1 · 同层节点拖拽重排序
- **Test case（人话）**：进多节点对话树 → 长按第 2 个节点拖拽把手（`drag_handle_${nodeId}`）→ 拖到第 1 个位置 → 松手 → 顺序立即变 → 刷新/重进顺序保持。另含「跨层拖拽应被禁止」「拖拽后刷新保持顺序」。
- **状态**：⚠️ **桩文件 / Android 阻塞**——`node_reorder_test.dart` 满是 TODO、硬编码 `drag_handle_node1/node2`，非真能跑。Android 上 `LongPressDraggable` 与 `SelectionArea` 手势冲突曾引发异常。
- **平台覆盖**：iOS ⚠️ / Android ⚠️（阻塞）/ macOS ⚠️
- **Related script**：`common/node_reorder_test.dart`
- **Run**：`flutter test integration_test/common/node_reorder_test.dart -d <device> --plain-name "同层节点拖拽重排序"`（目前不完整）

### MERGE-1 · Merge Chat 按钮可点击并导航到确认页
- **Test case（人话）**：主题 tab → 建主题 → 建 2 个 chat 节点 → 进主题详情 → Overflow → 「合并 & 创建新 Chat」→ FullTreeScreen 加载（多选模式自动开）→ 点 2 个节点标题选中 → 点底部「合并 & 创建新 Chat」→ 验证导航到 MergeChatConfirmScreen（出现「选择挂载位置」）。测试点：合并按钮可点击（B4 修复 `minimumSize: Size.zero`）、多选→确认页链路。纯 UI，不需 LLM。超时 90s。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/merge_chat_button_test.dart`
- **Run**：`flutter test integration_test/common/merge_chat_button_test.dart -d <device> --plain-name "Merge Chat 按钮可点击并导航到确认页"`

### NOTE-1 · 笔记 CRUD 全流程 + 持久化
- **Test case（人话）**：笔记 tab → 建笔记（主题+标题+内容）→ 编辑内容 → 重命名标题 → 删除。测试点：创建/编辑/重命名/删除全链路 + 持久化（不清理测试数据，时间戳防冲突）。不需 LLM。超时 90s。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/note_crud_test.dart`
- **Run**：`flutter test integration_test/common/note_crud_test.dart -d <device> --plain-name "笔记 CRUD 全流程 + 持久化验证"`

### SEARCH-1 · 搜索有结果
- **Test case（人话）**：建含唯一关键词的笔记 → 搜索该关键词 → 验证有结果。复用 note_crud 创建流程。不需 LLM。超时 90s。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/search_test.dart`
- **Run**：`flutter test integration_test/common/search_test.dart -d <device> --plain-name "Case 1: 搜索有结果"`

### SEARCH-2 · 搜索无结果
- **Test case（人话）**：搜索不存在的关键词 → 验证空态文案出现。不需 LLM。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/search_test.dart`
- **Run**：`flutter test integration_test/common/search_test.dart -d <device> --plain-name "Case 2: 搜索无结果"`

### SEARCH-3 · 搜索索引异常修复
- **Test case（人话）**：用 `FailingSearchService` 模拟 `DatabaseException` → 触发索引修复弹窗 → 验证修复完成、搜索恢复。测试点：索引损坏自愈链路。用 mock service，不需真实 LLM。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/search_test.dart`
- **Run**：`flutter test integration_test/common/search_test.dart -d <device> --plain-name "Case 3: 搜索索引异常"`

### BACKUP-1 · 备份与恢复完整往返
- **Test case（人话）**：`common/backup_restore_test.dart` group「备份与恢复流程测试」含：完整备份和恢复往返测试（备份→清空→恢复→数据一致）、备份文件格式验证、恢复冲突处理、恢复覆盖模式。测试点：磁盘↔索引一致性、备份文件人类可读（Markdown）。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅（纯磁盘/DB 逻辑）
- **Related script**：`common/backup_restore_test.dart`
- **Run**：
  - 完整往返：`--plain-name "完整备份和恢复往返测试"`
  - 格式验证：`--plain-name "备份文件格式验证"`
  - 冲突处理：`--plain-name "恢复冲突处理测试"`
  - 覆盖模式：`--plain-name "恢复覆盖模式测试"`

### CHAT-1 · 进入聊天页面包屑可点回跳
- **Test case（人话）**：`common/chat_breadcrumb_test.dart`——进入任意聊天页不崩溃，且面包屑（breadcrumb）每一段均可点，逐级回跳到父级不乱。测试点：深层树导航的面包屑回跳。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/chat_breadcrumb_test.dart`
- **Run**：`flutter test integration_test/common/chat_breadcrumb_test.dart -d <device> --plain-name "进入聊天页不崩溃且面包屑每段均可点回跳"`

### LATEX-1 · LaTeX 公式渲染不溢出
- **Test case（人话）**：`common/chat_latex_overflow_test.dart` group「LaTeX 公式渲染回归」含：简单 inline 公式不抛 RenderFlex overflow；含 `\frac \sum \int` 复杂公式不溢出；block 公式（`\[...\]`）不溢出；公式+普通文本混排不溢出；非法公式 fallback 到文本渲染不抛异常。测试点：Markdown/LaTeX 渲染稳定性（长公式回归防护）。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅（渲染与平台无关）
- **Related script**：`common/chat_latex_overflow_test.dart`
- **Run**：逐个 `--plain-name "简单 inline 公式不抛 RenderFlex overflow"` 等

### STREAM-1 · 对话发送与流式回复
- **Test case（人话）**：`common/chat_streaming_test.dart` group「对话发送与流式回复测试」含：发送消息并等待流式回复；发送空消息（应被拦截或提示）；快速连续发送消息（队列/不串台）。测试点：流式链路 + 边界。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ⚠️（桌面用 Enter 发送，common 用例按 `send_button` tap，需适配）
- **Related script**：`common/chat_streaming_test.dart`
- **Run**：`--plain-name "发送消息并等待流式回复"` 等

### KEYWORD-1 · 关键词排行榜导航
- **Test case（人话）**：`common/keyword_ranking_test.dart`——进入关键词排行榜，验证列表渲染、点击条目可导航到相关会话/笔记。测试点：排行功能可达性。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/keyword_ranking_test.dart`
- **Run**：`flutter test integration_test/common/keyword_ranking_test.dart -d <device> --plain-name "关键词排行榜导航测试"`

### LAB-1 · Lab 标签页
- **Test case（人话）**：`common/lab_tab_test.dart`——验证 Lab 占位/实验功能页可达、不崩溃。（当前内容较轻，详见 Dart。）
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/lab_tab_test.dart`
- **Run**：`flutter test integration_test/common/lab_tab_test.dart -d <device>`（无 testWidgets 标题时整文件跑）

### NOTESEARCH-1 · 笔记内搜索
- **Test case（人话）**：`common/note_search_test.dart`——在笔记内搜索关键词，验证定位/高亮。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/note_search_test.dart`
- **Run**：`flutter test integration_test/common/note_search_test.dart -d <device>`

### NOTETITLE-1 · 笔记标题自动提取与必填
- **Test case（人话）**：`common/note_title_required_test.dart`——「笔记标题自动提取与必填：6 个场景」：从首行自动提取标题；空内容时标题必填拦截；边界场景覆盖。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/note_title_required_test.dart`
- **Run**：`flutter test integration_test/common/note_title_required_test.dart -d <device> --plain-name "笔记标题自动提取与必填：6 个场景"`

### NOTE2CHAT-1 · 笔记 → 对话
- **Test case（人话）**：`common/note_to_chat_test.dart`——从笔记创建 chat 并自动续聊（笔记内容作为上下文带入对话）。测试点：笔记与对话的闭环。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/note_to_chat_test.dart`
- **Run**：`flutter test integration_test/common/note_to_chat_test.dart -d <device> --plain-name "笔记 → 对话：从笔记创建 chat 并自动续聊"`

### SEARCHBTN-1 · 搜索设置按钮
- **Test case（人话）**：`common/search_settings_button_test.dart`——验证搜索页设置按钮可达、点击展开设置。
- **平台覆盖**：iOS ✅ / Android ✅ / macOS ✅
- **Related script**：`common/search_settings_button_test.dart`
- **Run**：`flutter test integration_test/common/search_settings_button_test.dart -d <device>`

---

## 四、Android 平台专属（platform/android/*）

> 这些 case 只在 Android 上跑（脚本仅在该端有意义）。iOS 走 common 的对应能力；macOS 桌面有独立桌面实现。

### BRA-1 · Android 点 branch 按钮进入分支流程
- **Test case（人话）**：主题 tab → 建主题 → 建 1 个 chat 节点 → 进节点详情 → 点 `branch_button`（**非** SelectionArea 长按，B4 后 Android 走按钮）→ 验证进入分支创建流程（`l10n.branch` 文案出现）。不需 LLM。`createTestApp` 用 `AppSettings` 不带 `llmConfigStore`。已知坑：`ValueKey('branch_button')` 是 TODO(verify-key)，若 Android 实际 key 不同需改 `branch_shared.dart`。
- **平台覆盖**：Android ✅ / iOS ❌ / macOS ❌
- **Related script**：`platform/android/branch/android_test.dart`
- **Run**：`flutter test integration_test/platform/android/branch/android_test.dart -d <android> --plain-name "Android 分支创建：点 branch 按钮进入分支流程"`

### IMG-1 · Android 图片发送
- **Test case（人话）**：进 chat 节点 → 点图片附加按钮（`openImagePicker`）→ 选第一张图（`pickFirstImage`）→ 发消息「看图」→ 验证消息中出现图片 widget（`expectImageInMessage`）。测试点：图片附加→发送→气泡内渲染。需 LLM（发了消息触发回复）。模拟器相册可能空，预置 `assets/test_image.jpg` 作 fixture。复用 `branch_shared.dart`。
- **平台覆盖**：Android ✅ / iOS ❌ / macOS ❌
- **Related script**：`platform/android/image/android_test.dart`
- **Run**：`flutter test integration_test/platform/android/image/android_test.dart -d <android> --dart-define-from-file=build/dart_define.json --plain-name "Android 图片发送：附加图片并出现在消息中"`

### SHARE-1 · Android 分享导出
- **Test case（人话）**：进 chat 节点 → 发一条消息「分享这条」→ 在气泡上点分享按钮（`openShareSheet`）→ 验证系统分享 sheet 被触发（`expectShareSheetVisible`）。测试点：分享入口可达、系统分享 sheet 唤起。需 LLM（先发消息）。Android 分享走系统 sheet，仅断言流程被触发。已知坑：`l10n.share` 断言曾不存在，已改为断言系统 sheet 可见（TODO: 补 share 文案断言）。
- **平台覆盖**：Android ✅ / iOS ❌ / macOS ❌
- **Related script**：`platform/android/share/android_test.dart`
- **Run**：`flutter test integration_test/platform/android/share/android_test.dart -d <android> --dart-define-from-file=build/dart_define.json --plain-name "Android 分享导出：消息分享触发系统 sheet"`

---

## 五、macOS 桌面端（platform/desktop/*）

> 桌面端交互模型与移动端**完全不同**：多栏布局、sidebar 导航（`sidebar_item_0..3`）、右键代替长按、菜单代替 sheet、Cmd 快捷键、hover、Enter 发送。以下 case 仅 macOS 跑。

### DESK-1 · 桌面壳启动 + 默认搜索分支 + 切主题
- **Test case（人话）**：启动后侧栏 `ThkTree` 标题存在（说明走 `_DesktopShell` 而非移动端壳）→ 默认落地 `/search` → `SearchWorkspace` 渲染 → 点侧栏「主题」(`sidebar_item_1`) → `ThemesWorkspace` 渲染 → 切回「搜索」(`sidebar_item_0`) → `SearchWorkspace` 仍在（indexedStack 不重置）。纯 UI，不触发 LLM。
- **平台覆盖**：macOS ✅ / iOS ❌ / Android ❌
- **Related script**：`platform/desktop/shell_smoke_test.dart`
- **Run**：`flutter test integration_test/platform/desktop/shell_smoke_test.dart -d macos --plain-name "桌面壳启动：侧栏存在 + 默认搜索分支 + 切换主题分支"`

### DESK-2 · 侧栏四分支切换渲染对应工作区
- **Test case（人话）**：点侧栏四项分别渲染对应工作区且不重置：搜索(0)→SearchWorkspace；主题(1)→ThemesWorkspace；笔记(2)→NotesWorkspace；Lab(3)→LabPlaceholderScreen；切回主题验证 indexedStack 保留状态。纯 UI。
- **平台覆盖**：macOS ✅ / iOS ❌ / Android ❌
- **Related script**：`platform/desktop/sidebar_nav_test.dart`
- **Run**：`flutter test integration_test/platform/desktop/sidebar_nav_test.dart -d macos --plain-name "侧栏四分支切换渲染对应工作区"`

### DESK-3 · 主题 → 节点 → 聊天 2 round（桌面流式）
- **Test case（人话）**：切到主题分支 → 点 `add_theme_button` 建主题（填 `theme_title_input` → `theme_create_button`）→ 点主题进详情 → 点 `add_node_button` 建节点（`node_title_input` → `node_create_button`）→ 点节点进聊天 → 发「请用一句话介绍你自己」「请讲一个简短的冷笑话」两轮（**桌面用 Enter 键发送**，非点发送按钮）→ 等流式：出现 `stop_button` 表示进行中，`send_button` 重新出现表示完成（极短回复可能 stop 一闪而过，3s 内 send 回来即视为完成），最长 180s/轮。验证两条消息均出现。需真实 LLM（dart-define）。
- **平台覆盖**：macOS ✅ / iOS ❌ / Android ❌
- **Related script**：`platform/desktop/theme_chat_test.dart`
- **Run**：`flutter test integration_test/platform/desktop/theme_chat_test.dart -d macos --dart-define-from-file=build/dart_define.json --plain-name "桌面壳：主题 → 节点 → 聊天 2 round"`

### DESK-4 · 综合 A：3 主题 × 3 根节点树
- **Test case（人话）**：`comprehensive_test.dart` A 段——建 3 个主题 → 选中第一个 → 建 3 个根节点 → 断言三个根节点均出现在树中。验证桌面多主题多节点树构建。纯 UI（Kimi provider）。
- **平台覆盖**：macOS ✅ / iOS ❌ / Android ❌
- **Related script**：`platform/desktop/comprehensive_test.dart`
- **Run**：`flutter test integration_test/platform/desktop/comprehensive_test.dart -d macos --plain-name "A: 3 主题 × 3 层节点树 + 深度限制"`

### DESK-5..9 · 综合 B/C/D/E/F（TODO 桩，未实现）
- **状态**：⚠️ `comprehensive_test.dart` 的 B（三种分支创建模式）、C（图片消息+Kimi）、D（同层排序）、E（节点合并）、F（分享导出）均为 TODO 空壳，未实现。其中 B 暴露**桌面端分支创建触发尚未实现**（无 `branch_button` 桌面入口），故 BC-1..13 在 macOS 标 ❌。
- **平台覆盖**：macOS ⚠️（待实现）
- **Related script**：`platform/desktop/comprehensive_test.dart`
- **Run**：（待实现）

---

## 六、iOS 平台专属（platform/recovery/ios_test.dart）

### IOS-1 · 后台中断恢复（iOS 专属）
- **Test case（人话）**：`platform/recovery/ios_test.dart`——iOS 后台任务中断→恢复场景（如聊天流式进行中 App 被挂起/恢复，状态不丢失、可续传）。测试点：iOS 生命周期与后台恢复。iOS 专属（依赖 iOS 后台机制）。
- **状态**：⚠️ 当前继承 `LlmClient` mock 历史债 → 编译失败（见末尾「别跑」）。修 mock 后可跑。
- **平台覆盖**：iOS ⚠️（编译债）/ Android ❌ / macOS ❌
- **Related script**：`platform/recovery/ios_test.dart`
- **Run**：（修 mock 后）`flutter test integration_test/platform/recovery/ios_test.dart -d <ios> --dart-define-from-file=build/dart_define.json`

---

## 七、别跑（已知编译债，独立 task 修 mock 后可跑）

> 以下 case **真实存在且有价值**，但 `integration_test/` 继承 `LlmClient` mock 历史债：`LlmClient.streamChatCompletion` 接口新增 `deepThinking` / `webSearch` 形参，mock 子类未跟上 → `invalid_override` 编译失败。三端共有，不在本次重排范围。
> **修法（独立任务）**：给 `_support/topic_llm_client.dart` 及所有 `LlmClient` mock 子类补 `deepThinking`/`webSearch` 形参（默认值），再跑。

- `common/llm_error_retry_test.dart`（LLM 错误态 + i18n + 重试，case 1..5）—— 真实 case，待修 mock。
- `common/offline_test.dart`（断网场景：错误 UI / 流式中途断网 / 恢复重试）—— 真实 case，待修 mock。
- `common/theme_chat_e2e_test.dart`（主题→节点→聊天 2 round 完整链路）—— 真实 case，待修 mock。
- `platform/recovery/ios_test.dart`（IOS-1 后台恢复）—— 真实 iOS case，待修 mock。

---

## 八、贡献约定（开源参与者必读）

- 改本目录（test case 描述）直接提交到主仓库，不必会 Dart。
- 改了 case 行为（步骤/预期变了），对应 Dart 实现须同步更新，且 flutter analyze 无新增 error。
- 新增 case：在对应 section 加一条 `ID · Title` + Test case 人话 + 平台覆盖 + Related script + Run；Dart 落到 `common/` 或 `platform/<端>/`。
- 主题/文章数据改了 `test-data/topics.md`，也要同步 `_support/topic_library.dart`（反之亦然）。
