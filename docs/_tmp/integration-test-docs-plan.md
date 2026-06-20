# 集成测试文档编写方案

> 状态：草稿（待用户确认）  
> 创建：2026-06-18  
> 触发：用户上一会话报告"bug解决了；很好；但现在我需要你写文档，关于这个集成测试的文档"

---

## 1. 背景与目标

`integration_test/` 目录已积累 5 个集成测试 + 3 个 `_support/` 辅助文件，但**完全没有专门文档**——所有"这个测试在测什么 / 怎么跑 / 注入为什么这样写"的信息都散落在源码注释 + 1 份 LLM 注入文档里（`docs/modules/llm/specs/integration-test-llm-injection.md`，208 行，质量很高）。

本次任务目标：把这些零散信息**结构化**到 `docs/_shared/integration-testing/` 下，让任何新成员能 30 分钟内：
- 知道这里有哪些集成测试、各自覆盖什么场景
- 能跑起来（fixtures / helpers / 入口命令）
- 能新增一个测试（规范、命名、ValueKey 约定、_support 复用）

---

## 2. 最终 Folder 结构（用户决策）

**统一收 `docs/_shared/integration-testing/`**（用户选 A）。

```
docs/_shared/integration-testing/
├── README.md              # 总论：架构、目录约定、命名、运行调试、新增测试 checklist
├── fixtures.md            # fixtures 详解（InMemoryLlmConfigStore + LlmTestConfig）
├── helpers.md             # test_helpers.dart 工具函数清单
├── llm-injection.md       # ⭐ 已有详细版的导航 + 摘要，详细版留在 modules/llm/specs/
├── chat-streaming.md      # chat_streaming_test.dart 现状 + TODO + 编写指南
├── theme-chat-e2e.md      # theme_chat_e2e_test.dart（从 docs/_tmp/theme_chat_e2e_test.md 草稿迁移）
├── backup-restore.md      # backup_restore_test.dart（4 个空 testWidgets 的补全指南）
├── branch-creation.md     # branch_creation_test.dart（部分实现 + TODO 收尾）
└── node-reorder.md        # node_reorder_test.dart（拖拽 ValueKey 约定 + TODO 收尾）
```

**总文档数**：6 个新文档（README + fixtures + helpers + chat-streaming + theme-chat-e2e + backup-restore + branch-creation + node-reorder = 实际 8 个新文档 + 1 个 LLM 注入导航版）

---

## 3. 详细文档清单

### 🆕 A. 新建文档（8 个 + 1 个导航版）

#### A1. `docs/_shared/integration-testing/README.md`（总论）⭐ 入口

**章节大纲**：

1. **目标与边界** — 这套文档覆盖什么、不覆盖什么
2. **架构总览** — 一张 ASCII 图展示 integration_test/ ↔ lib/main_test.dart ↔ Riverpod Override ↔ _support/ fixtures 的关系
3. **目录约定** — `_support/` vs 测试文件本体 vs fixtures（assets/test_llm_config/）
4. **命名与文件结构** — `xxx_test.dart` 命名、`group` 用法、`testWidgets` 命名
5. **ValueKey 约定** — 必须给 UI 关键交互点加 ValueKey，命名规范（`add_theme_button` / `chat_input` / `stop_button` 等）
6. **真实 vs Mock LLM** — 当前策略（真实 API），未来想 Mock 的路线图
7. **运行命令** — `flutter test integration_test/<file>.dart -d <device>`
8. **调试技巧** — `dev.log`、`print`、`pumpAndSettleWithTimeout`、超时排查
9. **新增测试 Checklist** — 8 步：选模块→写场景→补 ValueKey→用 helpers→跑通→加文档
10. **测试现状速览表** — 5 个 test 文件 ×（覆盖场景 / 实现状态 / 阻塞点 / 相关 spec）

#### A2. `docs/_shared/integration-testing/fixtures.md`

**章节大纲**：

1. **为什么用 asset 而不是 host 文件**（核心避坑）
   - simulator 看不到 host `tool/` 目录
   - asset 打进 `.app` bundle，`rootBundle.loadString` 能读
