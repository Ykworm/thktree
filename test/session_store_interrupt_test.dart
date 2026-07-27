import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/stores/session_store.dart';

void main() {
  test('interruptAssistant replaces streaming marker with interrupted', () async {
    final dir = await Directory.systemTemp.createTemp('thktree_interrupt_test');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final sessionPath = '${dir.path}/session.md';
    await File(sessionPath).writeAsString('''
---
nodeId: nd_test
---
## user · 2026-07-27T05:00:00.000Z · msg_01J8Z9128M0X0Z8XJ2A1C4D3E6
hello

## assistant · 2026-07-27T05:00:01.000Z · msg_01J8Z9128M0X0Z8XJ2A1C4D3E7 · gpt-4o
Partial content saved so far.

<!-- streaming -->
''');

    final store = SessionStore(
      getSessionPathForNode: (_) async => sessionPath,
    );
    await store.interruptAssistant(
      handle: AssistantStreamHandle(
        nodeId: 'nd_test',
        msgId: 'msg_01J8Z9128M0X0Z8XJ2A1C4D3E7',
      ),
    );

    final raw = await File(sessionPath).readAsString();
    expect(raw.contains('<!-- streaming -->'), isFalse);
    expect(raw.contains('<!-- interrupted -->'), isTrue);

    final doc = await store.readSession('nd_test');
    final assistant = doc.messages.last;
    expect(assistant.status, SessionMessageStatus.interrupted);
    expect(assistant.body, 'Partial content saved so far.');
  });
}
