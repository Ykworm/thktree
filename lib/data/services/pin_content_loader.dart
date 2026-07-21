import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:thk_tree/data/services/pin_storage.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/stores/note_store.dart';

/// Pin 卡片全文解析结果。
class PinContent {
  const PinContent({required this.body, this.noteTitle});

  /// 消息 / 笔记正文全文。
  final String body;

  /// 笔记标题（kind=note 时有值，供卡片来源行展示）。
  final String? noteTitle;
}

/// 按 Pin 锚点解析卡片全文。
///
/// - kind=message：通过 [sessionReader] 读该 chat 的 session 文档，
///   取 msgId 对应消息的 body
/// - kind=note：读 `themes/<themeId>/notes/<noteId>.md` 的 body 与标题
///
/// 消息 / 笔记已删或读取失败 → 返回 null（UI 降级为 excerpt 展示）。
class PinContentLoader {
  PinContentLoader({
    required this.themesDir,
    this.sessionReader,
  });

  /// themes 根目录路径（笔记按 `themes/<themeId>/notes` 定位）。
  final String themesDir;

  /// message 解析用的 session 读取器（生产注入 `SessionStore.readSession`，
  /// 测试注入临时目录数据）；为 null 时 message 锚点一律解析失败。
  final Future<SessionDocument> Function(String nodeId)? sessionReader;

  /// 解析 [pin] 对应的全文；锚点失效或读取失败返回 null。
  Future<PinContent?> load(Pin pin) async {
    try {
      if (pin.kind == PinKind.note) {
        return await _loadNote(pin);
      }
      return await _loadMessage(pin);
    } catch (_) {
      return null;
    }
  }

  Future<PinContent?> _loadNote(Pin pin) async {
    final themeId = pin.themeId;
    final noteId = pin.noteId;
    if (themeId == null || noteId == null) return null;
    final notesDir = Directory(p.join(themesDir, themeId, 'notes'));
    if (!await File(p.join(notesDir.path, '$noteId.md')).exists()) {
      return null;
    }
    final store = NoteStore(notesDir: notesDir);
    final body = await store.readBody(noteId);
    final metas = await store.listNoteMetas();
    final title =
        metas.where((m) => m.noteId == noteId).firstOrNull?.title;
    return PinContent(body: body, noteTitle: title);
  }

  Future<PinContent?> _loadMessage(Pin pin) async {
    final reader = sessionReader;
    final nodeId = pin.nodeId;
    final msgId = pin.msgId;
    if (reader == null || nodeId == null || msgId == null) return null;
    final doc = await reader(nodeId);
    final message =
        doc.messages.where((m) => m.msgId == msgId).firstOrNull;
    if (message == null) return null;
    return PinContent(body: message.body);
  }
}
