import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:ulid/ulid.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/data/services/file_write_queue.dart';

class LogRecord {
  final String id;
  final String ts;
  final String level;
  final String msg;
  final Map<String, Object?>? attrs;
  final Map<String, String>? err;

  LogRecord({
    required this.id,
    required this.ts,
    required this.level,
    required this.msg,
    this.attrs,
    this.err,
  });

  Map<String, Object?> toJson() {
    final m = <String, Object?>{
      'id': id,
      'ts': ts,
      'level': level,
      'msg': msg,
    };
    if (attrs != null && attrs!.isNotEmpty) {
      m['attrs'] = attrs;
    }
    if (err != null) {
      m['err'] = err;
    }
    return m;
  }

  String toJsonLine() => '${jsonEncode(toJson())}\n';

  static String toHumanLine(LogRecord r) {
    final buf = StringBuffer('[${r.ts}][${r.level}] ${r.msg}');
    if (r.attrs != null && r.attrs!.isNotEmpty) {
      buf.write(' ');
      buf.write(r.attrs!.entries.map((e) => '${e.key}=${e.value}').join(' '));
    }
    if (r.err != null) {
      buf.write('\n');
      buf.write(r.err!['msg'] ?? '');
      final stack = r.err!['stack'];
      if (stack != null && stack.isNotEmpty) {
        buf.write('\n');
        buf.write(stack);
      }
    }
    return buf.toString();
  }
}

class AppLogger {
  /// [remoteLogUrl] 来自编译期 define `THKTREE_LOG_URL`，是**仅开发用**的
  /// 远程日志回传通道（配套接收端是明文 HTTP 的 tools/host_log_server.py，
  /// 无鉴权，日志行可能含会话标题与本地绝对路径）。
  ///
  /// 红线：release / 上架构建**禁止**传 `--dart-define=THKTREE_LOG_URL=...`；
  /// 开发使用时应指向 https 或本机地址。不传 define 时该通道完全关闭
  /// （_remoteUri 为 null，_sendRemote / _backfillRemote 均不执行）。
  AppLogger({required this.paths, String remoteLogUrl = ''}) : _remoteUri = Uri.tryParse(remoteLogUrl.trim());

  final AppPaths paths;
  final FileWriteQueue _queue = FileWriteQueue();
  final Uri? _remoteUri;

  String get logFilePath => paths.todayLogPath;
  String get remoteLogUrl => _remoteUri?.toString() ?? '';
  bool get hasRemoteLogging => remoteLogUrl.isNotEmpty;

  Future<void> init() async {
    await paths.ensureCreated();
    final file = File(paths.todayLogPath);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    // 启动时静默清理过期日志，失败不影响正常启动
    unawaited(_pruneOldLogs());
    if (_remoteUri != null) {
      unawaited(_backfillRemote());
    }
  }

  /// 清理 3 天前的本地日志文件。
  /// 整个操作被 try-catch 包裹，任何异常都不影响 app 启动。
  Future<void> _pruneOldLogs({int retainDays = 3}) async {
    try {
      final dir = paths.logsDir;
      if (!await dir.exists()) return;
      final now = DateTime.now();
      final cutoff = now.subtract(Duration(days: retainDays));
      final cutoffStr = DateFormat('yyyy-MM-dd').format(cutoff);

      final files = await dir.list().where((e) => e is File).toList();
      for (final file in files) {
        final name = file.uri.pathSegments.last;
        // 匹配 app-YYYY-MM-dd.log 格式
        final match = RegExp(r'^app-(\d{4}-\d{2}-\d{2})\.log$').firstMatch(name);
        if (match == null) continue;
        final dateStr = match.group(1)!;
        if (dateStr.compareTo(cutoffStr) < 0) {
          await file.delete();
        }
      }
    } catch (_) {
      // 静默吞掉异常，清理失败不影响 app 正常运行
    }
  }

