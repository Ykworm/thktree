# LLM 模型默认上下文窗口从 0 改为 1M tokens

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-24 |
| 范围 | llm 模块(模型上下文窗口默认值) |
| 设计文档 | 无 |
| 状态 | ✅ 完成 |

## 背景

从 LLM 提供商 API 获取模型列表时，如果 API 不返回上下文窗口大小，模型会被标记为 0（未设置），在 UI 中显示"未设置"提示，用户需要手动选择。这对用户来说体验不好，绝大多数现代模型都支持至少 1M tokens 的上下文。

## 根因

`ModelFetcher` 中的 `_defaultContextWindow` 常量设为 0，表示"未知/未设置"。

## 方案

将默认上下文窗口大小从 0 改为 1000000（1M tokens）。

## 实施内容

### 修改文件(1 个)

```
lib/data/services/model_fetcher.dart       # _defaultContextWindow 常量从 0 改为 1000000
```

### 关键改动

**`lib/data/services/model_fetcher.dart` — 默认值调整:**

```dart
/// 默认上下文窗口大小（默认 1M tokens）
const int _defaultContextWindow = 1000000;
```

## 验证

| 类别 | 状态 |
|---|---|
| UI 显示 | ✅ 获取模型列表后，所有模型不再显示"未设置"，而是显示"1M" |
| 功能完整 | ✅ 模型列表拉取、保存、使用流程正常 |
| `flutter analyze` | ✅ 无新增 error |

## 关联

- 与 `LlmModelConfig.fromJson()` 中的默认值（1000000）保持一致
