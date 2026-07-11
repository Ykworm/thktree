## ADR-028 · Android 端采用 Flutter 同仓库 + 底部导航/导航栏壳

### 背景

ThkTree 当前是 iOS + macOS 双端的 Flutter 应用，design token 已建立 code-first 单一真源
（`app_colors` / `app_spacing` / `app_durations`，由 `scripts/sync-design-tokens.dart`
单向生成 `design-tokens.yaml`，`check_color_tokens.dart` 拦裸色）。`TalkWithClaude/Android-handoff.md`
是一份交接文档，目标是在 Android 上用同一套 token 体系落一个与 macOS 桌面端同一定位的
文档方向应用（跨平台、本地优先）。文档 §4.1 列出 3 个未定前提（项目关系 / 技术栈 / token 策略），
本 ADR 采用 handoff 强烈推荐的默认值拍板，待用户实测后可在 review 阶段推翻。

### 决策

1. **项目关系**：在 ThkTree 同仓库新增 Android target（既有 `android/` 工程已就位），
   不另起仓库、不重写移植。
2. **技术栈**：Flutter（共享 Dart token 真源，token 维护成本最低、视觉 100% 一致）。
3. **token 策略**：完全复用现有 Dart token 真源，**Android 端不新建、不重设计**。
   因 SF Symbols 在 Android 不可用，导航图标改用 Material Icons，但**颜色仍 100% 来自
   `AppColors`**（无裸色）；5 主题色与节点多色作为独立资源保留，不塞进 Material 默认槽位。
4. **UI 壳**：复用 go_router 的 `StatefulShellRoute.indexedStack` 分支状态——
   移动端 Cupertino tab bar 壳之外，新增 `AndroidNavigationShell`（手机底部 `NavigationBar`
   / 平板 `NavigationRail`），分支 navigator 直接作为内容区，`features/` 组件全量复用。
5. **平台约定**（handoff §2.7）：基于 `AppColors` 构造**自定义 Material 3 `ColorScheme`**
   （`primary = accent #3B82F6`，不套用 Material 默认紫、关闭 Monet dynamic color，
   保证品牌一致）；系统深色模式通过 `PlatformDispatcher.instance.platformBrightness`
   联动 `AppColors.setBrightness`（handoff §1.3）；edge-to-edge 用 `SafeArea` 处理状态栏/
   手势条；触摸目标 ≥ 48dp（比通用 token 的 44 更贴合 Android 可达性）。

### 影响

- **依赖**：Android 目标由既有 `android/` 工程支持，无新增原生依赖；Flutter Material
  组件原生可用，无需引入 Detekt/lint 裸色规则（guard 由 `check_color_tokens.dart` 覆盖）。
- **设计语言**：Android 端继承 accent 蓝 + 5 主题色 + 节点多色 + Slate 底座，不做视觉重设计。
- **代码位置**：新增 `lib/ui/platform/android/`（color_scheme / nav_bar / navigation_shell /
  brightness_controller / theme_tile），与 macOS 的 `_DesktopShell` 同模式，互不影响。
- **风险**：内页目前是 Cupertino 组件，在 Android 上视觉偏 iOS 风。本 ADR 只落地导航壳 +
  平台适配层（ColorScheme / 深色联动 / 安全区 / 触摸区），**内页 Material 化列为后续**。
- **guard**：`lib/` 内零裸色，`dart run scripts/check_color_tokens.dart` 通过。

### 实施

- [x] `lib/ui/platform/android/android_color_scheme.dart`：Material 3 ColorScheme 由 AppColors 真源映射（light/dark 双值）。
- [x] `lib/ui/platform/android/android_nav_bar.dart`：表现层 `AndroidNavBar`（手机）/ `AndroidNavRail`（平板）。
- [x] `lib/ui/platform/android/android_navigation_shell.dart`：适配器 + 平板断点 + 系统深色联动分发。
- [x] `lib/ui/platform/android/android_brightness_controller.dart`：系统亮度 → AppColors 联动（可注入来源单测）。
- [x] `lib/ui/platform/android/android_theme_tile.dart`：主题卡片，徽章色来自 `themeTileColorFor`。
- [x] `lib/ui/core/router.dart`：`Platform.isAndroid` → `AndroidNavigationShell` 分发（不碰 iOS/macOS 路径）。
- [x] `test/android/` 单测：token 映射 + light/dark、导航结构/onTap 索引、断点判定、系统深色联动、主题卡片徽章色（全绿，`flutter test` 36 passed）。
- [ ] 用户实测 `flutter run -d android`（第一版交付后）。
- [ ] 后续：内页 Cupertino→Material 适配、动态色开关设置项、权限申请时机（首次用到再请求）、平板 large-screen 细节打磨。
