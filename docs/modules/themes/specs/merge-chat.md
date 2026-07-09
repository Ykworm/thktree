# 合并 & 创建新 Chat（multi-chat merge）

> 选最多 3 个 chat 节点，合并它们的完整对话历史，创建一个新 chat。
> 合并内容作为新 chat 的首批**已发送 user 消息**（`autoTriggerReply = false`），用户输入新问题后一起发给 AI。

## 1. 入口（两个，行为不同）

| 入口 | 跳转参数 | `crossTree` |
|------|----------|-------------|
| **Tree Page** — ThemeDetailScreen overflow menu → 「合并 & 创建新 Chat」 | `full-tree?multiSelect=true`（`currentNodeId == null`） | `true` |
| **Chat Page** — ChatScreen「查看整棵树」→ FullTreeScreen，切到多选 | `full-tree?currentNodeId=xxx` | `false` |

> 入口判定依据：`currentNodeId == null ⟺ tree page 入口`。`FullTreeScreen._onMergeAndCreate` 跳转 merge-confirm 时带 `?crossTree=${widget.currentNodeId == null}`；`router.dart` 的 merge-confirm 路由读 `state.uri.queryParameters['crossTree']` 传给 `MergeChatConfirmScreen`。

## 2. 流程

1. **FullTreeScreen 多选模式**：勾选 ≤ 3 个 chat 节点（只能选 chat 节点，summary 不可选），底部操作栏「合并 & 创建」。
2. **MergeChatConfirmScreen（Step 2）**：输入标题 + 选择挂载位置（parent node）。
3. **提交**：读取每个选中节点的 `session.md` → 逐条 `importMessages` 写入新 chat（保持 role，assistant 保留 modelId）→ 跳转新 chat。

## 3. 跨 Tree 范围（关键约束）

> ⚠️ **Theme ≠ Tree**：一个 `ThemeEntity` 可以有多个 root 节点 = 多棵树。所以"限制在当前主题"**不等于**"限制在当前树"。挂位置选择器的 tree 范围必须显式按入口区分。

| 入口 | `crossTree` | 挂位置选择器行为 |
|------|-------------|------------------|
| **Chat Page** | `false` | 只显示**当前树**（合并节点所在的子树）；挂载位置只能选该树上的节点；「顶层」选项 = 挂到当前树根下，**不新建顶层树** |
| **Tree Page** | `true` | 显示整个 theme；若 theme 含 > 1 棵树，顶部出现横滑 tree chip 选择行，可跨树挂载到任意树 |

### 实现要点

- `MergeChatConfirmScreen` 在 `crossTree == false` 时：
  - 用 `merge_chat_tree_scope.dart` 的纯函数从 `selectedNodes.first` 沿 `parentId` 上溯到当前树根 `currentTreeRootId`；
  - 再 `subTreeNodes(allNodes, currentTreeRootId)` 只取该子树节点渲染到挂位置列表（其他树的节点根本不进入列表，UI 上无法选中）；
  - `_submit` 额外加**防御锁**：若选中的挂载点 `_selectedParentId` 不在当前树子树 `subIds` 内，强制落回 `currentTreeRootId`（不应发生，但 defense in depth）。
- `crossTree == true` 时：挂位置列表显示整个 theme；`_buildThemeSelector` 仅当 tree 总数 > 1 时渲染 chip 行，切 tree 时重置选中。

## 4. 涉及文件

| 文件 | 职责 |
|------|------|
| `lib/ui/features/themes/full_tree_screen.dart` | 多选模式 + 跳转带 `crossTree` 参数 |
| `lib/ui/features/themes/merge_chat_confirm_screen.dart` | Step 2（标题 + 挂载位置），`crossTree` 驱动 UI 与 `_submit` |
| `lib/ui/features/themes/merge_chat_tree_scope.dart` | 纯函数 `currentTreeRootIdOf` / `subTreeNodes` / `directChildren`（子树计算，可单测） |
| `lib/ui/features/themes/theme_detail_screen.dart` | Tree Page 入口（overflow menu） |
| `lib/data/stores/session_store.dart` | `importMessages`（逐条写入合并历史） |
| `lib/ui/core/router.dart` | merge-confirm 路由解析 `crossTree` |

## 5. 测试

- `test/merge_chat_tree_scope_test.dart` — 6 case：构造含两棵树（rootA→a1→a2 / rootB→b1→b2）的 theme，断言 `subTreeNodes(rootA)` 只含 Tree A、`directChildren(rootA)` 排除 Tree B、cross-tree 节点 `b1` 永不可选。固定"挂载节点只能选当前 tree"长期约束。
