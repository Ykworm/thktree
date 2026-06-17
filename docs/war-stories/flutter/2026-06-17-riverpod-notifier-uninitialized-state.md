# Riverpod Notifier 构造函数中访问 state 导致 uninitialized state 异常

**日期**：2026-06-17  
**模块**：全局 / 状态管理  
**标签**：Flutter, Riverpod, Notifier, 初始化, 状态管理

## 现象

应用启动时或页面首次加载时崩溃，报错：

```
StateError: Bad state: Cannot use ref after the provider was disposed
```

或

```
StateError: Cannot read the state of a provider inside build
```

堆栈指向某个 `Notifier` 的构造函数或 `initState` 中调用了 `ref.read()` / `ref.watch()`。

## 根因分析

Riverpod 3.x 中，`Notifier` 的构造函数和 `build()` 方法有严格的执行顺序：

1. 构造函数执行（此时 `ref` 已可用，但**不能访问 state**）
2. `build()` 执行（返回初始 state）
3. 之后才能通过 `ref.read` / `ref.watch` 安全访问其他 provider

常见错误模式：

```dart
// ❌ 错误：构造函数中访问 state
class MyController extends Notifier<MyState> {
  MyController() {
    // 错误！此时 state 尚未初始化
    final other = ref.read(otherProvider);  // 可能抛异常
  }
  
  @override
  MyState build() => MyState();
}
```

```dart
// ❌ 错误：build 中调用 setState / notifyListeners
class MyController extends Notifier<MyState> {
  @override
  MyState build() {
    final data = ref.watch(dataProvider);
    // 错误！build 中不能修改 state
    if (data != null) {
      state = state.copyWith(data: data);  // 抛异常
    }
    return MyState();
  }
}
```

## 解决方案

### 方案 1：将初始化逻辑移到 build() 中

```dart
// ✅ 正确：build 返回初始 state，异步初始化用 Future
class MyController extends AsyncNotifier<MyState> {
  @override
  Future<MyState> build() async {
    // build 中可以安全使用 ref
    final other = await ref.read(otherProvider.future);
    return MyState(data: other);
  }
  
  Future<void> doSomething() async {
    // 方法中可以安全使用 ref
    final service = await ref.read(someServiceProvider.future);
    await service.doWork();
  }
}
```

### 方案 2：使用 `AsyncNotifier` 处理异步依赖

```dart
// ✅ 正确：异步初始化用 AsyncNotifier
class ThemeListController extends AsyncNotifier<List<ThemeEntity>> {
  @override
  Future<List<ThemeEntity>> build() async {
    final store = await ref.watch(themeStoreProvider.future);
    await store.reindexThemesFromDisk();
    return await store.listThemes();
  }
}
```

### 方案 3：延迟初始化（非首选）

```dart
// ⚠️ 次选：用 bool 标记避免重复初始化
class MyController extends Notifier<MyState> {
  bool _initialized = false;
  
  @override
  MyState build() {
    return MyState();
  }
  
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    
    // 现在可以安全使用 ref
    final data = await ref.read(dataProvider.future);
    state = state.copyWith(data: data);
  }
}
```

## 关键代码

项目中的正确示例（`theme_list_controller.dart`）：

```dart
class ThemeListController extends AsyncNotifier<List<ThemeEntity>> {
  @override
  Future<List<ThemeEntity>> build() async {
    final store = await ref.watch(themeStoreProvider.future);
    await store.reindexThemesFromDisk();
    final themes = await store.listThemes();
    return await _loadPreviews(themes);
  }
  // ...
}
```

## 相关文件

- `lib/ui/features/themes/theme_list_controller.dart`
- `lib/ui/features/settings/tts_controller.dart`
- `lib/ui/features/notes/note_browse_screen.dart`

## 参考链接

- [Riverpod 官方文档 - Notifier](https://riverpod.dev/docs/providers/notifier_provider)
- [TECH-DEBT.md](../TECH-DEBT.md)

## 复盘

- **为什么一开始没发现**：Riverpod 2.x 和 3.x 在初始化时机上有差异，从 2.x 迁移过来的代码可能保留了旧习惯。模拟器上有时不会触发竞态，真机或 Release 模式下更容易暴露。
- **以后如何避免**：
  1. 所有 `Notifier` 子类的构造函数中禁止调用 `ref.read` / `ref.watch`
  2. 异步初始化一律用 `AsyncNotifier` + `build()` 返回 `Future`
  3. Code Review 时重点检查 Notifier 构造函数和 build 方法
- **扩展**：此问题模式适用于所有 Riverpod `Notifier` / `AsyncNotifier` 子类（Riverpod 3.0 已移除 `StateNotifier`）。
