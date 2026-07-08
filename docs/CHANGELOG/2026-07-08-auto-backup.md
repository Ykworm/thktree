# 2026-07-08 自动备份与分享提醒解耦

## 改动摘要

上线「定时自动备份」功能，并重构备份提醒为「分享提醒」——本地自动备份不刷新提醒，只有分享出去才刷新。

## 用户视角

- 设置页新增「备份与恢复」聚合页
- 自动备份默认开启，每 24 小时静默生成一份本地 zip（保留最近 7 份）
- 搜索页顶部分享提醒横幅：显示本地备份份数，引导用户分享出去
- 分享提醒周期可调：3 / 5 / 7 / 14 天，默认 3 天
- 手动备份仍可调起系统分享面板，分享成功后刷新提醒日期
- 修复旧 bug：手动备份成功后不再刷新提醒日期

## 技术实现

- 新增 `AutoBackupService`（24h 前台补偿，原子写入 `.tmp` → rename，保留 7 份）
- 新增 `BackupRestoreScreen`（聚合页：自动备份 / 本地备份列表 / 手动备份 / 恢复 / 分享提醒）
- 新增 `AppSettings` 字段：`autoBackupEnabled`、`lastAutoBackupAt`、`backupReminderIntervalDays`
- 新增 `AppPaths.backupsDir`
- `AuthGate` 认证成功后触发 `AutoBackupService.maybeBackup`
- `ExportService.exportFull` 支持 `outputDir` 参数，原子写入
- 搜索页横幅文案改为动态份数，按钮改为「去分享」/「忽略」

## 相关文件

- `lib/data/services/auto_backup_service.dart`
- `lib/data/services/export_service.dart`
- `lib/data/services/settings_store.dart`
- `lib/ui/core/app_paths.dart`
- `lib/ui/core/auth_gate.dart`
- `lib/ui/features/backup_restore/backup_restore_screen.dart`
- `lib/ui/features/settings/settings_screen.dart`
- `lib/ui/features/search/search_content.dart`
- `lib/ui/features/settings/settings_controller.dart`

## 相关文档

- `docs/_tmp/2026-07-08-auto-backup.md` — 方案 brainstorming
- `docs/superpowers/specs/2026-07-07-backup-reminder-design.md` — 分享提醒设计
- `docs/_shared/integration-testing/backup-restore.md` — 集成测试路线
- `docs/modules/settings/README.md` — 设置模块说明
