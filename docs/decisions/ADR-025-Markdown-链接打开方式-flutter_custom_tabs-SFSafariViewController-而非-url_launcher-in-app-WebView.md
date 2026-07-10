## ADR-025: Markdown 链接打开方式——flutter_custom_tabs（SFSafariViewController）而非 url_launcher / in-app WebView

2026-07-08 决定。Chat / 笔记 / TTS 播放器的消息体用 `gpt_markdown` 渲染，但所有调用点都没传 `onLinkTap`，markdown 里的链接是死文本——既不可点，也没有"打开"动作；`pubspec.yaml` 也无 `url_launcher` / `webview_flutter`，整条链路缺失。选择 `flutter_custom_tabs`（iOS = SFSafariViewController / Android = Chrome Custom Tabs）作为链接打开方案。

决策理由（三方案对比）：

1. **安全隔离优先于控制力**：链接内容来自 LLM 输出，本质是不可信内容。in-app WebView（方案 C）继承 App 上下文、能跑 JS、能在 App 自己的 UI chrome 里钓鱼，且撞 Android cleartext（API 28+ 默认禁 `http://`）+ iOS ATS，要改 manifest / Info.plist，后续债多。`flutter_custom_tabs`（方案 B）与 `url_launcher` 外部浏览器（方案 A）都是把 URL 交给浏览器进程，App 不碰 ATS / cleartext，地址栏可见，登录态在浏览器侧。
2. **体验**：A 每次全切到 Safari / Chrome，打断感强；B 是应用内浮层滑出（SFSafariViewController 从底部推入、可下拉关闭），不离开 App，是 Twitter / Reddit / 新闻类 App 的标准做法。B 在安全上与 A 等同，体验明显更顺，故选 B。
3. **关键洞察——"打不开 http"痛点不复发**：SFSafariViewController 运行在浏览器进程，不受 App 的 ATS（App Transport Security）约束，`http://` 链接可直接加载，无需改 `Info.plist` 的 `NSAppTransportSecurity`。这正是选 B 而非 in-app WebView 的核心收益之一。

实现要点：

- 依赖：`pubspec.yaml` 新增 `flutter_custom_tabs: ^2.5.0`（已确认 iOS deployment target 13.0 ≥ 插件要求 12.0）。
- 统一入口：新建 `lib/ui/core/shared/link_launcher.dart`，`openMarkdownLink(context, url, [title])` —— 先 `Uri.tryParse` + scheme 白名单（仅 `http` / `https`，静默忽略 `javascript:` / `data:` / `file:` 等，避免 LLM 不可信链接触发异常）→ `flutter_custom_tabs.launchUrl`（iOS `SafariViewControllerOptions`：`preferredBarTintColor` = `AppColors.surface`、`preferredControlTintColor` = `AppColors.accent`；Android `CustomTabsColorSchemes` 同色）→ 失败兜底 `ThkAlert`。
- 接入面：6 处 `GptMarkdown` 传 `onLinkTap: (url, _) => openMarkdownLink(context, url)` —— `message_bubble.dart`（正文 / reasoning / 表格展开 / 表格单元格 共 4 处）、`tts_player_screen.dart`（1 处）、`note_detail_screen.dart`（1 处）。`share_card_widget.dart` 的 `GptMarkdown` 用于分享图片导出，非交互，跳过。
- 不做"长按复制" sheet：`gpt_markdown` 的链接仅暴露 `onLinkTap`（单击），无长按回调；但消息体外层已包 `SelectionArea`，用户长按选中文本即可复制链接，已覆盖"复制"诉求。
- `http://`（非 https）不单独加确认弹窗：交由系统浏览器自身处理，App 不背判断负担。
- `AppColors` 注意：`AppColors.surface` 是 getter（非 const），故 `SafariViewControllerOptions` / `CustomTabsColorSchemes` 不能用 const 构造，全部运行时构造。

影响范围：`pubspec.yaml`（新增依赖）、`lib/ui/core/shared/link_launcher.dart`（新增）、`lib/ui/core/shared/message_bubble.dart`（import + 4 处 onLinkTap）、`lib/ui/features/settings/tts_player_screen.dart`（import + 1 处）、`lib/ui/features/notes/note_detail_screen.dart`（import + 1 处）。

后续如需"在卡片内嵌渲染网页内容"（如富链接预览卡片）：可引入 in-app WebView 作为补充，但需配套处理 ATS / cleartext、JS bridge、cookie / storage 隔离，不作为默认路径。已知运行时风险：`SelectionArea` 与链接单击手势可能冲突（消息正文 / reasoning 外层有 SelectionArea，表格展开视图无），需真机实测确认单击不被"选中文字"手势抢掉。
