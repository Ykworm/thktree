# 备份提醒功能设计文档

## 概述

在搜索页面顶部显示备份提醒横幅，以 3-7 天随机间隔提醒用户备份数据。用户可在 Settings 中关闭提醒。

## 需求

- 间隔：3-7 天随机
- 提醒位置：搜索页面（SearchScreen）顶部
- 提醒形式：非侵入式横幅，内含备份按钮 + 关闭按钮
- 开关控制：Settings 页面中一个总开关，默认开启
- 关闭后：不再显示横幅，直到用户重新开启

## 数据模型

### AppSettings 新增字段

```dart
final bool backupReminderEnabled;      // 默认 true
final DateTime? nextBackupReminderDate; // 下次提醒日期
```

### SettingsStore 新增存储 key

- `backup_reminder_enabled` → bool string
- `next_backup_reminder_date` → ISO8601 string

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

  /// 计算下次提醒日期（3-7天随机）
  static DateTime computeNextDate() {
    final days = 3 + Random().nextInt(5); // 3,4,5,6,7
    return DateTime.now().add(Duration(days: days));
  }
}
```

## UI 设计

### 1. 搜索页面横幅 (SearchScreen)

在 `SearchContent` 的 `Column` 中，搜索框上方插入横幅：

```
┌─────────────────────────────────────┐
│ 📦 建议定期备份数据以保护您的内容   │
│ [立即备份]              [✕]        │
├─────────────────────────────────────┤
│ 🔍 Search...                        │
│                                     │
│   [recent tags...]                  │
└─────────────────────────────────────┘
```

- 背景色：使用 `AppColors.surfaceMuted` 或轻微强调色
- 图标：AppIcons.archive 或 CupertinoIcons.archivebox
- 文案："建议定期备份数据以保护您的内容"
- 按钮："立即备份"（主按钮样式）
- 关闭：右侧小 ✕ 按钮，点击后计算下次日期并隐藏横幅

### 2. Settings 开关

在 `备份与恢复` section 上方新增：

```
备份提醒
副标题：每 3-7 天提醒一次
[开关 ON]
```

## 交互流程

### 用户看到横幅时

1. 点击"立即备份" → 触发 `_BackupEntry` 的导出流程 → 成功后计算下次日期
2. 点击 ✕ 关闭 → 计算下次日期（3-7天随机）→ 横幅隐藏

### 用户在 Settings 关闭开关

- 立即隐藏横幅（如果当前显示）
- 不再计算下次日期

### 用户重新开启开关

- 立即计算一个下次日期（3-7天随机）
- 如果当前已过提醒时间，横幅立即显示

## 触发时机

在 `SearchContent` 的 `build` 方法中，根据 `settingsControllerProvider` 的状态决定是否显示横幅。

不需要 `AppLifecycleObserver`，因为搜索页面每次切换回来都会重新 build。

## Dev 调试入口

在 Settings 页面的 `Dev Tools` section 新增一个调试按钮：

```
[触发备份提醒]  // 仅在 kDebugMode 显示
```

点击后将 `nextBackupReminderDate` 设为 `DateTime.now().subtract(Duration(days: 1))`，下次进入搜索页立即触发横幅显示。

## 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/data/services/settings_store.dart` | 修改 | AppSettings 新增字段，SettingsStore 新增读写方法 |
| `lib/ui/features/settings/settings_controller.dart` | 修改 | 新增 saveBackupReminderEnabled / saveNextBackupReminderDate / triggerBackupReminderDebug |
| `lib/ui/features/settings/settings_screen.dart` | 修改 | 新增备份提醒开关入口 + Dev Tools 调试按钮 |
| `lib/ui/features/search/search_content.dart` | 修改 | 新增横幅 Widget 及备份逻辑 |
| `lib/l10n/app_en.arb` | 修改 | 新增本地化文案 |
| `lib/l10n/app_zh.arb` | 修改 | 新增本地化文案 |
| `lib/l10n/generated/*.dart` | 重新生成 | 本地化代码生成 |

## 验收标准

1. 首次安装后，搜索页面顶部显示备份提醒横幅
2. 点击"立即备份"触发系统分享面板导出数据
3. 点击 ✕ 关闭后，横幅消失，3-7 天内不再出现
4. Settings 中关闭开关后，横幅不再出现
5. 重新开启开关后，如果已过提醒时间，横幅立即显示
6. 横幅样式与现有 Cupertino 设计一致
