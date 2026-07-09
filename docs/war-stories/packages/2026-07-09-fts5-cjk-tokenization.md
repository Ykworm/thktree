# FTS5 CJK 分词 — 连续中文字符无法子串搜索

> **日期**：2026-07-09  
> **模块**：search  
> **EC 关联**：EC-015（已修复）  
> **影响范围**：`search_service.dart`、`app_database.dart`

---

## 现象

搜索中文子串（如 `Flutter开发`）时，必须加空格才能搜到结果。

## 根因

SQLite FTS5 的 `unicode61` tokenizer 将**连续 CJK 字符视为一个 token**：

```
索引内容 "Flutter开发指南"
  → tokens: 'flutter', '开发指南'（两个 token，ASCII/CJK 边界分割）
  → FTS5 MATCH 'Flutter开发' → 无匹配（不是完整 token）
```

`unicode61` 在 ASCII 和 CJK 边界处分割，但连续 CJK 字符不分割。所以 `开发指南` 是一个 token，搜 `开发` 搜不到。

## 修复方案

**CJK 逐字分词**：在索引写入和查询时，对 CJK 字符逐字拆开（字符间插入空格），让 FTS5 按单字 AND 匹配。

### 索引写入（`_tokenizeCjk`）

```dart
// "决策树算法指南" → "决 策 树 算 法 指 南"
// FTS5 tokens: 决, 策, 树, 算, 法, 指, 南（每个字独立 token）
```

### 查询处理（`_sanitizeQuery`）

```dart
// 用户输入 "决策树" → "决 策 树"
// FTS5 AND 匹配：决 AND 策 AND 树 → 命中 "决 策 树 算 法 指 南"
```

### Snippet 后处理（`_cleanSnippet`）

FTS5 `snippet()` 返回分词后的文本（带空格），需要清理 CJK 间空格：

```
"决 策 树 算 法" → "决策树算法"
"</b> <b>" → "</b><b>"（清理高亮标记间的空格）
```

### 数据库迁移（v6）

`app_database.dart` 版本升到 6，新增 `_migrateV6`：

```dart
Future<void> _migrateV6(Database db) async {
  await db.execute('DROP TABLE IF EXISTS search_index');
  await db.execute('''CREATE VIRTUAL TABLE search_index USING fts5(...)''');
}
```

DROP + CREATE 触发 `searchServiceProvider` 的空表检测 → 自动 `rebuildAll`（带分词）。

**涉及文件**：
- `lib/data/services/search_service.dart` — `_tokenizeCjk`、`_cleanSnippet`、`_sanitizeQuery`、`_searchWithLike`
- `lib/data/services/app_database.dart` — `_migrateV6`

## 验证

- Python sqlite3 实测：`决策树` 命中 `决 策 树 算 法 指 南`
- Dart sqlite3 实测：`Flutter开发` 命中 `Flutter 开 发 指 南`
- 集成测试 Case 6：覆盖不加空格搜 CJK 子串场景

## 防御建议

- FTS5 `unicode61` 对 CJK 的分词行为是：连续 CJK = 一个 token，ASCII/CJK 边界分割
- 如果需要 CJK 子串搜索，必须在索引和查询两侧都做分词
- LIKE 兜底无法完全替代 FTS5，因为 LIKE 也依赖精确子串匹配
