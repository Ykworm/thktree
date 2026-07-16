# 笔记列表刷新机制不稳定

**日期**：2026-05-27  
**模块**：notes / 笔记列表  
**标签**：Flutter, Riverpod, 刷新机制, StatefulShellRoute, 状态同步

## 现象

笔记模块存在多个刷新问题：

1. **添加到笔记后，笔记列表不刷新** — 从聊天页选中文本追加到笔记，切回笔记列表页，新内容未显示
2. **下拉刷新无动画/无效** — 下拉手势不触发 `RefreshIndicator` 动画
3. **笔记页面数据突然为空** — 偶尔进入笔记列表页，内容全部消失，显示空态

## 根因分析

### 问题 1：列表不刷新

项目使用 `StatefulShellRoute.indexedStack` 管理底部 Tab，页面常驻内存不销毁。笔记写盘后，列表页不会自动重新读取磁盘。

### 问题 2：下拉刷新无效

`RefreshIndicator` 要求子 widget 必须是可滚动列表。但之前用 `FutureBuilder` 包裹，加载态/空态/错误态不是可滚动 widget，导致手势无法识别。

### 问题 3：数据突然为空

`appPathsProvider` 是异步初始化的（读取应用文档目录），页面 `build()` 中直接 `ref.read(appPathsProvider)` 获取的是 `AsyncLoading` 状态，未 await 就继续执行，导致路径为空。

## 解决方案

### 方案 1：全局版本号 + Tab 切换触发

```dart
// app_services.dart — 定义全局版本号
final noteListVersionProvider = NotifierProvider<int>(() => 0);

// 写操作后 bump
class NoteStore {
  Future<void> appendBody(...) async {
    // ... 写入文件
    ref.read(noteListVersionProvider.notifier).bump();  // 递增版本号
  }
}

// _MainShell 中 tab 切换时触发
class _MainShell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) {
          if (index == notesTabIndex) {
            ref.read(noteListVersionProvider.notifier).bump();
          }
        },
      ),
    );
  }
}
```

### 方案 2：手动 _load() + 可滚动包裹

所有页面从 `FutureBuilder` 改为手动 `_load()` + `setState`：

```dart
class _NoteBrowseScreenState extends ConsumerState<NoteBrowseScreen> {
  List<NoteEntity>? _notes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // 监听版本号变化
    ref.listen(noteListVersionProvider, (_, __) => _load());
    
    return RefreshIndicator(
      onRefresh: _load,
      child: _ScrollableWrap(  // 自定义：任何状态都包裹在 ListView 中
        isLoading: _isLoading,
        isEmpty: _notes?.isEmpty ?? false,
        emptyWidget: _buildEmpty(),
        error: _error,
        child: _buildList(_notes!),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final store = await ref.read(noteStoreProvider.future);
    final notes = await store.listNoteMetas();
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }
}
```

### 方案 3：await appPathsProvider

```dart
Future<void> _loadThemeNotes() async {
  // ✅ 正确：await future
  final paths = await ref.read(appPathsProvider.future);
  // ... 继续加载
}
```

## 曾尝试但不可行的方案

| 方案 | 失败原因 |
|------|----------|
| `ref.listen` 放在 `initState` | Riverpod 3.x 不允许在 initState 中调用 |
| `ref.listen` 放在 `build` | 触发 `_refresh` → `setState` → rebuild → 再注册 listen，循环不稳定 |
| `WidgetsBindingObserver.resumed` | 只在 app 前后台切换触发，同一应用内 tab 切换不会触发 |
| `FutureBuilder` + 替换 Future | `FutureBuilder` 可能不重新执行新 Future |
| `ValueKey(version)` 强制重建 | 配合 `setState` 时 `RefreshIndicator` 动画异常 |

## 关键代码

版本号触发点汇总：

| 操作 | 触发 bump 的位置 |
|------|-----------------|
| 聊天页选中文本追加到笔记 | `note_select_screen.dart` `_appendToNote()` / `_createAndAppend()` |
| 笔记详情页编辑保存 | `note_detail_screen.dart` `_toggleEditing()` |
| 笔记总览页新建笔记 | `note_browse_screen.dart` `_createNoteInUncategorized()` |
| 用户点击底部笔记 tab | `router.dart` `_MainShell` `onDestinationSelected`；版本号定义在 `app_services.dart` |

## 相关文件

- `lib/ui/core/app_services.dart` — `noteListVersionProvider` 定义
- `lib/ui/core/router.dart` — `_MainShell` tab 切换触发 bump
- `lib/ui/features/notes/note_browse_screen.dart`
- `lib/ui/features/notes/note_detail_screen.dart`
- `lib/ui/features/notes/note_select_screen.dart`
- `lib/data/stores/note_store.dart`

## 参考链接

- [笔记功能开发进度](../modules/notes/CHANGELOG.md) — 第 3 节 刷新机制设计
- [TECH-DEBT.md](../TECH-DEBT.md) — `appPathsProvider` 未就绪时笔记列表短暂空态

## 复盘

- **为什么一开始没发现**：`StatefulShellRoute.indexedStack` 的常驻特性在开发初期不明显，数据量小、操作慢时不会感知到刷新问题。随着功能增加，多个入口写入笔记后，刷新问题才集中暴露。
- **以后如何避免**：
  1. 任何跨页面数据同步，优先考虑全局状态（版本号 / EventBus / Stream），而非页面间传参
  2. `RefreshIndicator` 的 child 必须始终是可滚动 widget，用 `_ScrollableWrap` 一类工具组件统一处理
  3. 异步 provider 必须 `await ref.read(provider.future)`，禁止直接 `ref.read(provider)`
- **扩展**：此问题模式适用于所有使用 `StatefulShellRoute.indexedStack` 或类似常驻页面架构的模块。
