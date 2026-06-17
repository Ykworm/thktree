# Android 上 TTS 按钮可点击但无声音（NoOpTtsService 静默桩）

**日期**：2026-06-18  
**模块**：settings / TTS  
**标签**：Flutter, 平台分支, TTS, UX 陷阱

## 现象

设置页 TTS 相关功能入口正常显示，按钮可点击、状态切换正常，但 Android 设备上点击后完全没有声音。用户无法从 UI 上判断 TTS 是否真正生效。

## 根因分析

`app_services.dart:239` 中 `ttsServiceProvider` 根据平台返回不同实现：

```dart
final ttsServiceProvider = Provider<TtsService?>((ref) {
  if (Platform.isIOS) return AppleTtsService();
  return NoOpTtsService();
});
```

`NoOpTtsService` 是完全静默的桩实现——所有方法调用不报错、不提示、不发声。UI 层直接消费 `ttsServiceProvider` 的返回值，未检查是否为真实实现，导致用户在 Android 上看到完全正常的 TTS 控件但功能实际无效。

结合 PROJECT.md 中"Android MVP 不保证可用"的定位，这是一个"看着能用其实没生效"的经典 UX 陷阱。

## 解决方案

### 方案 1：UI 层条件隐藏（推荐）

当 `ttsServiceProvider` 返回 `NoOpTtsService` 时，隐藏 TTS 功能入口：

```dart
final ttsService = ref.watch(ttsServiceProvider);
if (ttsService != null && ttsService is! NoOpTtsService) {
  // 显示 TTS 控件
}
```

### 方案 2：NoOpTtsService 抛出平台提示

让 `NoOpTtsService` 在调用时弹出 SnackBar 告知用户当前平台不支持 TTS，而非静默吞掉。

### 方案 3：返回 null 替代 NoOp

将非 iOS 平台的返回值改为 `null`，UI 层统一做 null 检查来决定是否展示 TTS 入口。

## 关键代码

当前问题代码：

```dart
// lib/ui/core/app_services.dart:238-243
/// 其他平台（Android / 桌面）使用 [NoOpTtsService] 静默桩。
final ttsServiceProvider = Provider<TtsService?>((ref) {
  if (Platform.isIOS) return AppleTtsService();
  return NoOpTtsService();
});
```

## 相关文件

- `lib/ui/core/app_services.dart` — `ttsServiceProvider` 定义
- `lib/data/services/no_op_tts_service.dart` — 静默桩实现
- `lib/ui/features/settings/tts_settings_screen.dart` — TTS 设置页 UI

## 复盘

- **为什么一开始没发现**：开发时只在 iOS 上测试 TTS 功能，Android 端虽然有设置入口但从未实际验证过声音输出。UI 层没有区分"功能不可用"和"功能未实现"的状态。
- **以后如何避免**：
  1. 任何平台分支的功能，UI 层必须根据实际实现能力决定是否展示入口
  2. No-op 桩实现不应完全静默——至少在 debug 模式下打印日志或抛出提示
  3. "Android MVP 不保证可用"的功能应有明确的 UI 标记（如灰显、tooltip），而非看起来完全可用
- **扩展**：此问题模式适用于所有平台分支 + 静默桩的组合场景。
