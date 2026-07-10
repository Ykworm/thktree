## ADR-002: 路由方案 go_router

2026-05 决定用 go_router 替代 Navigator 1.0。理由有三：声明式路由表跟 Riverpod 风格统一，deep linking 不用手写 `onGenerateRoute`；嵌套路由天然适合"主题详情 = 树 + 子页面"的层次；`go_router` 8.x 之后支持 type-safe routes，配合 `routeName + args` 让 search 模块能跨模块跳转。影响范围：`lib/main.dart` 的 `MaterialApp.router` 配置 + `lib/ui/core/router/`（如存在）；所有 `Navigator.push/pop` 调用统一改为 `context.go/push`。实施要点：route 名是契约，**改了要在 search 模块 README 同步**（搜索靠 routeName 跳转）。
