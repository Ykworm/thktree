import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    if (_remoteUri != null) {
      unawaited(_backfillRemote());
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
    await _queue.run(paths.todayLogPath, () async {
      final file = File(paths.todayLogPath);
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    });
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
