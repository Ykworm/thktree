import 'dart:io';
import 'dart:developer' as dev;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:thk_tree/domain/ids.dart';
import 'package:thk_tree/data/services/file_write_queue.dart';
import 'package:thk_tree/data/services/session_markdown.dart';

class SessionStore {
  SessionStore({required this.getSessionPathForNode});

  final Future<String> Function(String nodeId) getSessionPathForNode;

  final FileWriteQueue _queue = FileWriteQueue();
  static const _streamingMarker = '\n<!-- streaming -->\n';
  static const _legacyStreamingMarker = '<!-- streaming -->\n';

  /// 扫描文档目录下所有 `session.md`，找出含 `<!-- streaming -->` 标记的中断消息。
  ///
  /// 返回结构：`List<({String nodeId, String sessionPath})>`
  ///
  /// 调用时机：AppLifecycleState.resumed 触发一次 + App 冷启动后。
  ///
  /// 行为约定：
  /// - 不复用 [FileWriteQueue]：扫描是只读操作，不应阻塞正在进行的写
  /// - 并发读取所有 session.md（一次性 `Future.wait`）
  /// - 单个文件 IO 错误被 swallow（best-effort 扫盘，不能因为一个坏文件阻塞整个流程）
  /// - 兼容 legacy marker（`<!-- streaming -->\n`，无前置换行）
  static Future<List<({String nodeId, String sessionPath})>> findInterrupted() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final themesDir = Directory(p.join(docsDir.path, 'themes'));
    if (!await themesDir.exists()) return const [];

    final nodeDirs = <Directory>[];
    await for (final themeEntry in themesDir.list(followLinks: false)) {
      if (themeEntry is! Directory) continue;
      await for (final nodeEntry in themeEntry.list(followLinks: false)) {
        if (nodeEntry is Directory) nodeDirs.add(nodeEntry);
      }
    }

