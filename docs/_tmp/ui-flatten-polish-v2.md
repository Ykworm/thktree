# UI 重设计 Brief v2 — `codex/ui-flatten-polish` 升级版

> 分支：`codex/ui-flatten-polish`（freemode）
> 状态：**v1 草稿已废弃**（"功能没考虑、配色没体系、不合理、没创意"），本文按 ardot-ui-design 方法论重写
> 工作流：brief 先拍板 → 视觉稿 → 落 Dart
> 上一版教训：把设计当换色，没建体系、没拆状态、没映射源码

---

## 第 0 节 设计原则（不可违反，做每页前先过一遍）

来自 `ardot-ui-design` 移动端 guidelines + 通用 web app system prompt（`guidelines-web-app.md`）：

1. **Purpose First**（第 1 节 webapp）— 一屏一主问题、一主动作。三页的「主问题」是下面 第 3 节 Screen Blueprint 里的 "Header" 注释。
2. **Constraint Over Decoration**（第 14 节 webapp）— 不服务于导航/理解/决策/行动的视觉元素**不存在**。mockup 里出现前先问：这回答了什么问题？
3. **System Status Visibility**（第 6 节 webapp）— 每个数据驱动面都要画 loading / empty / error / success + 业务专属态。绝不能只画 happy path。
4. **Action Hierarchy**（第 7 节 webapp）— 一主一次，破坏性动作与"罕见动作"必须视觉降级或进 overflow 菜单。
5. **Density Intentionality**（第 9 节 webapp）— 一屏内密度模式统一，不混 air/medium/compact。
6. **Recognition Over Recall**（第 5 节 webapp）— 任何操作必须当下可见，不靠用户记忆。
7. **Mobile Vertical Stack**（mobile guidelines）— Status Bar（62px SF Pro/Inter）→ App Content（**单 wrapper** + gap 控距，标题字号全 app 统一）→ Bottom Bar（pill-style 3-5 tabs，4-5 个为止）。
8. **状态 first-class**（mobile guidelines 明确写）— 4 states 不是装饰，是必经路径。

---

## 第 1 节 设计 Token 体系（**不是抄 hex，是建角色**）

### 1.1 现状（app_colors.dart 已有的，按角色重命名）

| 角色 | light 值 | dark 值 | 用途 | 用法纪律 |
|---|---|---|---|---|
| `pageBg` | `#F8FAFC` Slate 50 | `#020617` Slate 950 | 屏幕底色 | **唯一**页面级背景 |
| `surface` | `#FFFFFF` | `#0F172A` Slate 900 | 卡片/气泡/输入框底 | 浮在 pageBg 上 |
| `surfaceMuted` | `#F1F5F9` Slate 100 | `#1E293B` Slate 800 | 二级表面（funcbar、工具 chip 背景、思考块、tabBar） | 比 surface 低一阶 |
| `textPrimary` | `#1E293B` Slate 900 | `#F1F5F9` Slate 100 | 标题/正文 | 一屏不超 1 处作为"主"字重 |
| `textSecondary` | `#64748B` Slate 500 | `#94A3B8` Slate 400 | 副文/时间/状态 | |
| `textTertiary` | `#94A3B8` Slate 400 | `#64748B` Slate 500 | 占位/禁用 | |
| `border` | `#E2E8F0` Slate 200 | `#334155` Slate 700 | 0.5–1px 描边 | 默认隐藏，需要区分时启用 |
| `accent` | `#6366F1` Indigo | 同 | 主交互（按钮/链接/选中态） | **全 app 唯一**强调色 |
| `accentLight` | `#EEF2FF` | `#1E1B4B` | 用户气泡底、tag 背景 | 始终是 accent 的低饱版 |
| `accentDeep` | `#4F46E5` | 同 | pressed/active | 触发态独用 |
| `destructive` | `#DC2626` | 同 | 删除/失败 | 只在破坏性操作 |
| `success` | `#34C759` | 同 | 成功/sent | 状态徽章 |
| `scrim` | `#80000000` 50% 黑 | 同 | 模态遮罩 | 唯一 |
| `elevationShadow` | `#1F000000` 12% 黑 | 同 | 浮层阴影 | 浮层必用 |

