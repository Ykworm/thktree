# 温暖极简视觉重构计划（历史记录）

> ⚠️ **本文是历史变更记录**。本次重构已于 2026-06-06 完成，所有色彩 token 已合入 [design-system.md](design-system.md)。新设计/重构请直接编辑 [design-system.md](design-system.md)，不再回写本文。

## 背景

ThkTree 初版（2026-04）采用**暖色调**（coral / amber / rose）作为主题色板，整体偏"温暖/手工"质感。但在 iOS Cupertino 风格下显得不够克制，且与"清新多彩"的节点卡片配色（5 套 `_NodePalette`）形成风格冲突。

本次重构目标：

1. 主题色板从暖色 → **冷色清新调色板**（skyBlue / mint / lavender / coral / amber，HSL 同明度 L≈60-70%）
2. 大标题字体从 `.SF Pro Display` → **Cormorant Garamond** serif（营造"文学/笔记"质感）
3. 节点色保持不变（5 套 `_NodePalette`），与新主题色形成"内容+容器"双层信息架构

## 重构内容

### 1. 主题色板调整

| Token | 旧值（暖色） | 新值（冷色清新） |
|-------|------------|----------------|
| `skyBlue` | `#38BDF8` | 不变 |
| `mint` | `#34D399` | 不变 |
| `lavender` | `#A78BFA` | 不变 |
| `coral` | `#FB7185` | 不变（保留一抹暖色平衡） |
| `amber` | `#FBBF24` | 不变（保留一抹暖色平衡） |

实际未调整色值，但**重新定义**了 5 色的角色分配：从"主调色板"降级为"清新点缀色板"，不再以暖色（coral/amber）为主。

### 2. 字体调整

| 场景 | 旧字体 | 新字体 |
|------|--------|--------|
| 屏幕大标题 | `.SF Pro Display` 28 w700 | **Cormorant Garamond** 34 w600 |
| 二级显示标题 | `.SF Pro Display` 24 w700 | **Cormorant Garamond** 28 w600 |
| 正文 | `.SF Pro Text` 17 w400 | 不变 |

新增 `assets/fonts/CormorantGaramond-*.ttf`（Regular / SemiBold / Bold）。

### 3. accent 色微调

| Token | 旧值 | 新值 | 说明 |
|-------|------|------|------|
| `accent` | `#5B5FCF` (灰蓝紫) | `#6366F1` (indigo 500) | 统一 Tailwind 调色板 |
| `accentLight` | `#EEF1FA` | `#EEF2FF` | 对齐 indigo 50 |
| `accentDeep` | `#4A4FB8` | `#4F46E5` | 对齐 indigo 600 |

### 4. 节点卡片色组选择策略

旧策略：节点色基于 `nodeId` hash 但未与主题色解耦。
新策略：节点色基于 `nodeId` hash（5 套 `_NodePalette`），**与主题色完全解耦**。

用户切换主题时，节点内容（视觉记忆点）保持稳定——形成"内容+容器"双层信息架构。

## 实施步骤（已完成）

1. ✅ 2026-06-04：设计新调色板 + 字体方案
2. ✅ 2026-06-05：替换 `app_colors.dart` / `app_theme.dart` 静态常量
3. ✅ 2026-06-05：注册 Cormorant Garamond 字体（`pubspec.yaml` + `assets/fonts/`）
4. ✅ 2026-06-05：所有屏幕替换为 `AppTheme.largeTitle` / `AppTheme.displayTitle`
5. ✅ 2026-06-06：节点色与主题色解耦（`_NodePalette` 独立常量）
6. ✅ 2026-06-06：色组合规检查（`rg` 旧 token 0 命中）

## 验证

- ✅ iOS 模拟器截图：所有屏幕在冷色清新调色板下视觉协调
- ✅ Android 模拟器截图：字体回退到 PingFang SC，无明显差异
- ✅ 主题切换测试：节点色保持稳定，仅容器色变化
- ✅ 性能：字体加载无卡顿（大标题仅在屏幕首次渲染时实例化）

## 后续行动

本文作为历史记录保留。如需追溯"为什么不用暖色作为主调色板"，参考本文 § 1。如需追溯"为什么节点色与主题色解耦"，参考 [design-system.md § 7.1](design-system.md)。
