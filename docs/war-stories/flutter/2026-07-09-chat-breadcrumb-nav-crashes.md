# 聊天页面包屑导航的三个运行时崩溃

**日期**：2026-07-09  
**模块**：chat / 导航（go_router）/ Riverpod 生命周期  
**标签**：go_router, StatefulShellBranch, Riverpod, initState, dispose, 断言崩溃, 面包屑

## 现象

给聊天页加祖先链面包屑后，连续撞三个运行时断言崩溃：

1. **进聊天页即崩**：
   ```
   Tried to modify a provider while the widget tree was building
   #10 _ChatScreenState.initState (chat_screen.dart:109)
   ```
2. **点面包屑回跳后崩**（导航离开聊天页触发 dispose 才暴露）：
   ```
   You have popped the last page off of the stack
   'package:go_router/src/delegate.dart': Failed assertion: line 175 pos 7: 'currentConfiguration.isNotEmpty'
   #8 ThkBreadcrumbRow._popToRoute (thk_breadcrumb_nav.dart:98)
   ```
3. **点面包屑后 dispose 又崩**（修完 2 才浮出来）：
   ```
   Tried to modify a provider while the widget tree was building
   #10 _ChatScreenState.dispose (chat_screen.dart:137)
   ```
   以及 `Bad state: Using "ref" when a widget ... has been unmounted is unsafe`。

## 根因分析

### 崩溃 1：initState 构建期改 provider

`initState` 里直接 `ref.read(branchFromSelectionProvider.notifier).state = ...`。
Riverpod 在 widget 树构建期开启 `_debugCanModifyProviders` 断言，此时任何 provider 写入都被拦截。
**为什么现在才暴露**：加面包屑后 `build` 里 `ref.watch(themeDetailControllerProvider)` 引发同帧 rebuild 链，把这个原本偶发的坑稳定复现。

### 崩溃 2：go_router 管理的路由误用 popUntil

面包屑原实现用 `Navigator.of(context).popUntil((route) => route.settings.name == ...)` 按 `RouteSettings.name` 回跳。
但聊天页位于 go_router 的 `StatefulShellBranch`（themes 分支），**栈由 go_router 自己管理**。
`popUntil` 一把把多个路由弹掉，go_router 内部的 route match list 被摘空 → 断言 `currentConfiguration.isNotEmpty`。
对照：settings / llm 那套面包屑能用 `popUntil`，是因为它们是用普通 `Navigator.push` 压的（不在 router.dart 里），go_router 不管它们的栈。

### 崩溃 3：dispose finalize 期改 provider（"缓存 notifier 引用"是假修复）

第一版把 dispose 改成"缓存 notifier 引用到 State 字段、dispose 里用 `_branchNotifier?.state = null`"——**没用**。
断言 `_debugCanModifyProviders` 在 `dispose` / `unmount`（树 finalize 阶段）仍开着，看的是"是否在构建/finalize 期"，不是"是否用 ref"。缓存引用照样是同步改 provider，照样炸。
**为什么第一轮测试没抓到**：那版测试只"打开聊天页、没点面包屑、没导航离开"，dispose 根本没被触发。

## 解决方案

