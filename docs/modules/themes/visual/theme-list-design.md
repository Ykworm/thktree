# ThemeListScreen — 主题列表设计

> 范围：`ThemeListScreen` + `ThemeListController`。完整模块索引见 [README.md](README.md)；主题详情/对话树见 [theme-detail-design.md](theme-detail-design.md)。

## Summary

`ThemeListScreen` 是主题 Tab 的入口屏幕，展示用户所有主题（按 `updatedAt DESC` 排序，置顶优先）。每个主题是一条 `ThkListTile`，左侧 folder 图标跟随主题色（典雅黑金色调）。右上角 `+` 按钮新建主题。支持下拉刷新和长按操作（重命名/置顶/删除）。

**核心设计语言**：与全局 [design-system.md](../../../_shared/design-system.md) 对齐——`surface` 白色背景、`accent`（indigo）通用交互色、每个主题分配一个典雅黑金色调颜色（图标跟随）。

---

## 设计决策

| 决策点 | 选择 | 说明 |
|--------|------|------|
| 页面结构 | `CupertinoPageScaffold` + `CustomScrollView` | 参照笔记列表，支持下拉刷新 |
| 列表项 | `ThkListTile` | 复用核心 widget，leading 跟随主题色 |
| 主题视觉记忆点 | folder 图标跟随主题色 | 典雅黑金色调 5 色调色板 |
| 导航方式 | `context.push('/themes/:themeId/tree')` | 推入式导航，保留 Tab 状态 |
| 新建主题 | `CupertinoAlertDialog` + `ThkTextField` | 复用详情页的 `_promptTitle` 模式 |
| 刷新方式 | 下拉刷新 | `CupertinoSliverRefreshControl`，去掉 NavBar 刷新按钮 |
| 长按操作 | Action Sheet | 重命名/置顶/删除三个选项 |
| 置顶功能 | 数据库 `pinned` 列 | SQLite 存储，重启后保持 |
| 列表排序 | `pinned DESC, updatedAt DESC` | 置顶优先，然后按最后活跃时间 |
| Subtitle | 最后消息预览或相对时间 | 从 `search_index` 查询预览，无预览则显示时间 |
| 列表分隔 | 0.5px 容器，缩进 56px | 与 ThkListTile 的内边距对齐 |

---

## 配色方案（典雅黑金色调）

### 主题色（5 色）

| 颜色 | 色值 | HSL | 感觉 |
|------|------|-----|------|
| 香槟金 | `#C4A77D` | HSL(36, 33%, 63%) | 哑光金，不闪亮 |
| 烟灰 | `#8E8B82` | HSL(42, 4%, 53%) | 温暖中性灰 |
| 玫瑰灰 | `#A89090` | HSL(0, 10%, 61%) | 细腻的粉灰 |
| 橄榄灰 | `#8B9080` | HSL(80, 7%, 53%) | 沉稳的绿灰 |
| 深蓝灰 | `#6B7B8E` | HSL(210, 14%, 49%) | 冷静的锚点 |

**分配规则**：`themeId.hashCode.abs() % 5` 稳定分配

### 图标颜色

```dart
// ThkListTile 中
final iconColor = themeId != null
    ? AppColors.colorForTheme(themeId!)  // 主题色
    : AppColors.accent;  // 默认 indigo
```

---

## 1. 布局结构

```
┌────────────────────────────────────┐
│  主题                              + │  ← NavBar trailing（只有新建按钮）
│ ─────────────────────────────────── │
│                                    │
│  📁 主题 A    帮我看看这段代码...   ›  │  ← folder 图标跟随主题色
│  ──────────────────────────────── │  ← 0.5px 分隔（缩进 56px）
│  📁 主题 B    3天前               ›  │
│  ──────────────────────────────── │
│  📁 未分类    ⭐                  ›  │  ← 置顶图标
│                                    │
└────────────────────────────────────┘
```

**页面基色**：
- 背景：`AppColors.surface`（纯白）
- 标题色：`AppColors.textPrimary`
- Trailing icon：`AppColors.accent`

---

## 2. NavBar Trailing

右侧只有新建按钮：

```dart
trailing: CupertinoButton(
  padding: EdgeInsets.zero,
  onPressed: () async {
    final title = await _promptTitle(context);
    if (title == null) return;
    if (!context.mounted) return;
    await ref.read(themeListControllerProvider.notifier).createTheme(title: title);
  },
  child: Icon(AppIcons.add),
),
```