2. **JSON 配置文件结构**（参考 `assets/test_llm_config/test_llm_config.example.json`）
   ```json
   { "activeProvider": "deepseek",
     "providers": { "deepseek": { "apiKey": "...", "model": "deepseek-chat" }, ... } }
   ```
3. **`LlmTestConfig.loadFromAsset()` 失败模式**
   - asset 不存在 → StateError（清晰的解决指引）
   - JSON 非法 → FormatException
   - activeProvider 没填 apiKey → StateError
4. **`toAppSettings()` vs `toLlmConfigStore()` 双注入**
   - 为什么要两层（路径 B 用 store，路径 C 用 settings）
   - `appSettingsProvider` 单独 override 是死注入（路径 B 在 loadAll() 返回空数组时直接退出）
5. **`InMemoryLlmConfigStore extends LlmConfigStore`** — 为什么用继承而不是 Mock 库
   - `overrideWithValue` 要求类型精确匹配
   - 只需重写 3 个方法：`loadAll` / `getProvider` / `readApiKey`
6. **Provider ID 映射表**（**关键避坑**）— 摘录自 `integration-test-llm-injection.md § 5.3`
   - `claude → preset_anthropic`（不是 `preset_claude`）
   - 其他 5 个 LlmProvider 的对应 ID
7. **如何新增一种 LLM** — 改 enum + 补 `_presetIdFor()` + 补 JSON schema 字段

#### A3. `docs/_shared/integration-testing/helpers.md`

**章节大纲**（按 test_helpers.dart 的 18 个工具分组）：

1. **pump 类** — `pumpAndSettleWithTimeout`、`waitForLLMResponse`、`waitForText`、`waitForWidget`、`waitForLoadingToComplete`
2. **操作类** — `safeTap`、`enterTextAndWait`、`longPressAndWait`、`dragFromTo`
3. **断言类** — `getAllTexts`、`containsText`
4. **业务快捷方法** — `createTestNode`、`navigateToChat`、`navigateToTheme`、`sendMessage`、`stopStreaming`、`refreshNodeList`
5. **空实现（需补）** — `getNodeTitles()`、`verifyNodeOrder()` 当前是 `// TODO`，列出"什么时候必须补"
6. **使用约定** — 不直接调 `tester.pumpAndSettle()`，统一用 `pumpAndSettleWithTimeout`；不直接 `find.text`，优先 `find.byKey(ValueKey)`

#### A4. `docs/_shared/integration-testing/llm-injection.md`（导航 + 摘要）

**策略**：**不重复**详细版内容，只放：
1. **TL;DR** — 3 句话结论（`chat_controller` 读 `llmConfigStoreProvider`、注入点只在 `main_test.dart`、必须 override `LlmConfigStore` 子类）
2. **详细版链向**：`docs/modules/llm/specs/integration-test-llm-injection.md`
3. **本目录中的相关章节**：fixtures.md § 4-5、helpers.md § 4

#### A5. `docs/_shared/integration-testing/chat-streaming.md`

**章节大纲**：

1. **覆盖场景**（3 个 testWidgets）
   - 发送消息并等待流式回复（**TODO 占位**，需要补 `navigateToChat`）
   - 发送空消息（边界用例：空串、纯空格）
   - 快速连续发送消息（顺序 + 不丢）
2. **现状评估** — 3 个测试都只有 TODO 注释 + 简单 `enterText/tap`，没有真实跑通
3. **编写路线**
   - 用 `navigateToChat`（来自 helpers.md）跳到对话页
   - 复用 `waitForLLMResponse` 等待流式结束
   - 用 `find.byKey(ValueKey('chat_input'))` 定位
4. **依赖 helpers** — `enterTextAndWait`、`navigateToChat`、`waitForLLMResponse`、`waitForWidget(stop_button)`
5. **阻塞点** — 需要先确认 `chat_input` / `send_button` / `stop_button` ValueKey 在 `chat_screen.dart` 已存在

#### A6. `docs/_shared/integration-testing/theme-chat-e2e.md`

**章节大纲**（从 `docs/_tmp/theme_chat_e2e_test.md` 迁移完善）：

