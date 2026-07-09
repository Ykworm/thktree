# ThkTree × Yk酱 品牌一致性策略（v1 提案）

> 品牌守护者诊断 + 策略框架 + 从 APP 到个人品牌的阶梯路线
> 日期：2026-07-09 · 品牌守护者

---

## 0. 一句话结论

你现在的"品牌不一致"根源不在外部渠道，而在**产品自身**：设计文档定义的品牌（Riviera Blue + Terracotta、知识树隐喻、克制人文气质）与代码实际呈现的品牌（Indigo 主色、Slate 灰底、模板残留命名）已经分裂。先把 App 自己统一，它才能作为你个人品牌的"旗舰展品"。

---

## 1. 现状诊断（Brand Audit）

### 1.1 视觉层：文档 vs 代码 打架（一致性缺口 #1，最高优先级）

- 设计系统"宪法"（`docs/_shared/design-system.md` §1 / §2.1）明确主品牌色 **Riviera Blue `#183451`** + 强调 **Terracotta `#A9601C`**，中性底座目标 **Soft Ivory `#F3ECDE`**。
- 但代码真相源（`lib/ui/core/theme/app_colors.dart`）主色仍是 **Indigo `#6366F1`**，pageBg 仍是 **Slate 50 `#F8FAFC`**。文档自己都标注"迁移到 Riviera Blue 是独立代码迁移工单"。
- 结论：你**已经有品牌宪法，但它没被执行**。这是"自己跟自己不一致"的源头。

### 1.2 命名层：一个产品四种写法

| 位置 | 当前值 | 问题 |
|------|--------|------|
| `pubspec.yaml` description | `A new Flutter project.` | 模板残留，零品牌信息 |
| Android `android:label` | `thk_tree` | 下划线 + 小写，不像产品名 |
| iOS `CFBundleDisplayName` | 空 | 回退到包名 |
| l10n `appName` | `ThkTree` | 唯一正确写法 |

连名字都没统一，何谈跨渠道统一。

### 1.3 声音层：完全空白

全 repo 检索 `tagline / 品牌声音 / slogan / 口号` → 仅 TTS 文档误命中，无正式 verbal identity。有视觉"宪法"（design-system.md），**零文字"宪法"**：无 tagline、无品牌声音指南、无 messaging 架构。所有文案是功能性的。

### 1.4 关系层：产品品牌 vs 个人品牌 未定义

你是独立开发者（Yk酱），ThkTree 是你亲手打造的旗舰产品。但"ThkTree 品牌"和"Yk酱 个人品牌"的关系、谁为谁背书，从未规划。

---

## 2. 品牌基础定义（Brand Foundation · 提案，待确认）

### 2.1 关系定位（关键决策）

**ThkTree = Yk酱 个人品牌的旗舰展品（hero product）。** 个人品牌背书产品，产品反哺个人品牌。所有外部渠道（社媒 / 官网 / 商店）统一以"Yk酱 · ThkTree"的复合身份出现。

### 2.2 Brand Purpose（为什么存在）

让人机协作地构建"长在自己身上的"结构化知识体系——像树一样有机生长，而不是被信息洪流淹没。

### 2.3 Brand Vision（想去哪）

成为 AI-native 时代个人知识操作系统的标杆，让"思考有结构"成为默认体验。

### 2.4 Brand Mission（做什么）

为深度思考者提供一棵可生长、可检索、可对话的知识树；隐私优先、本地优先、人机协作。

### 2.5 Brand Values（价值观）

1. **有机生长（Organic）** — 知识如树，结构化但不僵化
2. **克制有序（Restraint & Order）** — 少即是多，层级即清晰
3. **实验包容（Experimental）** — 鼓励试错，Lab 精神
4. **人文温度（Humanist）** — 理性之外有温度，技术服务于人

### 2.6 Brand Personality（人格）

基于现有设计气质升级：克制 · 有序 · 实验性 · 人文 · 理性 —— 一个"安静但可靠的建筑师"。

### 2.7 Brand Promise（承诺）

你的知识，始终属于你；你的结构，始终清晰；你的工具，始终克制。

---

## 3. 品牌声音与信息架构（Verbal Identity · 提案）

### 3.1 Voice 特征

- **克制但有人味**：不堆术语、不喊口号，像靠谱的朋友讲解。
- **结构清晰**：先结论后展开，用层级而非喧哗表达。
- **实验精神**：坦诚分享"为什么这么设计"与取舍。

