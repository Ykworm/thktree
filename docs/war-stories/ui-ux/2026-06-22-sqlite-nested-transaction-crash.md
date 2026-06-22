# SQLite 嵌套事务崩溃——getSessionPathForNode 全量 reindex 并发冲突

**日期**：2026-06-22
**模块**：data stores / chat
**标签**：SQLite, 事务, 并发, reindex, sqflite

## 现象

用户在主题聊天页面发送第一条消息，等待 LLM 流式回复完成后，发送第二条消息时弹出错误对话框：

```
DatabaseException(Error Domain=SqliteDarwinDatabase Code=1
"cannot start a transaction within a transaction"
UserInfo={NSLocalizedDescription=cannot start a transaction within a transaction})
sql 'BEGIN IMMEDIATE' args []
```

第一条消息发送正常，第二条必崩。

## 根因分析

`getSessionPathForNode` 回调（`lib/ui/core/app_services.dart`）在每次获取 session 路径时都调用 `reindexThemesFromDisk()` 和 `reindexNodesFromDisk()`，两者都使用 `db.transaction()`。

当两个协程并发调用此回调时，两个 `db.transaction()` 在同一个 SQLite 连接上竞争：

- **协程 A**：第一条消息流式完成 → `onDone` → `_updateSearchIndex`（fire-and-forget）→ `readSession` → `getSessionPathForNode` → `reindexThemesFromDisk()` → `db.transaction()` 开始
- **协程 B**：用户发送第二条消息 → `sendUserMessage` → `appendUserMessage` → `getSessionPathForNode` → `reindexThemesFromDisk()` → `db.transaction()` 尝试开始

协程 A 的事务未提交时，协程 B 发起 `BEGIN IMMEDIATE` 导致嵌套事务崩溃。

此外，`_read()` 在流式过程中被每个 delta 调用，每次都触发全量 reindex，放大了并发冲突的窗口。

## 解决方案

三项改动（见 [DECISIONS.md ADR-014](../../DECISIONS.md#adr-014-db-一致性保障统一-disk-first-写入顺序--启动轻量同步)）：

1. **统一 disk-first 写入顺序**：所有操作先写 disk 再写 DB，确保 crash 后 disk 状态总是最新的。调换 `updateNodeTitle` 的写入顺序（原来 DB-first）。
2. **启动时轻量 syncFromDisk**：在 `appDatabaseProvider` 初始化时扫描磁盘目录 + 读 meta.json，与 DB 比对后只补差异，不做 DELETE ALL + re-INSERT。
3. **移除热路径上的 reindex**：`getSessionPathForNode`、`ThemeDetailController._load()`、`ThemeListController.build()` 中的 reindex 调用全部移除。

## 关键代码

原 `getSessionPathForNode` 中的 reindex 块（已移除）：

```dart
// 每次调用都全量重建 themes + nodes 表
await themeStore.reindexThemesFromDisk();      // db.transaction()
for (final theme in themes) {
  await nodeStore.reindexNodesFromDisk(...);   // db.transaction()
}
```

替换为启动时一次性 `syncFromDisk()`：

```dart
// appDatabaseProvider 初始化时调用一次
await themeStore.syncFromDisk();
for (final theme in themes) {
  await nodeStore.syncFromDisk(themePath: ...);
}
```

## 相关文件

- `lib/ui/core/app_services.dart` — `getSessionPathForNode`、`appDatabaseProvider`
- `lib/data/stores/theme_store.dart` — `syncFromDisk()`
- `lib/data/stores/node_store.dart` — `syncFromDisk()`、`updateNodeTitle()`
- `lib/ui/features/chat/chat_controller.dart` — `_updateSearchIndex`、`_read()`

## 复盘

- **为什么一开始没发现**：reindex 被当作"免费操作"嵌入 `getSessionPathForNode`，单协程下不会出问题。只有在第一条消息的 `onDone` 回调和第二条消息的 `sendUserMessage` 并发时才暴露。
- **以后如何避免**：热路径上不应有重量级写操作（尤其是 `db.transaction()`）；DB 一致性保障应集中在启动时一次性完成，而非分散在每次读操作中。
