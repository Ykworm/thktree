import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/wiki_service.dart';
import 'package:thk_tree/domain/node.dart';

void main() {
  test('buildWikiDocument filters system and incomplete messages', () async {
    final nodes = [
      NodeEntity(
        themeId: 'thm_1',
        nodeId: 'nd_1',
        parentId: null,
        kind: NodeKind.chat,
        title: 'Root',
        createdAtUtcIso8601: '2026-01-01T00:00:00.000Z',
        updatedAtUtcIso8601: '2026-01-01T00:00:00.000Z',
        sortOrder: 0,
      ),
      NodeEntity(
        themeId: 'thm_1',
        nodeId: 'nd_2',
        parentId: 'nd_1',
        kind: NodeKind.chat,
        title: 'Child',
        createdAtUtcIso8601: '2026-01-01T00:01:00.000Z',
        updatedAtUtcIso8601: '2026-01-01T00:01:00.000Z',
        sortOrder: 0,
      ),
    ];

    final sessions = {
      'nd_1': SessionDocument(
        frontmatter: {},
        messages: [
          SessionMessage(
            role: SessionRole.system,
            timestampUtcIso8601: '2026-01-01T00:00:00.000Z',
            msgId: 'msg_1',
            body: 'System prompt',
            status: SessionMessageStatus.done,
          ),
          SessionMessage(
            role: SessionRole.user,
            timestampUtcIso8601: '2026-01-01T00:00:01.000Z',
            msgId: 'msg_2',
            body: 'Hello',
            status: SessionMessageStatus.done,
          ),
          SessionMessage(
            role: SessionRole.assistant,
            timestampUtcIso8601: '2026-01-01T00:00:02.000Z',
            msgId: 'msg_3',
            body: 'Hi there',
            status: SessionMessageStatus.done,
          ),
          SessionMessage(
            role: SessionRole.assistant,
            timestampUtcIso8601: '2026-01-01T00:00:03.000Z',
            msgId: 'msg_4',
            body: 'Incomplete',
            status: SessionMessageStatus.streaming,
          ),
        ],
      ),
      'nd_2': SessionDocument(
        frontmatter: {},
        messages: [
          SessionMessage(
            role: SessionRole.user,
            timestampUtcIso8601: '2026-01-01T00:01:00.000Z',
            msgId: 'msg_5',
            body: 'Child question',
            status: SessionMessageStatus.done,
          ),
        ],
      ),
    };

    final service = const WikiService();
    final doc = await service.buildWikiDocument(
      themeId: 'thm_1',
      themeTitle: 'Test Theme',
      nodes: nodes,
      readSession: (nodeId) async => sessions[nodeId]!,
    );

    expect(doc.themeId, 'thm_1');
    expect(doc.themeTitle, 'Test Theme');
    expect(doc.root.title, 'Test Theme');
    expect(doc.root.children.length, 1);

    final root = doc.root.children.first;
    expect(root.nodeId, 'nd_1');
    expect(root.title, 'Root');
    expect(root.depth, 1);
    expect(root.messages.length, 2);
    expect(root.messages[0].role, SessionRole.user);
    expect(root.messages[1].role, SessionRole.assistant);

    expect(root.children.length, 1);
    final child = root.children.first;
    expect(child.nodeId, 'nd_2');
    expect(child.title, 'Child');
    expect(child.depth, 2);
    expect(child.messages.length, 1);
    expect(child.messages[0].role, SessionRole.user);
  });

  test('buildWikiDocument handles empty tree', () async {
    final service = const WikiService();
    final doc = await service.buildWikiDocument(
      themeId: 'thm_1',
      themeTitle: 'Empty',
      nodes: const [],
      readSession: (nodeId) async => SessionDocument(frontmatter: {}, messages: []),
    );

    expect(doc.root.children, isEmpty);
    expect(doc.flatten(), isEmpty);
  });
}
