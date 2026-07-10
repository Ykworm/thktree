# 聊天页面包屑导航（Chat Breadcrumb）

> ⚠️ **AI 改此功能前必读**
> 1. 聊天页位于 go_router 的 `StatefulShellBranch`（themes 分支）内，**栈由 go_router 管理**。面包屑回跳必须用 `GoRouter.go(path)` 声明式导航，绝不能用 `Navigator.popUntil`——会把 go_router 的 route match list 摘空、崩 "You have popped the last page off of the stack"。
> 2. 当前节点标签**永远用磁盘真实 `NodeEntity.title`**，不要用 `widget.title`——面包屑 `go()` 回跳时不传 `extra`，router 会把 `widget.title` 回退成 `'$themeId/$nodeId'`，暴露内部 ID。
> 3. `initState` / `dispose` 内**禁止同步写 Riverpod provider**（见下方「生命周期约束」）。

## 背景与动机

节点深埋在主题树里，导航栏只显示当前节点标题，用户不知道自己现在处于第几层、上面是谁。
主题详情页（tree 页）是整棵树平铺、无"当前层级"，面包屑在那里只是 `主题/主题名` 重复导航栏，**无意义**。

因此面包屑只放在**聊天页**：沿 `parentId` 回溯祖先链，显示
`主题 / 主题名 / 祖先1 / … / 当前节点`，点任意祖先段可跳回。

## 结构

```
[主题]  →  tab 根（themes-list）           goPath: '/'
[主题名] →  主题树详情页（theme-tree）       goPath: '/themes/:themeId/tree'
[祖先1] →  祖先节点聊天页（chat-ancestor）  goPath: '/themes/:themeId/nodes/:ancestorId'
…
[当前节点] → 当前聊天页，末段不可点
```

- 顺序：主题(tab) → 主题树 → 各级祖先节点（root→parent 正序，靠 `chain.reversed` 实现）→ 当前节点（末段不可点）。
- 每段 `BreadcrumbSegment` 带 `goPath`，由通用组件 `ThkBreadcrumbRow` 渲染（分隔符 `/`，末段加深加粗、不可点）。
- 空态（节点尚未加载 / 未找到）：`ThkBreadcrumbRow` 自动渲染 `SizedBox.shrink()`，不占空间。

## 数据来源

`_buildCrumbs(l10n, nodes, themeTitle)` 在 `chat_screen.dart` 的 `build` 内调用：

- `nodes` 来自 `ref.watch(themeDetailControllerProvider(themeId)).nodes`（主题下全量节点）。
- 用 `widget.nodeId` 找到 `current`，沿 `parentId` 回溯到 root，收集祖先链。
- `themeTitle` 来自 `localizedThemeTitle(l10n, data.themeTitle)`（未分类主题映射为 `l10n.uncategorized`）。

## 回跳机制

- **go_router 路由**（聊天页在 themes 分支内）：`ThkBreadcrumbRow._popToRoute` 检测 `segment.goPath != null` → `GoRouter.of(context).go(goPath)`，让 go_router 自己重建分支栈。
- **普通 Navigator 路由**（settings / llm 子页那套，不在 router.dart 里、用 `Navigator.push` 压栈）：保留 `popUntil(RouteSettings.name)` 精确匹配。两套互不干扰。
- router.dart 已给 themes 分支对应 `CupertinoPage` 设 `name`（`themes-list` / `theme-tree-$themeId` / `chat-$nodeId`），但**聊天页面包屑实际走 `goPath` 而非 name 匹配**。

## 防御：跳过内部 ID

某些节点 `title` 可能回退成 ULID（创建时未命名），或回退值（`widget.title`）是 `$themeId/$nodeId`。面包屑不能暴露这些内部标识：

- `_looksLikeRawId(s)`：以 `thm_` / `nd_` / `nt_` / `msg_` 前缀开头的字符串判为原始 ID。
- 祖先链循环：title 像 ID → `continue` 跳过该段。
- 当前节点：`_displayedTitle ?? current!.title`，若仍像 ID → 显示 `l10n.noTitle`（"无标题"）。
- 注意：**不要**用 `s.contains('/')` 当 ID 判据——会误杀含 `/` 的合法标题，且 `$themeId/$nodeId` 的问题应通过"优先用 `current!.title`"从根上规避，而非靠字符串检测。

## 生命周期约束（崩溃坑）

聊天页挂载时向全局 `branchFromSelectionProvider` 注册"从选区分支"回调，卸载时清空。原本在 `initState` / `dispose` 内**同步**写 provider，触发两个 Riverpod 断言崩溃：

1. **initState**：`Tried to modify a provider while the widget tree was building`
   → 写入延迟到 `WidgetsBinding.instance.addPostFrameCallback`（首帧构建完成之后）。
2. **dispose**：`_debugCanModifyProviders`（树 finalize 期同样在断言窗口内，"缓存 notifier 引用"没用——断言看的是"是否在构建/finalize 期"不是"是否用 ref"）
   → 清空延迟到 `Future.microtask`（脱离 finalize 期）+ 闭包引用守卫（只清自己设的值）。

详见 war-story：[2026-07-09-chat-breadcrumb-nav-crashes.md](../../war-stories/flutter/2026-07-09-chat-breadcrumb-nav-crashes.md)。

## 涉及文件

| 文件 | 改动 |
|------|------|
| `lib/ui/core/widgets/thk_breadcrumb_nav.dart` | `BreadcrumbSegment` 加 `goPath`；`_popToRoute` 按 `goPath` 走 `GoRouter.go()` / 否则 `popUntil` |
| `lib/ui/core/router.dart` | themes 分支 `/` 设 `name: 'themes-list'`；`/themes/:id/tree` 设 `name: 'theme-tree-$id'`；`/themes/:id/nodes/:nodeId` 设 `name: 'chat-$nodeId'` |
| `lib/ui/features/chat/chat_screen.dart` | `build` 内 watch `themeDetailControllerProvider` → `_buildCrumbs`；`_buildCrumbs` 构造祖先链 + ID 防御；initState/dispose 的 provider 写延迟 |
| `integration_test/chat_breadcrumb_test.dart` | 回归测试：进聊天页不崩 + 面包屑渲染 + 逐段点击回跳正确 + 全程无 provider/go_router 崩溃 |

## 相关历史

- 2026-07-09：面包屑功能落地聊天页，修 4 个运行时崩溃（initState 改 provider / dispose 改 provider / go_router 栈摘空 / 暴露内部 ID）。详见 war-story + CHANGELOG。
