import 'package:flutter/cupertino.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:gpt_markdown/custom_widgets/selectable_adapter.dart';

/// Markdown 渲染相关的 builder 集合，集中放在这个文件以便复用和测试。

/// LaTeX 渲染 builder：在 gpt_markdown 默认实现（Math.tex + SelectableAdapter）
/// 外面包一层 FittedBox(scaleDown)，让含大符号（\frac/\sum/\int）的公式超宽时
/// 等比缩放避开 flutter_math_fork 0.7.4 的 RenderLine 宽度计算溢出。
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
