## ADR-003: UI 框架纯 Cupertino

iOS-first 项目的硬性决定。ThkTree 是为 iPhone 设计的笔记/聊天 app，目标用户群就是 iOS 用户；引入 Material 组件会让 Cupertino 用户感到违和（涟漪/elevation/dialog 都跟 Apple HIG 反着来）。代价是 Android 端体验打折——但 MVP 阶段就只保证 iOS（参见 PROJECT.md "目标平台"）。影响范围：`lib/ui/core/widgets/` 下所有基础组件必须用 `Cupertino*` 前缀；不允许出现 `Scaffold` / `AppBar` / `ElevatedButton` 等 Material 组件。实施要点：跨平台库（flutter_tts / image_picker 等）默认走 Cupertino 风格 wrapper。
