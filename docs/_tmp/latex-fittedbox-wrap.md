# LaTeX 公式 RenderLine 溢出修复

## 背景

LLM 返回含数学公式的 Markdown 时，控制台抛出：

```
A RenderLine overflowed by 15 pixels on the right.
Line-[GlobalKey#b7d86]
Line:file:///.../flutter_math_fork-0.7.4/lib/src/ast/syntax_tree.dart:563:16
```

链路：`gpt_markdown` → `LatexMath.build` → `Math.tex(...)` → `RichText` → `_AutoScaleInlineWidget` → `Line`（宽度算多 15px）。

## 根因

`flutter_math_fork 0.7.4` 内部 `Line` widget 对含 `\frac` / `\sum` / `\int` 等大符号的公式宽度计算比实际短 ~15px，RichText 父容器 maxWidth 不够。`gpt_markdown` 是项目的直接依赖，传递依赖引入 `flutter_math_fork`。

APP 实际渲染正常（15px 溢出肉眼几乎不可见），仅在 debug 模式标记黄黑斜条 + 框架打 warning 日志。

## 方案

走 **方案 A：包 `FittedBox(scaleDown)`**。

通过 `GptMarkdown.latexBuilder` 接管 LaTeX 渲染，对 `Math.tex(...)` 的输出套 `FittedBox(fit: BoxFit.scaleDown)`：

- 子组件宽度 ≤ 父容器时 → 保持原尺寸，零侵入
- 子组件宽度 > 父容器时 → 等比缩放，刚好放下
- block（多行）公式也走同一 builder，统一处理

保留 `Math.tex` 默认参数（`mathStyle: display`、`strict: ignore`、`onErrorFallback`），行为与上游默认一致。

## 实施点

- 文件：`lib/ui/core/shared/message_bubble.dart`
- 改动：`_MessageBubbleState.build` 内调用 `GptMarkdown` 时新增 `latexBuilder` 参数
- 函数 `latexBuilder` 直接放该文件顶层私有函数 `_buildLatex`（与 `_buildCodeBlock` / `_buildTable` 同级）
- 同步在 `_TableExpandedView` 也加上同一 builder（保持视觉一致）

## 验证

1. `flutter analyze` 无错
2. 现有集成测试通过
3. 新增集成测试 `chat_latex_overflow_test.dart`：构造含 `$...$` 公式的 assistant 消息，触发聊天页面，断言无 `RenderLine overflowed` 异常
