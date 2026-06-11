# LLM 模块视觉设计

> 与 [`../../../_shared/design-system.md`](../../../_shared/design-system.md) 配套阅读。

---

## 屏幕地图

```
┌─────────────────────────────────────────────────────┐
│  SettingsScreen                                      │
│  └── LLM 提供商配置 ›                                │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│  LlmProvidersScreen                                  │
│  ─────────────────────────────────────────────────── │
│  NavBar: ThkNavBar.inline                            │
│          title: l10n.llmProviders                    │
│  ─────────────────────────────────────────────────── │
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Provider A (OpenAI)                          ›  │ │
│  │ api.openai.com/v1                              │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ Provider B (自定义)                          ›  │ │
│  │ custom.endpoint.com                            │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  (空态):                                             │
│  ┌─────────────────────────────────────────────────┐ │
│  │     暂无 Provider，点击 + 添加                    │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
                    │
                    │ tap item
                    ▼
┌─────────────────────────────────────────────────────┐
│  LlmProviderDetailScreen                             │
│  ─────────────────────────────────────────────────── │
│  NavBar: ThkNavBar.inline                            │
│          title: Provider 名称 / "新建 Provider"       │
│  ─────────────────────────────────────────────────── │
│                                                      │
│  Base URL    [https://api.openai.com/v1         ]    │
│  API Key     [••••••••••••••••                    ]    │
│                                                      │
│  ┌── 可用模型 ─────────────────────────────────────┐ │
│  │ ☑ gpt-4o           128K context                 │ │
│  │ ☑ gpt-4o-mini      128K context                 │ │
│  │ ☐ gpt-3.5-turbo     16K context                 │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  [测试连接]                                          │
│                                                      │
│  [设为默认]  [删除 Provider (destructive)]            │
└─────────────────────────────────────────────────────┘
```

---

## 1. LlmProvidersScreen

```dart
ConsumerWidget → providersAsync.when(
  data: _ProviderList(providers),
  loading: CupertinoActivityIndicator,
  error: Text(e.toString()),
)
```

### Provider 列表项

| 元素 | 规范 |
|------|------|
| 组件 | `_ProviderTile` |
| 标题 | Provider 名称 |
| 副标题 | base URL |
| trailing | chevron |
| 自定义 Provider | `provider.type == LlmProviderType.custom` 时有特殊标记 |

### 空状态

- 文案引导："暂无 Provider，点击 + 添加"

---

## 2. LlmProviderDetailScreen

编辑/新建 Provider 的表单页。

### 表单字段

| 字段 | 组件 | 说明 |
|------|------|------|
| Base URL | `ThkTextField` | Provider API 端点 |
| API Key | `ThkTextField` | 安全存储（`flutter_secure_storage` / iOS Keychain） |
| 可用模型 | 复选列表 | 从 `ModelFetcher` 拉取，用户勾选启用的模型 |
| 模型信息 | subtitle | 模型 ID + context window 大小 |

### 操作按钮

| 按钮 | 行为 | 样式 |
|------|------|------|
| 测试连接 | `LlmProviderService.testConnection(provider)`，显示结果（成功/失败 + HTTP status） | — |
| 设为默认 | 标记为 chat 模块首选 Provider | — |
| 删除 Provider | 二次确认，软删除（`isArchived=true`） | `isDestructiveAction: true` |

### 模型拉取

- 点击"拉取模型"按钮 → `ModelFetcher.fetchModels(baseURL, apiKey)`
- 结果填充 `_fetchedModels` 列表
- 有 context window 未知的模型时，弹出 picker 让用户手动设置
- 用户勾选/取消勾选模型 ID → `_selectedModelIds` 更新

### 新建 vs 编辑

| 模式 | NavBar trailing | 初始数据 |
|------|----------------|---------|
| 新建 | 保存按钮 | 空表单 |
| 编辑 | 保存按钮 | `widget.provider` 预填 |