**纪律**：除以上外，**不准新建颜色 token**。要加先回写 app_colors.dart。

### 1.2 主题 5 色（**分类色，不是装饰色**）

```
champagneGold  #C4A77D  香槟金
warmGray       #8E8B82  烟灰
dustyRose      #A89090  玫瑰灰
sageGray       #8B9080  橄榄灰
slateBlue      #6B7B8E  蓝灰
```

**用在哪**：
- ✅ 主题列表的"分类条/封面"（按 themeId hash 分配）
- ✅ 知识树节点圆点
- ✅ 节点卡片 circle/title/subtitle 的三联色（NodePalette 已存在）
- ✅ AppBar "回到"指示器（用当前节点 palette）
- ❌ **不**做大面积背景（不抢中性底）
- ❌ **不**做文字颜色（可读性差、撞 accent）
- ❌ **不**做按钮色（破坏全局 accent 一致性）
- ❌ **不**出现在系统状态色（success/error/...）里

**tint 规则**：每个主题色有 `tintForTheme`（15% 饱和 + 85% 白），只能作为"该主题的视觉锚点"用，不大面积铺。

### 1.3 主题 5 色 + tint 在三页里的具体映射

| 位置 | 用法 | 备注 |
|---|---|---|
| 主题列表卡片 | tint 当卡片底 + 主色当左侧 4px 边条/顶部色条 | 不上图标主色背景（避免大块色块） |
| 知识树节点圆点 | 主色 8px 实心圆 | |
| 节点卡片（`NodePalette`） | circle 主色 / title 深版 / subtitle 中版 | 已存在，照用 |
| 主题详情（未来） | 顶部 banner 用主色 → 渐变到 surface | 留口子 |

### 1.4 缺什么（**待补 token**，不影响 v2 视觉稿，但 mockup 里要标 ⚠️）

- `info`（蓝/中性）— warning/distinguish from accent
- `warning`（琥珀）— destructive vs warning 区分不清
- `appBar` / `appBarTint` — 当前没 AppBar 专用 token
- `disabled` — 按钮禁用态没有明确颜色
- dark mode 下 `success` `destructive` 的对比度需校验
- `focusRing` — 输入框聚焦 ring 没独立

---

## 第 2 节 三页 Screen Blueprint（每页按 mobile guidelines 拆）

### 2.1 Chat 对话页

**主问题**："我刚问了什么 / AI 回了什么 / 我下一步能做什么"

**Status Bar**：标准 62px，SF Pro / Inter 时间，不在内容区画（OS 控）

**App Content**（单 wrapper，gap=24px 主要分段、12px 分段内）：
- **Header**（sticky, height=56px）：
  - 左：返回箭头（24px icon，accent）
  - 中：节点标题（Title, 17px/600）+ 副行"模型·摘要"（12px/400, textSecondary）
  - 右：⋯（20px，更多菜单——含「摘要、深度思考、模型切换、复制节点、删除」按 Action Hierarchy 排序）
- **Breadcrumb**（gap 内嵌套 row, height=32px）：仅在 `parent != null` 或节点数 ≥ 2 时显示；不是 sticky；行内 ellipsis；`tap 任何一段 → Navigator.popUntil 到该层`
- **Question Header**（auto-generated, height=auto, paddingTop=8, paddingBottom=12）：
  - "你问了什么"（Caption, 12px, textTertiary）
  - 问题正文（Body, 15px, textPrimary），单气泡铺满
  - **这个不是气泡，是"问题摘要头"**——回答区第一条就是它
- **Stream Area**（flex 1, scroll）：
  - **Assistant Bubble**（surface + 0.5px border, padding=14/16, radius=16, maxWidth=screen·0.86）
    - 顶部元信息 row：12px 模型名（textTertiary） · 状态徽章（streaming→打点动画、done→success 绿点、failed→destructive 三角）
    - Markdown body（聊天记录里图片/代码块/思考折叠都在这里）
  - **操作行**（collapsed by default, tap bubble 展开 200ms）：复制/朗读/分享/转笔记/重生成，**每行 icon 18px + 文字 12px**，默认隐藏，点击/长按气泡才出现
  - **User Bubble**（accentLight, padding=14/16, radius=16, maxWidth=screen·0.78）：图片+正文；底部小 metadata "12:34 · 已发送"
  - **Failed Bubble 替换态**：destructive 描边 + 顶部 banner "生成失败 · 重试"
  - **Streaming 态**：底部"停止"按钮浮在 input 上方
  - 消息之间 gap=12px
