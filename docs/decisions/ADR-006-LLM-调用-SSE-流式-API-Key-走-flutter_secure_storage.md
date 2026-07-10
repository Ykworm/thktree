## ADR-006: LLM 调用 SSE 流式 + API Key 走 flutter_secure_storage

2026-05 决定 LLM 调用走 SSE 流式（SSE = Server-Sent Events，逐 token 推回）。理由：用户体验优先——用户看到打字机效果比"加载中 5 秒后整段出现"更接近"在跟人聊"；避免长轮询的连接管理复杂度；DeepSeek/OpenAI 都原生支持 SSE 协议。**同时**决定 API Key 必走 `flutter_secure_storage`（iOS Keychain / Android Keystore），**禁止**进 `shared_preferences` / SQLite / 配置文件 / 日志。影响范围：`lib/data/services/llm_api_client.dart`（SSE 解析）；`lib/data/services/biometric_service.dart` 周边（同样走 secure storage）。实施要点：连接测试走 `LlmProviderService.testConnection(provider)`，**不要**在 chat 里复用流式逻辑 ping。
