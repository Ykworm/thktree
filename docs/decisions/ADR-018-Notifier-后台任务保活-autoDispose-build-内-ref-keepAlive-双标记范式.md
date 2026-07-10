## ADR-018: Notifier 后台任务保活——autoDispose + build() 内 ref.keepAlive() 双标记范式

2026-06-29 决定。Riverpod 3.x 中 `AsyncNotifierProvider.autoDispose.family` 的「autoDispose」触发条件是"无 listener 引用"，与 widget 生命周期无直接绑定，但与"widget push/pop 后的 listener 归零时点"高度耦合。本决策确立**有后台任务的 Notifier** 必须配合 `ref.keepAlive()` 的双标记范式。

背景：用户报告 [空白分支自动 title 持久化 Bug](CHANGELOG/2026-06-29-auto-title-persistence.md)——chat_screen 内流式结束后用户立刻 pop 回 tree，后台 title 生成任务在 `chat_screen` unmount 时被取消（autoDispose → AsyncNotifier dispose → in-flight Future 中断），DB 写与 tree 刷新未完成 → 用户再次进入看到占位"临时会话" title。详细排查见 [war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md](war-stories/flutter/2026-06-29-riverpod-autodispose-cancels-async-future.md)。

决策：**autoDispose 仍保留 + 需要保活的 Notifier 在 `build()` 内显式 `ref.keepAlive()`**——双标记范式。

- `autoDispose` 保留：业务场景里绝大多数 Notifier（UI 同步层、树形 data controller）按需保活更合适，避免内存常驻；不在 Provider 定义层一刀切去掉 autoDispose。
- `build()` 内 `ref.keepAlive()` 显式声明"我自己负责保活"：覆盖 autoDispose 的"无 listener 触发 dispose"规则；Notifier 实例**永不被自动 dispose**，只能通过显式 `container.invalidate(provider)` 清理。
- 调用时机：必须在 `build()` 内调用，且每次 `build()`（family 参数变化触发重建）都要重新声明——`keepAlive()` 是**单次 build 范围**的状态。

适用范围：

- ✅ **后台任务型 Notifier**——任务跑完才结束、与 widget 生命周期无关、需在 widget unmount 后继续执行（典型场景：AutoTitleController、LlmTaskRunner）。
- ❌ **UI 同步层 Notifier**——监听 source-of-truth 后同步给 widget，widget unmount 后无意义（典型场景：ThemeDetailController 树形 data controller、ChatController 流式状态）。
- ❌ **派生/计算型 Notifier**——纯函数计算，autoDispose 触发后下次 listener 来临时重建开销小（典型场景：filter 列表、search 结果）。

代价：每个 `keepAlive()` 的 Notifier 实例常驻内存（实测 ~100B/instance），直到 `container.invalidate(provider)` 显式清理。当前项目估算：每个 chat nodeId 一次任务完成后保留 AutoTitleController 实例 → 单次会话 1-2 个实例 → 完全可接受。**待 keepAlive 任务累计超 1000 个再 review 是否引入 WeakReference + 定时清理**，见 [TECH-DEBT.md](TECH-DEBT.md) `autoTitleControllerProvider 内存常驻`。

实施要点：

1. Provider 定义**必须**保留 `.autoDispose`（即使后续 keepAlive），便于其他 family 成员无 keepAlive 需求时仍受 autoDispose 保护。
2. `ref.keepAlive()` 在 `build()` 内**首行**调用，**不要**在 `runIfNeeded` / 其他方法内调用——keepAlive 标记只在 build 阶段生效。
3. family 参数变化（`nodeId` 切换）时 Notifier 实例重建，新实例的 `build()` 会重新跑 keepAlive，无需手动迁移。
4. 集成测试新增"提前 pop + 等后台任务跑完"模式（参 [branch-creation.md § 5.12/5.13](_shared/integration-testing/branch-creation.md) case 9.5/9.6）——验证 widget unmount 后任务继续跑、最终 UI 看到正确结果。

放弃的方案：A 全部去掉 autoDispose——内存常驻所有 family 成员，即使任务已完成；B 用全局 container 引用手动管理生命周期——绕开 Riverpod 范式、引入显式清理遗漏风险；C 用 `Timer` 延迟触发——丢失 Notifier 的 listen/state 优势。
