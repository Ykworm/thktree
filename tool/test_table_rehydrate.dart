import 'package:thk_tree/ui/core/shared/markdown_rehydrate.dart';

void main() {
  // 测试 1：完整表格（粘成一行）
  print('=== Test 1: 完整表格粘成一行 ===');
  final test1 = '#现代 AI模型类型全景对比##一、核心模型类型总览|模型类型 |代表模型 |核心能力 |核心优势 ✅ |核心劣势 ❌ |最佳适用场景 🎯 |不适用场景 ⚠️ ||:---|:---|:---|:---|:---|:---|:---|| **LLM**<br>大型语言模型 | GPT-5、Claude4.5 |文本理解与生成 |通用性强 |幻觉问题 |智能客服 |实时物理交互 |';
  print(rehydrateMarkdown(test1));

  print('\n\n=== Test 2: 正常文本不受影响 ===');
  final test2 = '正常文本\n## 标题\n内容\n- 列表项1\n- 列表项2';
  print(rehydrateMarkdown(test2));

  print('\n\n=== Test 3: 原有病句（确保不回归）===');
  final test3 = '开头段。## 章节一这是内容。## 章节二那是内容。---结尾';
  print(rehydrateMarkdown(test3));

  print('\n\n=== Test 4: em-dash 不误伤 ===');
  final test4 = 'a---b---c 都不该重建';
  print(rehydrateMarkdown(test4));
}
