# iOS Chat：键盘上方底栏空隙（对齐 Android）

> 日期：2026-07-16

## 背景

Chat 页键盘弹起后，联网搜索 / 深度思考 / 图片所在底栏与输入法之间多出约 tab 高度空白。Android 已通过「键盘时隐藏导航栏」修好；iOS 仍有。

## 根因

1. **`AndroidNavigationShell`**（已修）：`keyboardOpen` 时隐藏底栏，`Expanded` 占满高度，`viewInsets` 为真实键盘高度。
2. **iOS `_MainShell`**：键盘时仍保留 tab bar 占位，并把 `viewInsets.bottom` 减去 `tabBarHeight`。
3. **`ChatScreen`（`5dfae36`）**：用 `View.of` 把 `viewInsets` 恢复为完整键盘高度。Chat 仍在 shell 的 `Expanded`（高度已是 `screen − tabBar`）内，再按完整 `K` resize → 多出约 `tabBarHeight` 空白。

Android 因隐藏底栏 + 不改 viewInsets，同一段 ChatScreen 代码几乎是 no-op；iOS 上则制造空隙。

## 方案

对齐 Android：

| 文件 | 改动 |
|------|------|
| `lib/ui/core/router.dart` `_MainShell` | `keyboardOpen` 时隐藏 tab bar；去掉 `viewInsets − tabBarHeight` |
| `lib/ui/features/chat/chat_screen.dart` | 删除 `realBottomInset` MediaQuery 包装 |

## 验收

- [ ] iOS：Chat 聚焦输入，工具行紧贴键盘上沿
- [ ] iOS：收起键盘后 tab bar 正常
- [ ] Android：无回归空隙

## 相关

- Commit：`6576dcd`
- Android 先例：`AndroidNavigationShell` `if (!keyboardOpen)` 隐藏底栏
