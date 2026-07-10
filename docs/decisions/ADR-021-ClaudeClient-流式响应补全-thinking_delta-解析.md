## ADR-021: ClaudeClient 流式响应补全 `thinking_delta` 解析

2026-07-06 决定。ADR-020 把 DeepSeek 全量切到 Anthropic 协议后，`_extractClaudeDelta` 仍只读 `delta['text']` 字段——Anthropic 的 `content_block_delta` 事件还有另外两个分支：`type: 'thinking_delta'`（字段名 `delta.thinking`）与 `type: 'input_json_delta'`（tool use）。DeepSeek 的推理模型（`deepseek-reasoner` / `deepseek-v4-pro` / `deepseek-v4-flash`）以及 Anthropic Claude reasoning 系列（opus / sonnet thinking 模式）服务端都按 Anthropic 协议发 thinking 事件，前端解析只丢了它，导致 UI 上 `SessionMessage.reasoning` 永远是空串、折叠展开的「思考过程」永远看不到。

决策：在 `_extractClaudeDelta` 显式判断 `delta.type` 分支——`thinking_delta` 读 `delta.thinking` 进 `LlmResponseDelta.reasoning`；`text_delta` 或 `delta.type` 缺省时（兼容旧实现）继续读 `delta.text`；其他类型（`input_json_delta` 等）忽略。`content_block_start` 同步处理：`content_block.type == 'thinking'` 读 `block.thinking`（少数实现会在 block_start 预填首段，其他走 `text`）。Anthropic 协议是事件驱动——`delta` 字段名因 `type` 而异，**不能**用宽松 `delta['text']` 统一处理，必须按 type 分支。

影响范围：`lib/data/services/llm_client.dart` `_extractClaudeDelta` 函数（约 30 行扩展）。属 ADR-020 自然延续（同一份协议迁移代码），不需要新增端点或新文件。验证路径：deepseek-reasoner 在 streaming 响应里会先发 `content_block_start(type=thinking)`、再发多个 `content_block_delta(type=thinking_delta)` 累计 reasoning、`content_block_stop` 关闭、然后切到普通 text 块；解析器必须按顺序正确切分。