- **Input Area**（fixed bottom, single unified card, padding=10/12, radius=20, surface + 1px border）：
  - **行 1**（gap=8px）：
    - 左：📎 附件（36px 圆按钮，surfaceMuted 底）
    - 中：TextField（flex 1, height 36, radius 18, surfaceMuted 底，placeholder "消息 / 按 ⌘+Enter 发送"）
    - 右：🖼 图片（36px）+ 发送（36px, accent 底, white ↑）
  - **行 2（chips）**（gap=8px, 12px caption）：
    - 联网搜索 / 深度思考 / 添加图片 / 模型选择（4 个；选中态 = accent 边 + accentLight 底 + accent 文字）
  - **绝对**不跟 Before 一样：funcbar 分离 + 输入区分离。4 容器 → 1 卡片，行内部分两行。
- **Empty State**（无任何消息时）：插画占位（surfaceMuted 圆 + 主题色 4px 横条）+ "开始新对话" 引导文 + 主按钮 "开始"

**Scroll 行为**：stream 单一垂直滚动；新消息自动滚到底（除非用户主动上滑，下方出现"↓ 3 条新消息" 浮动按钮）

**Bottom Bar**：**不存在**（chat 是节点内部，不参与底部 tab 切换；返回到主题列表才是底部 tab）

---

### 2.2 主题列表页

**主问题**："我有哪些主题 / 我想去哪个"

**Status Bar**：标准

**App Content**（单 wrapper, gap=0，整页是 grid）：
- **Header**（sticky, 56px）：
  - 左：标题"主题"（Title, 17px/600）
  - 右：⋯（设置/排序方式）+ ➕（新建主题，主按钮）
- **Sort / Filter Strip**（height=44px, horizontal scroll）：按"最近活动 / 字母 / 颜色"排序 chip + 多选切换
- **Theme Grid**（padding=16, gap=14px, 2 columns）：
  - **Theme Card**（height=160px, padding=16, radius=16, surface + 1px border, position relative）：
    - 顶部 4px **主色条**（用 `colorForTheme(themeId)`，与卡片 tint 同色，**渐变到 transparent 60%**）
    - **主图标**（40x40, radius=10, 主色实心底, 白色 emoji）
    - **Title**（15px/700, textPrimary）
    - **Subtitle**（11px/400, textSecondary, 1 行 ellipsis = `lastMessagePreview`）
    - **Meta footer**（10px, textTertiary, 推到卡片底部）："2 小时前 · 12 条消息"
    - **长按菜单**（overlay sheet）：重命名、改颜色、合并、删除
  - **Loading State**：4 张骨架卡（surfaceMuted 块 + pulse）
  - **Empty State**（无主题）：中心插画（surfaceMuted 大圆 + 渐变）+ "还没有主题" + 主按钮"创建第一个"
  - **Multi-select 态**（长按触发）：卡片右上角出现 ☐ → ✓，底部出现 action bar（合并/删除/导出）
- **Search Bar**（sticky bottom？不，是头部下方展开 320ms height 0→48）：聚焦时取代 sort strip

**Bottom Bar**：pill-style Tab Bar，3 个 Tab：搜索/主题（active）/笔记；4 个 Tab：搜索/主题/笔记/Lab。**Tab 标 18px icon + 10px label uppercase**, active=accent 实心胶囊。

---

### 2.3 知识树页（**用户最终拍板：纯缩进 + 主题色圆点，无连线**）

**主问题**："这棵树下有什么 / 当前在哪个 / 怎么跳"

**Status Bar**：标准

**App Content**（单 wrapper, gap=0）：
- **Header**（sticky, 56px）：
  - 左：返回箭头（24px）
  - 中：当前节点标题（Title 17px/600）
  - 右：▦ 切换树形/平铺（18px icon, 切换 viewMode）+ ⋯（节点菜单：重命名/改颜色/删除/移动）+ ➕（新建子节点）
