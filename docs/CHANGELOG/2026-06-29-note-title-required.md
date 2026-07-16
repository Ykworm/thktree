# 2026-06-29 笔记标题必填校验

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-29 |
| 范围 | `lib/ui/features/notes/note_editor_screen.dart`（修改）+ l10n 双语（新增 key）+ `integration_test/note_title_required_test.dart`（新增 5 个 case）|
| 设计文档 | 无（单点修复，方案见 docs/_tmp/note-title-required.md）|
| 状态 | 🟡 代码完成，集成测试留给用户跑（用户反馈：测试案例太多，自己测）|

## 背景

从**笔记 Tab 顶部 nav bar 右上角 `+` 按钮**新建笔记时，如果用户没输入标题就点 ✓ 关闭，原有流程没有任何拦截——空标题笔记会落盘，列表展示一串空白项。

**入口链路**：

```
点击 笔记 Tab 右上角 +
   ↓
弹 showThemePicker（选主题）
   ↓
选中主题
   ↓
直跳 NoteEditorScreen(createMode: true)
   ↓
编辑器 initState 立即调 _store.createNote(title: '')   ← 空标题笔记落盘
   ↓
用户写 / 不写标题
   ↓
点 ✓ 关闭 → _saveNow 把空标题也存下来             ← 二次空标题落盘
```

## 根因

`NoteEditorScreen` 顶部 ✓ 按钮 `onPressed` 直接调 `_saveNow()` + `Navigator.pop()`，没有校验标题是否为空。`createMode: true` 路径在 `initState` 立即 `createNote(title: '')`，即使后续用户从未输入标题也会保存成功。

## 修复

单点修复——在 `NoteEditorScreen` 顶部 ✓ 按钮 `onPressed` 内做空标题校验：

```dart
trailing: CupertinoButton(
  padding: EdgeInsets.zero,
  onPressed: () async {
    if (_titleController.text.trim().isEmpty) {
      ThkAlert.show(
        context: context,
        message: l10n.titleCannotBeEmpty,
        defaultAction: l10n.ok,
      );
      return;
    }
    await _saveNow();
    if (mounted) {
      Navigator.of(context).pop();
    }
  },
  child: Icon(AppIcons.check),
),
```

**关键设计决策**：

1. **用 `trim().isEmpty` 而非 `isEmpty`**——避免用户输入纯空格蒙混过关
2. **校验后 `return;`**——不调 `_saveNow()`、不 `pop()`，编辑器状态完整保留
3. **ThkAlert.show 单"确定"按钮**——沿用 `lib/ui/core/widgets/thk_alert.dart` 的通知型 alert 范式（无需 cancelAction）
4. **单点修复覆盖所有入口**——笔记 Tab `+` / 详情页编辑入口都跳到同一个 `NoteEditorScreen`，✓ 按钮拦截能保证空标题永远无法通过这条路径落盘

## 文件变更

**修改（1 个）：**
- `lib/ui/features/notes/note_editor_screen.dart` L172-189 — ✓ 按钮 `onPressed` 加空标题校验 + ThkAlert.show

**修改（2 个 l10n）：**
- `lib/l10n/app_zh.arb` — 新增 `titleCannotBeEmpty`（标题不能为空，请输入后再保存）
- `lib/l10n/app_en.arb` — 新增 `titleCannotBeEmpty`（Title cannot be empty, please enter a title before saving）

**自动生成（3 个）：**
- `lib/l10n/generated/app_localizations.dart`
- `lib/l10n/generated/app_localizations_zh.dart`
- `lib/l10n/generated/app_localizations_en.dart`

**新增（1 个集成测试）：**
- `integration_test/note_title_required_test.dart`（186 行，5 个 case）

## 验证

| 类别 | 状态 |
|---|---|
| `flutter analyze` | ✅ 无新增 error |
| 集成测试全绿 | ⚠️ 留给用户跑（用户决定不再依赖 AI 跑测试） |
| 手工验证 | 见下方"手工验证步骤" |

## 手工验证步骤（iOS sim）

1. **空标题拦截**：笔记 Tab → `+` → 创建新主题 → 进入 NoteEditorScreen → 不输入标题 → 点 ✓ → **弹出"标题不能为空"alert** → 点"确定" → **编辑器仍在（未 pop）** → 输入"有效标题" → 点 ✓ → **正常退出**
2. **纯空格拦截**：笔记 Tab → `+` → 创建新主题 → 进入 NoteEditorScreen → 标题输入 3 个空格 → body 输入"有内容" → 点 ✓ → **弹 alert（trim 兜底生效）** → 关闭 alert → 标题改为"有效标题" → 点 ✓ → **正常退出**
3. **编辑模式同样生效**：笔记 Tab → 进入已有笔记 → 点 ✏️ 进入编辑模式 → 清空标题 → 点 ✓ → **弹 alert** → 关闭 alert → **编辑器仍在**
4. **回归**：笔记 Tab → 任意正常创建/编辑流程 → 行为与之前一致（无回归）

## 不在本次 scope

按"问题修复范围最小化原则"，以下场景未在本次同步改动：

- `note_detail_screen.dart:_renameNote` 重命名时清空标题的处理（已存在 `newTitle == _title` 跳过逻辑，但未拦截 trim().isEmpty）
- `note_select_screen.dart:_createAndAppend` 的 `_promptTitle`（已有自己的空标题处理）
- 自动标题生成机制
- 历史空标题笔记的展示兜底（已用 `noteId` 占位显示）

如后续需要扩展到重命名 dialog，再单独走一个增量任务。

## 关联

- 上游 brainstorming — 用户确认"保留现状 + ✓ 按钮拦截"方案
- [笔记模块 CHANGELOG 第 11 节](../modules/notes/CHANGELOG.md#11-笔记标题必填校验2026-06-29) — 模块级详细记录
- [笔记模块 README](../modules/notes/README.md) — 功能列表"标题必填校验"行
- [FEATURES.md 第 2 节](../FEATURES.md) — 功能总表"标题必填校验"行