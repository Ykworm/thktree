import 'dart:convert';
import 'dart:io';

import 'package:thk_tree/data/services/keyword_storage_utils.dart';

/// 单个分类条目。
class KeywordCategory {
  const KeywordCategory({
    required this.id,
    required this.name,
    required this.aliases,
    required this.source,
    this.addedAt,
  });

  final String id;
  final String name;
  final List<String> aliases;

  /// `default`（内置 10 个）或 `llm_added`（LLM 抽取时动态新增）。
  final String source;
  final DateTime? addedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'aliases': aliases,
        'source': source,
        if (addedAt != null) 'added_at': addedAt!.toIso8601String(),
      };

  factory KeywordCategory.fromJson(Map<String, Object?> json) {
    return KeywordCategory(
      id: json['id']! as String,
      name: json['name']! as String,
      aliases: ((json['aliases'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      source: json['source']! as String,
      addedAt: _parseDate(json['added_at']),
    );
  }
}

/// 全局 `keyword_category_catalog.json` 文件结构。
class KeywordCategoryCatalogFile {
  KeywordCategoryCatalogFile({
    Map<String, KeywordCategory>? categories,
  }) : categories = categories ?? <String, KeywordCategory>{};

  static const int currentVersion = 1;

  /// 默认 10 个分类（与设计文档 § 3.4 starter catalog 对齐）。
  static const List<Map<String, Object?>> _defaultCategorySpecs = [
    {'name': '哲学', 'aliases': ['哲学思辨', '哲学思考']},
    {'name': '科技', 'aliases': ['技术', 'IT', '编程']},
    {'name': '教育', 'aliases': ['学习', '教学']},
    {'name': '社科', 'aliases': ['社会学', '心理学']},
    {'name': '情感', 'aliases': ['情绪', '感受']},
    {'name': '个人成长', 'aliases': ['自我提升']},
    {'name': '商业', 'aliases': ['工作', '职场']},
    {'name': '艺术', 'aliases': ['创意', '设计']},
    {'name': '健康', 'aliases': ['健身', '医疗']},
    {'name': '生活', 'aliases': ['日常']},
  ];

  DateTime? updatedAt;

  /// id → category。
  final Map<String, KeywordCategory> categories;

  /// 默认分类 id（首次初始化时由程序生成 8 位随机短 ID）。
  static Map<String, KeywordCategory> buildDefaultCategories() {
    final result = <String, KeywordCategory>{};
    final existingIds = <String>{};
    for (final spec in _defaultCategorySpecs) {
      final id = KeywordStorageUtils.generateShortId(existingIds);
      existingIds.add(id);
      final name = spec['name']! as String;
      final aliases = (spec['aliases']! as List).cast<String>();
      result[id] = KeywordCategory(
        id: id,
        name: name,
        aliases: aliases,
        source: 'default',
      );
    }
    return result;
  }

  Map<String, Object?> toJson() => {
        'version': currentVersion,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        'categories': categories.values.map((c) => c.toJson()).toList(),
      };

  factory KeywordCategoryCatalogFile.fromJson(Map<String, Object?> json) {
    final rawList = json['categories'] as List? ?? const [];
    final categories = <String, KeywordCategory>{};
    for (final raw in rawList) {
      final c = KeywordCategory.fromJson(Map<String, Object?>.from(raw as Map));
      categories[c.id] = c;
    }
    return KeywordCategoryCatalogFile(categories: categories)
      ..updatedAt = _parseDate(json['updated_at']);
  }

  /// 按 name 查找（catalog 匹配池查询）。
  KeywordCategory? findByName(String name) {
    for (final c in categories.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// 按 alias 查找（LLM 输出 alias 时反查）。
  KeywordCategory? findByAlias(String alias) {
    for (final c in categories.values) {
      if (c.aliases.contains(alias)) return c;
    }
    return null;
  }
}

/// 全局 `keyword_category_catalog.json` 文件读写器。
///
/// 文件路径：`<rootDir>/keyword_category_catalog.json`
class KeywordCategoryStorage {
  KeywordCategoryStorage({required this.rootDir});

  final String rootDir;

  String get _filePath => '$rootDir/keyword_category_catalog.json';

  /// 读取或初始化文件。
  /// 文件不存在时自动写入默认 10 个分类（id 由程序生成的 8 位短 ID）。
  Future<KeywordCategoryCatalogFile> loadOrInit() async {
    final file = File(_filePath);
    if (!await file.exists()) {
      final empty = KeywordCategoryCatalogFile(
        categories: KeywordCategoryCatalogFile.buildDefaultCategories(),
      );
      await _write(empty);
      return empty;
    }
    return read();
  }

  /// 读取文件。文件不存在或解析失败时抛出异常。
  Future<KeywordCategoryCatalogFile> read() async {
    final file = File(_filePath);
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('keyword_category_catalog.json is not an object');
    }
    return KeywordCategoryCatalogFile.fromJson(Map<String, Object?>.from(decoded));
  }

  /// 原子写入文件。
  Future<void> _write(KeywordCategoryCatalogFile data) async {
    data.updatedAt = DateTime.now().toUtc();
    final encoder = const JsonEncoder.withIndent('  ');
    await KeywordStorageUtils.atomicWriteString(
      _filePath,
      encoder.convert(data.toJson()),
    );
  }

  /// 读 → 修改 → 写（原子）。
  Future<KeywordCategoryCatalogFile> updateAsync(
    KeywordCategoryCatalogFile Function(KeywordCategoryCatalogFile current) mutator,
  ) async {
    final current = await loadOrInit();
    final updated = mutator(current);
    await _write(updated);
    return updated;
  }

  /// 增量新增一个 llm_added 分类（id 由程序生成 8 位短 ID）。
  ///
  /// 返回新分配的 category id，供 Prompt A 后续写入 keyword 时使用。
  Future<String> addLlmCategory({required String name, required List<String> aliases}) async {
    String? newId;
    await updateAsync((current) {
      newId = KeywordStorageUtils.generateShortId(current.categories.keys.toSet());
      current.categories[newId!] = KeywordCategory(
        id: newId!,
        name: name,
        aliases: aliases,
        source: 'llm_added',
        addedAt: DateTime.now().toUtc(),
      );
      return current;
    });
    return newId!;
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}