1. **目标** — 验证"创建主题 → 创建节点 → 聊天 2 round"完整链路
2. **场景表**（草稿 § 场景 8 行表格）— 复用并加 column：操作 / 期望 / 涉及 ValueKey
3. **LLM 接入策略** — 真实 API、用 Settings 默认 provider/model、单轮 90s 超时、不验证回复内容、不清理数据
4. **改动清单**（草稿 § 改动清单）— main_test.dart 加 locale 参数、theme_list_screen.dart 补 ValueKey、theme_detail_screen.dart 补 ValueKey、新建 theme_chat_e2e_test.dart
5. **ValueKey 清单**（关键约定）— `add_theme_button` / `theme_title_input` / `theme_create_button` / `add_node_button` / `node_title_input` / `node_create_button`
6. **测试步骤详解**（结合 theme_chat_e2e_test.dart 实际代码）— `_switchToTab` / `_createTheme` / `_createNode` / `_sendAndWaitForReply` 4 个 helper 函数说明
7. **断言** — 4 条消息、send_button 恢复、user 消息文本存在
8. **执行命令** — `flutter test integration_test/theme_chat_e2e_test.dart -d "<iOS Simulator>"`
9. **完成状态**（草稿 § 完成状态 checkbox 化）— 4 个改动点 + iOS 模拟器跑通
10. **已知问题** — 真 API 不稳定时的兜底（提高超时到 120s / 加 retry 逻辑）

#### A7. `docs/_shared/integration-testing/backup-restore.md`

**章节大纲**：

1. **覆盖场景**（4 个空 testWidgets）
   - 完整备份和恢复往返测试（创建数据→备份→清空→恢复→比对）
   - 备份文件格式验证（zip 包含 manifest + theme 文件）
   - 恢复冲突处理（合并模式）
   - 恢复覆盖模式（完全替换）
2. **现状** — 4 个全是 TODO 空壳，没有任何实质实现
3. **实现前置依赖**
   - settings 页面需要暴露 ValueKey 触达"备份"/"恢复"入口
   - 备份产物文件存储位置需确定（文档目录？）
   - 备份 zip 文件 schema（manifest.json 字段）
4. **编写路线**
   - 创建测试数据（用 theme_chat_e2e 的 `_createTheme` + `_createNode` 思路）
   - 触发备份 → 找到产物文件 → 验证 schema
   - 清空数据（用覆盖恢复空数据集模拟）
   - 触发恢复 → 验证数据完整性
5. **风险** — 备份文件 I/O 时序、超时设置需谨慎（zip 大文件 + 模拟器磁盘慢）
6. **依赖 helpers** — `_createTheme`、`_createNode`（**可能需要从 theme_chat_e2e_test.dart 提到 `_support/`**）

#### A8. `docs/_shared/integration-testing/branch-creation.md`

**章节大纲**：

1. **覆盖场景**（实际是 7 个 testWidgets，第 91 行开始的 3 个之前漏看）
   - 选中文本 + raw 模式
   - 选中文本 + summarize 模式
   - 无选中文本 + raw 模式
   - 无选中文本 + summarize 模式
   - 模式选择取消
   - 标题选择取消
   - LLM 失败 fallback
2. **现状** — 7 个测试都完成了"主题/节点/发消息"前置，**但核心"选中文本→分支创建"全是 TODO**
3. **编写前置**
   - `_createTestTheme` / `_createTestNode` / `_sendMessage` 在文件内私有定义（line 147-217），可考虑提升到 `_support/`
   - chat_screen 需要提供"选中文本"的交互入口（长按弹出 ActionSheet？）
   - "raw" vs "summarize" 模式选择 UI 需要 ValueKey
4. **编写路线** — 7 个用例共享前置（创建主题→节点→发一条消息），用 `setUpAll` 或共享 helper
5. **LLM 失败 fallback** 测试的特殊性 — 需要 mock `llmConfigStoreProvider` 返回空 apiKey
6. **依赖 helpers** — 需要新增 helper：`selectTextInMessage`、`openBranchSheet`、`confirmBranchCreation`

#### A9. `docs/_shared/integration-testing/node-reorder.md`

**章节大纲**：

