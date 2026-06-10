# ThemeListScreen — 主题列表设计

> 范围：`ThemeListScreen` + `ThemeListController`。完整模块索引见 [README.md](README.md)；主题详情/对话树见 [theme-detail-design.md](theme-detail-design.md)。

## Summary

`ThemeListScreen` 是主题 Tab 的入口屏幕，展示用户所有主题（按磁盘扫描顺序），通过 `ThkLargeTitlePage` + 列表呈现。每个主题是一条 `ThkListTile`，左侧 3px 主题色书脊线 + folder 图标作为视觉记忆点。右上角支持 `↻`（重新索引）和 `+`（新建主题）。空状态用 accountTree icon + 友好文案引导创建第一个主题。

**核心设计语言**：与全局 [design-system.md](../../../_shared/design-system.md) 对齐——`pageBg` 背景、`surface` 卡片、`accent`（indigo）通用交互色、每个主题分配一个 5 色调色板色（书脊线 + leading icon 背景/前景）。

---

## 设计决策

| 决策点 | 选择 | 说明 |
|--------|------|------|
| 页面结构 | `ThkLargeTitlePage` | 大标题 + 滚动内容，统一 iOS 大标题模式 |
| 列表项 | `ThkListTile` | 复用核心 widget，leading/trailing/subtitle 全 token 化 |
| 主题视觉记忆点 | 3px 竖线书脊线 + folder icon | 5 色调色板（与节点卡片解耦） |
| 导航方式 | `context.push('/themes/:themeId/tree')` | 推入式导航，保留 Tab 状态 |
| 新建主题 | `CupertinoAlertDialog` + `ThkTextField` | 复用详情页的 `_promptTitle` 模式 |
| 调试模式 | 显示 themeId 在 subtitle | 仅 `kDebugMode` 可见，发布模式隐藏 |
| 列表分隔 | 0.5px 容器，缩进 56px | 与 ThkListTile 的内边距对齐 |

---

## 1. 布局结构

```
┌────────────────────────────────────┐
│  主题                          ↻  + │  ← ThkLargeTitlePage，trailing
│ ─────────────────────────────────── │
│                                    │
│  ▎ 📁 主题 A                    ›  │  ← 3px 书脊线 + folder + chevron
│  ──────────────────────────────── │  ← 0.5px 分隔（缩进 56px）
│  ▎ 📁 主题 B                    ›  │
│  ──────────────────────────────── │
│  ▎ 📁 未分类                      ›  │  ← kUncategorizedThemeTitle 特殊
│                                    │
└────────────────────────────────────┘
```

**页面基色**：
- 背景：跟随 `ThkLargeTitlePage` 默认（`AppColors.pageBg`）
- 标题色：`AppColors.textPrimary`
- Trailing icon：`AppColors.accent`（来自 `ThkLargeTitlePage` 默认）

---

## 2. NavBar Trailing

右侧两个 0-padding `CupertinoButton`：

```dart
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => ref.read(themeListControllerProvider.notifier).reindex(),
      child: Icon(AppIcons.refresh),
    ),
    CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        final title = await _promptTitle(context);
        if (title == null) return;
        if (!context.mounted) return;
        await ref.read(themeListControllerProvider.notifier).createTheme(title: title);
      },
      child: Icon(AppIcons.add),
    ),
  ],
),
```

**按钮语义**：

| 按钮 | Icon | 行为 | 备注 |
|------|------|------|------|
| ↻ | `AppIcons.refresh` | `reindex()` 从磁盘重建索引 | 不创建主题 |
| + | `AppIcons.add` | 弹对话框 → `createTheme()` | 见 §5 |

---

## 3. 列表项（ThkListTile）

```dart
ThkListTile(
  title: localizedThemeTitle(l10n, themes[i].title),
  subtitle: kDebugMode ? themes[i].themeId : null,
  trailing: ThkListTile.chevron,
  themeId: themes[i].themeId,           // 关键：传 themeId 触发 5 色书脊线
  leading: Icon(AppIcons.folder),
  onTap: () => context.push('/themes/${themes[i].themeId}/tree'),
)
```

**视觉细节**：

