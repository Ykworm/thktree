## ADR-024: 自动备份采用"前台补偿"而非 iOS BGTaskScheduler

2026-07-08 决定。用户需要 App 主动、定期地保护数据，但 iOS 没有真正可靠的定时后台任务。可选三条路：BGTaskScheduler、前台补偿、本地通知+手动确认。ThkTree 是个人用笔记 App，数据只在用户打开 App 时才产生，因此选择**前台补偿**（App 认证成功后检查，超过 24 小时则自动备份）为主方案，**不接入 BGTaskScheduler**。

决策理由：

1. **业务契合**：用户不开 App 就没有新数据，前台触发反而精准对应"有数据需要保护"的时刻。BGTaskScheduler 的调度由系统决定，延迟几小时甚至一天都常见，且低电量/后台压力大时会被跳过，用户会误以为已备份实际没有。
2. **复杂度控制**：BGTaskScheduler 需要改 iOS 原生配置（Info.plist 注册 `BGTaskSchedulerPermittedIdentifiers`、写 Swift/ObjC 调度代码、处理任务注册/取消），收益虚、可靠性差。前台补偿是纯 Dart 逻辑，可在 `AuthGate` 认证成功后触发。
3. **数据安全**：备份过程只读用户数据，最坏情况只是"没生成 zip"，不会损坏笔记、对话或 session.md。原子写入（先 `.tmp` 再 `rename`）保证不会出现半截 zip。

实现要点：

- 频率：24 小时，由 `AppSettings.lastAutoBackupAt` 记录上次时间；仅当距现在超过 24 小时或首次使用才执行。
- 保留份数：7 份，本地 `{root}/backups/` 目录；超出的老备份删除。
- 触发点：`AuthGate` 生物认证成功或无需认证时，静默调用 `AutoBackupService.maybeBackup`，不阻塞 UI。
- 产物：完整 zip（复用 `ExportService.exportFull`），含 `thktree-export/thktree-manifest.json` + `themes/...`。
- 中断安全：`ExportService` 先在内存里构造完整 zip 字节流，再写 `.tmp`；成功后再 `rename`。如果写盘过程中 App 退出，残留 `.tmp` 会在下次备份前自动清理。
- 流式文件处理：备份时若读到带 `<!-- streaming -->` 标记的 `session.md`，跳过该文件；避免把流式中间态打包进去。
- 分享提醒解耦：本地自动备份**不**刷新 `nextBackupReminderDate`；只有"分享出去"（手动备份或本地备份列表点分享）才刷新。本地备份只防 App 内数据损坏，不防设备丢失。

影响范围：`lib/data/services/auto_backup_service.dart`（新增）、`lib/data/services/export_service.dart`（支持 `outputDir`、原子写入）、`lib/data/services/settings_store.dart`（新增 `autoBackupEnabled`/`lastAutoBackupAt`/`backupReminderIntervalDays`）、`lib/ui/core/app_paths.dart`（新增 `backupsDir`）、`lib/ui/core/auth_gate.dart`（认证成功后触发）、`lib/ui/features/backup_restore/backup_restore_screen.dart`（新增聚合页）、`lib/ui/features/settings/settings_screen.dart`（入口收敛）、`lib/ui/features/search/search_content.dart`（横幅重构为"分享提醒"）。

后续如需 BGTaskScheduler：可作为补充方案，在 App 进入后台/前台时向系统注册一个 processing task，但主防线仍应是前台补偿。

---