**下拉刷新**：
```dart
CupertinoSliverRefreshControl(
  onRefresh: () async {
    await ref.read(themeListControllerProvider.notifier).reindex();
  },
),
```

---

## 3. 列表项（ThkListTile）

```dart
ThkListTile(
  title: localizedThemeTitle(l10n, themes[i].title),
  subtitle: themes[i].lastMessagePreview ?? formatRelativeTime(l10n, themes[i].updatedAtUtcIso8601),
  trailing: themes[i].pinned
      ? Icon(AppIcons.star, color: AppColors.accent, size: 18)
      : ThkListTile.chevron,
  themeId: themes[i].themeId,  // 关键：传 themeId 触发主题色图标
  leading: Icon(AppIcons.folder),
  onTap: () => context.push('/themes/${themes[i].themeId}/tree'),
)
```

**视觉细节**：

| 元素 | 来源 | 备注 |
|------|------|------|
| 标题 | `localizedThemeTitle(l10n, theme.title)` | "未分类" 会映射到 `l10n.uncategorized` |
| Subtitle | `lastMessagePreview` 或 `formatRelativeTime()` | 优先显示预览，无预览显示时间 |
| Leading icon 颜色 | `AppColors.colorForTheme(themeId)` | 典雅黑金色调 5 色 |
| Trailing | 置顶图标或 chevron | 置顶显示星标 |
| 点击 | `context.push('/themes/.../tree')` | 推入详情页 |

---

## 4. 长按 Action Sheet

```dart
GestureDetector(
  onLongPress: () => _showThemeActions(context, ref, themes[i], l10n),
  child: ThkListTile(...),
)
```

**Action Sheet 选项**：
- 重命名
- 置顶/取消置顶
- 删除（isDestructiveAction）

---

## 5. 新建主题对话框

复用 Cupertino 原生模式：

```dart
Future<String?> _promptTitle(BuildContext context) async {
  // showCupertinoDialog<String> + CupertinoAlertDialog
  // content: ThkTextField(autofocus: true, maxLength: 30)
  // actions: [取消] [创建(isDefaultAction)]
}
```

---

## 6. 空状态

0 个主题时：

```dart
Padding(
  padding: const EdgeInsets.only(top: 80),
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.accountTree, size: 40, color: AppColors.textTertiary),
        const SizedBox(height: 12),
        Text(l10n.noThemesYet, style: TextStyle(color: AppColors.textSecondary)),
      ],
    ),
  ),
)
```

---

## 7. ThemeListController

`AsyncNotifier<List<ThemeEntity>>`，全局单实例。

```dart
class ThemeListController extends AsyncNotifier<List<ThemeEntity>> {
  @override
  Future<List<ThemeEntity>> build() async {
    final store = await ref.watch(themeStoreProvider.future);
    await store.reindexThemesFromDisk();
    final themes = await store.listThemes();
    return await _loadPreviews(themes);
  }

  Future<List<ThemeEntity>> _loadPreviews(List<ThemeEntity> themes) async {
    // 从 search_index 查询每个主题的最新消息
    // 截取前 40 字符作为预览
  }

  Future<void> createTheme({required String title}) async { ... }
  Future<void> reindex() async { ... }
  Future<void> togglePin({required String themeId, required bool pinned}) async { ... }
  Future<void> deleteTheme({required String themeId}) async { ... }
  Future<void> renameTheme({required String themeId, required String title}) async { ... }
}
```

---

## Test Plan

1. **空列表**
   - 0 个主题：accountTree icon + noThemesYet

2. **多条主题**
   - 排序：置顶优先，然后按 updatedAt DESC
   - 每个 ThkListTile 图标颜色不同（基于 themeId hash）
   - Subtitle 显示预览或相对时间

3. **下拉刷新**
   - 下拉触发 reindex()

4. **长按操作**
   - 重命名：弹对话框
   - 置顶/取消置顶：切换 pinned 状态
   - 删除：带确认对话框

5. **导航**
   - 点击 ThkListTile：`context.push('/themes/:themeId/tree')`

---

## Assumptions

- "未分类"主题可以通过置顶功能手动置顶（不再硬编码）
- 主题数很多时（100+）不做虚拟滚动优化（暂时未遇到性能问题）
- 预览从 search_index 查询，可能有轻微延迟（取决于上次 reindex 时间）
- 相对时间格式复用 `formatRelativeTime()` 函数（支持 l10n）
