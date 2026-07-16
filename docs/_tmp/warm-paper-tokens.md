# warm-paper-tokens

> **模式：** 讨论稿（design discuss）— **禁止写业务代码**，直到用户明确「开干 / 可以」。  
> **真源约束（定稿实现后）：** `lib/ui/core/theme/app_colors.dart` → `dart run scripts/sync-design-tokens.dart`（code-first，不手改 yaml）。  
> **UI 情报 skill：** **Cursor** → `~/.cursor/skills/ui-ux-pro-max/`（**不用** `~/.claude/skills`）。  
> 查询示例：`python3 ~/.cursor/skills/ui-ux-pro-max/scripts/search.py "liquid glass" --domain style`

---

## 0. Meta

| | |
|--|--|
| Worktree | `/Users/yuweikang/dev/ykcode/ThkTree-worktrees/warm-paper-tokens` |
| Branch | `ThkTree/warm-paper-tokens` |
| Base | `dev` @ `f000c48`（开 worktree 时） |
| Status | **P2 已实现— 停等 `P2 OK`（含 Android 扫一眼）** |
| 工作名 | **Warm Paper Glass**（暖纸液玻） |
| 气质剂量 | **安静书房**（默认）：玻轻、光淡、卡实；不是液态展厅 |
| Agent skill 路径 | **`~/.cursor/skills/ui-ux-pro-max`**（Cursor global；已确认存在） |

### 一句话产品视觉

**纸做底座，卡做内容，玻做壳层，光做呼吸。**  
色板用暖米色；结构用卡片；nav/tab/sheet 用克制液态玻璃；页级极淡渐变光。  
**不是**全站 Glassmorphism / 不是高饱和 Aurora 营销站。

---

## 1. 动机

| 现状 | 问题 |
|------|------|
| `pageBg #F8FAFC` + `accent #3B82F6` | 冷 slate + 鲜蓝，工具感强，偏离「哑光香槟 / 书房」 |
| themeTile 荧光五色 | 与历史香槟/暖灰注释分裂 |
| 用户参考暖米色 + 想叠 渐变光 / 卡片 / 液态玻璃 | 需合成，不能三套风格互抢 |

目标：ThkTree（知识树 + 笔记 + 长读 Chat）**长时间可读**，同时壳层现代一点。

---

## 2. 用户暖米色 token（完整真源草案）

### 2.1 底色

| Token | 值 | 角色 |
|-------|-----|------|
| `--paper` | `#f7f5f0` | 页主背景、画布底 |
| `--paper-warm` | `#f3efe8` | rail / 表单底 / 面板辅助 / tab 实心底（降级） |

### 2.2 文字

| Token | 值 | 角色 |
|-------|-----|------|
| `--ink` | `#1f2933` | 正文、标题 |
| `--ink-2` | `#4a5568` | 二级、角色名、次要动作 |
| `--ink-3` | `#8492a6` | 辅助、footnote、placeholder |
| `--ink-4` | `#b8c2cc` | 弱标签、禁用、装饰字（**不做正文**） |

### 2.3 边框

| Token | 值 | 角色 |
|-------|-----|------|
| `--hair` | `rgba(31,41,51,0.07)` | 默认细边、分割 |
| `--hair-2` | `rgba(31,41,51,0.12)` | hover / input 外框 / focus 外环底 |

### 2.4 五色 + soft

| Token | 实色 | Soft | 角色 |
|-------|------|------|------|
| `--blue` | `#4a7ab5` | `rgba(74,122,181,0.10)` | **唯一主交互**、当前、系统 |
| `--sage` | `#5a9e7f` | `rgba(90,158,127,0.10)` | 确认、active 辅、typing 点、∑ |
| `--clay` | `#c47856` | `rgba(196,120,86,0.10)` | 草稿、软警告；**硬删仍用红** |
| `--gold` | `#c9a24e` | `rgba(201,162,78,0.10)` | pin、附属分支 |
| `--plum` | `#8b6aae` | `rgba(139,106,174,0.10)` | 收集、合并、多选 |

### 2.5 阴影（Flutter 映射意图）

