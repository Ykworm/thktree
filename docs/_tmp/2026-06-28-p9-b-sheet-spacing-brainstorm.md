# P.9-B 选择 sheet 顶部间距优化 — Brainstorming 草稿（v1）

> **本文件状态**：brainstorming 阶段结论（用户 2026-06-28 确认方案）
> **下游**：writing-plans → 实现 → context-sync → 收尾
> **关联 issue**：P.9 § B 部分（[product-feedback-backlog.md § P.9](2026-06-24-product-feedback-backlog.md)）
> **上游文档**：[issues-priorities.md](2026-06-24-issues-priorities.md) § 1. P.9

---

## 🎯 一句话目标

修复 `showBranchModeSheet` 标题区"第一行文字与顶部的距离太大"问题——仅改这一处 padding，圆角/字号/字重保持现状。

---

## 🧱 用户原话与翻译

> "另外就是这个弹出的选择 sheet，貌似第一行文字与顶部的距离太大了，比例不好看"

翻译为可执行项：

| 原文关键词 | 翻译 |
|----------|------|
| "弹出的选择 sheet" | `showBranchModeSheet`（`lib/ui/core/shared/title_suggestion_screen.dart:636`） |
| "第一行文字" | sheet 标题 `l10n.branchModeSheetTitle`（如 "选择模式"） |
| "与顶部的距离" | title 区 `EdgeInsets.fromLTRB(16, 16, 16, 8)` 的第一个参数（顶部 16） |
| "太大" | iOS HIG sheet 顶部留白通常 8-12pt，16 偏大 |
| "比例不好看" | 视觉比例失衡：标题上下间距不对称（顶 16 / 底 8） |

---

## 📊 现状摸底（已通过 rg/wc/grep 验证）

### 涉及代码（仅 1 处）

[`lib/ui/core/shared/title_suggestion_screen.dart:633-730`](../../lib/ui/core/shared/title_suggestion_screen.dart)（`showBranchModeSheet` 函数）