| 元素 | 来源 | 备注 |
|------|------|------|
| 标题 | `localizedThemeTitle(l10n, theme.title)` | "未分类" 会映射到 `l10n.uncategorized` |
| Subtitle | `theme.themeId`（仅 debug 模式） | 发布模式不显示 |
| Leading icon 背景 | `AppColors.tintForTheme(themeId)` | 15% tint（自动） |
| Leading icon 颜色 | `AppColors.colorForTheme(themeId)` | 5 色调色板色 |
| 左侧书脊线 | `AppColors.colorForTheme(themeId)`，3px，圆角 1.5px | 由 `ThkListTile.themeId` 参数自动渲染 |
| Trailing | `ThkListTile.chevron` | 默认 chevron 图标，`textTertiary` 色 |
| 点击 | `context.push('/themes/.../tree')` | 推入详情页 |

**分隔线**（手动绘制，不依赖 `ThkListSection`）：

```dart
if (i < themes.length - 1)
  Padding(
    padding: const EdgeInsetsDirectional.only(start: 56),
    child: Container(
      height: 0.5,
      color: AppColors.border,
    ),
  ),
```

缩进 56px 与 `ThkListTile` 的 leading 区域对齐。

---

## 4. 特殊标题：未分类

`localizedThemeTitle()` 是从 `note_browse_screen.dart` 共享的助手：

```dart
const String kUncategorizedThemeTitle = '未分类';

String localizedThemeTitle(AppLocalizations l10n, String title) {
  if (title == kUncategorizedThemeTitle) return l10n.uncategorized;
  return title;
}
```

**为什么主题列表会有"未分类"**：

当用户在笔记里创建节点但未选主题时，节点会被归到"未分类"主题的虚拟文件夹（磁盘上没有 `themes/未分类/` 目录，由控制器逻辑创建）。所以即便用户没主动建过任何主题，列表也可能有"未分类"一项。

**l10n**：`AppLocalizations.uncategorized`（"Uncategorized" / "未分类"）。

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

**关键点**：

- `autofocus: true`：键盘自动弹起
- `maxLength: 30`：限制标题长度（磁盘目录名不宜过长）
- `controller.value.composing`：处理中文输入法"未确认"状态，按回车不要提前 dismiss
- trim() 去除首尾空白；空字符串返回 null
- 按回车（`onSubmitted`）等同于点击"创建"
- 取消按钮 vs 创建按钮：`isDefaultAction: true` 让创建成为回车默认

**返回 null 的两种情况**：

1. 用户点取消
2. 用户输入空字符串 / 纯空白

`createTheme` 只在非 null 时调用。

---

## 6. 空状态

0 个主题时（实际上几乎不可能，因为"未分类"总会存在）：

```dart
Padding(
  padding: const EdgeInsets.only(top: 80),
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          AppIcons.accountTree,
          size: 40,
          color: AppColors.textTertiary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.noThemesYet,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  ),
)
```

**视觉**：

- 40pt accountTree icon，`textTertiary`
- 12px 间距
- `l10n.noThemesYet` 文案（"还没有主题" / "No themes yet"），`textSecondary`
- 居中，距顶 80px

**与全局空状态规范一致**：icon + SizedBox(12) + Text，无 CTA 按钮（用户可用右上 + 按钮创建）。

---

## 7. 错误 / Loading 状态

```dart
themesAsync.when(
  data: ...,
  error: (e, st) => Padding(
    padding: const EdgeInsets.only(top: 80),
    child: Center(child: Text(e.toString())),
  ),
  loading: () => Padding(
    padding: const EdgeInsets.only(top: 80),
    child: Center(child: CupertinoActivityIndicator()),
  ),
)
```

错误直接打印 `e.toString()`，loading 用 Cupertino 菊花。视觉与空状态保持对称（同样距顶 80px 居中）。

---

## 8. ThemeListController

`AsyncNotifier<List<ThemeEntity>>`，全局单实例。