| Token | 意图 |
|-------|------|
| `--shadow-sm` | 卡默认：`0 4 14 -4 rgba(31,41,51,0.10)` |
| `--shadow-md` | 卡 hover / 抬起 |
| `--shadow-lg` | sheet / fork 菜单 only |

### 2.6 组件级参考（Web → 移动取舍）

| 参考组件 | 取 | 弃 / 改 |
|----------|----|---------|
| Rail | paper-warm、active blue soft | 移动无竖 rail；桌面另 topic |
| Topbar | 半透 + blur 思路 → L3 玻 | 不强依赖 backdrop-filter 百分比 |
| Canvas 三光晕 | **最多 2 角、opacity≤5%** | Chat 不铺网格/三光 |
| Node cards | 白卡 + hair + soft 环 | 根节点深色渐变卡（默认不做） |
| Chat panel | 输入 paper 底 + blue focus | 面板整面玻璃 |
| 消息 | 用户 soft 蓝底；助手白卡 | AI 头像大渐变可后置 |
| 选区工具条 | ink 底可选 P3 | 不挡 P0 |
| Typing | sage 圆点 | — |

---

## 3. 与 `AppColors` 映射表（实现时只改这里）

| `AppColors` | 新 light 值 | 备注 |
|-------------|-------------|------|
| `pageBg` | `#F7F5F0` | paper |
| `surface` | `#FFFFFF` | 白卡不变 |
| `surfaceMuted` | `#F3EFE8` | paper-warm |
| `textPrimary` | `#1F2933` | ink |
| `textSecondary` | `#4A5568` | ink-2 |
| `textTertiary` | `#8492A6` | ink-3 |
| `textQuaternary`（**新增可选**） | `#B8C2CC` | ink-4；无则 tertiary+opacity |
| `border` | `Color.fromRGBO(31,41,51,0.07)` 或近似 `#E8E4DC` | 优先 hair；若平台发糊用近似实色 |
| `borderStrong`（可选） | `fromRGBO(31,41,51,0.12)` | hair-2 |
| `accent` | `#4A7AB5` | blue |
| `accentLight` | `Color.fromRGBO(74,122,181,0.10)` 叠在白上 ≈ 实色 soft 底 | 或算死 `#E8F0F7` 类 |
| `accentDeep` | `#3D6A9E` 附近 | pressed，比 accent 略深 |
| `themeColors` / `themeTileColors` | blue, sage, clay, gold, plum 五实色 | 替换荧光 Tailwind |
| `nodePalettes` | 圆用五色实色/柔变；title 仍深 ink 系 | **统一五色，弃泥灰盘**（推荐） |
| `success` | sage `#5A9E7F` | 替换 systemGreen 鲜绿 |
| `destructive` | **保留** `#DC2626` | 硬删/不可逆 |
| `clay` / `gold` / `plum`（可选语义 getter） | 见上 | chip / merge / pin |
| `elevationShadow` | 改暖 ink 系 alpha | 对齐 shadow-sm 色相 |
| `glassFill` / `glassBlurSigma` / `glassStroke`（**新增**） | 见第 5.3 节 | **勿污染 surface** |
| `userBubbleBg` | → accentLight | |
| `assistantBubbleBg` | → surface | |
| `markdownCodeBg` | → paper 或 paper-warm | 代码略暖 |
| `thinkingBg` | → surfaceMuted | |
| Lab 色 | **不改** | 夜店对比保留 |

Dark：本期 **不改语义 dark 表**（可另 topic）；禁止把 paper 简单反相。

---

## 4. Warm Paper Glass 四层模型

```text
L0  Atmosphere   渐变光（page 级，静态，极淡）
L1  Canvas       paper / paper-warm 实色
L2  Content      白卡片 + hair + soft shadow
L3  Chrome       液态玻璃克制版（nav / tab / sheet / 可选 composer 条）
```

| 层 | 做 | 不做 |
|----|----|------|
| L0 | 主题列表/搜索空态 1～2 角 soft radial | Chat 网格、滚动跟随光、五色齐射、8–12s 动画 mesh |
| L1 | 全页阅读底 | 冷 slate |
| L2 | 消息、主题卡、设置分组 | 每行 blur、每条消息毛玻璃 |
| L3 | 壳层半透 + blur + hair | 正文底玻璃、列表 cell blur |