- **Tree List**（padding=0, **每行 44px**）：
  - 缩进 `paddingLeft = 16 + depth·28px`（保持现状）
  - **Row 内容**（horizontal, gap=10px, vertical center）：
    - 主题色圆点 10x10px（用 `colorForTheme`，保持现状）
    - 节点标题 15px/500，textPrimary；当前行加 indigo 文字 + 左侧 3px 边条
    - 右：≡ 拖拽手柄（保持现状）
  - **展开/折叠**：左侧 ▶ 三角形 icon（8px, 节点有子项时显示）
  - **空白行处理**：根节点展示一行 "未分类"，但当 `themes` 只有一个时去掉这层
- **Scroll 行为**：保持当前位置；点新节点 → 滚动到目标行
- **Empty State**（树为空）：不显示（这个页面从主题详情进入，树就是从该节点 build 的）
- **Loading State**：6 行骨架（surfaceMuted 横条）
- **Error State**：网络/解析错误时显示 "加载失败 · 重试" 横幅

**Bottom Bar**：同 2.2（pill-style, 主题 tab active）

---

## 第 3 节 状态矩阵（**这是 v1 漏掉的关键**）

### 3.1 Chat 状态（8 态）

| 状态 | 触发 | Layout 表现 | 关键元素 |
|---|---|---|---|
| `loading` | 进入节点 | 4 张 skeleton 消息 | 灰色块流 |
| `empty` | 全新节点 | 引导插画 + 主按钮"开始" | surfaceMuted 圆 + 主题色装饰条 |
| `streaming` | AI 在生成 | 助手气泡底出现打字点 + 输入区上方浮"停止"按钮 | success 点动画 |
| `idle` | 流结束 | 气泡静态化，状态徽章变 "已发送" | success 绿点 |
| `sending` | 用户已发未到 AI | 用户气泡出现 loading spinner + 状态 "发送中" | 灰色 spinner |
| `failed` | AI 错误 / 网络断 | 气泡 destructive 描边 + 顶部 banner "生成失败 · 重试" | 红色描边 |
| `retrying` | 用户点重试 | 旧气泡 dim（alpha 0.5）+ 新气泡流式出现 | 重试行 |
| `partial-error` | 流中断 | 已收到的部分保留，底部追加 "已中断 · 重试/继续" | partial state |

**纪律**：v1 mockup 只画了 idle 单一态，**这是核心失败点**。

### 3.2 主题列表状态（5 态）

| 状态 | Layout 表现 |
|---|---|
| `loading` | 4 张 skeleton 卡片 |
| `empty` | 引导插画 + "创建第一个" 主按钮 |
| `normal` | 2 列卡片网格 |
| `multi-select` | 卡片右上角 checkbox 出现，底部 action bar 滑入 |
| `search-empty` | 网格被空结果状态替换（保留搜索栏） |

### 3.3 知识树状态（4 态）

| 状态 | Layout 表现 |
|---|---|
| `loading` | 6 行 skeleton |
| `normal` | 树（无连线 + 主题色圆点） |
| `error` | 顶部 banner "加载失败 · 重试" |
| `menu-open` | 节点长按：浮动 action sheet（重命名/改色/删除/移动） |

---

## 第 4 节 功能映射（**改设计要能改代码，否则是装饰**）

### 4.1 Chat 页组件 → 源码

| 组件 | 源码 widget | 关键状态 | callback |
|---|---|---|---|
| AppBar | `chat_screen.dart` 自绘 | 节点名、模型、菜单可见性 | `onModelTap`, `onMenuAction` |
| Breadcrumb | `chat_screen.dart` 内 | 路径数组 | `Navigator.popUntil` |
| Question Header | 由 `auto_title_controller` 生成 | 一行文字 | 显示，不可编辑 |
| Assistant Bubble | `MessageBubble` (`role=assistant`) | status: `pending/streaming/done/failed` | `onCopy`, `onTts`, `onShare`, `onNote`, `onRetry` |
| User Bubble | `MessageBubble` (`role=user`) | images[] + body | `onLongPress` 编辑/删除 |
| 操作行 | `MessageBubble` 内部展开动画 | visible | 上面 5 个 callback |
| Input Card | `ChatComposer` | text, attachments, chips, sendEnabled | `onSend`, `onChipToggle` |
| Empty | `chat_screen.dart` 内部 | isFirstOpen | `onStart` |

