# 备份提醒功能设计文档

## 概述

在搜索页面顶部显示备份提醒横幅，提醒用户将本地备份分享出去。用户可在 Settings 中关闭提醒或调整周期。

> **2026-07-08 更新**：自动备份已上线。分享提醒与自动备份解耦——本地自动备份不刷新提醒日期，只有“分享出去”才刷新。

## 需求

- 间隔：3 / 5 / 7 / 14 天可选，默认 3 天
- 提醒位置：搜索页面（SearchScreen）顶部
- 提醒形式：非侵入式横幅，内含「去分享」按钮 + 「忽略」按钮 + 关闭按钮
- 开关控制：Settings 页面中一个总开关，默认开启
- 关闭后：不再显示横幅，直到用户重新开启

## 数据模型

### AppSettings 新增字段

```dart
final bool backupReminderEnabled;          // 默认 true
final DateTime? nextBackupReminderDate;     // 下次提醒日期
final int backupReminderIntervalDays;      // 提醒周期：3/5/7/14，默认 3
final bool autoBackupEnabled;               // 自动备份开关，默认 true
final DateTime? lastAutoBackupAt;           // 上次自动备份时间
```

### SettingsStore 新增存储 key

- `backup_reminder_enabled` → bool string
- `next_backup_reminder_date` → ISO8601 string
- `backup_reminder_interval_days` → int string
- `auto_backup_enabled` → bool string
- `last_auto_backup_at` → ISO8601 string

## 提醒逻辑

### BackupReminderService

```dart
class BackupReminderService {
  /// 检查当前是否需要显示提醒
  static bool shouldRemind(AppSettings settings) {
    if (!settings.backupReminderEnabled) return false;
    if (settings.nextBackupReminderDate == null) return true; // 首次使用
    return DateTime.now().isAfter(settings.nextBackupReminderDate!);
  }

  /// 计算下次提醒日期（按用户设定的周期，默认 3 天）
  static DateTime computeNextDate(AppSettings settings) {
    final days = settings.backupReminderIntervalDays;
    return DateTime.now().add(Duration(days: days));
  }
}
```

**关键规则**：
- 自动备份成功**不**刷新 `nextBackupReminderDate`
- 手动备份成功（分享出去）**刷新** `nextBackupReminderDate`
- 横幅上点「去分享」并成功分享后**刷新**
- 点「忽略」**刷新**为当前时间 + 周期天数

## UI 设计

### 1. 搜索页面横幅 (SearchScreen)

在 `SearchContent` 的 `Column` 中，搜索框上方插入横幅：

```
┌─────────────────────────────────────────────┐
│ 📦 你已有 N 份本地备份，建议分享一份到     │
│    iCloud 或其他设备保存                     │
│ [去分享]  [忽略]               [✕]        │
├─────────────────────────────────────────────┤
│ 🔍 Search...                                │
│                                             │
│   [recent tags...]                          │
└─────────────────────────────────────────────┘
```

- 背景色：使用 `AppColors.surfaceMuted` 或轻微强调色
- 图标：AppIcons.archive 或 CupertinoIcons.archivebox
- 文案：动态显示本地备份份数
- 按钮：「去分享」（跳转到备份与恢复页）、「忽略」（推迟一个周期）
- 关闭：右侧小 ✕ 按钮，点击后关闭横幅（不刷新日期，用户需主动关闭开关来停止提醒）

> 注：关闭按钮建议保留，但忽略按钮更常用；若点击关闭，可视为用户暂时不想看，也可按忽略逻辑处理。

### 2. Settings 开关

在「备份与恢复」聚合页内：

```
分享提醒
副标题：每 3 天提醒一次（默认）
[开关 ON]
```

点击「分享提醒」行进入周期选择：

```
提醒周期
○ 3 天（默认）
○ 5 天
○ 7 天
○ 14 天
```

## 交互流程

### 用户看到横幅时

1. 点击「去分享」→ 跳转 `BackupRestoreScreen` → 用户选择一份本地备份 → 分享成功后刷新 `nextBackupReminderDate`
2. 点击「忽略」→ 计算下次日期（当前 + 周期天数）→ 横幅隐藏
3. 点击 ✕ 关闭 → 横幅隐藏（建议按忽略处理，或保持关闭直到设置重新开启）

### 用户在 Settings 关闭开关

- 立即隐藏横幅（如果当前显示）
- 不再计算下次日期

### 用户重新开启开关

- 立即计算一个下次日期（当前 + 周期天数）
- 如果当前已过提醒时间，横幅立即显示

### 用户修改周期

- 立即按新周期重新计算 `nextBackupReminderDate`
- 新周期从当前时间开始算

## 触发时机

在 `SearchContent` 的 `build` 方法中，根据 `settingsControllerProvider` 的状态决定是否显示横幅。

不需要 `AppLifecycleObserver`，因为搜索页面每次切换回来都会重新 build。

## Dev 调试入口

在 Settings 页面的 `Dev Tools` section 保留调试按钮：

```
[触发备份提醒]  // 仅在 kDebugMode 显示
```

点击后将 `nextBackupReminderDate` 设为 `DateTime.now().subtract(Duration(days: 1))`，下次进入搜索页立即触发横幅显示。

## 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/data/services/settings_store.dart` | 修改 | AppSettings 新增字段，SettingsStore 新增读写方法 |
| `lib/ui/features/settings/settings_controller.dart` | 修改 | 新增 saveAutoBackupEnabled / saveLastAutoBackupAt / saveBackupReminderIntervalDays / saveNextBackupReminderDate |
| `lib/ui/features/settings/settings_screen.dart` | 修改 | 设置页入口收敛为「备份与恢复」行 |
| `lib/ui/features/backup_restore/backup_restore_screen.dart` | 新增 | 备份与恢复聚合页（自动备份 / 本地备份 / 手动备份 / 恢复 / 分享提醒） |
| `lib/ui/features/search/search_content.dart` | 修改 | 横幅文案改动态份数，按钮改为「去分享」/「忽略」 |
| `lib/data/services/auto_backup_service.dart` | 新增 | 自动备份调度（24h 前台补偿） |
| `lib/data/services/export_service.dart` | 修改 | 支持 `outputDir` 参数、原子写入 `.tmp` → rename |
| `lib/ui/core/app_paths.dart` | 修改 | 新增 `backupsDir` |
| `lib/ui/core/auth_gate.dart` | 修改 | 认证成功后触发 `_triggerAutoBackup` |
| `lib/l10n/app_en.arb` | 修改 | 新增本地化文案 |
| `lib/l10n/app_zh.arb` | 修改 | 新增本地化文案 |
| `lib/l10n/generated/*.dart` | 重新生成 | 本地化代码生成 |

## 验收标准

1. 首次安装后，搜索页面顶部显示分享提醒横幅（若未备份）
2. 横幅文案显示当前本地备份份数
3. 点击「去分享」跳转到备份与恢复页，分享成功后 3 天内不再提醒
4. 点击「忽略」后，横幅消失，按当前周期推迟
5. Settings 中关闭开关后，横幅不再出现
6. 重新开启开关后，如果已过提醒时间，横幅立即显示
7. 自动备份成功不刷新分享提醒日期
8. 手动备份成功（分享出去）刷新分享提醒日期
9. 横幅样式与现有 Cupertino 设计一致
