# 2026-07-26 — Morandi 换肤 + 查看树返回修复

## 摘要

| 项 | 内容 |
|----|------|
| **配色皮肤 v1** | Settings → 外观：`warmPaper`（默认）/ `morandi`；registry 内置 `slate` = dark |
| **持久化** | SecureStorage `color_palette`；parse 失败 → warmPaper |
| **Lab 豁免** | `labCoolBg` 等 Lab 色不随皮肤切换 |
| **导航修复** | Chat「查看树」改 `push`；FullTree 返回统一 `pop` |

## 关键代码

| 路径 | 说明 |
|------|------|
| `lib/ui/core/theme/app_palette_tokens.dart` | 三表 + `AppColorPalette` registry |
| `lib/ui/core/theme/app_colors.dart` | delegate + `setPalette` / `setBrightness` |
| `lib/ui/core/theme/app_surfaces.dart` | `AppGlass` 读当前 palette |
| `lib/data/services/settings_store.dart` | `color_palette` key |
| `lib/ui/features/settings/settings_screen.dart` | `_PalettePicker` |
| `lib/ui/features/settings/settings_controller.dart` | `paletteProvider` + `saveColorPalette` |
| `lib/main.dart` | 冷启动加载 + 运行时切换 |
| `lib/ui/features/chat/chat_screen.dart` | 查看树 `context.push` |
| `lib/ui/features/themes/full_tree_screen.dart` | `_onBack` → `context.pop` |
| `scripts/sync-design-tokens.dart` | 解析 palette 文件同步 YAML |
| `scripts/check_color_tokens.dart` | palette 文件白名单 |
| `test/theme/*_tokens_test.dart` 等 | palette 回归 |

## 设计约束

1. **light-only 用户选肤**：Settings 只暴露 warmPaper / morandi；深色仍走 Dev Tools → slate。
2. **语义 token 是 getter**：随 `setPalette` 变；widget 侧勿包 `const`。
3. **节点圆点随皮肤**：`nodePalettes.circle` 五色在 morandi 下为低饱和灰调，hash 槽位不变。
4. **Matte Gold / questionSourceTag**：morandi 下随 accent 降饱和。

## 测试

- `dart test test/theme/` — warmPaper / morandi / slate / round-trip / lab exempt
- `dart test test/data/services/settings_store_palette_test.dart`

## 文档

- [design-system.md](../_shared/design-system.md) — 配色皮肤节
- [settings README](../modules/settings/README.md)
- [FEATURES.md](../FEATURES.md)
