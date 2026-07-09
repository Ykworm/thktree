import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:thk_tree/data/services/keyword_storage_utils.dart';

/// 一条文本碎片。
class Clip {
  const Clip({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.putAt,
  });

  /// `clip_<timestamp36><random36>`，全局唯一。
  final String id;

  /// 碎片正文，不可为空。
  final String text;

  /// 首次创建时间（UTC）。
  final DateTime createdAt;

  /// 最近放入时间（UTC），排序依据，去重时刷新。
  final DateTime putAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'putAt': putAt.toIso8601String(),
      };

  factory Clip.fromJson(Map<String, Object?> json) {
    return Clip(
      id: json['id']! as String,
      text: json['text']! as String,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now().toUtc(),
      putAt: _parseDate(json['putAt']) ?? DateTime.now().toUtc(),
    );
  }

  Clip copyWith({DateTime? putAt}) => Clip(
        id: id,
        text: text,
        createdAt: createdAt,
        putAt: putAt ?? this.putAt,
      );
}

/// `clips.json` 文件结构。
class _ClipFile {
  _ClipFile({this.updatedAt, List<Clip>? clips}) : clips = clips ?? <Clip>[];

  static const String schema = 'clips/v1';

  DateTime? updatedAt;
  final List<Clip> clips;

  Map<String, Object?> toJson() => {
        'schema': schema,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'clips': clips.map((c) => c.toJson()).toList(),
      };

  factory _ClipFile.fromJson(Map<String, Object?> json) {
    final rawList = json['clips'] as List? ?? const [];
    return _ClipFile(
      updatedAt: _parseDate(json['updatedAt']),
      clips: rawList
          .map((e) => Clip.fromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
    );
  }
}

/// 全局 `clips.json` 文件读写器。
///
/// 文件路径：`<rootDir>/clips.json`
/// 与 `keyword_global.json` 同级，遵循 ThkTree 全局数据存储惯例。
///
/// 数据规则：
/// - 去重：同一文本 trim 后完全一致 → 不新建，刷新 putAt 排到最前
/// - 排序：putAt 倒序（LIFO）
/// - 上限：18 条，满了 FIFO 静默淘汰
/// - 持久化：磁盘存储，App 重启后还在
class ClipStorage {
  ClipStorage({required this.rootDir});

  final String rootDir;

  /// 最大碎片数量。
  static const int maxClips = 18;

  String get _filePath => '$rootDir/clips.json';

  final Random _random = Random.secure();

  /// 内存缓存，首次 load 后后续操作不需要重复读磁盘。
  List<Clip>? _cache;

  /// 获取所有碎片（按 putAt 倒序）。
  ///
  /// 首次调用时从磁盘加载并缓存。
  Future<List<Clip>> getAll() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    _cache = await _loadFromDisk();
    return List.unmodifiable(_cache!);
  }

  /// 添加碎片。
  ///
  /// - 去重：同一文本 trim 后已存在 → 刷新 putAt 排到最前
  /// - 上限：满 18 条时 FIFO 淘汰最早的
  Future<List<Clip>> add(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return getAll();

    final clips = List<Clip>.from(await getAll());
    final now = DateTime.now().toUtc();

    // 去重：查找已存在的同文本条目
    final existingIdx = clips.indexWhere(
      (c) => c.text.trim() == trimmed,
    );

    if (existingIdx >= 0) {
      // 刷新 putAt，移到列表最前
      final updated = clips[existingIdx].copyWith(putAt: now);
      clips.removeAt(existingIdx);
      clips.insert(0, updated);
    } else {
      // 新建
      clips.insert(0, Clip(
        id: _generateId(),
        text: text,
        createdAt: now,
        putAt: now,
      ));
      // FIFO 淘汰
      if (clips.length > maxClips) {
        clips.removeRange(maxClips, clips.length);
      }
    }

    await _writeToDisk(clips);
    _cache = clips;
    return List.unmodifiable(clips);
  }

  /// 删除单条碎片。
  Future<List<Clip>> remove(String id) async {
    final clips = List<Clip>.from(await getAll());
    clips.removeWhere((c) => c.id == id);
    await _writeToDisk(clips);
    _cache = clips;
    return List.unmodifiable(clips);
  }

  /// 清空全部碎片。
  Future<List<Clip>> clearAll() async {
    await _writeToDisk([]);
    _cache = [];
    return const [];
  }

  // ── 内部方法 ──

  Future<List<Clip>> _loadFromDisk() async {
    final file = File(_filePath);
    if (!await file.exists()) {
      // 文件不存在，写空骨架
      await _writeToDisk([]);
      return [];
    }
    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return [];
      }
      final clipFile = _ClipFile.fromJson(Map<String, Object?>.from(decoded));
      // 按 putAt 倒序排列
      final clips = clipFile.clips
        ..sort((a, b) => b.putAt.compareTo(a.putAt));
      return clips;
    } catch (_) {
      // 解析失败，视为空列表（不覆盖损坏文件，让用户手动恢复）
      return [];
    }
  }

  Future<void> _writeToDisk(List<Clip> clips) async {
    final clipFile = _ClipFile(
      updatedAt: DateTime.now().toUtc(),
      clips: clips,
    );
    final encoder = const JsonEncoder.withIndent('  ');
    await KeywordStorageUtils.atomicWriteString(
      _filePath,
      encoder.convert(clipFile.toJson()),
    );
  }

  String _generateId() {
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36);
    final rand = _random.nextInt(0xFFFFFF).toRadixString(36).padLeft(4, '0');
    return 'clip_$ts$rand';
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
