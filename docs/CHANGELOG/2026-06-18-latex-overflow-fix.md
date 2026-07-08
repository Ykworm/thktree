# LaTeX 公式 RenderLine 溢出修复

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-18 |
| 范围 | chat 模块（共享 message_bubble）+ 新建 `markdown_builders.dart` |
| 设计文档 | [`docs/_tmp/latex-fittedbox-wrap.md`](../war-stories/ui-ux/latex-fittedbox-wrap.md) |
| War Story | [`docs/war-stories/ui-ux/2026-06-18-gptmarkdown-latex-renderline-overflow.md`](../war-stories/ui-ux/2026-06-18-gptmarkdown-latex-renderline-overflow.md) |
| 状态 | ✅ 完成，5 个集成测试通过 |

## 背景

LLM 返回含数学公式的 Markdown 时，控制台抛出：

```
A RenderLine overflowed by 15 pixels on the right.
Line-[GlobalKey#b7d86]
Line:file:///.../flutter_math_fork-0.7.4/lib/src/ast/syntax_tree.dart:563:16
```

链路：`gpt_markdown` → `LatexMath.build` → `Math.tex(...)` → `RichText` → `_AutoScaleInlineWidget` → `Line`（宽度算少 15px）。

APP 实际渲染正常（15px 溢出肉眼几乎不可见），仅在 debug 模式标记黄黑斜条 + 框架打 warning 日志。

## 根因

`flutter_math_fork 0.7.4` 内部 `Line` widget 对含 `\frac` / `\sum` / `\int` 等大符号的公式宽度计算比实际短 ~15px，RichText 父容器 maxWidth 不够。`gpt_markdown` 是项目的直接依赖，传递依赖引入 `flutter_math_fork`。

## 方案

走 **方案 A：包 `FittedBox(scaleDown)`**。

通过 `GptMarkdown.latexBuilder` 接管 LaTeX 渲染，对 `Math.tex(...)` 的输出套 `FittedBox(fit: BoxFit.scaleDown)`：

- 子组件宽度 ≤ 父容器时 → 保持原尺寸，零侵入
- 子组件宽度 > 父容器时 → 等比缩放，刚好放下
- block（多行）公式也走同一 builder，统一处理

保留 `Math.tex` 默认参数（`mathStyle: display`、`strict: ignore`、`onErrorFallback`），行为与上游默认一致。

## 实施内容

### 新增文件（2）

```
lib/ui/core/shared/markdown_builders.dart                      # buildLatex 函数 + LatexBuilder 签名保护
integration_test/chat_latex_overflow_test.dart                 # 5 个集成测试
```

### 修改文件（2）

```
pubspec.yaml                                                    # flutter_math_fork: any 升为直接依赖
lib/ui/core/shared/message_bubble.dart                          # 2 处 GptMarkdown 调用加 latexBuilder + useDollarSignsForLatex
```

### 关键改动

**`message_bubble.dart` — 主消息渲染：**

```dart
GptMarkdown(
  body,
  style: baseStyle,
  tableBuilder: _buildTable,
  codeBuilder: _buildCodeBlock,
  latexBuilder: buildLatex,
  useDollarSignsForLatex: true,
),
```

**`message_bubble.dart` — `_TableExpandedView`（点放大按钮的全屏视图）：**

```dart
GptMarkdown(
  content,
  style: TextStyle(fontSize: 17, height: 1.6),
  codeBuilder: _buildCodeBlock,
  tableBuilder: _buildTable,
  latexBuilder: buildLatex,
  useDollarSignsForLatex: true,
),
```

**`pubspec.yaml`：**

```yaml
gpt_markdown: ^1.1.7
# flutter_math_fork 由 gpt_markdown 传递引入；项目里 MessageBubble 需要直接调用
# Math.tex() 来自定义 LaTeX 渲染，所以在这里也声明为直接依赖（不锁版本，跟随
# gpt_markdown 的解析结果）。
flutter_math_fork: any
```

## 验证

| 类别 | 状态 |
|---|---|
| `flutter analyze` | ✅ 无错 |
| 集成测试 `chat_latex_overflow_test.dart` | ✅ 5 / 5 通过 |
| 场景覆盖 | 简单 inline / 含 `\frac\sum\int` 复杂公式 / block / 混排 / 非法公式 fallback |

## 已知风险（留给后续决定）

`GptMarkdown` 在以下 4 个文件也使用了，但本次修复**仅**在 `message_bubble.dart` 加了 `latexBuilder`：

- `lib/main.dart`
- `lib/ui/features/notes/note_detail_screen.dart`
- `lib/ui/core/shared/share_card_widget.dart`
- `lib/ui/features/settings/tts_player_screen.dart`

理论上这些地方也存在同类 RenderLine 溢出风险（取决于是否真有 LaTeX 内容）。本次不动这些文件（超出本 changelog 范围）。后续如观察到以下场景的 overflow warning，需把 `latexBuilder: buildLatex, useDollarSignsForLatex: true` 同步加到对应 `GptMarkdown(...)` 调用：

1. 笔记详情页渲染含 `$...$` 公式的笔记
2. 分享卡片截图含 LaTeX
3. TTS 播放器朗读含 LaTeX 的消息

## 关联

- [DECISIONS.md ADR-007](../DECISIONS.md#adr-007-markdown-渲染库-gpt_markdown-替代-flutter_markdown) — Markdown 渲染库选型
- [docs/war-stories/ui-ux/2026-06-18-gptmarkdown-latex-renderline-overflow.md](../war-stories/ui-ux/2026-06-18-gptmarkdown-latex-renderline-overflow.md) — 同类问题 war story
- [docs/war-stories/ui-ux/2026-06-17-gptmarkdown-heading-style-in-cupertino.md](../war-stories/ui-ux/2026-06-17-gptmarkdown-heading-style-in-cupertino.md) — 前置同类问题（标题样式 + h1 横线）