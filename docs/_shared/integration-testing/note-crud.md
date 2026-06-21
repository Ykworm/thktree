# 笔记 CRUD 集成测试（note_crud_test.dart）

> **文件**：[`integration_test/note_crud_test.dart`](../../../integration_test/note_crud_test.dart)（245 行，1 个 testWidgets）  
> **状态**：✅ **完整可跑通**  
> **草稿来源**：[docs/_tmp/note-crud-test.md](../../_tmp/note-crud-test.md)（已吸收）

---

## 1. 目标

验证笔记模块的完整 CRUD 生命周期：

```
创建主题 → 创建笔记 → 编辑内容 → 重命名 → 持久化验证 → 删除
```

不依赖 LLM，纯 UI + 数据层验证，运行速度快（约 15 秒）。

---

## 2. 场景表

| 步骤 | 操作 | 期望 | 涉及定位方式 |
|------|------|------|-------------|
| 准备 | 切到"主题" tab → 创建测试主题 | 主题出现在列表 | `add_theme_button` / `theme_title_input` / `theme_create_button` |
| 1 | 切到"笔记" tab → 点 + → 选主题 → 填标题+内容 → 点 ✓ 保存 | 笔记出现在主题笔记列表 | `AppIcons.add` / `find.text(themeTitle)` / `AppIcons.check` |
| 2 | 点笔记 → 进详情 → 点编辑 → 追加内容 → 点 ✓ 保存 | 详情页显示追加内容 | `AppIcons.edit` / `CupertinoTextField` / `AppIcons.check` |
| 3 | 点更多操作 → 重命名 → 输入新标题 → 保存 | 列表标题更新，旧标题消失 | `CupertinoIcons.ellipsis` / `ThkTextField` |
| 4 | 数据层验证（`runAsync`） | 主题、笔记标题、笔记内容均持久化到磁盘 | `AppPaths` / `NoteStore` |
| 5 | 进详情 → 更多操作 → 删除 → 确认 | 笔记从列表消失 | `CupertinoAlertDialog` / `find.text('删除')` |

---

## 3. 不依赖 LLM

本测试纯 CRUD 操作，不需要 LLM 配置注入。`createTestApp()` 仅传 `locale`，不传 `llmSettings` / `llmConfigStore`。

运行命令：
```bash
flutter test integration_test/note_crud_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d <device>
```

> 注：`--dart-define-from-file` 仍需传入（避免 `loadFromDefine()` 抛错），但测试本身不调用 LLM。

---

## 4. 关键实现决策

### 4.1 主题选择器定位

笔记创建流程通过 `showThemePicker` 底部弹窗选择主题。弹窗（overlay）和背景列表同时包含同一主题标题文本，用 `find.text(themeTitle).last` 精确点击 overlay 层的条目。

### 4.2 编辑内容验证

编辑后用 `find.textContaining(editAppend)` 替代 `find.text(fullBody)`，因为 `GptMarkdown` 可能把含换行的文本拆分成多个 `Text` widget。

### 4.3 持久化验证策略

通过 `tester.runAsync` 直接读取文件系统验证数据持久化，而非 `pumpWidget` 重启 App。原因：全局 `appRouter`（顶层 `GoRouter`）在 `pumpWidget` 重启场景下存在状态残留，导致 `NoteBrowseScreen` 无法正常加载。数据层验证更可靠且更快。

### 4.4 NoteBrowseScreen 分组结构

`NoteBrowseScreen` 按主题分组显示（主题名 + 笔记数量），不直接显示单篇笔记标题。测试通过进入 `ThemeNoteListScreen`（点击主题）来验证单篇笔记的存在。

---

## 5. 测试数据

- 时间戳后缀避免重复运行冲突（不清理数据）
- 主题名：`Intg笔记主题_<ts>`
- 笔记名：`Intg笔记_<ts>`
- 重命名后：`Intg重命名_<ts>`

---

## 6. 超时设置

- 总超时：90 秒
- 实际运行：约 15 秒

---

## 7. 已知限制

- 不测试笔记搜索功能
- 不测试笔记分组排序
- 持久化验证走数据层而非 UI 重启（见 § 4.3）
