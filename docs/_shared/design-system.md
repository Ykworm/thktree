# ThkTree Design System · 约定（code-first）

> 代码是真源。设计 token 写在手写类里，文档只是镜像，CI 拦裸色防止漂移。

## 产品视觉：Warm Paper Glass（安静书房）

**一句话：** 纸做底座，卡做内容，玻做壳层，光做呼吸。  
**剂量默认：安静书房**——玻轻、光淡、卡实；不是全站 Glassmorphism / 不是高饱和 Aurora 营销站。

| 层 | 角色 | 真源 / 组件 |
|----|------|-------------|
| L0 纸 | `pageBg` 暖米色画布 | `AppColors.pageBg` / `surfaceMuted` |
| L1–L2 卡 | 白卡 + hair + 轻影 | `AppColors.surface` + `AppSurfaces.contentCard` |
| L3 玻 | nav/tab/sheet 壳层磨砂；composer 为白瓷特例 | `AppGlass` + `ThkGlassBar`；composer 见 `ChatComposer`（白瓷无描边） |
| L0 光 | 页级静态 soft radial（主题列表 / 搜索） | `AppAtmosphere` + `ThkPageAtmosphere` |

### 颜色气质（light）

- **纸：** `#F7F5F0` / paper-warm `#F3EFE8`
- **唯一主交互：** 雾蓝 accent `#4A7AB5`（`AppColors.accent`）
- **五色（分类 / 主题 tile / 节点圆，非第二 accent）：** blue / sage / clay / gold / plum
- **高级强调 (Matte Gold)：** 哑光暖沙金 `#D4A373`，搭配极淡暖金/米白渐变。用于极简且极具质感的全局引导、空状态卡片及 Alert 确认按钮，替代生硬的原生蓝。
- **独立冷灰空间 (Lab)：** 冷银灰 `#F2F4F7`（`AppColors.labCoolBg`）。用于 Lab 等需要与“暖纸”拉开材质区分、体现科技感与精密感的独立页面。
- **success → sage**；Lab 霓虹色豁免书房换肤

### 配色皮肤（2026-07-26）

v1 在 **Settings → 外观** 提供 light 换肤：`warmPaper`（默认）与 `morandi`。Registry 内置第三套 `slate` = 现网 dark 色，由 Dev Tools 深色开关触发，**不进 Settings UI**。

| 皮肤 id | 说明 |
|---------|------|
| `warmPaper` | 默认 Warm Paper Glass，行为与迁移前 pixel 一致 |
| `morandi` | 低饱和灰调书房；节点圆点五色随皮肤变 |
| `slate` | 内置 dark 表；`AppColors.setBrightness(dark)` 时选中 |

运行时：`AppColors.setPalette` + `AppColors.setBrightness` → `_current` = dark ? slate : 用户 palette。持久化 key：`color_palette`（`warmPaper` \| `morandi`，缺省 warmPaper）。

### 玻璃（`AppGlass`，`lib/ui/core/theme/app_surfaces.dart`）

| 规则 | 说明 |
|------|------|
| 用途 | 底 tab、sheet 头等 **壳层**；**禁止**列表 cell / 助手长文 / 树节点行每行 blur |
| iOS | `BackdropFilter` + 半透 fill（约 55% 暖白量级，`AppGlass.fill`） |
| Android | **不透明** `fillOpaque` paper-warm（无 blur，防脏与性能） |
| 叠层 | 底 tab **必须 Stack 叠在内容上方**，Column 并排无法磨到页面像素 |
| 顶栏 | `ThkNavBar` = 不透明 `pageBg`（顶栏属底座纸色，非白卡），且 `automaticBackgroundVisibility: false`：静止与滚动同色，滚动不变色；特例：TTS 播放器页显式透明让自定义背景透出 |

Composer（`ChatComposer` / `_ComposerGlassShell`）：**悬浮白瓷**——不透明 `AppColors.surface` + 极淡双层阴影，**无 hair 描边**；工具 chip 与输入同壳，禁止裸叠气泡正文。背后必须是消息列表像素（`ChatListView` 不铺实心 `pageBg`，用 `bottomContentInset`）。`AppGlass.composerFill` 等 token 仍保留，当前壳未走 blur 路径。

### 氛围光（`AppAtmosphere` + `ThkPageAtmosphere`）

| 规则 | 说明 |
|------|------|
| 范围 | **仅**主题列表、搜索页；Chat / 笔记 / 设置默认无 |
| 形态 | 静态 soft radial：蓝从 **title bar 下缘中线** 向下释放；左下 sage 极淡托底 |
| 剂量 | 核心约 8–10% alpha，径向淡出；可 `AppAtmosphere.enabled = false` 关掉 |
| 禁区 | 列表 cell blur、动画 mesh、全屏霓虹 |

### 内容卡（`AppSurfaces`）

- `contentCard`：白 surface + hair 边 + `cardShadowSm`
- 用户气泡：`accentLight`；助手：白卡 + hair

完整分期与验收记录见 [CHANGELOG/2026-07-17-warm-paper-glass.md](../CHANGELOG/2026-07-17-warm-paper-glass.md)。

## 排版与排布范式 (Editorial Layout)

### 空态扉页感 (Editorial Empty State)

空态不要做得像“系统报错提示”。应当像“打开一本新书的空白扉页”。
- **主标题**：降低对抗感。使用 `w400`（常规字重），并配合 `letterSpacing: 1.2` 拉开字间距，营造印刷品的呼吸感；使用 `AppColors.textMatteGoldDark` 并叠加 `0.8` 透明度。
- **副标题**：禁止使用突兀的冷灰（如 `textSecondary/Tertiary`）。使用与主标题同色系的 `textMatteGoldDark` 叠加 `0.5` 透明度贯通色调，并设置 `height: 1.5` 增加行高。
- **视觉中心**：不要使用死板的方形容器和边框，让主图形（如 SVG）直接成为视觉中心。

