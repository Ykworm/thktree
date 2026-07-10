## ADR-009: 本地搜索 SQLite FTS5 + BM25

2026-05 决定。全文搜索走 SQLite FTS5 虚表 + BM25 排序，**不**走在线 embedding/语义搜索。理由：用户搜索的是"我之前写的那句话里的关键词"——精确匹配 + BM25 排序足够；离线可用，无外部服务依赖；查询速度 < 50ms（10 万条语料）。`notes_fts` 虚表 + 触发器同步更新（write/delete 时自动增删）；跨模块跳转靠 `routeName + args`（`lib/data/search/search_service.dart` 决定跳转目标）。影响范围：`lib/data/services/app_database.dart` 的 FTS5 schema；`lib/data/search/` 整个目录。实施要点：FTS5 同步更新是硬性约束（参见 `docs/modules/search/README.md` 顶部"AI 改模块前必读"），**禁止**单走一条路。
