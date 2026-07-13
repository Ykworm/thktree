# Settings 模块

> ⚠️ **AI 改模块前必读**
> 1. **TTS 必读 spec**——iOS 原生 TTS 设计未完全上线，**先看** [`specs/2026-06-05-语音播放功能-design.md`](specs/2026-06-05-语音播放功能-design.md)；选引擎/选音调/调语速都在那里。
> 2. **设置项顺序**——外观→语言→语音→LLM 入口→生物认证→分享→调试。**不要重排**，设计稿定了。
> 3. **`AuthGate` 未上线前不要提交 Face ID 启用代码**——`BiometricService` 在但门未接，硬上会有挫锐感。
> 4. **调试面板**仅 `kDebugMode` 可见；不能上 release。

## 职责

应用设置模块。承载所有用户级偏好配置：外观（主题/字体）、语言、语音播放（TTS）、大模型入口、账户/数据管理、About。

## 功能列表

- 外观：主题模式（浅色/深色/跟随系统）、字体大小、节点配色方案
- 语言：i18n 切换（中/英）
- 语音播放：TTS 引擎选择、语速（播放器内循环切换 0.75× / 1× / 1.5× / 2×）、试听
- 大模型：从设置页进入独立的"大模型"子页，再进入"模型提供商"（仅显示 KIMI、MiniMax、MIMO、DeepSeek、豆包 五个，通过 `visibleProviderTypes` 常量过滤）和"默认模型配置"。深层页面顶部有面包屑导航（`ThkBreadcrumbRow`），点击祖先段可快速跳回任意上层。
- 联网搜索偏好：`web_search_enabled_{providerType}` key 持久化，支持 KIMI、MIMO、DeepSeek 原生联网搜索
- 默认模型配置：集中设置聊天 / 标题生成 / 对话总结 3 个默认模型，点选后进入独立模型选择页
- 数据：**备份与恢复**（自动备份 / 手动备份并分享 / 从 zip 恢复 / 分享提醒）
- 关于：版本号、开源许可、隐私政策
- 调试（仅 debug 模式）：查看 SQLite 大小、强制重索引、日志级别

## 代码文件

| 文件 | 角色 | 行数 |
|------|------|------|
| `lib/ui/features/settings/settings_screen.dart` | 设置主屏幕（分组列表） | 692 |
| `lib/ui/features/backup_restore/backup_restore_screen.dart` | 备份与恢复聚合页 | — |
| `lib/ui/features/settings/llm_settings_screen.dart` | 大模型入口页 | 70 |
| `lib/ui/features/settings/default_model_config_screen.dart` | 默认模型配置页 | 180 |
| `lib/ui/features/settings/default_model_picker_screen.dart` | 默认模型选择页（单选） | 130 |
| `lib/ui/features/settings/settings_controller.dart` | 偏好状态管理（持久化） | 75 |
| `lib/data/services/auto_backup_service.dart` | 自动备份调度（24h 前台补偿） | — |
| `lib/data/services/export_service.dart` | 全量导出为 zip（手动 / 自动备份共用） | 105 |
| `lib/data/services/import_service.dart` | 从 zip 恢复（覆盖 / 合并） | 133 |

## 子文档

- [specs/2026-06-05-语音播放功能-design.md](specs/2026-06-05-语音播放功能-design.md) — TTS 完整设计书（架构/iOS 原生 AVSpeechSynthesizer/UI/数据流/i18n/测试/扩展）

## 备份与恢复

设置页中「备份与恢复」为聚合入口，进入 `BackupRestoreScreen` 后分区管理：

1. **自动备份**
   - 开关：`autoBackupEnabled`（默认开启）
   - 触发：`AuthGate` 认证成功后前台补偿，仅当距 `lastAutoBackupAt` 超过 24h 才执行
   - 产物：本地 `{root}/backups/thktree-backup-{ms}.zip`，最多保留 7 份
   - 原子写入：先写 `.tmp`，成功后 `rename` 到正式文件名；时间戳在写入成功后更新，中断可自愈
   - 安全：备份全程只读用户数据，不会损坏 `themes/` 下任何文件

2. **手动备份**
   - 生成完整 zip 并立即调起系统分享面板
   - 成功后将 `nextBackupReminderDate` 推后一个周期（修复原“手动备份不刷新提醒”bug）

3. **从备份恢复**
   - 调用系统文件选择器选择 zip
   - 若本地已有数据，弹出冲突对话框：覆盖 / 合并 / 取消

4. **分享提醒**
   - 开关：`backupReminderEnabled`（默认开启）
   - 周期：`backupReminderIntervalDays`（3/5/7/14 天，默认 3 天）
   - 文案：搜索页横幅显示当前本地备份份数，引导用户“分享出去才是真正的安全备份”
   - 行为：仅“分享出去”刷新 `nextBackupReminderDate`；自动备份不刷新（本地备份 ≠ 离开设备）

---

## 关键设计原则

- **设置 = 单例持久化**：`SettingsController` 整个 App 共享一份，写入后立即生效
- **外观与节点色解耦**：主题色控制整体配色（见 [themes 模块](../themes/README.md)），节点色是节点身份标识（hash 决定）—— 两者独立
- **TTS 跨平台抽象**：TtsService 接口在 domain 层；iOS 实现走 AVSpeechSynthesizer（MethodChannel），Android/其他走 flutter_tts
- **i18n 一致性**：所有设置项 key 必须在 `lib/l10n/app_*.arb` 双语完整
- **危险操作二次确认**：清空缓存、删除数据等带 destructive 警示

## 维护要点

- 新增设置项：先在 `arb` 文件加 key → `SettingsController` 加字段 → 设置 UI 渲染
- 大模型相关设置保持三层导航：`设置页 -> 大模型 -> 具体子页`，不要把默认模型项重新摊回主设置页；使用 `BreadcrumbSegment` + `RouteSettings.name` 让面包屑可点击跳回
- TTS 相关改动必读 [specs/2026-06-05-语音播放功能-design.md](specs/2026-06-05-语音播放功能-design.md)
- 主题相关改动跨 [themes 模块](../themes/README.md)
- 数据导出格式参考 [storage-format](../../_shared/storage-format.md)
- iOS 原生 TTS 注意 [ios-migration-plan](../../_shared/ios-migration-plan.md)
- 调试面板仅 debug 模式可见，release 自动隐藏

## 相关历史

- 2026-04：设置模块初版（外观 + 语言）
- 2026-05：TTS 接入（iOS AVSpeechSynthesizer 优先）
- 2026-05：LLM 入口从设置页跳转
- 2026-06：数据导出/索引修复工具入口
- 2026-06-20：LLM 区域重构为"大模型"入口，默认模型选择改为独立页面单选列表
- 2026-06：调试面板（debug only）
- 2026-06-17：TTS v1 上线 + UI 迭代（mini bar 布局、毛玻璃、双击标题回顶）
- 2026-06-20：设置页 icon 从 CupertinoIcons 全量迁移 SF Symbols（统一 optical alignment，padding 微调）
- 2026-07-03：联网搜索功能上线，提供商列表过滤为 KIMI/MiniMax/MIMO/DeepSeek，新增搜索偏好持久化
- 2026-07-08：设置 → 大模型 → 模型配置 → 模型选择三级深层页面添加面包屑导航（`ThkBreadcrumbRow`），点击祖先段直接 popUntil 跳回，不再需要逐层返回
