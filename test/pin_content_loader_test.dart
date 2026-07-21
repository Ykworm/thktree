import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/data/services/pin_content_loader.dart';
import 'package:thk_tree/data/services/pin_storage.dart';
import 'package:thk_tree/data/services/session_markdown.dart';

Pin _messagePin({String? msgId, String? nodeId, String? themeId}) => Pin(
      id: 'pin_1',
      kind: PinKind.message,
      themeId: themeId ?? 'thm_1',
      nodeId: nodeId ?? 'nd_1',
      msgId: msgId ?? 'msg_AAAAAAAAAAAAAAAAAAAAAAAAAA',
      excerpt: '摘要',
      createdAt: DateTime.utc(2026),
    );

Pin _notePin({String? noteId, String? themeId}) => Pin(
      id: 'pin_2',
      kind: PinKind.note,
      themeId: themeId ?? 'thm_1',
      noteId: noteId ?? 'nt_1',
      excerpt: '摘要',
      createdAt: DateTime.utc(2026),
    );

/// 缺字段的 Pin 直接构造（辅助方法的默认值会吞掉显式 null）。
Pin _pinWithMissing({
  required PinKind kind,
  String? themeId,
  String? nodeId,
  String? msgId,
  String? noteId,
}) =>
    Pin(
      id: 'pin_3',
      kind: kind,
      themeId: themeId,
      nodeId: nodeId,
      msgId: msgId,
      noteId: noteId,
      excerpt: '摘要',
      createdAt: DateTime.utc(2026),
    );

void main() {
  late Directory tmpDir;
  late String themesDir;
  late String sessionPath;

  // session 消息头要求 msgId 为 msg_ + 26 位 [0-9A-Z]；
  // 解析器只 trimRight，头部不空行以保证 body 无前置空行
  const sessionMd = '---\n'
      'schema: session/v1\n'
      '---\n'
      '## user · 2026-01-01T00:00:00Z · msg_AAAAAAAAAAAAAAAAAAAAAAAAAA\n'
      '第一条消息正文\n'
      '\n'
      '## assistant · 2026-01-01T00:01:00Z · msg_BBBBBBBBBBBBBBBBBBBBBBBBBB · deepseek-chat\n'
      '第二条消息正文\n'
      '多行内容\n';

  const noteMd = '---\n'
      'schema: note/v1\n'
      'themeId: "thm_1"\n'
      'noteId: "nt_1"\n'
      'title: "测试笔记"\n'
      'createdAt: "2026-01-01T00:00:00.000Z"\n'
      'updatedAt: "2026-01-01T00:00:00.000Z"\n'
      '---\n'
      '\n'
      '笔记正文第一行\n'
      '第二行\n';

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('pin_content_loader_test');
    themesDir = p.join(tmpDir.path, 'themes');
    // 造 session 数据：临时目录里的真实 session.md
    final nodeDir = Directory(p.join(themesDir, 'thm_1', 'nodes', 'nd_1'));
    await nodeDir.create(recursive: true);
    sessionPath = p.join(nodeDir.path, 'session.md');
    await File(sessionPath).writeAsString(sessionMd);
    // 造笔记数据：themes/<themeId>/notes/<noteId>.md
    final notesDir = Directory(p.join(themesDir, 'thm_1', 'notes'));
    await notesDir.create(recursive: true);
    await File(p.join(notesDir.path, 'nt_1.md')).writeAsString(noteMd);
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  PinContentLoader makeLoader() => PinContentLoader(
        themesDir: themesDir,
        sessionReader: (nodeId) async {
          expect(nodeId, 'nd_1');
          return parseSessionMarkdown(await File(sessionPath).readAsString());
        },
      );

  test('message 锚点解析：取出 msgId 对应消息全文', () async {
    final loader = makeLoader();

    final first = await loader.load(_messagePin());
    expect(first, isNotNull);
    expect(first!.body, '第一条消息正文');
    expect(first.noteTitle, isNull);

    final second = await loader.load(
      _messagePin(msgId: 'msg_BBBBBBBBBBBBBBBBBBBBBBBBBB'),
    );
    expect(second!.body, '第二条消息正文\n多行内容');
  });

  test('note 锚点解析：读出笔记全文与标题', () async {
    final loader = makeLoader();

    final content = await loader.load(_notePin());
    expect(content, isNotNull);
    expect(content!.body, '笔记正文第一行\n第二行');
    expect(content.noteTitle, '测试笔记');
  });

  test('锚点失效返回 null：消息已删 / msgId 缺失 / session 读取失败', () async {
    final loader = makeLoader();

    // msgId 不存在
    expect(
      await loader.load(_messagePin(msgId: 'msg_CCCCCCCCCCCCCCCCCCCCCCCCCC')),
      isNull,
    );
    // pin 缺 msgId
    expect(
      await loader.load(_pinWithMissing(kind: PinKind.message, nodeId: 'nd_1')),
      isNull,
    );
    // pin 缺 nodeId
    expect(
      await loader.load(
        _pinWithMissing(
          kind: PinKind.message,
          msgId: 'msg_AAAAAAAAAAAAAAAAAAAAAAAAAA',
        ),
      ),
      isNull,
    );

    // sessionReader 抛错（session.md 丢失等）
    final broken = PinContentLoader(
      themesDir: themesDir,
      sessionReader: (_) async => throw StateError('session not found'),
    );
    expect(await broken.load(_messagePin()), isNull);

    // 未注入 sessionReader
    final noReader = PinContentLoader(themesDir: themesDir);
    expect(await noReader.load(_messagePin()), isNull);
  });

  test('锚点失效返回 null：笔记已删 / 字段缺失', () async {
    final loader = makeLoader();

    // 笔记文件不存在
    expect(await loader.load(_notePin(noteId: 'nt_404')), isNull);
    // pin 缺 noteId
    expect(
      await loader.load(_pinWithMissing(kind: PinKind.note, themeId: 'thm_1')),
      isNull,
    );
    // pin 缺 themeId
    expect(
      await loader.load(_pinWithMissing(kind: PinKind.note, noteId: 'nt_1')),
      isNull,
    );

    // 删掉真实笔记文件后也返回 null
    await File(p.join(themesDir, 'thm_1', 'notes', 'nt_1.md')).delete();
    expect(await loader.load(_notePin()), isNull);
  });
}
