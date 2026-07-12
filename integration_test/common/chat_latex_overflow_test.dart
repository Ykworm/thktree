import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/ui/core/shared/markdown_builders.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('LaTeX 公式渲染回归', () {
    // 复现 message_bubble 报错时的真实约束：RichText 父容器 maxWidth=331.9。
    const constrainedWidth = 331.9;

    // 收集 pump 过程中的 FlutterError，断言没有 RenderLine overflowed 之类。
    final overflowErrors = <String>[];

    setUp(() {
      overflowErrors.clear();
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final msg = details.exceptionAsString();
        if (msg.contains('overflowed') || msg.contains('RenderFlex')) {
          overflowErrors.add(msg);
        }
        originalOnError?.call(details);
      };
    });

    tearDown(() {
      FlutterError.onError = null;
    });

    Future<void> _pumpLatex(WidgetTester tester, String body) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SafeArea(
              child: Center(
                child: Container(
                  width: constrainedWidth,
                  padding: const EdgeInsets.all(8),
                  child: GptMarkdown(
                    body,
                    style: const TextStyle(fontSize: 17, color: Color(0xFF000000)),
                    latexBuilder: buildLatex,
                    useDollarSignsForLatex: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // 触发 layout + 字体加载。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('简单 inline 公式不抛 RenderFlex overflow', (tester) async {
      await _pumpLatex(tester, r'能量公式：$E = mc^2$。');
      expect(overflowErrors, isEmpty,
          reason: '简单公式不应触发布局溢出，错误日志: $overflowErrors');
    });

    testWidgets('含 \\frac \\sum \\int 的复杂公式不溢出', (tester) async {
      // 复现 issue: \\frac + 长求和式在过去会 RenderLine 溢出 15px。
      final body = r'级数：$\sum_{i=1}^{n} \frac{i^2 + 2i + 1}{i + 1}$。';
      await _pumpLatex(tester, body);
      expect(overflowErrors, isEmpty,
          reason: '复杂公式不应触发布局溢出，错误日志: $overflowErrors');
    });

    testWidgets('block 公式（\\[...\\]）不溢出', (tester) async {
      final body = r'块公式：'
          r'\['
          r'\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}'
          r'\]';
      await _pumpLatex(tester, body);
      expect(overflowErrors, isEmpty,
          reason: 'block 公式不应触发布局溢出，错误日志: $overflowErrors');
    });

    testWidgets('公式 + 普通文本混排不溢出', (tester) async {
      final body = '前置文本前缀 '
          r'$\sqrt{a^2 + b^2}$'
          ' 中间普通文字 '
          r'$\frac{1}{2} \sum_{k=1}^{N} k$'
          ' 收尾。';
      await _pumpLatex(tester, body);
      expect(overflowErrors, isEmpty,
          reason: '混排公式不应触发布局溢出，错误日志: $overflowErrors');
    });

    testWidgets('非法公式 fallback 到文本渲染不抛异常', (tester) async {
      // 故意缺右花括号，触发 Math.tex 的 onErrorFallback 路径。
      await _pumpLatex(tester, r'坏公式：$\frac{1}{2$');
      expect(overflowErrors, isEmpty,
          reason: 'fallback 路径不应抛布局错误，错误日志: $overflowErrors');
    });
  });
}