**不允许**：
- ❌ 加新的"美观装饰"（渐变、阴影、动画）没有 callback 对应
- ❌ 用 emoji 替代有语义的 icon（emoji 是 fallback，不是设计语言）

### 4.2 主题列表组件 → 源码

| 组件 | 源码 widget | 关键状态 | callback |
|---|---|---|---|
| Tab Bar | `router.dart` 已有 | currentIndex | tab 切换 |
| AppBar | `theme_list_screen.dart` | 标题、菜单 | `onAdd`, `onSort` |
| Sort/Filter Strip | 待加 | sortMode, filterMode | `onSortChange` |
| Theme Card | `theme_list_screen.dart` 改 | themeId, lastPreview, lastTime | `onTap` (进详情), `onLongPress` (多选菜单) |
| Multi-select Action Bar | 待加 | selectedIds[] | `onMerge`, `onDelete`, `onExport` |
| Empty | 待加 | isEmpty | `onCreate` |

### 4.3 知识树组件 → 源码

| 组件 | 源码 widget | 关键状态 | callback |
|---|---|---|---|
| AppBar | `full_tree_screen.dart` | 标题、viewMode | `onViewModeToggle`, `onAdd`, `onMenu` |
| Tree Row | `full_tree_screen.dart` | depth, isCurrent, isExpanded | `onTap` (跳节点), `onLongPress` (菜单), drag |
| 拖拽手柄 ≡ | `ReorderableListView` | order | `onReorder` |
| Empty | 根节点展示 "未分类" | — | `onAdd` |

---

## 第 5 节 不做清单（**Constraint Over Decoration**）

mockup 阶段，每加一个元素前过一遍这个清单：

- ❌ 大渐变 / 玻璃拟态 / 发光（项目调性是 low-saturation 哑光）
- ❌ 主题色当按钮底色（破坏 accent 一致性）
- ❌ Emoji 替代语义 icon（除非 placeholder）
- ❌ "好看的"占位插画（用 surfaceMuted 圆 + 主题色条够了）
- ❌ 装饰性 divider（border-line 已统一）
- ❌ 多层阴影叠加（elevationShadow 一档足够）
- ❌ 动画（无 callback = 无意义；状态切换有动效即可）
- ❌ 自定义 status bar（OS 控）
- ❌ 三种以上圆角值（统一 12/16/20 三档）
- ❌ 文字颜色超过 4 档（primary/secondary/tertiary + accent + destructive）

---

## 第 6 节 决策链（v1 → v2）

- v1: 知识树加连接线（**撤销**，用户改主意）
- v1: 主题色卡片网格 2 列（**保留**）
- v1: Chat 4 容器 → 1 卡片（**保留并强化** + 内部 2 行结构）
- v1: 操作行默认收起（**保留**）
- v1: 面包屑降级（**保留** + 加"仅 depth ≥ 2 显示"规则）
- **新增**：配色 token 角色化、状态矩阵、功能映射、不做清单
- **撤销**：v1 草稿的"现状诊断"中的"对比微妙但够用"等凭印象判断——v2 全部由源码 + 截图支撑

---

## 第 7 节 验收方式

- **必做**：brief 逐节拍板（用户逐条 OK）→ 才出视觉稿
- **必做**：视觉稿必须覆盖所有列出的状态（v1 只画 happy path 失败）
- **必做**：每个组件都能回答"对应源码哪个 widget"
- **不做**：覆盖率高的单元测试（项目已有；不重复）
- **不做**：把 mockup 当最终交付（mockup 是 brief 的可视化）

---

## 第 8 节 下一步

1. ⏳ 用户拍板 第 1 节（token）+ 第 3 节（状态）—— 这是 v1 没做到的根因
2. ⏳ 出 mockup：ardot canvas（已恢复，fileId 702356760232399）三页 + 各页关键状态
3. ⏳ 拍板 mockup → 落 Dart
