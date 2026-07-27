import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/session_markdown.dart';

void main() {
  test('parse interrupted marker', () {
    const md = '''
---
title: t
---
## assistant · 2026-07-27T05:00:00.000Z · msg_01J8Z9128M0X0Z8XJ2A1C4D3E5 · gpt-4o
Partial answer here.
<!-- interrupted -->
''';
    final doc = parseSessionMarkdown(md);
    expect(doc.messages.single.status, SessionMessageStatus.interrupted);
    expect(doc.messages.single.body, 'Partial answer here.');
  });

  test('interrupted preserves reasoning block', () {
    const md = '''
---
title: t
---
## assistant · 2026-07-27T05:00:00.000Z · msg_01J8Z9128M0X0Z8XJ2A1C4D3E5
<!-- reasoning:start -->
think
<!-- reasoning:end -->

Answer body
<!-- interrupted -->
''';
    final doc = parseSessionMarkdown(md);
    final msg = doc.messages.single;
    expect(msg.status, SessionMessageStatus.interrupted);
    expect(msg.reasoning, 'think');
    expect(msg.body, 'Answer body');
  });
}