**规则「一玻一实」：** 同一视线深度最多一层强 blur；卡实、壳玻。

---

## 5. 三风格 × ui-ux-pro-max（Cursor skill）对照

**Skill 安装位置（本机已就绪）：**

```text
~/.cursor/skills/ui-ux-pro-max/
  SKILL.md
  data/styles.csv …
  scripts/search.py
```

安装/刷新（人类或 agent 在本机）：

```bash
npm install -g ui-ux-pro-max-cli@latest
uipro init --ai cursor --global    # → ~/.cursor/skills/  不要用 --ai claude 作为默认
```

> **明确：默认路径是 Cursor，不是 `~/.claude/skills`。**  
> Grok 会话不会自动加载该 skill；查库请跑 `search.py` 或把结果贴进本文件。

### 5.1 液态玻璃 → 取「克制 Glass + 拒完整 Liquid」

| Pro Max 条目 | 库内关键词 | ThkTree 取舍 |
|--------------|------------|--------------|
| **Liquid Glass** | morph、iridescent、chromatic、400–600ms、性能 Moderate-Poor | **不整站照搬**（对比/性能差） |
| **Glassmorphism** | blur 10–20、透白 10–30%、描边 | **壳层用**，但 fill **提到 55–72%**（暖纸上 15% 太脏） |
| **Spatial UI** | VisionOS 15–30% + blur 40 | **不做** 浮窗展厅 |

**ThkTree 玻璃配方（安静书房）：**

| 变量 | 值 |
|------|-----|
| `glassFill` | `Color.fromRGBO(255,255,255,0.65)` 偏暖白（可 soft 叠 paper） |
| `glassBlurSigma` | **12–16**（iOS）；Android 可降或 0 |
| `glassStroke` | hair / `rgba(31,41,51,0.08)` |
| 高光 | 顶边 0.5px 更浅描边 optional |
| 降级 | `paper-warm` 不透明 + hair（Reduce Transparency / 低端机） |
| 适用范围 | `ThkNavBar`、底部 tab、sheet 头、可选 composer **外框** |
| 禁区 | 助手长文、树节点行、笔记正文、主题网格每张卡 |

仓内先例：TTS mini bar `BackdropFilter` + **锁 saveLayer 高度** → 新 chrome 必须同样锁条带。

### 5.2 卡片式 → 取 Bento「白卡+圆角+软影」，拒粘土/不对称展板

| Pro Max 条目 | 取 | 弃 |
|--------------|----|----|
| **Bento Grids / Bento Box** | 白卡、16–20 radius、soft shadow、page 非纯白、内容优先 | 强制 1×1/2×2 营销不对称网格铺满 Chat |
| **Claymorphism** | — | 糖果紫粉、squish 弹簧（非产品调） |

**页面策略：**

| 页面 | 策略 |
|------|------|
| 主题网格 | 白卡 + hair + shadow-sm；选中 blue-soft 环 |
| 主题树 | 默认行；当前节点 left bar 或极浅抬卡 |
| Chat | 用户 accentLight 卡；助手白卡 + hair |
| 设置 | iOS grouped inset 卡 + paper 页底 |
| 搜索 | 默认紧行；选中可抬卡 |

### 5.3 渐变光 → 取「静态 soft radial」，拒 Aurora 全套

| Pro Max 条目 | 库内倾向 | ThkTree |
|--------------|----------|---------|
| **Gradient Mesh / Aurora Evolved** | 青洋红黄高饱和、流动 | **拒** 高饱和与 prismatic |
| **Aurora UI** | 8–12s 循环、complementary 霓虹 | **拒** 动画 mesh；**取**「大气层」概念 |

**ThkTree 光：**

- 仅 **主题列表 / 搜索空态**（可选 Lab 除外）  
- 右上：`blue-soft` radial ≤5%  
- 左下：`sage-soft` radial ≤5%  
- **静态**；`prefers-reduced-motion` 无关（无动画）  
- Chat / 笔记 / 设置：**默认无光**

### 5.4 Pro Max 自动 design-system 输出（仅参考，**不覆盖**本色板）

