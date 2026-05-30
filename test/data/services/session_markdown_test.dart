import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/session_markdown.dart';

void main() {
  test('parses frontmatter and messages', () {
    const doc = '''
---
schema: session/v1
themeId: "thm_01J8Z8T3C3P7W6XK9YB2V2J0QK"
nodeId: "nd_01J8Z8W2K4T9Z5D1H3G0W7N2Q9"
kind: "chat"
parentId: null
title: "New Chat"
createdAt: "2026-05-25T12:01:00.000Z"
updatedAt: "2026-05-25T12:01:03.120Z"
---

## user · 2026-05-25T12:01:00.000Z · msg_01J8Z90Z5H7H7G1W5Q2QH1B9Y8
hello

## assistant · 2026-05-25T12:01:03.120Z · msg_01J8Z9128M0X0Z8XJ2A1C4D3E5
world
''';

    final parsed = parseSessionMarkdown(doc);
    expect(parsed.frontmatter['schema'], 'session/v1');
    expect(parsed.messages, hasLength(2));
    expect(parsed.messages[0].role, SessionRole.user);
    expect(parsed.messages[0].body, 'hello');
    expect(parsed.messages[0].status, SessionMessageStatus.done);
    expect(parsed.messages[1].role, SessionRole.assistant);
    expect(parsed.messages[1].body, 'world');
  });

  test('parses streaming marker as status=streaming', () {
    const doc = '''
---
schema: session/v1
themeId: "thm_x"
nodeId: "nd_x"
kind: "chat"
parentId: null
title: "t"
createdAt: "2026-05-25T12:01:00.000Z"
updatedAt: "2026-05-25T12:01:03.120Z"
---

## assistant · 2026-05-25T12:01:03.120Z · msg_01J8Z9128M0X0Z8XJ2A1C4D3E5
partial
<!-- streaming -->
''';

    final parsed = parseSessionMarkdown(doc);
    expect(parsed.messages, hasLength(1));
    expect(parsed.messages[0].status, SessionMessageStatus.streaming);
    expect(parsed.messages[0].body, 'partial');
  });

  test('parses error marker as status=error with errorCode', () {
    const doc = '''
---
schema: session/v1
themeId: "thm_x"
nodeId: "nd_x"
kind: "chat"
parentId: null
title: "t"
createdAt: "2026-05-25T12:01:00.000Z"
updatedAt: "2026-05-25T12:01:03.120Z"
---

## assistant · 2026-05-25T12:01:03.120Z · msg_01J8Z9128M0X0Z8XJ2A1C4D3E5
partial
<!-- error: network -->
''';

    final parsed = parseSessionMarkdown(doc);
    expect(parsed.messages[0].status, SessionMessageStatus.error);
    expect(parsed.messages[0].errorCode, 'network');
    expect(parsed.messages[0].body, 'partial');
  });

  test('does not split on non-matching ## lines in body', () {
    const doc = '''
---
schema: session/v1
themeId: "thm_x"
nodeId: "nd_x"
kind: "chat"
parentId: null
title: "t"
createdAt: "2026-05-25T12:01:00.000Z"
updatedAt: "2026-05-25T12:01:03.120Z"
---

## user · 2026-05-25T12:01:00.000Z · msg_01J8Z90Z5H7H7G1W5Q2QH1B9Y8
line1
## not a header
line3
''';

    final parsed = parseSessionMarkdown(doc);
    expect(parsed.messages, hasLength(1));
    expect(parsed.messages[0].body, 'line1\n## not a header\nline3');
  });

  test('accepts lowercase msg ids', () {
    const doc = '''
---
schema: session/v1
themeId: "thm_x"
nodeId: "nd_x"
kind: "chat"
parentId: null
title: "t"
createdAt: "2026-05-25T12:01:00.000Z"
updatedAt: "2026-05-25T12:01:03.120Z"
---

## user · 2026-05-25T12:01:00.000Z · msg_01j8z90z5h7h7g1w5q2qh1b9y8
hello
''';

    final parsed = parseSessionMarkdown(doc);
    expect(parsed.messages, hasLength(1));
    expect(parsed.messages[0].msgId, 'msg_01j8z90z5h7h7g1w5q2qh1b9y8');
    expect(parsed.messages[0].body, 'hello');
  });
}