### 字体图标陷阱与 SVG 替代

- **居中陷阱**：Flutter 中的 `Icon` 渲染的是字体包围盒（bounding box），字体设计为了基线对齐通常偏上。在方形卡片中用 `Center` 包裹 `CupertinoIcons` 永远会导致**视觉偏上**。
- **解决方案**：在空态卡片或对几何居中要求极高的场景中，**禁止使用字体图标手动调 offset**，必须引入 `flutter_svg`，使用真正的 SVG 矢量图配合 `Center` 进行渲染。

---

## 单一真源

| 类别 | 真源文件 | 镜像字典 |
|------|----------|----------|
| 颜色 color | `lib/ui/core/theme/app_palette_tokens.dart`（三表 + registry）+ `lib/ui/core/theme/app_colors.dart`（delegate + Lab/scrim const） | `docs/_shared/design-tokens.yaml` → `color` |
| 间距/圆角 dimension | `lib/ui/core/theme/app_spacing.dart` | `docs/_shared/design-tokens.yaml` → `dimension` |
| 动效时长/曲线 time | `lib/ui/core/theme/app_durations.dart` | `docs/_shared/design-tokens.yaml` → `time` |
| 内容卡 / 壳层玻璃 / 氛围光 | `lib/ui/core/theme/app_surfaces.dart`（`AppSurfaces` / `AppGlass` / `AppAtmosphere`） | 以代码为准；yaml 暂不镜像结构类 |
| 图标 icon | `lib/ui/core/theme/app_icons.dart` | — |
| 字体 typography | `lib/ui/core/theme/app_theme.dart`（`textTheme`） | — |

`docs/_shared/design-tokens.yaml` 由 `scripts/sync-design-tokens.dart` **单向生成**，不要手改。

## 改色流程（必读）

1. **改真源**：在 `app_palette_tokens.dart` 增 / 改皮肤表，或在 `app_colors.dart` 增 Lab/scrim 等 const；间距/动效仍改 `app_spacing` / `app_durations`。
2. **改 widget**：把裸色 `CupertinoColors.*` / `Color(0x…)` 改为 `AppColors.<token>`。
   - 语义 token 是 **getter**（随 `AppColors.setPalette` / `setBrightness` 变），不是编译期常量——
     在 `const TextStyle / BoxDecoration / Icon` 里用时**去掉外层 `const`**。
   - `CupertinoColors.x.resolveFrom(context)` 直接换成 `AppColors.<token>`（getter 已随亮度变，无需 resolveFrom）。
3. **同步文档**：`dart run scripts/sync-design-tokens.dart` → 重新生成 `design-tokens.yaml`。
4. **提交**：pre-commit hook 跑 `scripts/check_color_tokens.dart` 拦裸色。

壳层玻璃 / 氛围光改 `app_surfaces.dart` 与对应 widget（`thk_glass_bar.dart` / `thk_page_atmosphere.dart`），**不要**把 blur 写进列表 cell。

## 禁止（防回归）

`lib/` 内禁止出现以下裸写法（app_colors.dart 自身除外，它是真源）：

- `CupertinoColors.*`
- `Color(0x…)`（含 `Color.fromARGB` / `Color.fromRGBO` / `Color.from`）
- 装饰性特征色也走 token：`AppColors.labBg / labAccentBlue / labAccentOrange / labAccentPurple / waveTeal / waveOrange / wavePurple`
- **原生的 `CupertinoSlidingSegmentedControl`**：其内置的半透明叠加逻辑会破坏我们精准配置的字色和底色，导致未选中状态文字发虚、无法看清。在严格色系中应改用自定义的 `Container` + `Row` 组合实现。

> 注：Material `Colors.*` 当前未强制拦截，但同样建议走 token；后续可纳入 guard。  
> 玻璃/氛围相关裸色仅允许出现在 `app_surfaces.dart` 与明确声明的 glass shell 内（与 color 真源同纪律）。

## 防回归机制

- `scripts/check_color_tokens.dart`：`--mode=warn`（只报告）/ `--mode=block`（发现即 exit 1）。
- `.git/hooks/pre-commit`：提交前自动跑 block 模式。
- **CI 接入**：当前仓库无 CI（Gitee remote），待搭建 Gitee CI 后，在流水线加一步
  `dart run scripts/check_color_tokens.dart --mode=block` 即可常态化拦裸色。

## 审计证据

- `docs/_shared/design-audit/overview.md`：Step 4 回修前后对照，lib/ 裸色偏差 **92 → 0**。
- `docs/_shared/design-audit/thktree-design-spec.html` 第 9 节：全局 Color Token 对照表。

## 历史

- Step 4（2026-07-11）：code-first 收敛。原 handoff 记录的「157 处」已漂移，以 lib/ 实测 92 处为准。
  新增中性原语 `white/black/transparent`、scrim 家族 `scrimStrong/scrimMid/scrimSoft`、装饰 token `lab*/wave*`。
- Warm Paper Glass（2026-07-17）：P0 色板 → P1 内容卡 → P2 壳层玻璃（含 composer）→ P3 主题/搜索静光。见 CHANGELOG 同日条目。
- Morandi 换肤（2026-07-26）：`app_palette_tokens.dart` registry + Settings 外观 picker。见 [CHANGELOG/2026-07-26-morandi-skin.md](../CHANGELOG/2026-07-26-morandi-skin.md)。
