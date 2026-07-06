# 移除 doubao-seed-2-0-lite-250528

> 日期：2026-07-06

`doubao-seed-2-0-lite-250528` 在用户方舟 ARK 账户上持续不可达。该 model id 应该是方舟端 250528 版本（2025-05-28）的 Lite 模型；方舟端该版本 Lite 当前不可用（可能是已下架、可能是用户账户未开通）。继续保留会引导用户选到死路径（UI 显示该模型可选，调用却失败）。

## 改动

- `lib/data/services/model_fetcher.dart`：`_doubaoWhitelist` 删 lite 项，保留 `doubao-seed-2-1-pro-260628` / `doubao-seed-2-1-turbo-260628` 两模型（260628 = 2026-06-28 版本）。
- `lib/data/models/model_capabilities.dart`：同步删除 `doubao-seed-2-0-lite` capability 关键词（避免旧模型残留命中 capability 推断）。

## 历史

保留 `docs/CHANGELOG/2026-07-05-chat-model-search-doubao.md` 不变（changelog 是冻结档案）。该 changelog 当时记的"3 个 Seed 系列模型"现改为 2 个。

## 用户影响

- 新用户：模型选择器里豆包下只剩 2 个选项，干净。
- 已有用户：之前 Lite 模型可能已存进 provider config；下次重启 app 后如未重新拉取模型列表，Lite id 仍在列表里但 capability 推断为 `{ModelCapability.text}` 默认值（无 alwaysThinking 也无 vision），UI 上不会显示 "深度思考（默认）" chip。

## 不做

- 不加 Lite 迁移（删用户 store 里的 Lite model id）—— 用户重新拉模型列表后自然消失，影响很小，迁移不划算。
- 不重命名为 `doubao-seed-2-1-lite` —— 用户没要新模型，没确认方舟端新 ID 是否可用，留待后续真要加时再走小迭代。
