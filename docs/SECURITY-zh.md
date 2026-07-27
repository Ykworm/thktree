# 安全与隐私说明（SECURITY）

> 记录 ThkTree 在隐私与安全上的设计立场、已修复的问题，以及「评估后有意不改」的决策。
> 法律文本（隐私政策、服务协议）见 `docs/legal/`；本文是工程视角的补充。

## 数据流向（总览）

- 聊天内容只发往**你自己配置的 LLM Provider**；没有 ThkTree 服务端，也没有任何统计、崩溃上报、追踪 SDK。
- API Key 存系统安全存储（iOS Keychain / Android Keystore），不落明文、不写入 `llm_providers.json`、不包含在导出备份里。
- 聊天正文以明文存于应用沙盒（`Documents/thktree/` 下的 `session.md` 与 `index.sqlite`），与其他同类本地优先应用一致。

## 已修复（2026-07-27，分支 `ThkTree/privacy-hardening`）

1. **Release 构建不再打印 LLM 流式明文。** 此前 OpenAI / Claude / Gemini 三处调试 print 与豆包错误 print 在 release 下也会把对话内容写入 logcat/os_log；现已全部由 `kDebugMode` 门控，release 构建中编译器直接剔除。
2. **聊天图片统一剥离 EXIF（含 GPS）。** 此前小于 4MB 且小于 1024px 的图片原样透传，EXIF 会随图发给 Provider 并落盘；现统一重编码剥离（PNG 保持无损与透明底；GIF 本身无 EXIF，透传以保留动画），并通过 bakeOrientation 保证显示方向正确。

## 评估后「有意不改」的决策

### 1. Markdown 远程图片自动加载 —— 现状：允许

- **风险**：AI 输出中的 `![](https://...)` 会被 `NetworkImage` 自动请求。理论上，恶意或被注入的模型输出可借此回传「设备正在阅读」的信号（IP、时间）。
- **决策理由**：联网搜索答案中引用图片是正常功能；图片仅作为像素加载，不执行任何脚本，攻击面限于「一次性 GET 请求」。
- **未来触发条件**：若日后提供「严格隐私模式」，或发现实际滥用案例，再通过 `imageBuilder` 做域名白名单 / 点击加载。

### 2. Android 云备份 —— 现状：`allowBackup` 默认开启

- **风险**：明文聊天数据库会进入用户 Google 账号的 Auto Backup（Google 侧加密存储），也可被 `adb backup` 导出。
- **决策理由**：备份落在用户自己的 Google 账号下，换机自动恢复是重要的用户体验；最敏感的 API Key 位于安全存储，本就不参与备份。App 自带的导出/导入（未加密 zip）性质相同，且是用户主动触发。
- **未来触发条件**：上架前若需收紧，一行 `android:allowBackup="false"` 或用 `dataExtractionRules` 排除数据目录即可。
- iOS 侧对应行为（`Documents/thktree/` 纳入用户自己的 iCloud 备份）已在 README 与隐私政策中写明。

### 3. 远程日志回传 `THKTREE_LOG_URL` —— 现状：保留代码，默认彻底关闭

- **机制**：编译期 dart-define。构建时不传该 define，`_remoteUri` 为 null，上传代码完全不执行；全仓库没有任何打包脚本/CI 传它。
- **红线**：release / 上架构建**禁止**传 `--dart-define=THKTREE_LOG_URL=...`。配套接收端 `tools/host_log_server.py` 是明文 HTTP、无鉴权，仅用于本机调试；日志行可能包含会话标题与本地绝对路径。
- 该约束已固化在 `lib/ui/core/app_logger.dart` 的构造函数注释中。

## 报告安全问题

请通过 GitHub Issues 提交：<https://github.com/Ykworm/thktree/issues>。涉及敏感细节时请先描述影响面，避免直接贴出可利用的完整细节。
