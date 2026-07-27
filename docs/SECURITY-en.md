# Security & Privacy Notes (SECURITY)

> Engineering perspective on ThkTree's privacy and security posture: design choices, fixes, and intentional non-changes.
> Legal text (privacy policy, terms of service) lives in `docs/legal/`; this document is supplementary.

## Data flow (overview)

- Chat content is sent only to **LLM providers you configure**. There is no ThkTree backend, analytics, crash reporting, or tracking SDK.
- API keys are stored in platform secure storage (iOS Keychain / Android Keystore). They are not stored in plain text, not written to `llm_providers.json`, and not included in export/backup archives.
- Chat bodies are stored in plain text inside the app sandbox (`session.md` and `index.sqlite` under `Documents/thktree/`), consistent with other local-first apps.

## Fixed (2026-07-27, branch `ThkTree/privacy-hardening`)

1. **Release builds no longer print raw LLM stream text.** Debug prints for OpenAI / Claude / Gemini streams and Doubao errors previously wrote conversation content to logcat/os_log in release builds. All are now gated by `kDebugMode` and stripped from release builds at compile time.
2. **Chat images always strip EXIF (including GPS).** Previously, images under 4MB and 1024px were passed through unchanged, so EXIF could be sent to providers and saved on disk. Images are now re-encoded to strip metadata (PNG stays lossless with alpha; GIF has no EXIF and is passed through to preserve animation). Orientation is normalized via bakeOrientation.

## Intentional decisions (evaluated, unchanged)

### 1. Remote Markdown images auto-load — status: allowed

- **Risk:** AI output like `![](https://...)` triggers `NetworkImage` requests. In theory, malicious or injected model output could use this as a one-shot beacon (IP, timing).
- **Rationale:** Citing images from web search is normal product behavior. Images load as pixels only—no script execution. Attack surface is limited to a single GET request.
- **Future trigger:** If we add a "strict privacy mode" or see real-world abuse, we can add domain allowlists or tap-to-load via `imageBuilder`.

### 2. Android cloud backup — status: `allowBackup` enabled by default

- **Risk:** Plaintext chat data may enter the user's Google Auto Backup (encrypted on Google's side) or be exported via `adb backup`.
- **Rationale:** Backup stays in the user's own Google account; auto-restore on device change matters for UX. API keys live in secure storage and are excluded from backup. In-app export/import (unencrypted zip) is equivalent and user-initiated.
- **Future trigger:** Before store tightening, set `android:allowBackup="false"` or use `dataExtractionRules` to exclude app data.
- **iOS:** `Documents/thktree/` is included in the user's iCloud backup when enabled—documented in README and the privacy policy.

### 3. Remote log upload `THKTREE_LOG_URL` — status: code kept, off by default

- **Mechanism:** Compile-time `dart-define`. If the define is omitted at build time, `_remoteUri` is null and upload code never runs. No repo script or CI passes it.
- **Red line:** Release / store builds **must not** pass `--dart-define=THKTREE_LOG_URL=...`. The companion receiver `tools/host_log_server.py` is plain HTTP with no auth—local debugging only. Log lines may include session titles and local absolute paths.
- This constraint is documented in `lib/ui/core/app_logger.dart`.

## Report a security issue

Open a GitHub Issue: <https://github.com/Ykworm/thktree/issues>. For sensitive findings, describe impact first—avoid posting full exploit details in public.
