# Riverpod autoDispose + AsyncNotifier 在 widget unmount 时取消 in-flight Future

**日期**：2026-06-29
**模块**：chat / 自动 title 持久化
**标签**：Flutter, Riverpod, AsyncNotifier, autoDispose, ref.keepAlive, 后台任务

---

## 现象

用户报告 Bug：在"空白分支"模式下创建新对话 → chat_screen 内发消息 → LLM 流式回复 → 用户在 nav bar 标题未更新前（此时 LLM 回复已完、AutoTitleController 正在跑标题生成）点 back 返回 tree 页 →

- ❌ tree 中该 node 的标题仍是占位"临时会话"
- ❌ 用户再次进入该 chat_screen，nav bar 标题还是"临时会话"
- ❌ 用户点 theme 内"刷新"按钮也没刷到新 title（**DB 写可能未完成或 tree controller 缓存未失效**）

复现窗口极窄：用户必须在 LLM 回复结束后立刻（1-2s 内）pop，否则任务已跑完正常落库。普通 QA 难以稳定命中，集成测试也走了"等任务完成再断言"路径，没覆盖提前 pop 场景。

---

## 根因分析

`AutoTitleController` 用 `AsyncNotifierProvider.autoDispose.family<AutoTitleController, AutoTitleState, String>` 声明，**autoDispose 触发条件是"无 listener 引用"**——不是"页面 pop"或"widget dispose"。

但 chat_screen 与 tree page 的关系是 push/pop：

1. 用户在 tree page（保留 listener on `themeDetailControllerProvider`，但**不**保留 `autoTitleControllerProvider` 的 listener——它是 family，实例按需创建）
2. 点 node → push chat_screen → chat_screen 内 `ref.listen<AutoTitleState>(autoTitleControllerProvider(nodeId), ...)` → **首次**为该 nodeId 创建 Notifier 实例 + 加 listener
3. 流式结束 → `runIfNeeded` 触发 → 任务进入 LLM HTTP 请求 + 指数退避重试循环
4. 用户点 back → pop chat_screen → `autoTitleControllerProvider` 的 listener 归零 → **autoDispose 触发 → AsyncNotifier 被 dispose → 内部 Future 链被中断**

被中断的内容包括：
- 还未完成的 LLM HTTP 请求
- 已成功但未写的 `nodeStore.updateNodeTitle`
- 已完成但未触发的 `themeDetailController.refresh()`

结果完全看时序：

- **运气好**（用户在流式结束 30s 后才 pop）：LLM 已返回 + DB 写完 + tree refresh 完成 → 仅 UI 偶尔闪一下 → 用户感知不到
- **运气差**（流式结束 1-2s 后立刻 pop）：任务刚启动 → dispose 取消 → DB 完全没写 → tree 显示占位 title → 用户再次进入看到占位 title → 看起来"没持久化"

更隐蔽的：DB 写实际**成功**的情况下（AsyncNotifier dispose 时 Future 已被 cancel 但 SQLite 事务可能已 commit），tree controller 缓存也未刷新 → UI 显示旧占位。用户点"刷新"按钮能恢复，但普通用户不会想到。

---

## 解决方案

在 `AsyncNotifier.build()` 内显式调用 `ref.keepAlive()`：

```dart
@override
Future<AutoTitleState> build() async {
  // keepAlive：任务与 widget 完全解耦，chat_screen dispose 不影响 Notifier
  ref.keepAlive();
  return AutoTitleState.initial;
}
```

**`ref.keepAlive()` 的语义**（Riverpod 3.x）：

- 标记当前 Notifier 为"我自己负责保活"，不再受"无 listener 触发 dispose"规则影响
- Notifier 实例**永不被自动 dispose**，只能通过显式 `container.invalidate(provider)` 清理
- 调用时机：必须在 `build()` 内调用，且每次 `build()`（family 参数变化触发实例重建）都要重新声明——`keepAlive()` 是**单次 build 范围**的状态，跨实例不继承

