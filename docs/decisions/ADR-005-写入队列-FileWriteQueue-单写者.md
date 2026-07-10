## ADR-005: 写入队列 FileWriteQueue 单写者

2026-05 决定。Markdown 文件写入走 `FileWriteQueue`（`lib/data/services/file_write_queue.dart`），单写者队列 + 串行执行。理由：流式 SSE 响应逐 token 追加到 `session.md` 时，如果允许并发写（多个 chat 页面同时打开同一节点），会出现内容交错/截断；流式追加必须原子化（`writeAsStringSync` + `flush`）。所有写盘调用都进队列，队列保证同节点有序、跨节点独立。影响范围：所有 `NoteStore` / `SessionMarkdown` 的写盘入口；任何新模块的写盘**必须**走队列，不能自己 `File.writeAsString`。实施要点：队列是单一入口，**禁止**绕过。
