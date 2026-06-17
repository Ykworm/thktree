# AlibabaCloudRUM initialize 阻塞 runApp 导致黑屏

**日期**：2026-06-18  
**模块**：build / 启动  
**标签**：Flutter, 启动, RUM SDK, await 阻塞

## 现象

App 启动后黑屏，无任何错误日志、无崩溃堆栈。设备屏幕保持空白，等待数分钟仍无变化。

## 根因分析

`lib/main.dart:25` 在 `runApp()` 之前对 RUM SDK 初始化做了 `await`：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlibabaCloudRUM().initialize();  // ← 阻塞点
  // ... runApp 在后面
}
```

`AlibabaCloudRUM().initialize()` 没有超时机制，也没有降级路径。如果 SDK 初始化卡住（网络不通、版本兼容问题、配置错误等），`main()` 永远不会执行到 `runApp()`，表现为黑屏。

由于 `runApp` 还没执行，Flutter 的错误处理体系（ErrorWidget、FlutterError.onError 等）尚未注册，所以即使 SDK 内部抛异常也可能被静默吞掉。

## 解决方案

### 推荐：加超时 + 降级

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AlibabaCloudRUM().initialize()
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    // RUM 初始化失败不影响 app 启动
    debugPrint('RUM init failed: $e');
  }

  runApp(const MyApp());
}
```

### 备选：异步初始化，不阻塞 runApp

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());  // 先启动 app

  // RUM 在后台初始化，失败不影响已启动的 app
  AlibabaCloudRUM().initialize().catchError((e) {
    debugPrint('RUM init failed: $e');
  });
}
```

## 关键代码

当前问题代码：

```dart
// lib/main.dart:25
await AlibabaCloudRUM().initialize();
```

## 相关文件

- `lib/main.dart`

## 复盘

- **为什么一开始没发现**：开发环境网络正常、SDK 版本匹配时，初始化在毫秒级完成，不会阻塞。只有在弱网、SDK 版本不兼容、或配置缺失的场景下才会暴露。
- **以后如何避免**：
  1. 任何在 `main()` 中 `await` 的第三方 SDK 初始化都必须加超时
  2. 非核心 SDK（监控、日志、分析）的初始化失败不应阻止 app 启动
  3. `runApp()` 应尽早执行，确保 Flutter 错误处理体系就位
- **扩展**：此问题模式适用于所有在 `main()` 中阻塞式初始化非核心 SDK 的场景。
