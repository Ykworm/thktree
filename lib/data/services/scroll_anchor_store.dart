import 'dart:convert';
import 'dart:io';

import 'package:thk_tree/data/services/keyword_storage_utils.dart';

/// 单个 chat 的滚动锚点：离开时视口顶部第一条可见消息。
class ScrollAnchor {
  const ScrollAnchor({required this.msgId, required this.updatedAt});

  /// 首条可见消息的 msgId（不存像素 offset）。
  final String msgId;

  /// 最近写入时间（UTC）。
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'msgId': msgId,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ScrollAnchor.fromJson(Map<String, Object?> json) {
    return ScrollAnchor(
      msgId: json['msgId']! as String,
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }
}

/// `scroll_anchors.json` 文件结构。
class _ScrollAnchorFile {
  _ScrollAnchorFile({this.updatedAt, Map<String, ScrollAnchor>? anchors})
      : anchors = anchors ?? <String, ScrollAnchor>{};

  static const String schema = 'scroll_anchors/v1';

  DateTime? updatedAt;
  final Map<String, ScrollAnchor> anchors;

  Map<String, Object?> toJson() => {
        'schema': schema,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'anchors': anchors.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory _ScrollAnchorFile.fromJson(Map<String, Object?> json) {
    final rawMap = json['anchors'] as Map? ?? const {};
    return _ScrollAnchorFile(
      updatedAt: _parseDate(json['updatedAt']),
      anchors: rawMap.map(
        (k, v) => MapEntry(
          k as String,
          ScrollAnchor.fromJson(Map<String, Object?>.from(v as Map)),
        ),
      ),
    );
  }
}

/// 全局 `scroll_anchors.json` 文件读写器（chat 滚动锚点记忆）。
///
/// 文件路径：`<rootDir>/scroll_anchors.json`
/// 与 `clips.json` 同级，遵循 ThkTree 全局数据存储惯例。
///
/// 数据规则：
/// - 键为 nodeId，值为该 chat 离开时首条可见消息的 msgId
/// - 在底部是默认状态，不记锚点（由调用方负责 remove）
/// - 持久化：磁盘存储，App 重启后还在
class ScrollAnchorStore {
  ScrollAnchorStore({required this.rootDir});

  final String rootDir;

  String get _filePath => '$rootDir/scroll_anchors.json';

  /// 内存缓存，首次 load 后后续操作不需要重复读磁盘。
  Map<String, ScrollAnchor>? _cache;

  /// 读取全部锚点（nodeId → ScrollAnchor）。
  ///
  /// 首次调用时从磁盘加载并缓存。
  Future<Map<String, ScrollAnchor>> load() async {
    if (_cache != null) return Map.unmodifiable(_cache!);
    _cache = await _loadFromDisk();
    return Map.unmodifiable(_cache!);
  }

  /// 全量写入锚点表。
  Future<void> save(Map<String, ScrollAnchor> anchors) async {
    await _writeToDisk(anchors);
    _cache = Map<String, ScrollAnchor>.from(anchors);
  }

  /// 取某个 chat 的锚点 msgId；无则 null。
  Future<String?> anchorFor(String nodeId) async {
    return (await load())[nodeId]?.msgId;
  }

  /// 记录某个 chat 的锚点（覆盖旧值）。
  Future<void> setAnchor(String nodeId, String msgId) async {
    final anchors = Map<String, ScrollAnchor>.from(await load());
    anchors[nodeId] = ScrollAnchor(
      msgId: msgId,
      updatedAt: DateTime.now().toUtc(),
    );
    await _writeToDisk(anchors);
    _cache = anchors;
  }

  /// 删除某个 chat 的锚点（不存在则静默跳过）。
  Future<void> remove(String nodeId) async {
    final anchors = Map<String, ScrollAnchor>.from(await load());
    if (!anchors.containsKey(nodeId)) return;
    anchors.remove(nodeId);
    await _writeToDisk(anchors);
    _cache = anchors;
  }

  // ── 内部方法 ──

  Future<Map<String, ScrollAnchor>> _loadFromDisk() async {
    final file = File(_filePath);
    if (!await file.exists()) {
      return <String, ScrollAnchor>{};
    }
    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return <String, ScrollAnchor>{};
      }
      return _ScrollAnchorFile.fromJson(
        Map<String, Object?>.from(decoded),
      ).anchors;
    } catch (_) {
      // 解析失败，视为空表（不覆盖损坏文件，让用户手动恢复）
      return <String, ScrollAnchor>{};
    }
  }

  Future<void> _writeToDisk(Map<String, ScrollAnchor> anchors) async {
    final anchorFile = _ScrollAnchorFile(
      updatedAt: DateTime.now().toUtc(),
      anchors: anchors,
    );
    final encoder = const JsonEncoder.withIndent('  ');
    await KeywordStorageUtils.atomicWriteString(
      _filePath,
      encoder.convert(anchorFile.toJson()),
    );
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
