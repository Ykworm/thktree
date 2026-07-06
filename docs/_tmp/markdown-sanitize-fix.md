# Markdown 清洗修复方案

## 问题分析

目标文件：`lib/ui/core/shared/message_bubble.dart`，涉及顶层函数 `_sanitizeMarkdown`、`_buildSeparatorRow` 等。

### 问题 1：表格对齐信息丢失

**现状**：第 89-90 行，识别表格后调用 `_buildSeparatorRow(cols)` 重新生成分隔行，永远输出 `|---|---|`，丢失 `:---:` / `---:` 等对齐声明。`gpt_markdown` 解析后 `CustomTableField.alignment` 会全部是默认左对齐。

**修复**：解析原始 separator 行每一列的冒号位置，提取对齐信息，生成带 `:` 的 separator。
- 新增 `_parseColumnAlignments(String sepRow, int colCount)` 返回 `List<_ColumnAlign>`（left/center/right）
- `_buildSeparatorRow` 改为接收 alignments 列表，按列输出 `---` / `:---:` / `---:`

### 问题 2：`<think>` 全局删除

**现状**：`_sanitizeMarkdown` 无条件删除 `<think>...</think>`。调用点：
- L300：`sanitizedBody` — 所有消息（user + assistant）都走这里
- L543：`sanitizedReasoning` — 推理区（assistant）
- L743：展开表格视图（assistant 内容）

用户消息如果正文里包含 `<think>xxx</think>` 字面文本，会被吞掉。

**修复**：给 `_sanitizeMarkdown` 增加参数 `{bool stripThinkTags = false}`：
- 用户消息：`_sanitizeMarkdown(body, stripThinkTags: false)`
- assistant body / reasoning / expanded table：`stripThinkTags: true`

### 问题 3：全角符号处理不全

**现状**（L45）：只处理了 `\uff0a`（＊ → *）和 `\uff03`（＃ → #）。

**修复**：补充以下 markdown 语法字符的全角→半角映射（代码块外生效）：
- `｀` (U+FF40) → `` ` ``
- `＞` (U+FF1E) → `>`
- `－` (U+FF0D) → `-`
- `｜` (U+FF5C) → `|`
- `＿` (U+FF3F) → `_`
- `～` (U+FF5E) → `~`
- `＝` (U+FF1D) → `=`

注意：全角空格 `\u3000` 不属于 markdown 语法字符，不处理。全角符号转换在代码块（` ``` ` 围栏和 `` `inline` ``）内不应该做，需要跟踪行内 code 状态。

当前的 inCodeFence 只处理围栏代码块，没有处理行内反引号。对于全角符号处理，需要在非代码块区域内同时跟踪行内 code span（反引号对），避免把 code 里面的全角字符也替换了。

简化处理：行内 code span 的全角字符不转换（反引号配对之间的内容跳过）；围栏代码块内也不转换。

### 问题 4：`||` 拆分过于激进

**现状**（L58-64）：任何一行同时包含 `||`、`|`、`-` 就做 `||` → `|\n|` 拆分。普通文本如果恰好含这三个字符（例如"a | b - c || d"）会被误拆。

**修复**：收紧判断条件。`||` 拆分的目的是把 LLM 粘连的"表头 || 分隔行"或"分隔行 || 数据行"拆开，因此要求 `||` 分割后的片段至少有一段本身是合法的表格分隔行（即匹配 `^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*$`）。

具体：先用 `||` 试探性 split，检查是否存在某段（trim 后）匹配 `_looseTableSepPattern`；只有匹配时才做拆分，否则原样保留。

## 验收方式

1. **编译通过**：`flutter analyze` 无新增错误
2. **手工验证**（在 debug 模式下通过聊天 UI 验证）：
   - 含 `:---:` / `---:` 的表格渲染后居中/右对齐（观察 `CustomTableField.alignment` 是否正确）
   - 用户消息中发送含 `<think>xxx</think>` 的文本，显示完整
   - assistant 回复中的 `<think>` 仍被正确剥离
   - 全角 `｀＞－｜＿～＝` 在非代码区域被转为半角
   - 围栏代码块和行内 code 中的全角字符保留
   - 普通文本行 "a | b - c || d" 不被误拆

不新增 focused tests（纯字符串处理，编译通过 + 手工验证即可覆盖）。
