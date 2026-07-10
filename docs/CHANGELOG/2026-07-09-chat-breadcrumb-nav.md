# 聊天页祖先链面包屑（含 4 个运行时崩溃修复）

> 日期：2026-07-09

## 背景

节点深埋在主题树里，导航栏只显示当前节点标题，用户不知道自己处于第几层、上面是谁。
主题详情页（tree 页）是整棵树平铺、无"当前层级"，面包屑无意义——故面包屑只放在**聊天页**。

## 方案

聊天页消息列表顶部加面包屑：`主题 / 主题名 / 祖先1 / … / 当前节点`，沿 `parentId` 回溯
（`_buildCrumbs` 读 `themeDetailControllerProvider(themeId).nodes`）。点任意祖先段跳回对应层。

## 改动

- **新建** `lib/ui/core/widgets/thk_breadcrumb_nav.dart`：`BreadcrumbSegment` 加可选 `goPath`；`_popToRoute` 检测 `goPath != null` → `GoRouter.of(context).go(goPath)` 声明式回跳，否则保留 `popUntil(RouteSettings.name)`（settings/llm 那套普通 Navigator 路由用）
- **修改** `lib/ui/core/router.dart`：themes 分支 `/` 设 `name: 'themes-list'`；`/themes/:id/tree` 设 `name: 'theme-tree-$id'`；`/themes/:id/nodes/:nodeId` 设 `name: 'chat-$nodeId'`
- **修改** `lib/ui/features/chat/chat_screen.dart`：
  - `build` 内 `ref.watch(themeDetailControllerProvider)` → `_buildCrumbs`
  - `_buildCrumbs` 构造祖先链；当前节点优先用 `current!.title`（磁盘真实数据），不碰 `widget.title`
  - ID 防御：`_looksLikeRawId` 只匹配 `thm_`/`nd_`/`nt_`/`msg_` 前缀（去掉 `s.contains('/')` 误杀）；祖先链跳过 ID 段、当前节点回退 `l10n.noTitle`
  - `initState` 写 provider 延迟到 `addPostFrameCallback`；`dispose` 清空延迟到 `Future.microtask` + 闭包守卫
- **新建** `integration_test/chat_breadcrumb_test.dart`：进聊天页不崩 + 面包屑渲染 + 逐段点击回跳正确 + 全程无 provider/go_router 崩溃

## 四个崩溃修复

| # | 现象 | 根因 | 修复 |
|---|------|------|------|
| 1 | 进聊天页崩 `Tried to modify a provider while building` | `initState` 同步写 provider | `addPostFrameCallback` 延迟写入 |
| 2 | 点面包屑崩 `popped the last page off of the stack` | 聊天页在 go_router `StatefulShellBranch`，`popUntil` 摘空 go_router 栈 | `goPath` + `GoRouter.go()` 声明式回跳 |
| 3 | 点面包屑后 dispose 又崩（同类型断言） | `dispose` finalize 期同步改 provider；"缓存 notifier 引用"没用（断言看时期不看 ref） | `Future.microtask` 延迟 + 闭包守卫只清自己设的值 |
| 4 | 点面包屑跳过去后当前节点变"无标题"/暴露 `thm_/nd_` ID | `go()` 不传 extra → `widget.title` 回退 `$themeId/$nodeId` | 当前节点用 `current!.title`；去掉 `/` 误检 |

## 验收

`integration_test/chat_breadcrumb_test.dart`（纯导航、不依赖 LLM，iPhone 17 Pro simulator）：
`+1: All tests passed!`

## 相关

- spec：[docs/modules/chat/specs/chat-breadcrumb-nav.md](../../modules/chat/specs/chat-breadcrumb-nav.md)
- war-story：[docs/war-stories/flutter/2026-07-09-chat-breadcrumb-nav-crashes.md](../../war-stories/flutter/2026-07-09-chat-breadcrumb-nav-crashes.md)