对 query `knowledge tree notes reading mobile app flutter warm paper` 的一次生成摘要：

| 项 | Pro Max 给的 | 我们的决定 |
|----|--------------|------------|
| Pattern | App Store Landing | **忽略**（我们是 app 内，不是商店落地页） |
| Style | Swiss Modernism 2.0 | **部分**：网格/克制装饰 OK；字体学术衬线 **不做**（系统字体优先） |
| Colors | 暖墨 + 琥珀 CTA + cream | **不采用**其 hex；**采用用户暖米色 + blue accent** |
| Typography | Cormorant / Crimson | **P0 不换字体**；可 P4 再议 |
| Avoid | 过度装饰 | **采纳** |

→ Pro Max = **风格情报与反模式**；色板真源 = **第 2 节用户表 + 第 3 节映射**。

### 5.5 推荐风格标签（给 Agent 的简短 prompt 锚）

```text
ThkTree Warm Paper Glass =
  E-Ink/Paper base + Soft UI depth + Bento cards (content only)
  + restrained Glassmorphism chrome (not full Liquid Glass)
  + static soft radial atmosphere (not Aurora mesh)
  + palette: user warm-beige tokens; accent #4A7AB5
  + Flutter mobile-first; long-form reading first
```

---

## 6. 设计原则（定稿）

1. **唯一主交互色：** `blue` / `accent`；其余四色只语义与装饰 soft。  
2. **纸上叠白卡：** `pageBg=paper`，内容 `surface=white`。  
3. **一玻一实；** 玻璃独立 token，不污染 `surface`。  
4. **长读优先：** Chat/笔记 玻璃面积 ≈ nav+composer（&lt;15% 屏高）。  
5. **Lab 豁免** 深色霓虹。  
6. **code-first：** 只改 `app_colors.dart` + sync；实现后再 ctsync 正式 docs。  
7. **性能：** 禁止列表 cell `BackdropFilter`；blur 不参与每帧动画。  
8. **无障碍：** 正文对比 ≥4.5:1；玻璃上字 fill≥0.55；提供不透明降级。  
9. **与 ui-flatten：** 仍少色阶、唯一 accent；本方案换温度与表皮，不堆随机色。  
10. **平台：** iOS 可玻；Android blur 弱则半透纸降级，视觉目标接近而非像素一致。

---

## 7. 分期与验收（开干后）

| 阶段 | 内容 | 验收 | 默认是否做 |
|------|------|------|------------|
| **P0 色** | 第 3 节 semantic + theme 五色 + node 对齐 + success→sage | 搜索/主题/Chat/设置一眼暖纸 | **是（第一刀）** |
| **P1 卡** | 统一 radius/hair/shadow；消息与主题卡 | 层级清晰、无荧光边 | 是 |
| **P2 玻** | nav + tab + sheet；`ThkGlassBar` 或等价；降级路径 | 壳层磨砂、滚动列表不糊 | 是 |
| **P3 光** | 主题/搜索 atmosphere 1～2 处 | 静、淡、可关 | 是（小） |
| **P4 可选** | 字体、选区 ink 条、composer 整条玻璃、桌面 rail | 另确认 | 否 |

**禁止** P0 同时上四层。

### P0 文件预期（开干时）

- `lib/ui/core/theme/app_colors.dart`  
- `dart run scripts/sync-design-tokens.dart` → `docs/_shared/design-tokens.yaml`  
- 手测 iOS（优先）+ Android 扫一眼  

### 明确本阶段不做

- 不改业务逻辑、路由、Chat 协议  
- 不整页重写 widget 树  
- 不把 Pro Max 的 landing pattern 写进 app  
- 不 merge 直到 go-gate + 实现 +（可选）ctsync  

---

## 8. 开放问题 — 推荐结论（可改）

