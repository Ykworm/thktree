## ADR-014: DB 一致性保障——统一 disk-first 写入顺序 + 启动轻量同步

2026-06-22 决定。DB 一致性保障机制从"散落在各处的全量 reindex"改为"统一 disk-first 写入顺序 + 启动时轻量 syncFromDisk"。

背景：`getSessionPathForNode` 每次调用都执行全量 reindex（`reindexThemesFromDisk` + `reindexNodesFromDisk`），两者都使用 `db.transaction()`。当两个协程并发调用时（例如第一条消息流式完成后的 `_updateSearchIndex` 和第二条消息的 `sendUserMessage`），嵌套事务崩溃："cannot start a transaction within a transaction"。详见 [war-stories/ui-ux/2026-06-22-sqlite-nested-transaction-crash.md](war-stories/ui-ux/2026-06-22-sqlite-nested-transaction-crash.md)。

决策：三项改动。第一，统一 disk-first 写入顺序——所有操作（create/delete/modify）先写 disk 再写 DB，调换 `updateNodeTitle` 的写入顺序（原来 DB-first）；`renameTheme` 和 `createChatNode`、`deleteNodeSubtree` 已是 disk-first，无需改动。第二，启动时轻量同步——在 `appDatabaseProvider` 初始化时调用 `syncFromDisk()`，扫描磁盘目录 + 读 meta.json，与 DB 比对后只补差异（disk 有 DB 没有 → INSERT，DB 有 disk 没有 → DELETE），不做 DELETE ALL + re-INSERT。第三，移除散落的 reindex——`ThemeDetailController._load()`、`ThemeListController.build()`、`getSessionPathForNode` 中的 reindex 调用全部移除，用启动同步替代。

影响范围：`lib/data/stores/node_store.dart`（新增 `syncFromDisk` + `_collectNodeMeta`，调换 `updateNodeTitle` 写入顺序，移除 `deleteNodeSubtree` 中的 reindex）、`lib/data/stores/theme_store.dart`（新增 `syncFromDisk`）、`lib/ui/core/app_services.dart`（`appDatabaseProvider` 加启动同步）、`lib/ui/features/themes/theme_detail_controller.dart`（移除 `_load` 中的 reindex）、`lib/ui/features/themes/theme_list_controller.dart`（移除 `build` 中的 reindex，`reindex()` 改用 `syncFromDisk`）。

实施要点：`syncFromDisk` 只扫描目录名 + 读 meta.json，不读 session.md 内容，比全量 reindex 轻几个数量级。crash 恢复安全性依赖 disk-first 写入顺序——crash 后 disk 状态总是最新的，启动同步用 disk 覆盖 DB 即可。`reindexThemesFromDisk` 和 `reindexNodesFromDisk` 方法保留但不再在热路径调用，仅作为手动全量重建的逃生通道。
