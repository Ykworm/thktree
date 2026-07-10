## ADR-012: 语音播放 UI 交互——独立播放器页面 + 语速不持久化

2026-06-17 决定。语音播放的交互方式从"MessageBubble 内嵌播放/停止按钮"改为"点击播放按钮打开独立播放器页面"。理由有三：单条消息可能很长（Markdown 正文），内嵌按钮无法展示完整文本；语速调节需要滑块控件，MessageBubble 底部空间不足；独立页面让播放控制更聚焦（大按钮、清晰状态）。同时决定**语速不持久化**——每次打开播放器页面默认正常语速（0.5），用户调节仅对当前播放生效。理由：用户每次朗读的语境不同（快速浏览 vs 仔细聆听），固定默认值比记忆上次设置更合理；减少持久化状态，降低复杂度。影响范围：`lib/ui/core/shared/message_bubble.dart`（播放按钮改为打开页面）、`lib/ui/features/settings/tts_player_screen.dart`（新增）、`lib/ui/features/settings/tts_settings_screen.dart`（新增）。实施要点：播放器页面用 `CupertinoPageRoute` push 进入，导航栏返回按钮自动处理；语速滑块范围 0.0~1.0（直接映射 `AVSpeechUtterance.rate`），0.5 为正常语速。
