# War Stories — 踩坑记录

> 记录项目开发过程中**已解决**的技术问题。 
> 与 [TECH-DEBT.md](../TECH-DEBT.md) 的区别：TECH-DEBT 记"待解决"，这里记"已踩过并解决"。

## 目录结构

```
docs/war-stories/
├── README.md # 本文件：使用规范 + 索引
├── flutter/ # Flutter 框架层问题（Dart、Widget、状态管理等）
├── ios/ # iOS 原生层问题（Swift、Xcode、桥接等）
├── android/ # Android 原生层问题（Kotlin、Gradle等）
├── packages/ # 第三方依赖包问题
├── build/ # 构建、编译、CI/CD 问题
├── performance/ # 性能优化相关
└── ui-ux/ # UI/交互、设计实现问题
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
- **FTS5 反模式警示**：⚠️ 禁止在 SQLite FTS5 虚拟表上使用 `ConflictAlgorithm.replace` 进行 upsert——FTS5 不支持主键/UNIQUE，该调用会**静默失效**（不抛错不替换只多一行），导致搜索结果累加重复。正确做法：`db.transaction` 包裹 `DELETE + INSERT`，或查询侧用 `GROUP BY entityType, entityId` 聚合去重。详见 [packages/2026-06-29-fts5-conflict-replace-silent.md](packages/2026-06-29-fts5-conflict-replace-silent.md)、[`../_shared/edge-cases-backlog.md` EC-043](../_shared/edge-cases-backlog.md#ec-043-搜索结果重复fts5-无主键--upsert-累加--已修复2026-06-29)。

## 索引（按时间倒序）

### 2026-07

- `ui-ux/2026-07-09-search-tag-cloud-no-trigger.md` — Tag cloud 点击不触发搜索（ValueNotifier 只在值变化时触发 listener，不触发初始值；动态创建的 SearchResults widget 在 initState 中未处理初始值；initState 检查并处理）
- `flutter/2026-07-09-chat-breadcrumb-nav-crashes.md` — 聊天页面包屑导航三连崩溃：①initState 同步改 provider（`addPostFrameCallback` 延迟）②dispose finalize 期改 provider（"缓存 notifier 引用"没用，需 `Future.microtask` 延迟）③go_router 路由误用 `popUntil` 摘空栈（改 `GoRouter.go(path)`）；连带修复 `go()` 不传 extra 导致 `widget.title` 回退 `$id/$id` 暴露内部 ULID
- `flutter/2026-07-09-chat-selection-residual-branch-preview.md` — 复制/选区文本在「创建分支」预览残留（选中→复制/放入抽屉→分支仍预览旧文本；`currentSelectionProvider` 故意保留上次选区以支持"选中→分享为图片"，消费后未清导致残留；新增选区工具栏「分支」按钮读 `branchFromSelectionProvider` 从活跃选区即时分支 + 复制/分支/放入抽屉消费即清 `currentSelectionProvider`；「更多→分支」改传 `selectedText:null`；initState/dispose 写 provider 复用面包屑崩溃的 `addPostFrameCallback`/`Future.microtask` 延迟修法）
- `packages/2026-07-09-fts5-cjk-tokenization.md` — FTS5 CJK 分词导致子串搜索失败（unicode61 将连续 CJK 视为一个 token；新增 _tokenizeCjk 逐字分词 + _cleanSnippet 清理 + v6 迁移触发索引重建）
- `flutter/2026-07-08-titlebar-model-mismatch-dual-fallback.md` — Title bar 显示模型与实际调用不一致（显示侧 resolveChatModel 4 级 vs 调用侧内嵌 2 级 fallback，优先级缺失 + 兜底条件不同 + 异步竞态；空白分支 100% 命中；统一为 _resolveChatModelForLlm 复用 1-3 级 + 自行第 4 级查 apiKey；详见 ADR-026）
- `flutter/2026-07-08-nested-selectionarea-branch-preview.md` — 嵌套 SelectionArea 导致外层 onSelectionChanged 收不到选区（chat 选文字→分支预览消失；GptMarkdown 不可选被迫内层自包 SelectionArea，外层感知不到子选区；用共享 NotifierProvider + 顶层 `syncSelection(context,v)` 从内层透出；顺带踩 riverpod 3.0 移除 StateProvider）

### 2026-06

- `packages/2026-06-29-fts5-conflict-replace-silent.md` — FTS5 虚拟表上 `ConflictAlgorithm.replace` 静默失效（不抛错不替换只多一行；用 `db.transaction` 包裹 DELETE+INSERT + 扁平查询组合方案 A+B；下游 commit `cb9891f` 补强：方案 B 子查询+GROUP BY 在 iOS SQLite 报 `unable to use function X` 失败，重写为扁平查询 + `col=5`（content 列），`upsertMessage` 同款 bug 同步修复）
- `flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md` — AsyncNotifier autoDispose 在 widget unmount 时取消 in-flight Future（ref.keepAlive() 修复，空白分支 title 持久化场景；详见 ADR-018 + war-story）
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