| # | 问题 | **推荐结论** |
|---|------|----------------|
| 1 | accent 一步雾蓝？ | **是**，P0 与 paper 一起换 |
| 2 | theme/node 统一五色？ | **是** |
| 3 | border hair vs 实色？ | **优先 hair**；控件糊则 `#E8E4DC` 兜底 |
| 4 | 新 token？ | **要** `glass*`；`textQuaternary`/`borderStrong`/`shadow` 按需，少而稳 |
| 5 | destructive | **硬红保留**；clay = 软警告/草稿 |
| 6 | macOS rail | **另 topic**；本 topic 移动壳 |
| 7 | dark | **另 topic** |
| 8 | 验收 | **iOS 主**；Android 回归扫；mock 可选不挡 P0 |
| 9 | 玻璃强度 | **iOS 导航磨砂级**，不要高反光液态秀 |
| 10 | composer | **输入槽 paper 实色**；条可轻玻或仅顶部分割 |
| 11 | 主题树 | **行 + 当前 left bar**；不做满页 bento |
| 12 | `ThkGlassBar` | **P2 建议抽**，防复制 BackdropFilter |
| 13 | 先 mock？ | **不强制**；P0 token 即可眼验 |

**剂量默认：安静书房。** 若改「液态展厅」：提高 glass 透明度动画与光，需重开讨论。

---

## 9. 风险清单

| 风险 | 缓解 |
|------|------|
| ink-3 placeholder 对比 borderline | 实机；必要时 ink-3 略加深 |
| accent 闷 | 接受安静；Lab 仍鲜 |
| blur 卡顿 | 仅 chrome 条带；锁高度 |
| 暖纸+低透明度玻璃发脏 | fill≥0.55 暖白 |
| Pro Max 带偏成 marketing 站 | 第 5.4 节明确覆盖规则 |
| scope 膨胀 | 严守 P0→P3 |

---

## 10. 实现时 AI 必读（预写，开干贴进 chat README 小补）

- 改色只动 `app_colors.dart` + sync。  
- **禁止**在 `ChatScreen` 为「补偿 tab」改 `viewInsets`（已有键盘空隙 war）。  
- 键盘弹起时 shell **藏 tab**（iOS/Android 已对齐）。  
- 新玻璃组件必须：固定高度条带 + 降级不透明。  
- 五色实色不做第二按钮色。

---

## 11. 与相关文档关系

| 文档 | 关系 |
|------|------|
| `docs/_tmp/ui-flatten-polish*.md` | 结构/少色阶；本方案兼容，换温度 |
| `docs/_shared/design-tokens.yaml` | 实现后由 script 再生 |
| `docs/modules/chat/README` | 开干后 ctsync 小补键盘/玻璃纪律 |
| `docs/BRAND.md` | 若有品牌色冲突，ctsync 时对齐 |
| ui-ux-pro-max（Cursor skill） | 情报源，**非**色板真源 |

---

## 12. Go-gate 检查表（用户说「可以」前自检）

- [x] 色板表完整（用户暖米色）  
- [x] 四层模型与三风格取舍写清  
- [x] Pro Max 对照 + Cursor 路径（非 claude）  
- [x] AppColors 映射表  
- [x] 分期与推荐结论  
- [ ] 用户确认剂量（默认书房）或修改  
- [ ] 用户 **「开干 / 可以」** → litemode implement P0  

---

## 13. 讨论日志

| 日期 | 内容 |
|------|------|
| 2026-07-16 | 暖米色提出；worktree 讨论 only |
| 2026-07-16 | UI UX Pro Max 介绍；三风格名确认 |
| 2026-07-16 | 合成 Warm Paper Glass 四层草案 |
| 2026-07-16 | 用户要求 skill 路径用 **Cursor**（非 `~/.claude/skills`）；**补全本 md**；本机 `uipro init --ai cursor --global` 已就绪 |
| 2026-07-17 | 用户续聊「继续讨论美化 APP」→ 复盘 Warm Paper Glass 状态；仍待剂量 + 第 8 节确认 / go-gate |
| 2026-07-17 | 讨论：用 **goal 模式** 从 P0 干到 P3？先别干 — 见第 15 节 |
| 2026-07-17 | Goal 启动；**P0 色** 落地 commit `9f637cf`；停等用户 `P0 OK` |
| 2026-07-17 | 用户 `P0 OK`；**P1 卡** 落地 commit `aa92b2a`；停等 `P1 OK` |
| 2026-07-17 | 用户 `P1 OK`；**P2 玻** 落地；停等 `P2 OK` |
| 2026-07-17 | 用户反馈：面包屑消失、tab/sheet 不透明 → 修 Stack 叠 tab + 顶栏改回不透明 |