**为何用双标记范式（autoDispose 保留 + build 内 keepAlive）而不是去掉 autoDispose**：

- 业务场景里**绝大多数** Notifier 是"按需保活"（UI 同步层、树形 data controller）—— autoDispose 合适，去掉会造成所有 family 成员常驻
- 像 AutoTitleController 这种"后台任务执行器"——**必须** keepAlive
- Provider 定义**保留** `.autoDispose` 是为了**未来加新 Notifier 时不用每次想"要不要去掉 autoDispose"**，对所有 family provider 默认安全，keepAlive 由具体 Notifier 自己声明

---

## 关键代码

```dart
// lib/ui/features/chat/auto_title_controller.dart
final autoTitleControllerProvider =
    AsyncNotifierProvider.autoDispose.family<AutoTitleController, AutoTitleState, String>(
  AutoTitleController.new,
);

@override
Future<AutoTitleState> build() async {
  ref.keepAlive();  // ← 关键：标记 Notifier 永不自动 dispose
  return AutoTitleState.initial;
}
```

---

## 相关文件

- `lib/ui/features/chat/auto_title_controller.dart` — 新增 `ref.keepAlive()` + § 5 文档说明
- `lib/ui/features/chat/chat_screen.dart:165-176` — chat_screen 与 tree 的 push/pop 关系
- `lib/ui/features/chat/chat_screen.dart:480-560` — 旧 `_triggerBlankAutoTitle`（删除，迁到 Notifier）
- `lib/ui/features/themes/theme_detail_controller.dart` — tree controller（autoDispose，按需 reload，与本 Notifier 不同的设计）

---

## 参考链接

- [DECISIONS.md ADR-018](../DECISIONS.md) — autoDispose + build() 内 ref.keepAlive() 双标记范式
- [TECH-DEBT.md](../TECH-DEBT.md) — keepAlive 内存常驻风险（待 keepAlive 任务累计超 1000 再 review）
- [CHANGELOG/2026-06-29-auto-title-persistence.md](../CHANGELOG/2026-06-29-auto-title-persistence.md) — 本次 Bug 修复 changelog
- [Riverpod 官方文档 - keepAlive](https://riverpod.dev/docs/concepts/combining_providers#keep-alive)

---

## 复盘

### 为什么一开始没发现？

1. **复现窗口极窄**——用户必须在 LLM 回复结束后 1-2s 内立刻 pop。普通 QA 难以稳定命中。
2. **集成测试走了"等任务完成再断言"路径**——`pumpAndSettleWithTimeout(timeout: 60s)` 等任务完成，**没有**覆盖提前 pop 场景。case 9.6 就是为此新增的。
3. **DB 写的不确定性**——SQLite 事务在 Future cancel 时是否已 commit 看时序，所以"运气好时一切正常"掩盖了问题。
4. **autoDispose 的语义理解偏差**——直觉以为"页面 pop 才触发 autoDispose"，实际是"listener 归零"——而 chat_screen 的 listen 在 widget 卸载时同步归零，效果接近但**不等价于** widget dispose。

### 以后如何避免同类问题？

1. **任何"后台任务型" Notifier**（任务跑完才结束、与 widget 生命周期无关）**必须**加 `ref.keepAlive()`——把"双标记范式"作为 chat 模块的强约束
2. **集成测试新增"提前 pop 等后台任务跑完"模式**——参 case 9.5 / 9.6（[branch-creation.md § 5.12/5.13](../_shared/integration-testing/branch-creation.md)），必须存在
3. **模块 README 显式提醒**——在 `lib/ui/features/chat/README.md`"AI 改模块前必读"加了 § 6：所有 AutoTitleController 相关改动必须确认 keepAlive 是否仍适用
4. **code review 检查清单**——任何 `AsyncNotifierProvider.autoDispose.family` 的 `build()` 没调 `ref.keepAlive()` 需评估"是不是后台任务型"，是的话必须加