### 3.2 Tone 变体

- **产品内（UI 文案）**：安静、引导式、最少文字。
- **对外（社媒 / 博客）**：坦诚、有观点、带一点工程师的幽默。
- **危机 / 公告**：透明、负责、行动导向。

### 3.3 Messaging 架构（提案）

- **Tagline A**：「让思考，长成一棵树。」
- **Tagline B**：「你的知识，有机生长。」
- **Value Proposition**：本地优先、隐私安全的 AI 知识树，把对话、笔记、主题长成同一棵结构化的树。
- **Key Messages**：
  1. 对思考者：结构化不是束缚，是让复杂变清晰。
  2. 对隐私敏感者：数据在本地，模型你自选。
  3. 对开发者 / 同行：一个独立开发者的完整产品方法论。

### 3.4 命名规范（强制统一）

全渠道只允许一种写法：**ThkTree**（大驼峰，无空格无下划线）。`pubspec` description、Android label、iOS Display Name、商店页、社媒简介全部对齐。

---

## 4. 视觉一致性收口（Visual Consistency · 行动项）

### 4.1 第一刀：闭环 Indigo → Riviera

把 `AppColors.accent` 从 `#6366F1` 迁移到 **Riviera Blue `#183451`**，并补齐 **Terracotta `#A9601C`** 作为 Lab / 强调色。这是"让品牌宪法被执行"的最小高杠杆动作。

### 4.2 建立单一真相源

- `design-tokens.yaml` 已是结构化 token，但 `app_colors.dart` 与之不同步。
- 建议：以 `app_colors.dart` 为运行时唯一真相源，`design-tokens.yaml` 作文档镜像，加 CI 校验（`rg` 查 `CupertinoColors` 直引、断言 accent 值）。
- 深色模式目标态（design-system.md §2.8）已有定义，落地即可统一暗色表达。

### 4.3 视觉资产包（Brand Kit）

- 统一 App Icon（已有 lovart 资产）、Tab Icons、截图风格（统一留白 / 中性底座 / serif 大标题）。
- 产出一个可复用 brand kit：logo 变体（横 / 竖 / icon）、配色卡、字体规范、圆角 / 间距、动效时长。

---

## 5. 从 APP 到个人品牌的阶梯路线（Roadmap）

| Step | 阶段 | 目标 | 关键产出 |
|------|------|------|----------|
| 0 | 产品内收口（1–2 周） | 把 App 自己统一 | 迁移主色、统一命名、落地深色模式、补 UI 文案声音 → 内部一致的 ThkTree v1.0 |
| 1 | 品牌资产包（1 周） | 可复用素材 | Logo 变体 + 配色卡 + 字体 + 声音指南 + 命名规范 → brand kit / press kit |
| 2 | 个人品牌定位（思考） | 明确身份 | "Yk酱 = 独立开发者 / 知识管理产品人"，ThkTree 为旗舰案例；200 字简介 |
| 3 | 内容引擎（持续） | 用产品做内容 | 开发日志、设计决策复盘（你已有超强 docs 体系）、AI-native 知识管理方法论 |
| 4 | 跨渠道统一（持续） | 全渠道对齐 | App Store / Play / 官网 / GitHub / 社媒 同一名字、配色、声音、tagline |
| 5 | 品牌保护（尽早） | 护城河 | 域名、商标（App 名 + logo）、未授权使用监测 |

---

## 6. 建议的"最小第一步"

不要一口气做全部。建议从 **Step 0 的"视觉收口第一刀"（Indigo → Riviera 迁移）+ 命名统一** 开始——成本低、可见度高、立刻消除"自己跟自己不一致"的源头。

---

## 7. 下一步选项（你定方向，我来落地）

- **(A)** 直接产出可执行的《品牌基础定义 + 声音指南》正式文档（写入 `docs/`）
- **(B)** 给出 Indigo → Riviera 的迁移实施计划（代码改动清单 + 验收方式）
- **(C)** 先把命名三处（pubspec / Android / iOS）对齐成 `ThkTree`
- **(D)** 输出完整的 brand kit / press kit 规格

> 品牌守护者注：以上品牌基础定义为提案，需你确认后才是正式品牌资产。当前所有视觉数值均引自既有 `design-system.md`，未引入新设计，仅做收口与对齐。