---

## 15. Goal 模式 × P0→P3（讨论，未开干）

### Goal 是什么（相对 litemode）

- Grok `/goal`：跨多轮盯一个 objective，用 `update_goal` 报进度；适合「一条主线做完」。
- 仓内 **litemode**：worktree + `_tmp` + 实现 + unit（无大测试）+ commit + ctsync-ask + merge。
- **二者可叠加**：goal 管「做到哪一刀」；litemode 管「怎么安全改仓」。

### 一气 P0→P3 的利弊

| | |
|--|--|
| **利** | 一次视觉闭环（色→卡→玻→光）；少重复开闸；goal 进度条清晰 |
| **弊** | 色没眼验就上 blur/光 → 难归因；scope 膨胀；单 commit 难拆；P2 性能/Android 降级易拖死整 goal |
| **风险** | goal 默认「冲到完成」会跳过「P0 手测再 P1」的人眼闸门 |

### 推荐形态（若用 goal）

**一个 goal，但内置 4 个硬闸门（每阶段必须停等人）**：

```text
Goal: Warm Paper Glass P0–P3（安静书房）
  P0 色  → 实现 → 人眼验 iOS → 你说「P0 OK」→ 才 P1
  P1 卡  → 同上
  P2 玻  → 同上（含 Android 降级扫一眼）
  P3 光  → 同上 → ctsync-ask → merge
```

- **不要**把 goal 写成「一次 commit 全上四层」。  
- **可以** goal 内多个 code commit（P0/P1/… 分 commit 更清晰），文档 commit 仍分开。  
- worktree 仍用 `ThkTree/warm-paper-tokens`；`_tmp` 为讨论真源。  
- 默认 **litemode**（无 dev-e2e 强制）；P2 玻璃若你要 integration 再升 fullmode。  
- Lab 豁免、dark/macOS 不进本 goal。

### 不推荐

| 写法 | 原因 |
|------|------|
| goal = 「把 app 做漂亮」无分期 | 无限扩张 |
| goal 一口气 P0–P3 无人眼闸 | 糊成一团无法回滚归因 |
| 四个并行 goal | 色/卡/玻互相改 `AppColors`/壳，易冲突 |

### 与「只开 P0」对比

| 策略 | 适合 |
|------|------|
| 只 P0 | 先看暖纸气质是否接受；最稳 |
| Goal P0→P3 + 阶段闸门 | 你已认书房剂量 + 第 8 节，想一次闭环但保留刹车 |
| Goal 只 P0–P1 | 色+卡，玻/光另 goal（性能敏感时） |

### 讨论结论（agent 倾向，待你改）

- **可以用 goal 串 P0→P3**，前提是 **每阶段 go-gate**，不是自动驾驶四连。  
- 更稳默认：**goal 目标写「完成 Warm Paper Glass P0–P3，每阶段等人确认」**。  
- 若你对雾蓝/纸色没把握：先 goal 只到 P0，P1+ 再开。

---

## 14. Next

1. 你确认或改第 8 节推荐结论 / 书房剂量。  
2. 拍板 goal 形态：A 只 P0 / B goal P0–P1 / C goal P0–P3+阶段闸门。  
3. 说 **「开干」** 或 **「开干 P0」** → 仅在本 worktree 改 `app_colors.dart` + sync（仍不自动 merge 除非流程要求）。  
3. 在 Cursor 里做 UI 时依赖：`~/.cursor/skills/ui-ux-pro-max`；跑：

```bash
python3 ~/.cursor/skills/ui-ux-pro-max/scripts/search.py "liquid glass" --domain style
python3 ~/.cursor/skills/ui-ux-pro-max/scripts/search.py "bento" --domain style
python3 ~/.cursor/skills/ui-ux-pro-max/scripts/search.py "knowledge tree notes flutter" --design-system -p "ThkTree" -f markdown
```

4. 续聊：`继续 topic warm-paper-tokens` 或本文件路径。
