# 新建笔记标题拦截修复（笔记 Tab 添加按钮）

## 背景

用户报告 Bug：从**笔记 Tab 顶部 nav bar 右上角 `+` 按钮**新建笔记，如果没输入标题，没有任何拦截和提示。

入口路径：
[note_browse_screen.dart:113-118](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/notes/note_browse_screen.dart#L113-L118) `add_note_button` → [note_browse_screen.dart:263-295](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/notes/note_browse_screen.dart#L263-L295) `_createNoteInUncategorized`

## 当前完整流程

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

## 修复方案（用户确认）

**保留现状**（点 `+` 直接进入编辑器），只在编辑器顶部 **✓ 按钮**点击时校验：

- `_titleController.text.trim().isEmpty` → 弹 `titleCannotBeEmpty` alert，**不**调 `_saveNow`，**不**离开页面
- 非空 → 走原 `_saveNow` 流程，**正常离开**

## 改动范围（收敛到一个文件）

| 文件 | 改动 |
|------|------|
| `lib/ui/features/notes/note_editor_screen.dart` | ✓ 按钮 `onPressed` 包一层空标题校验 |
| `lib/l10n/app_zh.arb` | 新增 `titleCannotBeEmpty` |
| `lib/l10n/app_en.arb` | 新增 `titleCannotBeEmpty` |
| `lib/l10n/generated/app_localizations*.dart` | `flutter gen-l10n` 自动生成 |

**不动**的文件（之前误判的）：
- `note_browse_screen.dart` —— 入口流程保留
- `note_detail_screen.dart:_createNote` —— 不在本次 scope（用户只指笔记 Tab）
- `note_select_screen.dart:_createAndAppend` —— 已经有自己的 `_promptTitle`
- `note_select_screen.dart:_promptTitle` —— 不抽公共函数（不必要）

**修复为何能覆盖所有进入编辑器的入口**：
笔记 Tab `+` 入口最终都跳到同一个 `NoteEditorScreen`，编辑器 ✓ 按钮的拦截能保证空标题永远无法通过这个路径落盘。**单点修复即可**。

## l10n 新增文案

**中文** (`lib/l10n/app_zh.arb`)：
```json
"titleCannotBeEmpty": "标题不能为空,请输入后再保存",
"@titleCannotBeEmpty": {
  "description": "笔记编辑器保存时,标题为空的提示文案"
}
```

**英文** (`lib/l10n/app_en.arb`)：
```json
"titleCannotBeEmpty": "Title cannot be empty, please enter a title before saving",
"@titleCannotBeEmpty": {
  "description": "提示:笔记编辑器保存时,标题为空"
}
```

## 实现要点

[note_editor_screen.dart:172-181](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/notes/note_editor_screen.dart#L172-L181) 现有代码：
```dart
trailing: CupertinoButton(
  padding: EdgeInsets.zero,
  onPressed: () async {
    await _saveNow();
    if (mounted) {
      Navigator.of(context).pop();
    }
  },
  child: Icon(AppIcons.check),
),
```

修改后：
```dart
trailing: CupertinoButton(
  padding: EdgeInsets.zero,
  onPressed: () async {
    final l10n = AppLocalizations.of(context)!;
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

**注意事项**：
- 用 `ThkAlert.show`（项目统一 alert 组件，参考 [note_detail_screen.dart:289-294](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/notes/note_detail_screen.dart#L289-L294) 用法）
- 校验 `trim().isEmpty` 而非 `isEmpty`，避免用户输入空格"蒙混过关"
- 保留 `await _saveNow()` 的现有行为（已有内容自动保存）
- 已有空标题笔记的历史数据不动

## 验收方式（关键路径集成测试）

集成测试 `integration_test/note_title_required_test.dart`：

| Case | 步骤 | 期望 |
|------|------|------|
| 1 | 笔记 Tab 点 `+` → 选主题 → 进入编辑器（不输入标题）→ 点 ✓ | 弹 `titleCannotBeEmpty` alert，**不**离开编辑器，**不**保存空标题 |
| 2 | 笔记 Tab 点 `+` → 选主题 → 输入"测试标题" → 点 ✓ | 保存成功，离开编辑器，回到笔记 Tab，列表显示"测试标题" |
| 3 | 笔记 Tab 点 `+` → 选主题 → 输入"测试标题"+正文 → 点 ✓ | 同 case 2，标题和正文都保存 |
| 4 | 笔记 Tab 点 `+` → 选主题 → 输入"标题 "（含空格）→ 点 ✓ | 保存后 list 显示"标题"（trim 后），不是含空格的 |
| 5 | 笔记 Tab 点 `+` → 选主题 → 点 ✓（title 为空）→ alert → 关闭 alert → 输入标题 → 点 ✓ | 第一次拦截生效，第二次保存成功 |

**辅助检查**：测试结束后用 host 工具检查主题目录下**没有**空标题的 .md 文件。

## 不在本次 scope

- `note_detail_screen.dart:_renameNote` 重命名时清空标题的处理（不弹 alert 直接 return）
- `note_select_screen.dart:_createAndAppend` 的 `_promptTitle`（已有自己的空标题处理）
- 自动标题生成机制
- 历史空标题笔记的展示兜底（已用 `noteId` 占位，无需调整）