1. **覆盖场景**（3 个 testWidgets）
   - 同层节点拖拽重排序
   - 跨层拖拽应被禁止（`onWillAcceptWithDetails` 返回 false）
   - 拖拽后刷新保持顺序
2. **现状** — 假设了 `drag_handle_node1` / `drag_handle_node2` / `drag_handle_parent` / `drag_handle_child` ValueKey，**实际这些 Key 在代码里可能不存在或命名不同**
3. **ValueKey 核实** — 必须先查 `theme_detail_screen.dart` / 节点树 widget 实际用了哪些 Key；不存在需要补
4. **拖拽手势细节**
   - `longPressAndWait` → `dragFromTo(startOffset, endOffset)`
   - `getCenter(finder)` 取坐标
   - 跨层拖拽应被 `DragTarget.onWillAcceptWithDetails` 拒绝，验证方式是"顺序不变"
5. **依赖 helpers** — `longPressAndWait`、`dragFromTo`、`getCenter`、`refreshNodeList`、`waitForWidget`
6. **实现路线** — 先用 mock 数据 fixture 验证拖拽手势，再接入真实主题树

---

### 🔄 B. 更新现有文档（3 个）

#### B1. `docs/modules/llm/specs/integration-test-llm-injection.md`

**改动**：
- 文件顶部加 frontmatter 或元信息块：
  ```markdown
  > **创建**：2026-06-18  
  > **最近更新**：2026-06-18  
  > **维护者**：AI + 用户审阅  
  > **详细版**，简化导航版见 `docs/_shared/integration-testing/llm-injection.md`
  ```

#### B2. `docs/modules/llm/README.md`

**改动**：第 30-32 行（"## 子文档 / 本模块暂无子文档"）
- 改为：
  ```markdown
  ## 子文档

  - [集成测试：LLM 配置注入原理与实践](./specs/integration-test-llm-injection.md) — 集成测试如何注入 LLM 配置到 Riverpod
  - 集成测试总论、fixtures、helpers：[docs/_shared/integration-testing/](../../_shared/integration-testing/README.md)
  ```

#### B3. `docs/modules/chat/README.md`

**改动**：第 31-33 行（"## 子文档 / 本模块暂无子文档"）
- 改为：
  ```markdown
  ## 子文档

  - 集成测试 — 对话流式：[docs/_shared/integration-testing/chat-streaming.md](../../_shared/integration-testing/chat-streaming.md)
  - 集成测试总论、fixtures、helpers：[docs/_shared/integration-testing/README.md](../../_shared/integration-testing/README.md)
  ```

---

## 4. 执行顺序（依赖关系）

```
Step 1: B1 (更新元信息) + B2 + B3 (修 README)        ─┐
                                                      ├─ 独立、可并行
Step 2: A1 (总论 README)                              ─┘

Step 3: A2 (fixtures) + A3 (helpers)                 ─┐ 并行（互相独立）
                                                      │
Step 4: A4 (llm-injection 导航版)                    ─┘ 依赖 A1 完成

Step 5: A5-A9 (5 个 test spec)                       ── 全部依赖 A1+A2+A3
                                                      可全部并行（互相独立）
```

**总步骤数**：4 批（B 元信息 / 总论 / 横切 / 5 个 spec）

**预估工作量**：
- A1（总论）: 200 行（最复杂）
- A2（fixtures）: 180 行
- A3（helpers）: 100 行
- A4（导航版）: 30 行（短）
- A5-A9（5 个 spec）: 每个 80-150 行
- B 元信息: 每文件 5-10 行

**总计**：约 1100-1300 行新文档 + 3 处 README 修复

---

## 5. 关键设计决策（待确认）

### 决策 1：llm-injection.md 是放 _shared 还是留 modules/llm/specs/？

**用户原选 A**：统一收 `_shared/integration-testing/`，但**同时说"已有文档只更新元信息"**。

我的方案（**推荐**）：
- **详细版**保持 `docs/modules/llm/specs/integration-test-llm-injection.md`（用户已有投入 + LLM 模块专属视角）
- **`_shared/integration-testing/llm-injection.md`** 只做导航 + 摘要（30 行），详细版链向 modules 下那份
- 这样既符合 A 的"统一索引"，又不重复 208 行内容