**关键行**：

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),  // ← 待改
  child: Text(
    l10n.branchModeSheetTitle,  // fontSize: 17, fontWeight: w600
    ...
```

- 顶部 padding：**16** ← 待优化
- 左右 padding：16
- 底部 padding：8
- 字号：17
- 字重：w600
- 顶圆角（外层 Container）：12

### 设计 token 现状

- `docs/_shared/design-tokens.yaml:190` 有 `title1` Modal 标题（28pt w700）—— **本任务不使用**
- `docs/_shared/design-tokens.yaml:310` 有 `modal:` 节点 —— **不涉及 padding token**
- `docs/_shared/design-tokens.yaml:541` 列出 `ThkActionSheet` —— **本任务不涉及**
- **结论**：项目**没有** sheet padding 的统一 token（设计 token 本身是缺口）

### 项目内其他 sheet（仅参考，不动）

| 文件 | 行 | 用途 | 状态 |
|------|---|------|------|
| `lib/ui/core/shared/title_suggestion_screen.dart` | 638 | **本次目标**（branch mode 选择） | ⏳ 修 |
| `lib/ui/core/widgets/thk_action_sheet.dart` | 62 | ThkActionSheet 组件（已封装） | 🚫 不动 |
| `lib/ui/features/settings/settings_screen.dart` | 322 | 设置 sheet | 🚫 不动 |
| `lib/ui/features/llm/llm_provider_detail_screen.dart` | 607 | LLM provider 配置 sheet | 🚫 不动 |
| `lib/ui/features/notes/node_location_picker.dart` | 45/63 | 节点位置选择 sheet | 🚫 不动 |
| `lib/ui/features/themes/theme_list_screen.dart` | 121 | 主题列表操作 sheet | 🚫 不动 |

> **决策依据**：用户选"仅修本 sheet"——避免改其他 sheet 引起连锁；其他 sheet 如果未来发现同样问题再说。

---

## 🎨 视觉对比（方案前后）

### 改前（当前）

```
┌─────────────────────┐  ← 顶圆角 12
│                     │
│                     │  ← 顶部留白 16pt（"撑感"来源）
│      选择模式        │  ← 字号 17 / w600
│                     │  ← 标题下方 8pt
│  总结后创建         │
│  使用原始上下文创建   │
│  空白分支           │
│                     │
│  [取消]   [继续]    │
└─────────────────────┘
        底部留白 16pt
```

### 改后

```
┌─────────────────────┐  ← 顶圆角 12
│                     │
│      选择模式        │  ← 字号 17 / w600
│                     │  ← 标题上下都是 8pt（对称）
│  总结后创建         │
│  使用原始上下文创建   │
│  空白分支           │
│                     │
│  [取消]   [继续]    │
└─────────────────────┘
        底部留白 16pt
```

**视觉收益**：

- 节省 8pt 顶部留白 → 标题更"贴顶"，比例更紧
- 标题上下间距对称（8/8）→ 视觉平衡
- iOS HIG：sheet 顶部留白 8-12pt 区间内 → 符合 Cupertino 风格

---

## ✅ 决策清单（用户已确认）

| # | 决策点 | 选项 | 结果 | 理由 |
|---|--------|------|------|------|
| B.1 | 顶部 padding 目标值 | 16→8 / 16→12 / 自定义 | **16→8** | iOS HIG：sheet 顶部留白 8-12pt；与标题下方 8 对称 |
| B.2 | 修复范围 | 仅本 sheet / 全局 sheet | **仅本 sheet** | 避免改 ThkActionSheet 等组件；其他 sheet 未来再说 |
| B.3 | 顶圆角 | 不动 / 同步调 / 检查背景 | **不动（保持 12）** | 用户授权 AI 按代码现状决定 |
| B.4 | 字号 / 字重 | 不动 / 对齐 title1 / 微调 | **不动（保持 17 / w600）** | 用户明确 |

---

## 📁 涉及文件清单

| 文件 | 改动 | 状态 |
|------|------|------|
| `lib/ui/core/shared/title_suggestion_screen.dart` | 行 659 padding 改 `EdgeInsets.fromLTRB(16, 8, 16, 8)` | 修改 |
| `integration_test/branch_creation_test.dart` | 新增 1 个 case `branch_mode_sheet_title_padding_compact` | 修改 |
| `docs/FEATURES.md` § 分支模式 | 同步视觉变更（context-sync 时） | 修改 |
| `docs/_shared/design-tokens.yaml` | **不动**（用户选"仅修本 sheet"，不建 token） | 不动 |
| `docs/_shared/design-system.md` | **不动**（同） | 不动 |
| `docs/CHANGELOG/2026-06-28-branch-mode-sheet-spacing.md` | 新增短记录 | 新增 |

---

## 🧪 验收方式（按 AGENTS.md "测试与验收策略"）

### 静态层（最便宜，必做）

- `flutter analyze` 无新增 error / warning

### 集成测试层（关键路径，本项目禁用单测）

新增 1 个 case `branch_mode_sheet_title_padding_compact`：

```dart
testWidgets('branch mode sheet 标题区顶部 padding 收紧为 8', (tester) async {
  // 1. 打开 showBranchModeSheet
  // 2. 找到标题 Text widget（'branch_mode_sheet_title'）
  // 3. 向上找到最近 Padding，断言 EdgeInsets.fromLTRB(16, 8, 16, 8)
  // 4. 不应再是 16
});
```

### 手工验证层（iOS sim，必做）

1. chat 页 → 点 branch 按钮 → sheet 弹出
2. 看 sheet 标题"选择模式"与 sheet 顶部留白
3. 视觉对比：标题不再"撑"、上下间距对称
4. 回归：3 个选项（summarize / raw / blank）功能不变

### 不做的

- ❌ 不写单测（项目禁用）
- ❌ 不建 sheet padding token（用户选"仅修本 sheet"）
- ❌ 不改其他 sheet（避免连锁）

---

## ⚠️ 风险与缓解

| 风险 | 缓解 |
|------|------|
| 8pt 顶部留白仍嫌大 | iOS HIG 在 8-12pt 区间内是合规的；如仍嫌大，下次直接改 6 或 4 |
| 改了后视觉不平衡（标题贴太近顶圆角） | 顶圆角 12 + 8pt 留白是 iOS 标准比例（参考 Reminders / Notes app） |
| 影响其他 sheet 视觉一致性 | 用户明确"仅修本 sheet"；其他 sheet 不动是 accepted trade-off |
| 改动太小没必要做 | 用户原话明确指出比例问题，"小但必要"的视觉微调 |

---

## 🚦 不在本任务范围（明确划线）

- ❌ 不动 `ThkActionSheet` 组件（已封装、有自己的 padding 逻辑）
- ❌ 不建 `spacing.modalTitleTop` 等设计 token
- ❌ 不改其他 7 处 sheet 的顶部间距
- ❌ 不动 `l10n.branchModeSheetTitle` 文案
- ❌ 不改字号 / 字重 / 顶圆角
- ❌ 不写单测（项目禁用）
- ❌ 不动 CHANGELOG 之外的发布流程

---

## 📝 元说明

- **用户原文长度**：14 个汉字 + 9 个汉字（两句）
- **修改行数**：1 行代码 + 1 个集成测试 case + 1 条 CHANGELOG
- **预计工作量**：<0.5 天（与 P.9 卡估计一致）
- **worktree 名**：`codex/branch-mode-sheet-spacing`
- **草稿归档日**：2026-06-28
- **下游**：
  1. 用户确认草稿（当前阶段）
  2. writing-plans → 输出实现计划
  3. 验收优先 → 定义详细验收
  4. context-sync → 同步 FEATURES.md / CHANGELOG
  5. 收尾 → worktree + commit + rebase + merge
