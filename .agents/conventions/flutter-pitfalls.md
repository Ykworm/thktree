---
trigger: 写 lib/ 文件 I/O、状态管理代码前
---

# Flutter / Dart 写码踩坑约束

> **本文件定位**：写 lib/ 代码时容易踩的硬约束。每条 = 现象 + 约束 + 正反例。
> **何时读**：写文件 I/O、状态管理、新模块前；Code Review 时作为检查表。
> **维护方式**：新增 pitfall 追加到末尾；约束解除（如依赖升级修复）标注并保留追溯。
> **相关**：design token 红线见 `AGENTS.md` + `docs/_shared/design-system.md`；工具优先级见 `conventions/tool-priority.md`；实战踩坑（已解决）见 `docs/war-stories/`。

---

## 1. iOS 真机文件系统 `stat()` 不可靠

**现象**：iOS 真机 app sandbox 里，`stat()` 返回的 `st_ino`（inode）可能为 0，导致 Flutter 的 `Directory.exists()` / `File.exists()` 返回**假阴性**——文件明明存在但 `exists()` 返回 false。模拟器不复发（容器 `st_ino` 正常），只在真机触发。

**约束**：禁用"先 `exists()` 检查、再操作"的两步法。改成**直接 try 操作 / catch `FileSystemException`**。

**反例**：

```dart
if (dir.existsSync()) {          // ❌ 真机可能 false，跳过本该执行的操作
  final files = dir.list();
  ...
}
```

**正例**：

```dart
try {
  await for (final e in dir.list()) {   // ✅ 直接尝试，失败走 catch
    ...
  }
} on FileSystemException {
  // 目录确实不存在或不可读，按缺失处理
}
```

**背景**：图片清理 / 扫描逻辑（`themes/{themeId}/{nodeId}/images`）受此影响最大。

---

## 2. Riverpod 3.0 已移除 `StateProvider` / `StateNotifierProvider`

**现象**：`pubspec.yaml` 已是 `flutter_riverpod: ^3.0.0`。Riverpod 3.0 **移除**了 `StateProvider` 和 `StateNotifierProvider`，旧代码用它们会编译失败 / 找不到符号。

**约束**：写简单可变状态改用 `Notifier` + `NotifierProvider`。

**写法**：

```dart
class FooNotifier extends Notifier<FooState> {
  @override
  FooState build() => FooState.initial;

  void update(FooState s) => state = s;
}

final fooProvider =
    NotifierProvider<FooNotifier, FooState>(FooNotifier.new);
```

**调用点**：`ref.read(fooProvider.notifier).state = x` 写法不变。

**注意**：`AppColors` 是 static getter（非编译期常量），不能用于 `const` 表达式——这是独立约束，见 `docs/_shared/design-system.md`。

---

<!-- 后续新增 pitfall 追加到此处 -->