  Future<void> _backfillRemote() async {
    final uri = _remoteUri;
    if (uri == null) return;
    final file = File(paths.todayLogPath);
    if (!await file.exists()) return;
    final text = await file.readAsString();
    final lines = const LineSplitter().convert(text);
    final maxLines = 500;
    final start = lines.length > maxLines ? lines.length - maxLines : 0;
    for (int i = start; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      await _sendRemote('$trimmed\n');
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  Future<void> info(String message, {Map<String, Object?>? attrs}) async {
    await _append(LogRecord(
      id: Ulid().toCanonical(),
      ts: DateTime.now().toUtc().toIso8601String(),
      level: 'INFO',
      msg: _sanitize(message),
      attrs: attrs,
    ));
  }

  Future<void> error(Object error, StackTrace stackTrace, {String? hint, Map<String, Object?>? attrs}) async {
    final fullAttrs = <String, Object?>{...?attrs};
    if (hint != null && hint.trim().isNotEmpty) {
      fullAttrs['hint'] = hint;
    }
    await _append(LogRecord(
      id: Ulid().toCanonical(),
      ts: DateTime.now().toUtc().toIso8601String(),
      level: 'ERROR',
      msg: '',
      attrs: fullAttrs,
      err: {
        'msg': _sanitize(error.toString()),
        'stack': _sanitize(stackTrace.toString()),
      },
    ));
  }

  Future<void> flutterError(Object error, StackTrace stackTrace) async {
    await this.error(error, stackTrace, hint: 'FlutterError');
  }

  Future<String> readTail({int maxChars = 6000}) async {
    final file = File(paths.todayLogPath);
    if (!await file.exists()) return '';
    final text = await file.readAsString();
    final lines = const LineSplitter().convert(text);
    final buf = StringBuffer();
    int remaining = maxChars;
    for (int i = lines.length - 1; i >= 0 && remaining > 0; i--) {
      final line = lines[i];
      final lineWithNewline = '$line\n';
      if (lineWithNewline.length > remaining) {
        buf.write(lineWithNewline.substring(lineWithNewline.length - remaining));
        break;
      }
      buf.write(lineWithNewline);
      remaining -= lineWithNewline.length;
    }
    final chars = buf.toString();
    return String.fromCharCodes(chars.runes.toList().reversed);
  }

  Future<void> _append(LogRecord record) async {
    final line = record.toJsonLine();
    // release 模式不写本地文件，避免日志无限堆积占用用户存储
    if (!kReleaseMode) {
      await _queue.run(paths.todayLogPath, () async {
        final file = File(paths.todayLogPath);
        await file.writeAsString(line, mode: FileMode.append, flush: true);
      });
    }
    if (_remoteUri != null) {
      unawaited(_sendRemote(line));
    }
  }

  Future<void> _sendRemote(String line) async {
    final uri = _remoteUri;
    if (uri == null) return;
    final client = HttpClient();
    client.connectionTimeout = const Duration(milliseconds: 1500);
    try {
      final bytes = utf8.encode(line);
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 2));
      req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      req.contentLength = bytes.length;
      req.add(bytes);
      await req.flush();
      final resp = await req.close().timeout(const Duration(seconds: 2));
      await resp.drain<void>().timeout(const Duration(seconds: 2));
    } catch (e) {
      // release 模式不写本地错误日志；debug 模式记录远程发送失败
      if (!kReleaseMode) {
        final diag = LogRecord(
          id: Ulid().toCanonical(),
          ts: DateTime.now().toUtc().toIso8601String(),
          level: 'ERROR',
          msg: 'remote_send_failed',
          attrs: {'url': _remoteUri.toString()},
          err: {'msg': _sanitize(e.toString()), 'stack': ''},
        );
        await _queue.run(paths.todayLogPath, () async {
          final file = File(paths.todayLogPath);
          await file.writeAsString(diag.toJsonLine(), mode: FileMode.append, flush: true);
        });
      }
    } finally {
      client.close(force: true);
    }
  }
}

String _sanitize(String input) {
  var s = input;
  s = s.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._\\-]+'), 'Bearer ***');
  return s;
}