```dart
class ThemeListController extends AsyncNotifier<List<ThemeEntity>> {
  @override
  Future<List<ThemeEntity>> build() async {
    final store = await ref.watch(themeStoreProvider.future);
    await store.reindexThemesFromDisk();
    return store.listThemes();
  }

  Future<void> createTheme({required String title}) async {
    final store = await ref.read(themeStoreProvider.future);
    await store.createTheme(title: title);
    state = AsyncData(await store.listThemes());
  }

  Future<void> reindex() async {
    final store = await ref.read(themeStoreProvider.future);
    await store.reindexThemesFromDisk();
    state = AsyncData(await store.listThemes());
  }
}

final themeListControllerProvider =
    AsyncNotifierProvider<ThemeListController, List<ThemeEntity>>(ThemeList.new);
```

**关键行为**：

- `build()`：从 `themeStoreProvider` 拿 store → 磁盘 reindex → 返回列表
- `createTheme()`：创建 + 全量重新 `listThemes()` 同步 state
- `reindex()`：只重新索引（不创建），然后 `listThemes()` 同步 state
- 全部用 `await store.xxx()` 串行执行，不并发

**注意**：不要在 `build()` 里监听 `themeDetailControllerProvider`——两个 provider 数据流独立。详情页的修改不直接影响列表（删除/重命名不修改 theme.title）。

---

## 实现文件清单

| 文件 | 角色 |
|------|------|
| `lib/ui/features/themes/theme_list_screen.dart` | 屏幕本体（149 行） |
| `lib/ui/features/themes/theme_list_controller.dart` | controller（28 行） |
| `lib/ui/features/notes/note_browse_screen.dart` | 共享 `localizedThemeTitle()` 工具 |
| `lib/ui/core/widgets/widgets.dart` | `ThkLargeTitlePage` / `ThkListTile` / `ThkTextField` |
| `lib/ui/core/theme/app_colors.dart` | `colorForTheme` / `tintForTheme` / `border` / `pageBg` |
| `lib/ui/core/theme/app_icons.dart` | `folder` / `accountTree` / `add` / `refresh` |

---

## Test Plan

1. **空列表**
   - 0 个主题：accountTree icon + noThemesYet
   - 1 个"未分类"：显示该条（l10n.uncategorized 标题）

2. **多条主题**
   - 排序：按 `listThemes()` 返回顺序（通常是 `createdAt` 升序，磁盘扫描）
   - 每个 ThkListTile 书脊线色不同（基于 themeId hash）
   - debug 模式 subtitle 显示 themeId；release 模式不显示

3. **NavBar 按钮**
   - ↻：调 `reindex()`，state 更新但 list 内容可能不变（除非磁盘有变化）
   - +：弹 CupertinoAlertDialog
     - 输入有效标题：调 `createTheme()`，列表自动更新
     - 输入空 / 纯空白：返回 null，不创建
     - 取消：返回 null，不创建
     - 回车（onSubmitted）：等同于创建（注意 composing 状态）

4. **导航**
   - 点击 ThkListTile：`context.push('/themes/:themeId/tree')` 进入详情
   - 返回：从详情页 `context.pop()` 回到列表，列表状态保持

5. **跨屏刷新**
   - 在详情页新建/删除节点：列表**不刷新**（节点属于主题，不影响 theme.title 列表）
   - 在详情页重命名节点：列表**不刷新**

6. **加载 / 错误**
   - loading：菊花
   - error：`e.toString()` 文本（无错误图标）

7. **设计令牌合规**
   - `rg "CupertinoColors\." lib/ui/features/themes/theme_list_screen.dart` 0 命中
   - 颜色全部来自 `AppColors.*`

---

## Assumptions

- "未分类"主题的显示优先级与其他主题一致（按 `listThemes()` 返回顺序），不会置顶
- 主题列表的"创建时间排序"由 `themeStore.listThemes()` 保证，UI 层不二次排序
- 主题重命名功能**当前不存在**（不在本屏幕范围内）；如果未来添加，需要 `ref.invalidate(themeListControllerProvider)`
- `ThkListTile.themeId` 参数是触发书脊线的唯一条件；不传则不显示书脊线（保持纯白底）
- 列表滚动由 `ThkLargeTitlePage` 内部 ListView 处理，外层不需 `SingleChildScrollView`
- 主题数很多时（100+）不做虚拟滚动优化（暂时未遇到性能问题）
- 调试模式通过 `kDebugMode` 编译期常量判断，零运行时开销
