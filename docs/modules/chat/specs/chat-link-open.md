# Chat 链接可点击打开 — 实现计划

> Freemode。任务类型：普通功能。
> 方案：B（`flutter_custom_tabs`：iOS SFSafariViewController / Android Chrome Custom Tabs）。

## 背景 / 根因

- Chat 消息体用 `GptMarkdown` 渲染，但所有调用点都没传 `onLinkTap`，markdown 链接当前是死文本。
- `pubspec.yaml` 无 `url_launcher` / `webview_flutter`，不存在任何"打开链接"链路。
- 原"无法打开 http 连接"痛点：走 in-app `WebView` 会撞 iOS ATS / Android cleartext；走 `SFSafariViewController` / Custom Tabs（浏览器进程）则不受 App 的 ATS / cleartext 约束，`http://` 可直接加载。

## 决策

- **打开方式**：`flutter_custom_tabs`（iOS=`SFSafariViewController`，Android=Chrome Custom Tabs）。浏览器进程隔离 + 共享系统浏览器登录态 + 地址栏可见，安全性与 `url_launcher` 外部浏览器等同，但体验更顺滑（应用内浮层）。
- **交互**：单击链接 → 打开。不做专用"长按复制"——消息体已包在 `SelectionArea` 内，长按选中文本即可复制链接。
- **http(非 https)**：不单独加确认弹窗，交给系统浏览器处理。
- **不做** in-app `WebView`（ATS/cleartext/JS bridge/cookie 隔离全是债）。

## 前置核对（已确认）

| 项 | 要求 | 现状 | 结论 |
|---|---|---|---|
| iOS deployment target | ≥ 12.0 | 13.0 | ✅ |
| Android（仅核对） | SDK 19+ / AGP 7.4+ / Kotlin 1.8+ | 项目偏好 iOS（`flutter_launcher_icons.android=false`） | ⚠️ 若仍出 Android 包需在实现时核 AGP/Kotlin；iOS 优先 |
| 渲染器 | 单一 | 仅 `gpt_markdown`（`flutter_markdown` 声明但 lib 未用 `MarkdownBody`） | ✅ 单一接入面 |
| 链接回调 | `onLinkTap(url, title)` | gpt_markdown 1.1.7 支持，仅单击 | ✅ |

## 接入面（`GptMarkdown` 调用点）

| 文件:行 | 位置 | 是否接 | 备注 |
|---|---|---|---|
| `lib/ui/core/shared/message_bubble.dart:595` | 助手消息正文 | ✅ | 核心 |
| `lib/ui/core/shared/message_bubble.dart:778` | reasoning 区 | ✅ | |
| `lib/ui/core/shared/message_bubble.dart:938` | 表格展开全屏视图 | ✅ | |
| `lib/ui/core/shared/message_bubble.dart:1011` | 表格单元格内 | ✅ | 单元格内链接也需可点 |
| `lib/ui/features/settings/tts_player_screen.dart:136` | TTS 播放器跟随文本 | ✅ | |
| `lib/ui/features/notes/note_detail_screen.dart:587` | 笔记详情 | ✅ | 笔记含链接 |
| `lib/ui/core/shared/share_card_widget.dart:138` | 分享图片导出 | ❌ 跳过 | 非交互，导出为图 |

## 实现步骤

### 1. 依赖
- `pubspec.yaml` 增加 `flutter_custom_tabs: ^2.5.0`（iOS SFSafariViewController / Android Custom Tabs）。
- 备用 fallback：`url_launcher`（仅当 custom_tabs 启动失败时兜底走外部浏览器）。可暂不加，先看 custom_tabs 失败率；计划里先列，实现时定。

### 2. 新增链接处理 helper
新文件 `lib/ui/core/shared/link_launcher.dart`：
- `Future<void> openMarkdownLink(BuildContext context, String url, [String? title])`
  - 校验 scheme：仅放行 `http` / `https`；其余（`javascript:` / `data:` / `file:` / `tel:` 等）静默忽略。
  - `flutter_custom_tabs` 启动 SFSafariViewController，toolbar 颜色对齐 App 主题。
  - 失败兜底：`url_launcher`（若引入）外部浏览器；或 `ThkAlert` 提示"无法打开链接"。
- 纯函数 + 仅依赖 `BuildContext`，便于复用、不污染 widget。

### 3. 接入 `onLinkTap`
在上述 6 个调用点给 `GptMarkdown` 传：
```dart
onLinkTap: (url, _) => openMarkdownLink(context, url),
```
（表格单元格里无直接 `BuildContext` 闭包时，由父 widget 传入。）

### 4.（可选，非 MVP）`ThkMarkdown` 包装 widget
把 `GptMarkdown` + `onLinkTap` + 既有 `latexBuilder` / `codeBuilder` / `tableBuilder` 收敛进一个 `ThkMarkdown`，消除 6 处重复。MVP 可不做，后续清理时再上。

## 验证（先定验收，再实现）

风险类型 = UI 交互，非金额/权限/数据转换纯逻辑 → **不补 focused unit test**；以"编译 + 静态检查 + 手工验证"为验收层。

1. `flutter analyze` 无新增 error / warning。
2. `flutter build ios --no-codesign` 通过（确认原生依赖接入无破坏）。
3. 手工验证清单（iOS 模拟器 / 真机）：
   - [ ] 助手消息中 `[example](https://example.com)` → 单击 → SFSafariViewController 滑出、页面加载、地址栏可见、可下拉关闭。
   - [ ] `http://`（非 https）链接 → 能打开（验证 ATS 不拦 SFSafariViewController）。
   - [ ] `javascript:alert(1)` / `data:...` 链接 → 单击无反应（白名单生效）。
   - [ ] 表格单元格内链接 → 可点开。
   - [ ] reasoning 区链接 → 可点开。
   - [ ] 笔记详情链接 → 可点开。
   - [ ] TTS 播放器页链接 → 可点开。
   - [ ] 长按链接文本 → 可选中复制（SelectionArea 仍生效）。
   - [ ] 单击链接与 SelectionArea 选中文本的手势不冲突（若冲突，记录现象，纳入实现时处理）。

## 风险 / 待确认

- **SelectionArea × 链接单击手势冲突**：消息体在 `SelectionArea` 内，单击链接可能被选中手势拦截。实现时实测；若冲突，方案备选：链接区用 `TapAndPanGestureRecognizer` 优先级调整，或对链接单击加短延迟判定。
- **Android 是否仍出包**：若不出 Android，Custom Tabs 路径在 Android 上不验证；若出，需核 AGP/Kotlin 并在 Android 真机补测。
- **gpt_markdown 升级**：`onLinkTap` 签名 `(String url, String title)?`，升级时需复检。
