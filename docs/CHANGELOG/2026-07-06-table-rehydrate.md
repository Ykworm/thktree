# Markdown 表格重建兜底（rehydrateMarkdown）

> 日期：2026-07-06

## 背景

DeepSeek 流式 token 在 tokenization 边界可能丢 `\n`，导致 markdown 表格被压平成单行纯文本。`rehydrateMarkdown` 原有实现（针对 `##`、`---`、列表等块级结构）不覆盖表格场景，压扁的表格直接进入 `gpt_markdown` 解析器后渲染异常。

## 问题

以用户发送的 DeepSeek 表格输出为例，原始输入：

```
|模型类型 |代表模型 |核心能力 ||:---|:---|:---|| **LLM** | GPT-5 | 文本理解 || **SLM** | Phi-4 | 轻量推理 |
```

表头、分隔行、多行数据行全部粘在同一行，`|:---|` 里的 `---` 还会被 HR（水平分割线）规则误切成独立段落。表格内的连字符（`DeepSeek-V3`、`Kimi-K2`）还会被列表项规则切开。

## 改动

### `_rehydrateTables`（PASS 0，最先执行）

- 以 `|:---|:---|...` 分隔行为锚点，向左数 `|` 定位表头行，向右数 `|` 定位数据行（支持多行）
- 把压扁的表格重建为标准多行格式：表头行 / 分隔行 / 数据行（每行独立一行）
- 识别依据：连续的 `|:---|` 模式 + `|` 计数匹配（表头和数据行的 `|` 数量必须与分隔行一致）

### 占位符保护机制

- 表格重建后，用 `\u0000TABLE_N\u0000` 占位符替换整个表格块
- 所有后续规则（`---` HR、`- ` 列表项、`**` bold 段落等）在占位符上运行，碰不到表格内容
- 所有规则跑完后，还原表格

### `---` 规则防护

- HR 规则的 lookahead 加了 `(?![^\n]*\|)`：同一行内出现 `|` 的 `---` 不被当成 HR（双重防护，防止表格分隔行被切碎）

## 改动文件

- `lib/ui/core/shared/markdown_rehydrate.dart`（`_rehydrateTables` 重写 + 占位符保护 + `---` 规则加固）
- `tool/test_table_rehydrate.dart`（删除，原 smoke test 已覆盖表格场景）

## 验证

- `flutter analyze lib/ui/core/shared/markdown_rehydrate.dart` → 0 issues
- `dart run tool/rehydrate_smoke_test.dart` → 35/35 通过（含原有用例，无回归）
- 手工验证 DeepSeek 7 列多行表格：表头/分隔行/数据行各自独立，`DeepSeek-V3` 等连字符不被切开，两个表格各自独立重建
