# 愉悦体验改造方案（Delightful UX Whimsy）

> 状态：brainstorming 草稿（2026-07-09）
> 专家：惊喜喜（Delightful Experience Designer）
> 目标：在不破坏 ThkTree「克制 / 有序 / 人文 / 理性」品牌基因的前提下，提升交互惊艳度与用户满意度。

## 0. 设计原则：克制中的巧思

所有惊喜从产品自带隐喻「知识树 · 有机生长」长出，长在既有 token / 动效规范上，**绝不另立山头**：

- 颜色守 `design-system.md` §0.3「颜色有边界」——主题色只上结构，不铺背景；新增动效用中性色 + 现有 accent / NodePalette 派生色。
- 动效守 `design-system.md` §7 + `app_durations.dart`：快速 200 / 标准 300 / 慢速 500ms；「抽枝」类用 spring（需新增 spring 曲线）。
- 触感复用 `HapticService`（selection / light / medium / notification），不新增触感类型。
- **可访问性硬约束**：所有动效用 `MediaQuery.of(context).disableAnimations` 门控，关闭时退化为静态；文案走 `AppLocalizations`（i18n），对比度用现有 token。

## 1. 空态焕新（Delightful Empty States）

**问题**：全 App 无专用空态组件（搜索 / 主题树 / 笔记 / 实验室均为冷冰冰的逻辑空判断）。

**方案**：新增 `lib/ui/core/widgets/thk_empty_state.dart`，统一结构 = 极简「知识树」SVG 插画（细线树干 + 柔和树冠圆，sage/gold 派生色）+ 一行温暖主文案 + 一行行动引导。参数化 `variant` 与 `action`。

**落地位置**：
- `search_screen.dart` — 无结果
- `theme_list_screen.dart` / `theme_detail_screen.dart` — 首次无主题 / 主题下无节点
- 笔记列表 / `note_browse_screen.dart` — 无笔记
- `lab` 各屏（关键词排行 / 思维碰撞）— 无数据

**微文案（入 .arb）**：
- 搜索无结果：`这片森林还很安静` / `换个关键词，或种下你的第一个想法`
- 首次无主题：`你的知识树还没发芽` / `点下方按钮，种下第一个主题`
- 无笔记：`这里还没有笔记` / `把此刻的想法写下来吧`
- 实验室无数据：`还没有提炼出关键词` / `多聊几句，让思维碰撞出火花`

**Token**：插图用 `NodePalette` 派生（gold 树干 + sage 树冠），圆角 `AppSp.cardRadius`，文案 `AppTheme.subhead` / `caption1`。

## 2. AI 思考人格化（Personified AI Loader）

**问题**：`chat_screen` streaming 状态 = 纯 `CupertinoActivityIndicator` + 一行 "streaming" 文案，毫无人格。

**方案**：新增 `lib/ui/features/chat/widgets/thinking_loader.dart`，替换纯 spinner：
- 视觉：三颗 accent 圆点呼吸（呼应概念草图），或极简「抽枝」小动画；
- 文案：轮换俏皮提示语（每轮对话随机/轮换，避免闪烁干扰阅读）；
- 接入点：`chat_screen.dart` 发送区 loading、`message_bubble.dart` streaming 状态位。

**微文案（入 .arb，轮换池）**：
`正在抽枝展叶…` / `把你的想法慢慢想清楚` / `梳理中，稍候片刻` / `在组织语言…`

**Token**：圆点 `AppColors.accent`，周期用 `AppDur.streamingIndicator` 风格；reduced-motion 时退化为静态三点。

## 3. 微交互触感升级（Micro-interaction & Haptic Polish）

**方案**（地基级，提升整体「活」感）：
- `ThkButton`：按下时 `scale(0.97)` + 轻微弹性回弹（spring 曲线），复用 `HapticService.lightImpact`。
- 复制成功微庆祝：增强 `message_bubble.dart` 现有「复制→打勾变色」，加 200ms 弹性 pop（`AppDur.copyFeedback`）。
- 新建主题「抽枝」：主题创建完成那一刻，节点圆 `scale + 旋转抽枝` 动效 + `HapticService.lightImpact`（呼应概念草图右）。
- 列表展开弹簧：主题树展开/折叠改用 spring 曲线（现 `easeInOut` 200ms），更「有机」。

**新增 token**：`app_durations.dart` 补 `growth = Duration(ms: 500)` + `growthCurve = Curves.elasticOut`（或自定义 spring `Cubic`），供「抽枝」与按钮回弹共用。

## 4. 错误态温度（Warm Error Copy）

**问题**：`llm_error_card.dart` 文案功能化（network / timeout / rateLimited…），红色警示正确但零温度。

**方案**：
- **保留**红色警示与现有两种形态（card / compact）不变；
- 文案更有人味、带一句鼓励（仍走 `l10n`，按 `error.kind` 分支）；
- 新增极轻「摇一摇」提示动效（卡片入场轻微水平位移 1 次，非循环），`HapticService.notification()` 配合。

**微文案（入 .arb，按 kind）**：
- network：`网络打了个盹，再试一次？`
- timeout：`等得有点久，换个姿势重试？`
- rateLimited：`太快啦，稍歇一下再来`
- serverError：`服务端开了个小差，稍后重试`
- authFailed：`钥匙不对，去设置里看看？`
- 通用兜底：`出了点小状况，再试一次就好`

**注意**：保留 `LlmErrorKind.cancelled` 不渲染此组件的行为不变。

## 5. 可访问性与性能护栏

- 所有动效：`disableAnimations` 门控 → 静态降级；`Semantics` label 覆盖插画与状态。
- 字号：全部用 `AppTheme` / `AppSp` token，支持 Dynamic Type。
- 性能：插画用 `CustomPainter` / 轻量 SVG，不引入图片资源；spring 仅用于用户触发微交互，不进列表滚动热路径。
- i18n：所有新增文案加 `.arb` key 并重新生成 `app_localizations`。

## 6. 涉及文件

新建：
- `lib/ui/core/widgets/thk_empty_state.dart`
- `lib/ui/features/chat/widgets/thinking_loader.dart`

修改：
- `lib/ui/core/widgets/thk_button.dart`（按压弹簧）
- `lib/ui/core/theme/app_durations.dart`（spring / growth 曲线）
- `lib/ui/features/chat/chat_screen.dart` + `message_bubble.dart`（接入 ThinkingLoader + 复制庆祝）
- `lib/ui/features/themes/*`（新建主题抽枝）
- `lib/ui/core/widgets/llm_error_card.dart`（温暖文案 + 轻摇）
- `search_screen` / `theme_list` / `note_browse` / `lab` 各屏（接入 ThkEmptyState）
- `l10n/`（新增 .arb key）

## 7. 验收方式

- 编译通过 + `flutter analyze` 无新增告警；
- 关键路径手工验证：空态出现 / AI 思考动效 / 按钮按压 / 新建主题抽枝 / 错误态温暖文案；
- 可访问性：开启「减弱动态效果」后全部退化为静态、功能不受影响；
- i18n：中文本地化完整，无缺失 key。

## 8. 待确认

- 是否全量铺开四个 initiative，还是先做「空态 + AI 思考」最小惊艳包验证手感？
- 微文案语气边界：当前偏「温柔克制」，是否需要更俏皮一档（如 emoji 点缀）？注意 design-system §0 与可访问性对 emoji 的谨慎态度。
