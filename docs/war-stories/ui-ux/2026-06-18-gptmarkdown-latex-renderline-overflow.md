# GptMarkdown LaTeX 公式 RenderLine 溢出

**日期**：2026-06-18  
**模块**：chat / 共享 UI（MessageBubble）  
**标签**：Flutter, UI, Markdown, LaTeX, flutter_math_fork, overflow, 第三方库兼容

## 现象

跟 LLM 对话时，模型返回含数学公式的 Markdown，控制台抛出：

```
A RenderLine overflowed by 15 pixels on the right.
Line-[GlobalKey#b7d86]
Line:file:///.../flutter_math_fork-0.7.4/lib/src/ast/syntax_tree.dart:563:16
```

复现条件：

- LLM 回复含 `$...$`（inline）或 `$$...$$`（block）LaTeX 公式
- 公式带大符号（`\frac` / `\sum` / `\int` / 矩阵等）
- 公式宽度接近 message_bubble 的 `maxWidth`（chat 默认 520，有表格时屏幕宽 - 32 ≈ 343-400）

APP 实际渲染正常（15px 溢出肉眼几乎不可见），仅 debug 模式标记黄黑斜条 + 框架打 warning 日志。

## 根因分析

`gpt_markdown` 1.1.7 的 LaTeX 渲染走 `flutter_math_fork 0.7.4`：

```
gpt_markdown
  └─ LatexMath.build
       └─ Math.tex(...)           ← flutter_math_fork 入口
            └─ RichText
                 └─ _AutoScaleInlineWidget
                      └─ Line     ← 宽度算少 15px
```

`flutter_math_fork 0.7.4` 的 `Line` widget（`lib/src/ast/syntax_tree.dart:563`）对含 `\frac` / `\sum` / `\int` 等大符号的公式宽度计算比实际短 ~15px，导致 RichText 在 520px（或更窄的）maxWidth 容器里渲染时触发 overflow 警告。

这是 `flutter_math_fork` 0.7.4 上游 bug（issue tracker 已有，但截至本文尚未发修复版本）。

## 解决方案

自定义 `GptMarkdown.latexBuilder`，对 `Math.tex(...)` 的输出包一层 `FittedBox(fit: BoxFit.scaleDown)`：

- 子组件宽度 ≤ 父容器时 → 保持原尺寸，零侵入
- 子组件宽度 > 父容器时 → 等比缩放，刚好放下

### 实施代码

新建 `lib/ui/core/shared/markdown_builders.dart`：

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:gpt_markdown/custom_widgets/selectable_adapter.dart';

Widget buildLatex(
  BuildContext context,
  String tex,
  TextStyle textStyle,
  bool inline,
) {
  final rendered = SelectableAdapter(
    selectedText: tex,
    child: Math.tex(
      tex,
      textStyle: textStyle,
      mathStyle: MathStyle.display,
      textScaleFactor: 1,
      settings: const TexParserSettings(strict: Strict.ignore),
      options: MathOptions(
        sizeUnderTextStyle: MathSize.large,
        color: textStyle.color ?? CupertinoColors.label.resolveFrom(context),
        fontSize: textStyle.fontSize,
        mathFontOptions: FontOptions(
          fontFamily: 'Main',
          fontWeight: textStyle.fontWeight ?? FontWeight.normal,
          fontShape: FontStyle.normal,
        ),
        textFontOptions: FontOptions(
          fontFamily: 'Main',
          fontWeight: textStyle.fontWeight ?? FontWeight.normal,
          fontShape: FontStyle.normal,
        ),
        style: MathStyle.display,
      ),
      onErrorFallback: (err) {
        return Text(
          tex,
          textDirection: TextDirection.ltr,
          style: textStyle,
        );
      },
    ),
  );

  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: rendered,
  );
}

/// 标记 LatexBuilder 签名（防止以后 gpt_markdown 升级时类型签名变化导致静默断链）。
// ignore: unused_element
LatexBuilder _ensureSignature = buildLatex;
```

`message_bubble.dart` 的 `GptMarkdown` 调用加 2 个参数（主消息 + `_TableExpandedView`）：

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

`pubspec.yaml` 把 `flutter_math_fork` 从传递依赖升为直接依赖（项目里需要直接 `import 'package:flutter_math_fork/flutter_math.dart'`）：

```yaml
gpt_markdown: ^1.1.7
flutter_math_fork: any   # 由 gpt_markdown 传递引入；项目里需要直接调用 Math.tex
```

## 验证

- `flutter analyze` 无错
- `flutter test integration_test/chat_latex_overflow_test.dart` 5 个测试全部通过：
  - 简单 inline 公式 `$a^2 + b^2 = c^2$` → 无 overflow
  - 含 `\frac\sum\int` 复杂公式 → 无 overflow
  - block 公式 `$$...$$` → 无 overflow
  - 文字 + 公式混排 → 无 overflow
  - 非法公式（fallback 走 `Text(tex)`）→ 无 overflow

## 相关文件

- `lib/ui/core/shared/markdown_builders.dart` — 新建，`buildLatex` + LatexBuilder 签名保护
- `lib/ui/core/shared/message_bubble.dart` — 修改，2 处 GptMarkdown 调用加 latexBuilder + useDollarSignsForLatex
- `pubspec.yaml` — 修改，flutter_math_fork 升为直接依赖
- `integration_test/chat_latex_overflow_test.dart` — 新建，5 个集成测试

## 参考链接

- [DECISIONS.md ADR-007](../DECISIONS.md#adr-007-markdown-渲染库-gpt_markdown-替代-flutter_markdown) — Markdown 渲染库选型
- [CHANGELOG/2026-06-18-latex-overflow-fix.md](../CHANGELOG/2026-06-18-latex-overflow-fix.md) — 本次修复的 changelog
- [war-stories/ui-ux/2026-06-17-gptmarkdown-heading-style-in-cupertino.md](./2026-06-17-gptmarkdown-heading-style-in-cupertino.md) — 同类问题（标题样式 + h1 横线）
- 上游 bug：`flutter_math_fork` issue tracker（GitHub）

## 复盘

- **为什么一开始没发现**：debug 模式黄黑斜条不显眼，APP 实际渲染正常（15px 溢出肉眼几乎不可见）。普通对话不触发，只有 LLM 返回带大符号的数学公式时才暴露。
- **以后如何避免**：
  1. 引入第三方 markdown 库时，优先检查 LaTeX 路径，构造含 `\frac\sum\int` 的端到端测试
  2. 对所有 `GptMarkdown(...)` 调用统一传 `latexBuilder`，避免遗漏（建议加 lint 规则或在 chat 模块 README 维护要点里登记）
  3. 跨模块共享 builder：本次把 `buildLatex` 放在 `lib/ui/core/shared/markdown_builders.dart`，其他模块（如 note_detail / share_card）后续如需同样处理可直接引用
- **模式总结**：gpt_markdown 的 CupertinoApp 兼容问题已形成一个类别：
  - 标题样式失效（CupertinoApp 无 Material textTheme）
  - h1 自动横线
  - LaTeX RenderLine 溢出
  - 未来引入 gpt_markdown 新特性（如 Mermaid 图表）时，需主动复测 CupertinoApp 兼容性