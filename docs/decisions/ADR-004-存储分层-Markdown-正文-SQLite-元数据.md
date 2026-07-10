## ADR-004: 存储分层 Markdown 正文 + SQLite 元数据

2026-05 决定。**正文**走 Markdown 文件（`lib/data/services/session_markdown.dart` 写入 `Documents/<themeId>/<nodeId>/session.md`），**元数据**（节点关系/索引/时间戳/搜索索引）走 SQLite（`lib/data/services/app_database.dart`）。理由：Markdown 人可读、git 友好（用户能直接把笔记库当 git 仓库管理）、跨平台换系统不丢；SQLite 处理树形 parentId 关系、FTS5 全文索引、BM25 排序这些结构化需求。两层之间用 `nodeId` 对齐，**不要**在 Markdown 里塞 frontmatter 元数据（让 SQLite 唯一持有关系）。影响范围：所有写盘操作、跨设备迁移（如果以后加）、导出/导入功能。
