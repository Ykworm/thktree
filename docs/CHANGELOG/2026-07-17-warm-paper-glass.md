# 2026-07-17 — Warm Paper Glass（P0–P3）

> 视觉主线：安静书房剂量。人眼闸门 P0→P3 均 OK 后合入。

## 摘要

| 阶段 | 内容 | 人眼 |
|------|------|------|
| **P0 色** | light 暖纸 `pageBg` / 白 `surface` / 雾蓝 accent / 五色 tile+node / success→sage | OK |
| **P1 卡** | `AppSurfaces.contentCard` 统一 radius / hair / 轻影；消息与主题卡 | OK |
| **P2 玻** | `AppGlass` + `ThkGlassBar`；tab Stack 叠内容；顶栏不透明；Chat 双条毛玻璃 composer | OK |
| **P3 光** | `AppAtmosphere` + `ThkPageAtmosphere`：主题列表 + 搜索；蓝自 title bar 释放 | OK |

## 关键代码

| 路径 | 说明 |
|------|------|
| `lib/ui/core/theme/app_colors.dart` | Warm Paper light 色板真源 |
| `lib/ui/core/theme/app_surfaces.dart` | `AppSurfaces` / `AppGlass` / `AppAtmosphere` |
| `lib/ui/core/widgets/thk_glass_bar.dart` | 壳层毛玻璃条 |
| `lib/ui/core/widgets/thk_page_atmosphere.dart` | 页级静光 |
| `lib/ui/core/shared/chat_composer.dart` | 输入 pill + 工具 pill + 圆钮 |
| `lib/ui/core/shared/chat_list_view.dart` | 无实心 pageBg；`bottomContentInset` |
| `lib/ui/core/router.dart` | tab 叠层 + MediaQuery bottom 注入 |
| `lib/ui/features/chat/chat_screen.dart` | Stack 列表+composer；SafeArea bottom |
| `lib/ui/features/themes/theme_list_screen.dart` | `ThkPageAtmosphere` |
| `lib/ui/features/search/search_screen.dart` | `ThkPageAtmosphere` |
| `docs/_shared/design-tokens.yaml` | sync 镜像（色） |
| `docs/_shared/design-system.md` | 四层约定 |

## 约束（防回归）

1. **code-first：** 改色只动 `app_colors.dart` 再 `dart run scripts/sync-design-tokens.dart`。
2. **blur 禁区：** 列表 cell、树节点行、助手长文不做 `BackdropFilter`。
3. **真玻璃：** composer 背后必须是消息像素；列表勿铺不透明底挡住 blur。
4. **Android：** 玻璃降级不透明 paper-warm；氛围光仍可半透色斑。
5. **顶栏：** 保持不透明 surface，避免半透 nav 挡面包屑。
6. **氛围光范围：** 仅主题列表 / 搜索；Chat 默认无页级光。

## 不做（本轮）

- 字体换族、选区 ink 条整条 redesign（P4 可选）
- Lab 换肤
- 主题树节点行毛玻璃 / 满页 bento

## 文档

- 视觉宪法：[design-system.md](../_shared/design-system.md)
- 模块：`docs/modules/chat`、`themes`、`search` README / visual 小补
