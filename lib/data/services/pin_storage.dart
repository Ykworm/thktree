import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:thk_tree/data/services/keyword_storage_utils.dart';

/// Pin 类型：消息 / 笔记。
enum PinKind { message, note }

/// 一条 Pin：被钉住的消息或笔记，供对照栏展示。
class Pin {
  const Pin({
    required this.id,
    required this.kind,
    this.themeId,
    this.nodeId,
    this.msgId,
    this.noteId,
    required this.excerpt,
    required this.createdAt,
  });

  /// `pin_<timestamp36><random36>`，全局唯一。
  final String id;

  final PinKind kind;

  /// 所属主题（消息和笔记都有）。
  final String? themeId;

  /// 消息所属 chat 节点（kind=message 时有值）。
  final String? nodeId;

  /// 消息锚点（kind=message 时有值），去重依据。
  final String? msgId;

  /// 笔记锚点（kind=note 时有值），去重依据。
  final String? noteId;

  /// 卡片预览摘要（正文前 ~100 字符）。
  final String excerpt;

  /// 最近 Pin 时间（UTC），排序依据，重复 Pin 时刷新。
  final DateTime createdAt;

  /// 同锚点去重键：msgId 或 noteId。
  String get anchorKey => kind == PinKind.message ? 'm:$msgId' : 'n:$noteId';

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        if (themeId != null) 'themeId': themeId,
        if (nodeId != null) 'nodeId': nodeId,
        if (msgId != null) 'msgId': msgId,
        if (noteId != null) 'noteId': noteId,
        'excerpt': excerpt,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Pin.fromJson(Map<String, Object?> json) {
    return Pin(
      id: json['id']! as String,
      kind: json['kind'] == 'note' ? PinKind.note : PinKind.message,
      themeId: json['themeId'] as String?,
      nodeId: json['nodeId'] as String?,
      msgId: json['msgId'] as String?,
      noteId: json['noteId'] as String?,
      excerpt: json['excerpt'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  Pin copyWith({String? excerpt, DateTime? createdAt}) => Pin(
        id: id,
        kind: kind,
        themeId: themeId,
        nodeId: nodeId,
        msgId: msgId,
        noteId: noteId,
        excerpt: excerpt ?? this.excerpt,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// `pins.json` 文件结构。
class _PinFile {
  _PinFile({this.updatedAt, List<Pin>? pins}) : pins = pins ?? <Pin>[];

  static const String schema = 'pins/v1';

  DateTime? updatedAt;
  final List<Pin> pins;

  Map<String, Object?> toJson() => {
        'schema': schema,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'pins': pins.map((p) => p.toJson()).toList(),
      };

  factory _PinFile.fromJson(Map<String, Object?> json) {
    final rawList = json['pins'] as List? ?? const [];
    return _PinFile(
      updatedAt: _parseDate(json['updatedAt']),
      pins: rawList
          .map((e) => Pin.fromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
    );
  }
}

/// 全局 `pins.json` 文件读写器（多 chat 对照的 Pin 列表）。
///
/// 文件路径：`<rootDir>/pins.json`
/// 与 `clips.json` 同级，遵循 ThkTree 全局数据存储惯例。
///
/// 数据规则：
/// - 排序：createdAt 倒序（最新在前）
/// - 去重：同锚点（同 msgId 或同 noteId）重复 Pin → 刷新 excerpt/createdAt 移到最前
/// - 上限：5 条，满了 FIFO 静默淘汰最早的
/// - 持久化：磁盘存储，App 重启后还在
class PinStorage {
  PinStorage({required this.rootDir});

  final String rootDir;

  /// 最大 Pin 数量。
  static const int maxPins = 5;

  String get _filePath => '$rootDir/pins.json';

  final Random _random = Random.secure();

  /// 内存缓存，首次 load 后后续操作不需要重复读磁盘。
  List<Pin>? _cache;

  /// 获取所有 Pin（按 createdAt 倒序，最新在前）。
  ///
  /// 首次调用时从磁盘加载并缓存。
  Future<List<Pin>> getAll() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    _cache = await _loadFromDisk();
    return List.unmodifiable(_cache!);
  }

  /// 添加 Pin。
  ///
  /// - 去重：同锚点已存在 → 刷新 excerpt/createdAt 移到最前
  /// - 上限：满 5 条时 FIFO 淘汰最早的
  Future<List<Pin>> add({
    required PinKind kind,
    String? themeId,
    String? nodeId,
    String? msgId,
    String? noteId,
    required String excerpt,
  }) async {
    final anchorKey =
        kind == PinKind.message ? 'm:$msgId' : 'n:$noteId';
    final pins = List<Pin>.from(await getAll());
    final now = DateTime.now().toUtc();

    // 去重：查找已存在的同锚点条目
    final existingIdx = pins.indexWhere((p) => p.anchorKey == anchorKey);

    if (existingIdx >= 0) {
      // 刷新 excerpt/createdAt，移到列表最前
      final updated = pins[existingIdx].copyWith(
        excerpt: excerpt,
        createdAt: now,
      );
      pins.removeAt(existingIdx);
      pins.insert(0, updated);
    } else {
      // 新建
      pins.insert(0, Pin(
        id: _generateId(),
        kind: kind,
        themeId: themeId,
        nodeId: nodeId,
        msgId: msgId,
        noteId: noteId,
        excerpt: excerpt,
        createdAt: now,
      ));
      // FIFO 淘汰
      if (pins.length > maxPins) {
        pins.removeRange(maxPins, pins.length);
      }
    }

    await _writeToDisk(pins);
    _cache = pins;
    return List.unmodifiable(pins);
  }

  /// 删除单条 Pin。
  Future<List<Pin>> remove(String id) async {
    final pins = List<Pin>.from(await getAll());
    pins.removeWhere((p) => p.id == id);
    await _writeToDisk(pins);
    _cache = pins;
    return List.unmodifiable(pins);
  }

  // ── 内部方法 ──

  Future<List<Pin>> _loadFromDisk() async {
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
      final pinFile = _PinFile.fromJson(Map<String, Object?>.from(decoded));
      // 按 createdAt 倒序排列
      final pins = pinFile.pins
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return pins;
    } catch (_) {
      // 解析失败，视为空列表（不覆盖损坏文件，让用户手动恢复）
      return [];
    }
  }

  Future<void> _writeToDisk(List<Pin> pins) async {
    final pinFile = _PinFile(
      updatedAt: DateTime.now().toUtc(),
      pins: pins,
    );
    final encoder = const JsonEncoder.withIndent('  ');
    await KeywordStorageUtils.atomicWriteString(
      _filePath,
      encoder.convert(pinFile.toJson()),
    );
  }

  String _generateId() {
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36);
    final rand = _random.nextInt(0xFFFFFF).toRadixString(36).padLeft(4, '0');
    return 'pin_$ts$rand';
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
