# 模型配置页面交互改造设计文档

> 创建日期：2026-06-20
> 关联任务：Provider 详情页模型列表改造 + 设置页默认模型选择

---

## 背景与问题

当前 `LlmProviderDetailScreen`（提供商详情/配置页面）存在以下交互问题：

1. **强制弹窗突兀**：获取模型列表后，若模型 `contextWindow == 0`，立即逐个弹出 `CupertinoActionSheet` 强制用户选择 Context Size，阻塞式体验差
2. **选择逻辑冗余**：模型列表使用勾选框让用户选择"启用哪些模型"，但获取到的模型本应全部启用
3. **职责混杂**：当前页面同时承担了"模型启用配置"和"Context Size 设置"两个职责，且前者无意义

---

## 任务拆分

### 任务 1：Provider 详情页模型列表改造

**目标页面**：`lib/ui/features/llm/llm_provider_detail_screen.dart`

#### 改造内容

1. **移除勾选选择逻辑**
   - 删除 `_selectedModelIds` 状态变量
   - 删除模型行的 `CupertinoCheckbox` 勾选框
   - 获取到的模型默认全部启用，仅作展示

2. **模型行增加可展开详情区域**
   - 每行模型保留名称 + ID 展示
   - 增加右侧展开指示（chevron）或点击区域
   - 展开后显示：
     - **Context Size 选择器**：下拉形式（CupertinoPicker 或自定义下拉），选项：1M / 512K / 256K / 128K / 64K / 32K / 16K / 8K / 4K
     - **功能说明文案**："用于计算剩余可用 token，影响长对话的截断策略。如 Claude 等模型无需设置。"
     - 默认值：**1M**（不再使用 0 表示未知）

3. **移除强制弹窗逻辑**
   - 删除 `_promptForContextWindows` 方法
   - 删除获取模型后的自动弹窗触发
   - 未知 Context Size 的模型，在列表中显示"未设置"提示，由用户主动展开设置

4. **保存逻辑调整**
   - 保存提供商时，所有获取到的模型都包含在 `models` 列表中
   - 每个模型携带用户设置的 `contextWindow`（默认 1M）

#### 交互流程

```
用户点击"获取模型" → 显示模型列表 → 用户可展开任意模型行 → 设置 Context Size → 点击保存
```

---

### 任务 2：设置页增加"聊天默认模型"选择

**目标页面**：`lib/ui/features/settings/settings_screen.dart`

#### 改造内容

1. **新增"聊天默认模型"设置项**
   - 在设置页 LLM 相关区域，增加一行："聊天默认模型"
   - 显示当前选中的模型名称（如"OpenAI - GPT-4o"）
   - 点击后弹出与现有"标题生成模型"相同的 `showModelPicker` 选择器

2. **数据存储**
   - 使用 `AppSettings` 中新增字段：`chatDefaultProviderId`、`chatDefaultModelId`
   - 通过 `settingsControllerProvider` 保存

3. **聊天页 fallback 逻辑**
   - 聊天页选择模型时，优先使用用户显式选择的模型
   - 若无显式选择，fallback 到设置页配置的"聊天默认模型"
   - 若仍未配置，fallback 到第一个有 key 的 provider 的第一个模型（现有逻辑）

#### 现有功能保留

- "标题生成模型"和"摘要模型"的选择功能保持不变
- 继续使用 `showModelPicker` 统一选择器

---

## 关键决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| Context Size 默认值 | 1M | 覆盖绝大多数现代模型，避免频繁设置 |
| 未知 Context Size 处理方式 | 列表中显示"未设置"，不强制弹窗 | 非阻塞式体验，用户自主选择 |
| 模型启用/禁用 | 获取即全选，不提供禁用功能 | 简化交互，禁用需求低频 |
| 默认模型选择入口 | 设置页新增独立项 | 与标题/摘要模型选择保持一致 |

---

## 验收标准

### 任务 1
- [ ] 获取模型后不再弹出任何 Context Size 选择弹窗
- [ ] 模型列表不显示勾选框，仅展示模型名称和 ID
- [ ] 每个模型行可展开，展开后显示 Context Size 选择器 + 说明文案
- [ ] Context Size 默认值为 1M
- [ ] 保存提供商时所有模型都正确保存

### 任务 2
- [ ] 设置页出现"聊天默认模型"设置项
- [ ] 点击后弹出模型选择器，可选中并保存
- [ ] 聊天页未选择模型时，正确 fallback 到默认模型
- [ ] 现有"标题生成模型"和"摘要模型"功能不受影响

---

## 相关文件

- `lib/ui/features/llm/llm_provider_detail_screen.dart` — 任务 1 主文件
- `lib/ui/features/settings/settings_screen.dart` — 任务 2 主文件
- `lib/data/models/llm_model_config.dart` — 模型数据类（确认 `contextWindow` 字段）
- `lib/data/models/llm_provider_config.dart` — 提供商数据类
- `lib/data/models/app_settings.dart` — 设置数据类（新增默认模型字段）
- `lib/l10n/app_zh.arb` / `lib/l10n/app_en.arb` — 新增本地化文案