    final results = await Future.wait(nodeDirs.map(_scanNodeDir));
    return results.whereType<({String nodeId, String sessionPath})>().toList(growable: false);
  }

  static Future<({String nodeId, String sessionPath})?> _scanNodeDir(Directory nodeDir) async {
    try {
      final sessionPath = p.join(nodeDir.path, 'session.md');
      final file = File(sessionPath);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.contains(_streamingMarker) || content.contains(_legacyStreamingMarker)) {
        return (nodeId: p.basename(nodeDir.path), sessionPath: sessionPath);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<SessionDocument> readSession(String nodeId) async {
    dev.log('[SessionStore.readSession] ===== START nodeId=$nodeId =====');
    final path = await getSessionPathForNode(nodeId);
    dev.log('[SessionStore.readSession] path=$path');
    final file = File(path);
    final exists = await file.exists();
    dev.log('[SessionStore.readSession] file exists=$exists');
    if (!exists) {
      dev.log('[SessionStore.readSession] file NOT found, returning empty');
      return SessionDocument(frontmatter: {}, messages: []);
    }
    final text = await file.readAsString();
    dev.log('[SessionStore.readSession] file content ($path):');
    dev.log(text);
    dev.log('[SessionStore.readSession] calling parseSessionMarkdown...');
    final doc = parseSessionMarkdown(text);
    dev.log('[SessionStore.readSession] parsed, found ${doc.messages.length} messages:');
    for (int i=0; i<doc.messages.length; i++) {
      final m = doc.messages[i];
      dev.log('[SessionStore.readSession] msg $i: role=${m.role}, status=${m.status}, body="${m.body}"');
    }
    dev.log('[SessionStore.readSession] ===== END =====');
    return doc;
  }

  Future<void> appendUserMessage({
    required String nodeId,
    required String content,
  }) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final msgId = newMsgId();
    await _appendMessage(nodeId, role: SessionRole.user, timestamp: timestamp, msgId: msgId, body: content);
  }

  /// 更新 session.md frontmatter 中的 providerId 和 modelId
  Future<void> updateSessionModel({
    required String nodeId,
    required String providerId,
    required String modelId,
  }) async {
    await _queue.run(nodeId, () async {
      dev.log('[SessionStore.updateSessionModel] nodeId=$nodeId, providerId=$providerId, modelId=$modelId');
      final path = await getSessionPathForNode(nodeId);
      final file = File(path);
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final updated = updateSessionFrontmatter(content, {
        'providerId': providerId,
        'modelId': modelId,
      });
      await _atomicWriteString(path, updated);
      dev.log('[SessionStore.updateSessionModel] done, nodeId=$nodeId');
    });
  }

  Future<void> appendAssistantMessage({
    required String nodeId,
    required String content,
  }) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final msgId = newMsgId();
    await _appendMessage(
      nodeId,
      role: SessionRole.assistant,
      timestamp: timestamp,
      msgId: msgId,
      body: content,
    );
  }

  Future<bool> finishStreamingMessage({required String nodeId}) async {
    return _queue.run(nodeId, () async {
      final path = await getSessionPathForNode(nodeId);
      final file = File(path);
      final content = await file.readAsString();
      final (withoutMarker, found) = _stripStreamingMarker(content);
      if (!found) {
        return false;
      }
      final updated = '${withoutMarker.trimRight()}\n';
      await _atomicWriteString(path, updated);
      return true;
    });
  }

  Future<AssistantStreamHandle> beginAssistantMessage({
    required String nodeId,
  }) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final msgId = newMsgId();
    await _queue.run(nodeId, () async {
      final path = await getSessionPathForNode(nodeId);
      final file = File(path);
      final content = await file.readAsString();
      final updated =
          '${_ensureEndsWithNewline(content)}${formatMessageHeader(role: SessionRole.assistant, timestampUtcIso8601: timestamp, msgId: msgId)}\n$_streamingMarker';
      await _atomicWriteString(path, updated);
    });
    return AssistantStreamHandle(nodeId: nodeId, msgId: msgId);
  }

  Future<void> appendAssistantDelta({
    required AssistantStreamHandle handle,
    required String delta,
  }) async {
    await _queue.run(handle.nodeId, () async {
      final path = await getSessionPathForNode(handle.nodeId);
      final file = File(path);
      final content = await file.readAsString();
      final (withoutMarker, found) = _stripStreamingMarker(content);
      if (!found) {
        return;
      }
      final updated = withoutMarker + delta + _streamingMarker;
      await _atomicWriteString(path, updated);
    });
  }

  Future<void> finishAssistant({
    required AssistantStreamHandle handle,
  }) async {
    await _queue.run(handle.nodeId, () async {
      final path = await getSessionPathForNode(handle.nodeId);
      final file = File(path);
      final content = await file.readAsString();
      final (withoutMarker, found) = _stripStreamingMarker(content);
      if (!found) {
        return;
      }
      final updated = '${withoutMarker.trimRight()}\n';
      await _atomicWriteString(path, updated);
    });
  }

  Future<void> failAssistant({
    required AssistantStreamHandle handle,
    required String code,
  }) async {
    await _queue.run(handle.nodeId, () async {
      final path = await getSessionPathForNode(handle.nodeId);
      final file = File(path);
      final content = await file.readAsString();
      final (withoutMarker, found) = _stripStreamingMarker(content);
      if (!found) {
        return;
      }
      final updated = '$withoutMarker\n<!-- error: $code -->\n';
      await _atomicWriteString(path, updated);
    });
  }

  /// Remove the last assistant message from session.md (used for retry).
  Future<void> removeLastAssistantMessage({required String nodeId}) async {
    await _queue.run(nodeId, () async {
      final path = await getSessionPathForNode(nodeId);
      final file = File(path);
      if (!await file.exists()) return;
      
      final content = await file.readAsString();
      final doc = parseSessionMarkdown(content);
      
      // Find and remove the last assistant message
      final updatedMessages = <SessionMessage>[];
      for (int i = 0; i < doc.messages.length; i++) {
        final msg = doc.messages[i];
        // Keep all messages except the last assistant message
        if (msg.role == SessionRole.assistant && i == doc.messages.length - 1) {
          continue; // Skip the last assistant message
        }
        updatedMessages.add(msg);
      }
      
      // Rebuild session.md without the last assistant message
      final frontmatter = _extractFrontmatter(content);
      final rebuilt = _rebuildSessionMarkdown(frontmatter, doc, updatedMessages);
      await _atomicWriteString(path, rebuilt);
    });
  }

  Future<void> _appendMessage(
    String nodeId, {
    required SessionRole role,
    required String timestamp,
    required String msgId,
    required String body,
  }) async {
    await _queue.run(nodeId, () async {
      final path = await getSessionPathForNode(nodeId);
      dev.log('[SessionStore._appendMessage] path=$path, nodeId=$nodeId');
      final file = File(path);
      final content = await file.readAsString();
      final updated =
          '${_ensureEndsWithNewline(content)}${formatMessageHeader(role: role, timestampUtcIso8601: timestamp, msgId: msgId)}\n${body.trimRight()}\n';
      dev.log('[SessionStore._appendMessage] writing ${updated.length} chars to $path');
      await _atomicWriteString(path, updated);
      dev.log('[SessionStore._appendMessage] written OK, nodeId=$nodeId');
    });
  }
}

class AssistantStreamHandle {
  AssistantStreamHandle({required this.nodeId, required this.msgId});

  final String nodeId;
  final String msgId;
}

String _ensureEndsWithNewline(String content) {
  if (content.isEmpty) return '';
  return content.endsWith('\n') ? content : '$content\n';
}

(String, bool) _stripStreamingMarker(String content) {
  if (content.endsWith(SessionStore._streamingMarker)) {
    return (
      content.substring(0, content.length - SessionStore._streamingMarker.length),
      true,
    );
  }
  if (content.endsWith(SessionStore._legacyStreamingMarker)) {
    return (
      content.substring(0, content.length - SessionStore._legacyStreamingMarker.length),
      true,
    );
  }
  return (content, false);
}

Future<void> _atomicWriteString(String filePath, String content) async {
  final tmpPath = '$filePath.tmp';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsString(content);
  await tmpFile.rename(filePath);
}


String _extractFrontmatter(String content) {
  if (!content.startsWith('---')) return '';
  final endIdx = content.indexOf('\n---', 3);
  if (endIdx == -1) return '';
  return content.substring(0, endIdx + 4);
}

String _rebuildSessionMarkdown(
  String frontmatter,
  SessionDocument doc,
  List<SessionMessage> messages,
) {
  final buffer = StringBuffer(frontmatter);
  if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
    buffer.writeln();
  }
  
  for (final msg in messages) {
    final header = formatMessageHeader(
      role: msg.role,
      timestampUtcIso8601: msg.timestampUtcIso8601,
      msgId: msg.msgId,
    );
    buffer.writeln(header);
    buffer.writeln(msg.body.trimRight());
  }
  
  return buffer.toString();
}
