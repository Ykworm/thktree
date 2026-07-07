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

  /// 直接读取 session.md 原始文本，不做解析。
  ///
  /// 用于"查看原始 Markdown"场景，文件不存在时返回空字符串。
  Future<String> readSessionRaw(String nodeId) async {
    final path = await getSessionPathForNode(nodeId);
    final file = File(path);
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  Future<String> appendUserMessage({
    required String nodeId,
    required String content,
    String? imagePath,
  }) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final msgId = newMsgId();
    await _appendMessage(nodeId, role: SessionRole.user, timestamp: timestamp, msgId: msgId, body: content, imagePath: imagePath);
    return msgId;
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
    String? modelId,
  }) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final msgId = newMsgId();
    dev.log('[SessionStore.beginAssistantMessage] nodeId=$nodeId, modelId=$modelId, msgId=$msgId');
    await _queue.run(nodeId, () async {
      final path = await getSessionPathForNode(nodeId);
      final file = File(path);
      final content = await file.readAsString();
      final header = formatMessageHeader(role: SessionRole.assistant, timestampUtcIso8601: timestamp, msgId: msgId, modelId: modelId);
      dev.log('[SessionStore.beginAssistantMessage] header="$header"');
      final updated =
          '${_ensureEndsWithNewline(content)}${header}\n$_streamingMarker';
      await _atomicWriteString(path, updated);
    });
    return AssistantStreamHandle(nodeId: nodeId, msgId: msgId);
  }

  /// 流式追加 assistant delta。
  ///
  /// 直接在 markdown 原始字符串中做插入（不走 parse→rebuild 循环），
  /// 避免 trimRight 反复裁掉尾部换行符导致段落合并。
  ///
  /// session.md 中 streaming 消息的结构（由 serializeSessionMessageBody 保证）：
  ///
  ///   ## assistant · ... · msg_id · model
  ///   <!-- reasoning:start -->
  ///   (reasoning text)
  ///   <!-- reasoning:end -->
  ///
  ///   (content text)
  ///   <!-- streaming -->
  ///
  /// 插入策略：
  ///   - reasoningDelta：插在 `<!-- reasoning:end -->` 之前；
  ///     如果还没有 reasoning 块，则在 header 后插入完整块框架。
  ///   - contentDelta：插在 `<!-- streaming -->` 之前。
  Future<void> appendAssistantDelta({
    required AssistantStreamHandle handle,
    String contentDelta = '',
    String reasoningDelta = '',
  }) async {
    if (contentDelta.isEmpty && reasoningDelta.isEmpty) return;
    await _queue.run(handle.nodeId, () async {
      final path = await getSessionPathForNode(handle.nodeId);
      final file = File(path);
      final raw = await file.readAsString();

      // 找到 streaming marker 位置；找不到说明消息已经 finish 了
      final streamingIdx = raw.lastIndexOf(_streamingMarker);
      if (streamingIdx < 0) return;

      // streaming marker 之前就是当前消息体的末尾，delta 插在这里
      var insertPos = streamingIdx;
      var updated = raw;

      // ── 处理 reasoningDelta ──
      if (reasoningDelta.isNotEmpty) {
        const reasoningEndMarker = '<!-- reasoning:end -->';
        const reasoningStartMarker = '<!-- reasoning:start -->';
        final endIdx = updated.lastIndexOf(reasoningEndMarker, insertPos);
        if (endIdx >= 0 && endIdx < insertPos) {
          // reasoning 块已存在，在 end marker 前插入 delta。
          // 不加尾部 \n——_stripTrailingNewlines 已去掉每个 token 的尾 \n，
          // end marker 本身在 beginAssistantMessage 中已独占一行。
          updated = updated.substring(0, endIdx) +
              reasoningDelta +
              updated.substring(endIdx);
          insertPos += reasoningDelta.length;
        } else {
          // 还没有 reasoning 块，在 header 行末之后插入完整块
          // serializeSessionMessageBody 的输出格式：
          //   <!-- reasoning:start -->\n<reasoning>\n<!-- reasoning:end -->\n\n
          final headerStart = updated.lastIndexOf('\n## ', insertPos);
          final headerEnd = headerStart >= 0
              ? updated.indexOf('\n', headerStart + 1)
              : -1;
          final afterHeader = headerEnd >= 0 ? headerEnd + 1 : 0;
          final reasoningBlock =
              '$reasoningStartMarker\n$reasoningDelta\n$reasoningEndMarker\n\n';
          updated = updated.substring(0, afterHeader) +
              reasoningBlock +
              updated.substring(afterHeader);
          insertPos += reasoningBlock.length;
        }
      }

      // ── 处理 contentDelta ──
      // 在 streaming marker 前直接插入
      // 注意：如果之前还没有内容（header 后直接是 <!-- streaming -->），
      // 需要确保有一个 \n 分隔。实际上 beginAssistantMessage 已经写了
      // header\n\n<!-- streaming -->，所以 header 后有一个空行，
      // contentDelta 直接插在 <!-- streaming --> 前即可。
      //
      // 但要注意：如果刚插入了 reasoning 块，此时 <!-- streaming --> 之前
      // 可能已经有 \n\n，直接插入即可；如果只有 reasoningDelta 而没有 contentDelta，
      // 这一步跳过。
      if (contentDelta.isNotEmpty) {
        // 重新定位 streaming marker（因为 reasoningDelta 可能改变了位置）
        final newStreamingIdx = updated.lastIndexOf(_streamingMarker);
        if (newStreamingIdx >= 0) {
          updated = updated.substring(0, newStreamingIdx) +
              contentDelta +
              updated.substring(newStreamingIdx);
        }
      }

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
  ///
  /// 实现方式：**截断文件到最后一个 assistant 消息头之前**，而非 parse → rebuild。
  ///
  /// 原因：旧实现走 `parseSessionMarkdown` + `_rebuildSessionMarkdown` 重新序列化，
  /// 会丢消息头里的 `· image:...` 后缀（图片路径全失），并把 frontmatter 的当前
  /// session modelId 回填到没有显式 modelId 的消息（user 消息）再写回磁盘，污染历史
  /// 消息头。直接截断原始文本则完整保留 frontmatter 与前序消息的所有 header 信息，
  /// 只删掉最后一条 assistant 及其 body / streaming marker。
  ///
  /// 语义与旧实现一致：仅当最后一条消息是 assistant 时才删除（最后一条是 user/system
  /// 时原实现本就不删，这里同样不删）。
  Future<void> removeLastAssistantMessage({required String nodeId}) async {
    await _queue.run(nodeId, () async {
      final path = await getSessionPathForNode(nodeId);
      final file = File(path);
      if (!await file.exists()) return;

      final content = await file.readAsString();
      final lines = content.split('\n');

      // 从后往前找最后一条消息头（任意角色）
      int? lastHeaderLine;
      for (int i = lines.length - 1; i >= 0; i--) {
        if (isMessageHeaderLine(lines[i])) {
          lastHeaderLine = i;
          break;
        }
      }
      if (lastHeaderLine == null) return; // 没有任何消息，无需处理

      // 仅当最后一条消息是 assistant 时才删除
      final lastRole = messageHeaderRole(lines[lastHeaderLine]);
      if (lastRole != 'assistant') return;

      // 计算该消息头行首的字符偏移，截断到它之前（保留其前面的 \n）
      var truncateAt = 0;
      for (int i = 0; i < lastHeaderLine; i++) {
        truncateAt += lines[i].length + 1; // +1 为该行的 \n
      }
      final truncated = content.substring(0, truncateAt);
      if (truncated.isEmpty) return;

      // 去掉末尾多余空行，保留单个结尾换行，与 _appendMessage 产物一致
      final normalized = '${truncated.trimRight()}\n';
      await _atomicWriteString(path, normalized);
    });
  }

  /// 更新指定消息的 imagePath（用于图片持久化后回写）。
  Future<void> updateMessageImagePath({
    required String nodeId,
    required String msgId,
    required String imagePath,
  }) async {
    await _queue.run(nodeId, () async {
      final path = await getSessionPathForNode(nodeId);
      final file = File(path);
      if (!await file.exists()) return;
      final content = await file.readAsString();
      // 找到包含 msgId 的 header 行，替换或追加 image:path
      final lines = content.split('\n');
      var changed = false;
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].startsWith('## ') || !lines[i].contains(msgId)) continue;
        final imgIdx = lines[i].indexOf('· image:');
        if (imgIdx >= 0) {
          // 已有 · image:，替换路径部分
          lines[i] = '${lines[i].substring(0, imgIdx)}· image:$imagePath';
        } else {
          // 没有 · image:，追加
          lines[i] = '${lines[i]} · image:$imagePath';
        }
        changed = true;
        break;
      }
      if (changed) {
        await _atomicWriteString(path, lines.join('\n'));
      }
    });
  }

  Future<void> _appendMessage(
    String nodeId, {
    required SessionRole role,
    required String timestamp,
    required String msgId,
    required String body,
    String? imagePath,
  }) async {
    await _queue.run(nodeId, () async {
      final path = await getSessionPathForNode(nodeId);
      dev.log('[SessionStore._appendMessage] path=$path, nodeId=$nodeId');
      final file = File(path);
      final content = await file.readAsString();
      final updated =
          '${_ensureEndsWithNewline(content)}${formatMessageHeader(role: role, timestampUtcIso8601: timestamp, msgId: msgId, imagePath: imagePath)}\n${body.trimRight()}\n';
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



