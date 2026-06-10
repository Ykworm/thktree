# Settings 模块

> ⚠️ **AI 改模块前必读**
> 1. **TTS 必读 spec**——iOS 原生 TTS 设计未完全上线，**先看** [`specs/2026-06-05-语音播放功能-design.md`](specs/2026-06-05-语音播放功能-design.md)；选引擎/选音调/调语速都在那里。
> 2. **设置项顺序**——外观→语言→语音→LLM 入口→生物认证→分享→调试。**不要重排**，设计稿定了。
> 3. **`AuthGate` 未上线前不要提交 Face ID 启用代码**——`BiometricService` 在但门未接，硬上会有挫锐感。
> 4. **调试面板**仅 `kDebugMode` 可见；不能上 release。

## 职责

应用设置模块。承载所有用户级偏好配置：外观（主题/字体）、语言、语音播放（TTS）、LLM 入口、账户/数据管理、About。

## 功能列表

- 外观：主题模式（浅色/深色/跟随系统）、字体大小、节点配色方案
- 语言：i18n 切换（中/英）
- 语音播放：TTS 引擎选择、语速、音调、试听
- LLM：跳转到 [LLM 模块](../llm/README.md) 配置 Provider
- 数据：导出全部笔记/对话（JSON）、清空本地缓存、修复索引
- 关于：版本号、开源许可、隐私政策
- 调试（仅 debug 模式）：查看 SQLite 大小、强制重索引、日志级别

## 代码文件

| 文件 | 角色 | 行数 |
|------|------|------|
| `lib/ui/features/settings/settings_screen.dart` | 设置主屏幕（分组列表） | 580 |
| `lib/ui/features/settings/settings_controller.dart` | 偏好状态管理（持久化） | 75 |

## 子文档

- [specs/2026-06-05-语音播放功能-design.md](specs/2026-06-05-语音播放功能-design.md) — TTS 完整设计书（架构/iOS 原生 AVSpeechSynthesizer/UI/数据流/i18n/测试/扩展）

## 关键设计原则

- **设置 = 单例持久化**：`SettingsController` 整个 App 共享一份，写入后立即生效
- **外观与节点色解耦**：主题色控制整体配色（见 [themes 模块](../themes/README.md)），节点色是节点身份标识（hash 决定）—— 两者独立
- **TTS 跨平台抽象**：TtsService 接口在 domain 层；iOS 实现走 AVSpeechSynthesizer（MethodChannel），Android/其他走 flutter_tts
- **i18n 一致性**：所有设置项 key 必须在 `lib/l10n/app_*.arb` 双语完整
- **危险操作二次确认**：清空缓存、删除数据等带 destructive 警示

## 维护要点

- 新增设置项：先在 `arb` 文件加 key → `SettingsController` 加字段 → 设置 UI 渲染
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
- 2026-06：调试面板（debug only）
