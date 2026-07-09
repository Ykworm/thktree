# 跨平台方案：ThkTree Android 打通 + 功能对齐

> 阶段：brainstorming 草稿（待用户确认后转 writing-plans）
> 决策已对齐：双端统一 Cupertino / 先打通运行+功能对齐（暂不上架）/ 暂保持本地优先（不同步）

## 1. 方案结论（一句话）

保持现有 Flutter + 纯 Cupertino 底座不变，本轮只做 **「Android 可用性补齐」**：补权限清单、品牌化自适应图标、验证图片/TTS/后台重发在 Android 的等价性，并跑通 Android 集成测试。**架构不动、存储不动、UI 风格不动、不同步、不引入新依赖。**

## 2. 现状盘点（已逐项核实代码）

| 项 | 结论 | 说明 |
|----|------|------|
| 根 Widget | ✅ 已是 `CupertinoApp.router` | Android 原生渲染 Cupertino，零改动 |
| 后台桥接 `BackgroundTaskBridge` | ✅ 已 `if (!Platform.isIOS) return null/false` 守卫 | Android 不调 MethodChannel，不崩 |
| TTS | ✅ 已有 `NoOpTtsService` | Android 静默 no-op，不崩（仅无声） |
| 存储路径 | ✅ 走 `path_provider`（`themesDir` 等） | 平台无关；两层不对称结构（images 扁平 / session.md 嵌套）Android 同样适用 |
| Android 图标 | ⚠️ 已存在但为模板占位 robot，且无 adaptive 前景/背景层 | 非功能阻塞，需品牌化替换 |
| **AndroidManifest 权限** | ❌ **当前 0 条权限声明** | **头号阻塞**：无 INTERNET→LLM 废；无相机/存储→图片废；无生物→local_auth 废 |
| TTS UI | ⚠️ Android 上仍显示入口、点了没声音 | 体验瑕疵，需收口（隐藏/禁用并标注 iOS only） |

## 3. 实施清单（按阻塞优先级）

### A. 阻塞项（不解决 Android 直接废）
- **A1. AndroidManifest.xml 权限补齐**
  - `INTERNET`（LLM 联网必需）
  - `CAMERA`（image_picker 拍照）
  - `READ_MEDIA_IMAGES`（API 33+ 相册）/ `READ_EXTERNAL_STORAGE`（legacy 降级）
  - `USE_BIOMETRIC`（local_auth 生物认证）
  - `ACCESS_NETWORK_STATE`（建议，网络状态判断）
- **A2. 验证 `flutter run`（Android）可编译**
  - `minSdk` 跟随 Flutter（`flutter.minSdkVersion`）；若 image_picker 等要求更高则 bump 到 23（Android 6.0）
  - `targetSdk` / `compileSdk` 跟随 Flutter（`flutter.targetSdkVersion` / `flutter.compileSdkVersion`）

### B. 品牌与体验
- **B1. 自适应图标**：`flutter_launcher_icons` 开 `android: true` + adaptive 配置（foreground=ThkTree logo、background=品牌色），替换占位 robot；生成 `mipmap-anydpi-v26` + 各密度 `ic_launcher`。
- **B2. TTS UI 收口**：Android 上隐藏/禁用 TTS 入口并标注「iOS only」（底层 NoOp 已在跑，仅 UI 收口，无需新逻辑）。
- **B3. 系统 UI 适配**：Android 状态栏/导航栏配色（`SystemChrome`）、确认 `SafeArea` 已包住内容、硬返回键（go_router 已支持 `PopScope`/返回分发）。

### C. 功能等价验证（重点排查）
- **C1. 图片**：确认 `ChatImageService` 在 Android `content://` URI 下能 copy 到 app 私有目录并写入两层不对称结构（images 扁平 / session.md 嵌套）；补 Android 路径的集成测试。
- **C2. 后台重发**：Android 无 `beginBackgroundTask` 兜底，需确认「切回前台 `resumeInterrupted()` + 冷启动扫描（`ChatTaskServiceInitializer`）」已覆盖主场景；标注「退到后台期间中断」为已知限制（后续可选 WorkManager/foreground service 增强，本期不做）。
- **C3. 六模块冒烟**：搜索 / 主题 / 笔记 / Lab / LLM 配置 / 设置 在 Android emulator 逐一点测。

### D. 验证与基线
- **D1. Android 集成测试**：复用 `integration_test/`，关键路径在 Android emulator 跑通。
- **D2. 性能基线**：冷启动 <3s、内存 <100MB、Crash-free >99.5%（Mobile App Builder 成功指标）。

## 4. 明确不做（本轮范围外）

- Play 上架（签名 / AAB / 隐私政策 / 商店素材）
- iOS↔Android 跨设备同步（已有 macOS 同步调研基础，作为独立专项）
- Material 自适应 UI（保持 ADR-003 纯 Cupertino）
- Android 端真实 TTS 发声（本期仅收口 UI；后续可接 `flutter_tts`）

## 5. ADR 影响评估

**无需新增 ADR**：
- 框架/状态/路由/存储方案均不变（仍 Riverpod / go_router / sqflite + Markdown）
- ADR-003（纯 Cupertino）继续保持，本轮正是为了守住它
- TTS、后台桥接的跨平台守卫在之前迭代已落地

仅涉及 `pubspec.yaml`（`flutter_launcher_icons` 开 `android: true`）与 `android/app/src/main/AndroidManifest.xml` 的增量修改，无架构级决策。

## 6. 风险与开放问题

- `minSdk` 实测值需 `flutter run` 验证（image_picker 对 API 级别有要求）
- Android 13+ 相册权限运行时弹窗（image_picker 已处理大部分，需实测）
- 本地后台重发缺口（退后台期间）：可接受，已标注，不阻塞 MVP

## 7. 验收方式（先于实现）

- 编译 + `flutter analyze` 无新增错误；`flutter build apk --debug` 通过
- Android emulator 关键路径集成测试通过
- 六模块功能等价手工验证清单逐条勾选