### 1. initState 写入延迟到首帧后

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  final cb = (text) => unawaited(_branchFromSelection(context, text));
  _branchCallback = cb;
  _branchNotifier?.state = cb;
});
```

### 2. go_router 路由走声明式导航

`BreadcrumbSegment` 加可选 `goPath`；`_popToRoute` 检测 `goPath != null` → `GoRouter.of(context).go(goPath)` 让 go_router 自己重建分支栈：

```dart
void _popToRoute(BuildContext context, BreadcrumbSegment segment) {
  final goPath = segment.goPath;
  if (goPath != null) {
    GoRouter.of(context).go(goPath); // go_router 路由：声明式回跳
    return;
  }
  // 普通 Navigator 路由（settings/llm 子页）：保留 popUntil
  Navigator.of(context).popUntil((route) => route.settings.name == segment.routeName);
}
```

聊天页每段 crumb 都填 `goPath`（`/`、`/themes/:id/tree`、`/themes/:id/nodes/:nid`），不再走 `popUntil`。

### 3. dispose 清空延迟到 microtask + 闭包守卫

```dart
@override
void dispose() {
  final notifier = _branchNotifier;
  final cb = _branchCallback;
  Future.microtask(() {
    if (notifier?.state == cb) notifier?.state = null; // 只清自己设的值
  });
  super.dispose();
}
```

### 4.（连带）面包屑暴露内部 ULID

点面包屑跳转后，目标页面包屑末尾显示"无标题"、甚至直接显示 `thm_/nd_` 原始 ID。
根因：面包屑 `go(path)` **不传 `extra`** → router 回退 `widget.title = '$themeId/$nodeId'`（含 `/`）。
修复：当前节点标签**优先用 `current!.title`**（磁盘真实数据），不碰 `widget.title`；`_looksLikeRawId` 只匹配 ULID 前缀（`thm_`/`nd_`/`nt_`/`msg_`），**去掉 `s.contains('/')`** 这个误杀合法标题的过度检测。

## 关键代码/配置

- `lib/ui/core/widgets/thk_breadcrumb_nav.dart` — `BreadcrumbSegment.goPath` + `_popToRoute` 双分支
- `lib/ui/features/chat/chat_screen.dart` — `initState` postframe 写入 / `dispose` microtask 清空 / `_buildCrumbs` 用 `current!.title`
- `lib/ui/core/router.dart` — themes 分支三个路由设 `name`（给普通路由面包屑用）
- `integration_test/chat_breadcrumb_test.dart` — 回归测试

## 相关文件

- `lib/ui/core/widgets/thk_breadcrumb_nav.dart`
- `lib/ui/features/chat/chat_screen.dart`
- `lib/ui/core/router.dart`
- `lib/ui/core/shared/selection_state.dart`
- `integration_test/chat_breadcrumb_test.dart`

## 验收

`integration_test/chat_breadcrumb_test.dart`（纯导航、不依赖 LLM，iPhone 17 Pro simulator）：
- 进聊天页不崩（initState）
- 面包屑渲染且含主题名
- **逐个点**每段可点面包屑（主题名→主题树、主题→主题列表）回跳正确
- 全程无 provider 构建期错误 / 无 go_router 栈摘空崩溃 / 无 dispose 崩溃

`+1: All tests passed!`

## 复盘

- **go_router 路由绝不能用 `popUntil`**：只要页面在 `StatefulShellBranch` / 任何 go_router 管理的栈里，回跳必须用 `GoRouter.go()` / `context.go()` / `context.pop()`。把"按 RouteSettings.name pop"当成万能回跳是从 settings 子页（普通 Navigator 路由）学来的坏习惯，换到 go_router 路由就炸。
- **`initState` / `dispose` 是 Riverpod 断言雷区**：任何 provider 写入都要移出这两个生命周期回调。`addPostFrameCallback`（构建期后）/ `Future.microtask`（finalize 期后）是标准解法。
- **"缓存 notifier 引用避免 dispose 用 ref"是半对半错**：它解决了 `Bad state: using ref after unmount`，但**没解决** finalize 期改 provider 的断言——断言看"时期"不看"是否用 ref"。真正的解法是延迟执行。
- **测试必须真正触发 dispose**：只"打开页面"的集成测试不会触发 `dispose`，隐藏的 dispose 崩溃永远测不出来。面包屑测试**点了回跳、离开了聊天页**，dispose 才跑——这正是它比第一轮测试多抓出一个崩溃的原因。
- **`go()` 不传 `extra`**：声明式导航会丢掉 router 的 `extra` 参数，目标页的 `widget.title` 等字段会回退到 router 默认值。凡是从"已有数据"（如 `NodeEntity`）能拿到真实值的场景，UI 应优先用数据而非 router extra。
- **ID 过滤别过度**：用 `s.contains('/')` 判 ID 会误杀含 `/` 的合法标题；真问题是数据来源（widget.title 回退值），应从根上改用真实数据（current.title）规避。
