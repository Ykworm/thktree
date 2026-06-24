# War Stories — 踩坑记录

> 记录项目开发过程中**已解决**的技术问题。  
> 与 [TECH-DEBT.md](../TECH-DEBT.md) 的区别：TECH-DEBT 记"待解决"，这里记"已踩过并解决"。

## 目录结构

```
docs/war-stories/
├── README.md          # 本文件：使用规范 + 索引
├── flutter/           # Flutter 框架层问题（Dart、Widget、状态管理等）
├── ios/               # iOS 原生层问题（Swift、Xcode、桥接等）
├── android/           # Android 原生层问题（Kotlin、Gradle等）
├── packages/          # 第三方依赖包问题
├── build/             # 构建、编译、CI/CD 问题
├── performance/       # 性能优化相关
└── ui-ux/             # UI/交互、设计实现问题
```

## 文件命名规范

```
YYYY-MM-DD-简短问题描述.md
```

示例：
- `2026-06-17-tts-plugin-not-found-in-xcode.md`
- `2026-06-15-keychain-fail-on-real-device.md`

## 单篇格式模板

```markdown
# 问题标题（一句话描述）

**日期**：2026-06-17  
**模块**：settings / TTS  
**标签**：iOS, Swift, 编译错误, 桥接

## 现象

报错信息、异常行为、用户反馈等。

## 根因分析

为什么发生？涉及哪些代码/配置？

## 解决方案

1. 步骤一
2. 步骤二

## 关键代码/配置

```dart
// 或 swift / gradle / yaml 等
```

## 相关文件

- `ios/Runner/TtsPlugin.swift`
- `ios/Runner.xcodeproj/project.pbxproj`

## 参考链接

- [DECISIONS.md ADR-XXX](../DECISIONS.md)
- [TECH-DEBT #3](../TECH-DEBT.md)
- 外部资料：Apple Developer Documentation / Stack Overflow 等

## 复盘

- 为什么一开始没发现？
- 以后如何避免同类问题？
```

## 维护约定

- **新建**：解决问题后 24h 内补充记录，趁记忆新鲜。
- **更新**：发现之前的记录有误或方案有更新，直接修改原文件，在末尾加 **更新日志** 段。
- **AI 维护时机**：当 AI 协助排查并解决一个需要排查才能定位、且有复盘价值的技术问题时，主动询问用户是否需要登记为 war story。
- **ctsync 候选机制**：当 `ctsync` 识别到"已解决、需要排查才能定位、且有复盘价值的技术问题"时，应先将对应 war-story 列入影响清单，待用户确认后再新增或更新文档。
- **不写 diff 块**：具体代码改动用 git diff 查看，文档里只写关键片段和思路。

## 索引（按时间倒序）

### 2026-06

- `flutter/2026-06-24-integration-test-keychain-state-leak.md` — ProviderScope override + flutter_secure_storage Keychain 状态泄漏（3 个根因叠加：ProviderScope override 残留 + Keychain 内存缓存 + ChatController.isStreaming 状态残留；用 Navigator.of(element).pop 模拟点击 + ValueKey 改 providerId_modelId 稳定 key）
- `ui-ux/2026-06-22-sqlite-nested-transaction-crash.md` — SQLite 嵌套事务崩溃（getSessionPathForNode 全量 reindex 并发冲突，disk-first + 启动同步替代）
- `ui-ux/2026-06-20-chat-controller-stop-button-stuck.md` — ChatController stop_button 卡死（fire-and-forget 错误日志 + `_handle` 时序自愈）
- `ui-ux/2026-06-18-gptmarkdown-latex-renderline-overflow.md` — GptMarkdown LaTeX 公式 RenderLine 溢出（flutter_math_fork 0.7.4 宽度计算偏短，FittedBox 兜底）
- `build/2026-06-18-rum-initialize-blocks-runapp.md` — AlibabaCloudRUM initialize 阻塞 runApp 导致黑屏
- `build/2026-06-18-log-url-duplicate-define.md` — THKTREE_LOG_URL 重复定义 + String.fromEnvironment 编译期陷阱
- `ui-ux/2026-06-18-tts-noop-on-android.md` — Android 上 TTS 按钮可点击但无声音（NoOpTtsService 静默桩）
- `flutter/2026-06-17-riverpod-notifier-uninitialized-state.md` — Riverpod Notifier 构造函数访问 state 导致异常
- `ios/2026-06-17-tts-plugin-xcode-compilation.md` — 自定义 Swift 插件未被 Xcode 编译识别
- `packages/2026-06-15-secure-storage-keychain-accessibility.md` — flutter_secure_storage iOS 真机保存失败
- `ui-ux/2026-06-17-gptmarkdown-heading-style-in-cupertino.md` — GptMarkdown 标题样式在 CupertinoApp 中失效
- `ui-ux/2026-06-06-swipeable-row-overflow.md` — 左滑删除按钮宽度无限增加

### 2026-05

- `flutter/2026-05-27-note-list-refresh-unstable.md` — 笔记列表刷新机制不稳定

---

> 新增记录后，请同步更新本索引。