**替代方案**（如果用户希望彻底"统一收"）：
- 把 `modules/llm/specs/integration-test-llm-injection.md` 内容**整体迁移**到 `_shared/integration-testing/llm-injection.md`
- `modules/llm/specs/` 下留一个 `README.md` 占位说明"已迁移"

### 决策 2：docs/_tmp/theme_chat_e2e_test.md 草稿如何处理？

- **方案 A（推荐）**：把内容**吸收**到 `_shared/integration-testing/theme-chat-e2e.md`，然后**删除** `_tmp/theme_chat_e2e_test.md`
- 方案 B：保留 `_tmp` 草稿，新文档里标注"草稿来源 _tmp/..."
- 推荐 A，因为 `_tmp/` 是临时区，正式文档落地后应清空

### 决策 3：要不要把 helpers 里 `_createTheme` / `_createNode` 提升到 `_support/`？

- 当前在 `theme_chat_e2e_test.dart` 内私有定义（line 171-207）
- `branch_creation_test.dart` 也有自己的 `_createTestTheme` / `_createTestNode` / `_sendMessage`（line 147-217）
- **方案 A（推荐）**：把 3 个公共 helper 提升到 `_support/test_fixtures.dart` 或合并到 `test_helpers.dart`
- 方案 B：保持现状，让 backup-restore / branch-creation 各自复制一份
- 推荐 A 的理由：DRY 原则，且后续修改只改一处

**注**：决策 3 涉及代码改动（不属于"只改 doc"范围），可作为本次文档编写的**后续行动**留待下次任务。

---

## 6. 风险与边界

### 不在本次范围
- ❌ **不实现**任何空 testWidgets（chat_streaming / backup_restore / branch_creation / node_reorder 的 TODO 不动）
- ❌ **不补**任何 ValueKey（如果实际代码里 Key 不存在，只在文档里标注"需要补 Key: xxx"）
- ❌ **不重构** `_support/` 或 `test_helpers.dart`（决策 3 留作后续）
- ❌ **不跑**任何测试（不在文档任务范围内）
- ❌ **不改 git**（commit 留给用户）

### 风险点
- 文档里**假设的 ValueKey**（如 `drag_handle_node1`、`drag_handle_parent`）可能在实际 UI 不存在；需要在文档里**明确标注"⚠️ 待核实"**
- `_tmp/theme_chat_e2e_test.md` 的"完成状态"勾选框如果文档迁移后**未更新**，会让读者误以为未完成
- 文档体量大（1100+ 行），建议**分批提交**便于 review

### 已知过期声明
- `docs/modules/llm/README.md:32` "本模块暂无子文档"——**过期**（实际有 `specs/integration-test-llm-injection.md`）
- `docs/modules/chat/README.md:32` "本模块暂无子文档"——**过期**（即将在 `_shared/integration-testing/` 有 `chat-streaming.md`）

---

## 7. 验收 Checklist

完成所有改动后，确认：
- [ ] 8 个新文档在 `docs/_shared/integration-testing/` 下存在
- [ ] `docs/_tmp/theme_chat_e2e_test.md` 已删除
- [ ] `docs/modules/llm/specs/integration-test-llm-injection.md` 顶部有元信息 + 反向链接
- [ ] `docs/modules/llm/README.md` 第 30-32 行已修复
- [ ] `docs/modules/chat/README.md` 第 31-33 行已修复
- [ ] 总论 README.md 的"测试现状速览表"覆盖全部 5 个 test 文件
- [ ] 每个 spec 文档都标注了"现状 / 阻塞点 / 编写路线"
- [ ] 总论 README 顶部有清晰的目录链接

---

## 8. 待用户确认

请确认以下 3 件事：

1. **决策 1（llm-injection.md 归属）**：详细版留 modules/llm/specs/ + _shared 放导航版 ✅ / 整体迁移到 _shared/
2. **决策 2（_tmp 草稿）**：删除 `_tmp/theme_chat_e2e_test.md` ✅ / 保留
3. **决策 3（helpers 提升到 _support/）**：作为后续任务留待下次 ✅ / 本次只写文档不动代码

确认后进入实际编写（按 Step 1-5 分批输出）。