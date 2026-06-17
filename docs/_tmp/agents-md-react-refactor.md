# AGENTS.md context-sync 流程改造：ReAct 强制格式 + 工具手册拆分

> 目标：解决 LLM "Instruction Skipping" 问题——context-sync 时跳过 CodeGraph 状态检查。
> 方法：ReAct 强制格式（THOUGHT/ACTION/OBSERVATION）+ 工具手册拆分到独立文件。
> 触发原因：执行 ctsync 时未先跑 `codegraph status` 就打印降级提示。

---

## 外部建议采纳记录

Gemini 提供了 4 条建议，经评估后采纳 3 条、拒绝 1 条：

| 建议 | 采纳 | 原因 |
|------|------|------|
| Negative Example（异常降级范例） | ✅ 采纳 | 模型学到降级路径，报错时不慌 |
| 高频命令内联（status/sync 放 AGENTS.md） | ✅ 采纳 | 省一次读文件轮次，务实 |
| Step 0 加 🛑 BLOCKER 标记 | ✅ 采纳 | 语义更强，防止跳步 |
| Stop 约束（ACTION 后强制停止） | ❌ 拒绝 | Codex 直接调 exec_command 工具，系统自动返回结果，不存在"输出文本 → 等系统返回"的交互模式。THOUGHT/ACTION/OBSERVATION 是思维模板，不是执行协议 |

---

## 改动清单

1. `AGENTS.md` — context-sync 流程重构 + 工具段落替换为指引
2. `docs/_shared/tool-reference.md` — **新建**，存放工具参考手册

---

## 1. 新建 `docs/_shared/tool-reference.md`

从 AGENTS.md 中搬出以下内容（原样保留，命令和场景表保持真实可用）：

- CodeGraph 常用命令、使用场景表、fallback 策略、索引维护、MCP 模式
- rg 常用命令、fallback 策略
- 其他工具优先级表
- 工具降级时的行为

---

## 2. AGENTS.md 改造

### 2.1 顶部加 Few-Shot 示例（通用版，不写死具体数字）

在触发命令之后、硬约束之前插入：

```markdown
## 执行范式（ReAct）

每次执行 context-sync 必须严格遵循 THOUGHT → ACTION → OBSERVATION 循环。
禁止跳过任何步骤的 OBSERVATION，禁止在未看到工具返回值之前做假设。

### 范例 1（正常流程）

**用户**：ctsync

**Agent**：

> **THOUGHT**：用户触发 context-sync。第一步必须确认工具可用性。
>
> **ACTION**：`codegraph status`
>
> **OBSERVATION**：[返回索引状态：文件数、节点数、是否最新]
>
> **THOUGHT**：CodeGraph 可用，符号引用判断使用 codegraph。接下来收集改动范围。
>
> **ACTION**：`git diff --name-only HEAD`
>
> **OBSERVATION**：[返回改动文件列表]
>
> **THOUGHT**：改动涉及 XX 模块。接下来遍历 docs 并做三重判断。
> （继续后续步骤...）

### 范例 2（CodeGraph 不可用时的降级处理）

**Agent**：

> **THOUGHT**：第一步必须确认工具可用性。
>
> **ACTION**：`codegraph status`
>
> **OBSERVATION**：[Error: index not found / not running]
>
> **THOUGHT**：CodeGraph 不可用，必须执行降级策略并告知用户。使用 rg 搜索符号引用，精度有限需在影响清单前声明。
>
> **ACTION**：`rg "ClassName" docs/ --type md`
>
> **OBSERVATION**：[返回匹配文件列表]
>
> **THOUGHT**：继续使用 rg 完成后续影响评估...
```

### 2.2 流程步骤加 ReAct 格式

**Step 0：工具可用性检查 🛑 BLOCKER（新增）**

```markdown
### 🛑 [BLOCKER] Step 0：工具可用性前置检查 (MANDATORY)

不管用户后续要求做什么，本步骤是 BLOCKER（阻塞项）。
未获得 `codegraph status` 的真实 OBSERVATION 前，严禁推进到 Step 1。

> **THOUGHT**：执行 context-sync 前必须确认 CodeGraph 状态。
>
> **ACTION**：`codegraph status`
>
> **OBSERVATION**：[等待返回结果]
>
> **THOUGHT**：根据返回结果决定符号引用判断工具：
> - 索引最新 → 使用 codegraph（精确）
> - 索引过期 → 先 `codegraph sync`，再用 codegraph
> - 不可用 → 降级为 rg，必须在影响清单前告知用户
```

**Step 1-3** 加 THOUGHT/ACTION/OBSERVATION 标记，内容不变。

**Step 4-8** 保持原样。

### 2.3 工具段落替换为简要指引（高频命令内联）

```markdown
## 工具参考（核心命令）

最常用命令（直接使用，无需查阅手册）：
- 检查状态：`codegraph status`
- 同步索引：`codegraph sync`
- 文本搜索：`rg "keyword" <path>`

完整命令参考、使用场景、fallback 策略：
> 读取 `docs/_shared/tool-reference.md`

规则：
- 代码智能优先 `codegraph`，fallback `rg`
- 文本搜索优先 `rg`，fallback `grep`
- 文件查找优先 `fd`，fallback `find`
- 工具不可用时必须告知用户（CodeGraph）或静默 fallback（rg → grep）
- ⚠️ rg 必须优先于 grep，任何场景不得跳过
```

---

## 3. 保留不变的部分

- 硬约束 7 条
- Step 4 影响清单格式（列表 + 卡片）
- Step 5 卡片格式
- Step 6-8 确认/修改/汇报
- 不在管辖范围

---

## 预期效果

- **AGENTS.md**：从约 250 行压缩到约 110 行
- **tool-reference.md**：约 80 行工具手册，按需读取
- **关键检查强制化**：Step 0 🛑 BLOCKER + ReAct 格式锁死 CodeGraph 检查
- **降级路径覆盖**：Negative Example 让模型学会异常处理
- **注意力聚焦**：AGENTS.md 只保留执行规则，参考手册不占用注意力窗口

---

## Test Plan

- 保存后触发 `ctsync`，观察是否先执行 `codegraph status`
- 确认 CodeGraph 不可用时正确降级并告知
- 确认 tool-reference.md 内容完整可读
- 确认 AGENTS.md 整体流程无遗漏
