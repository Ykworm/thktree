<p align="center">
  <img src="./assets/readme/banner_en.png" width="100%"
       alt="ThkTree - Let Thoughts Grow into a Tree">
</p>

<p align="center">
  <strong>English</strong> · <a href="#zh-cn">简体中文</a>
</p>

<a id="en"></a>

---

## What is ThkTree?

ThkTree is an AI knowledge-tree app that organizes LLM conversations into a nested, searchable, locally-grown tree — privacy-first, bring your own model.

**Core value**: Human–AI collaboration to build a structured knowledge system that grows *on you* — organic like a tree, not drowned in information overload.

### Introduction

<a href="https://youtu.be/7DeELqEsagA" target="_blank" rel="noopener noreferrer"><img src="https://img.youtube.com/vi/7DeELqEsagA/hqdefault.jpg" alt="ThkTree introduction"></a>

---

> During the holiday I wanted to vide code an app. I didn't overthink it—I went with the first idea that popped into my head: tree-shaped conversations + Flutter.
>
> **Product positioning:**
> Typical LLM chats are mostly ephemeral, and this app is no exception! It's just a way to organize your thinking. There's no server, which means data is less likely to leak. As you build the tree, your understanding of the information deepens. The app's output is wiki—you can export wiki to your PC and use whatever tools you like to consolidate and analyze, for learning and reinforcement—e.g. Claude Code, Grok build, Codex, Kimi Code, WorkBuddy ...
>
> **Biggest problem today:**
> As a solo developer it's hard to make every feature solid—and on iOS in particular, if the app goes to the background you may not receive the full LLM response. Compatibility testing across different device models hasn't been done yet.
>
> **Plan:**
> 1.x is a simple tool
>
> 2.x doesn't replace 1.x—it adds a server side, but probably not the traditional web-dev pattern of simply calling APIs
>
> **Project status:** The holiday break is wrapping up and my focus is shifting back to work, so updates may come at a slower pace for a while. ThkTree is still actively maintained — issues and PRs are welcome. If you're interested in the idea and want to help polish features, fix bugs, or improve docs/tests, I'd love to collaborate.
>
> **About Lab:** it's the entry point for experimental features, aimed at developers
>
> **About the default palette:** Just before release I noticed the Morandi palette looked a lot like the colors I'd picked when I first started the app—it felt comfortable on the eyes—so I had AI set it as the default.
>
> **Why Flutter?**
> 1. It was a tech stack choice I once recommended to a team
> 2. While reading about 3D, I came across Toyota's Fluorite—a project that supports console-grade 3D rendering
> [Toyota is using Flutter to build the game engine Fluorite - 恋猫 on Zhihu](https://zhuanlan.zhihu.com/p/2007240745833210390)
> BTW: Recently there's another interesting project:
> [Flutter 3D rendering: new options and use cases - 恋猫 on Zhihu](https://zhuanlan.zhihu.com/p/2063773097333895339)
>
> Strictly speaking I don't really know Flutter or Dart—I once wrote a simple bridge between Dart and Java. That feeling of familiar yet unfamiliar, actually very unfamiliar—isn't that perfect for vide coding practice?

---

## Features

### Markdown-first information management

- **Markdown as the source of truth**: chats live in `session.md`, notes are local Markdown; SQLite holds metadata, relations, and FTS only
- **Readable & exportable**: view/copy raw session Markdown; aggregate a tree into Wiki and export zip to your PC
- **Markdown in, Markdown out**: doc split turns Markdown documents into tree nodes; Lab reports are saved as Markdown too

### Knowledge tree (Themes)

- **Multi-theme management**: Each theme is a node tree for a cluster of related thinking
- **Tree sessions / nodes**: One node = one chat or one note; nest, expand, drag
- **Merge & new chat**: Merge up to 3 chats into a new branch to reorganize ideas

  In the tree view, select up to 3 chats to merge their full conversation history into a new node. The merged messages become the starting context—add a new question and send everything to the LLM together, turning scattered threads into one conversation.

- **Tree → Wiki snapshot**: Aggregate a tree’s chats into a readable “book”; browse by chapter and export zip
- **Doc split**: Give a Markdown document to the LLM; auto-split into tree-shaped chat nodes

Think about how a tree *grows*: when you create a branch, parent and child may relate through different levels of inheritance.

1. **Level 0** — structural only: linked in the hierarchy; content is entirely yours to shape
2. **Weak** — a summary of the full context or the selected text
3. **Semi-strong** — inherits the selected text as-is
4. **Strong** — inherits the full context or the selected text

![ThkTree tree logic — inheritance levels and node merge](./assets/readme/tree-logic.png)

### Chat

- **Streaming**: SSE streaming, Markdown / LaTeX rendering, image upload and vision models
- **Branch**: Branch instantly from any message or selection to compare ideas

  <a href="https://youtube.com/shorts/ek68qDjBKrw?feature=share" target="_blank" rel="noopener noreferrer"><img src="https://img.youtube.com/vi/ek68qDjBKrw/hqdefault.jpg" alt="Branch demo"></a>

- **Web search**: Native search on KIMI / MIMO / DeepSeek / Doubao / xAI Grok, etc.
- **Deep thinking toggle**: Per-session (DeepSeek, MiniMax, etc.); some models lock server-side
- **Pin panel**: Pin key messages or notes to the screen edge for cross-chat reference

  Pin important messages or notes (up to 5). Tap the right-edge handle to open the panel and reference them across branches and tabs—jump to source, save as a note, or unpin anytime.

  <a href="https://youtube.com/shorts/cnm61xIWyK8?feature=share" target="_blank" rel="noopener noreferrer"><img src="https://img.youtube.com/vi/cnm61xIWyK8/hqdefault.jpg" alt="Pin panel demo"></a>

- **iOS background recovery**: ~30s grace when backgrounded; auto-resend on foreground if killed mid-stream

### Notes

- **Markdown notes**: Local editing, required title, table and heading toolbar
- **Chat-to-note**: Save a good reply as a note in one tap
- **LLM title / move theme**: Keep structure clear across themes

### Search

- **Full-text search**: SQLite FTS5 + BM25 across chats and notes
- **Theme / node title filter**: Locate quickly inside a tree

### Lab

- **Keyword leaderboard**: LLM extracts keywords → aggregate scores → see what you think about
- **Input summary**: Scan history and generate a Markdown analysis report
- **Spark collision**: Random keyword pairs → one-line sparks from the LLM → tap to start a new chat

---

## Tech stack

| Area | Choice |
|------|--------|
| Framework | Flutter (Cupertino-only UI) |
| State | Riverpod |
| Routing | go_router (declarative + deep linking) |
| Storage | Markdown body + SQLite metadata / relations / FTS5 |
| Write safety | FileWriteQueue single-writer (atomic streaming append) |
| LLM | SSE streaming + `flutter_secure_storage` for keys |
| Rendering | `gpt_markdown` + `flutter_math_fork` (LaTeX) |
| Platform | `image_picker`, iOS MethodChannel (background grace / TTS) |

### Code layout

```
lib/
  domain/                   # Theme, Node, entity ids
  data/
    models/                 # LLM config, serialization DTOs
    services/               # LLM client, SQLite/FTS, file I/O, pins, clips, keywords, wiki export…
    stores/                 # Riverpod notifiers (session, theme, settings…)
  ui/
    core/
      router.dart           # go_router routes & shell
      app_services.dart     # DB / paths bootstrap
      shared/               # composer, branch flow, title suggestion, selection…
      theme/                # AppColors, AppTheme
      widgets/              # design-system components
    features/
      themes/               # theme list, tree view, merge chat, full tree
      chat/                 # streaming chat, auto title, pin panel widgets
      notes/                # browse, editor, detail, location picker
      search/               # FTS search screen & shared SearchContent
      lab/                  # keyword ranking, input summary, thinking collision
      llm/                  # provider list & detail
      settings/             # LLM setup, defaults, backup hooks, onboarding
      wiki/                 # tree → wiki reader
      doc_split/            # markdown doc → tree nodes
      backup_restore/       # zip import/export
      about/
    platform/               # Android-specific UI hooks
  l10n/                     # zh / en (ARB + generated)
```

Four bottom tabs: **Search / Themes / Notes / Lab**; settings via gear on the search screen.

---

## Quick start

```bash
# 1. Clone
git clone <repo-url>
cd thk_tree

# 2. Onboarding check
python3 tools/check_onboarding.py

# 3. Dependencies
flutter pub get
cd ios && pod install && cd ..

# 4. Run
flutter run
```

> **First launch**: **ThkTree** shows a one-time prompt guiding you to **Settings → LLM** to add model providers and set default models. ThkTree uses LLMs for chat, title generation, and summarization—you can tap **Later** and configure anytime in Settings.

<a href="https://youtube.com/shorts/vckfravPXek?feature=share" target="_blank" rel="noopener noreferrer"><img src="https://img.youtube.com/vi/vckfravPXek/hqdefault.jpg" alt="LLM setup demo"></a>

> Environment, skills, and architecture: [`docs/PROJECT.md`](docs/PROJECT.md), [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`docs/FEATURES.md`](docs/FEATURES.md).

---

## Philosophy

> Human–AI collaboration to build a structured knowledge system that grows on you — organic like a tree, not lost in the flood.

Most tools flatten chats, notes, and sources into one stream. ThkTree’s answer is a metaphor: **knowledge is a tree**.

- **Organic** — Structured but not rigid; nest, branch, experiment
- **Restraint & order** — Hierarchy through whitespace and type, not noise
- **Experimental** — Lab spirit; share trade-offs and war stories
- **Humanist** — Privacy, tools that serve people

**Promise**: Your knowledge stays yours; your structure stays clear; your tool stays restrained.

---

## Positioning

| Dimension | Stance |
|-----------|--------|
| Platform | iOS (TTS, background recovery are native iOS capabilities) |
| Data | Local-first, no ThkTree server; on iOS, `Documents/thktree/` is included in **iCloud Backup** when enabled; API keys not stored in plain text |
| Models | Your provider and model, not vendor lock-in |
| Character | “Quiet, reliable architect” — restrained, ordered, human |

**iOS backup:** App data lives under `Documents/thktree/`. With iCloud Backup turned on, it is backed up to **your** iCloud account (not to ThkTree). See [Privacy Policy](./docs/legal/privacy-policy-en.md).

---

## Docs

- Architecture & doc map: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- Feature status: [`docs/FEATURES.md`](docs/FEATURES.md)
- Security & privacy notes: [`docs/SECURITY-en.md`](docs/SECURITY-en.md) · [中文](docs/SECURITY-zh.md)

## License

ThkTree is released under the [MIT License](./LICENSE).

| Document | English | 中文 |
|----------|---------|------|
| Privacy Policy | [privacy-policy-en.md](./docs/legal/privacy-policy-en.md) | [privacy-policy-zh.md](./docs/legal/privacy-policy-zh.md) |
| Terms of Service | [terms-of-service-en.md](./docs/legal/terms-of-service-en.md) | [terms-of-service-zh.md](./docs/legal/terms-of-service-zh.md) |

> Always **ThkTree** (PascalCase). Not `thk_tree`, `thktree`, or `Thk Tree`.

---

<p align="center">
  <a href="#en">English</a> · <strong>简体中文</strong>
</p>

<a id="zh-cn"></a>

## 什么是 ThkTree？

ThkTree 是一款 AI 知识树 App，把 LLM 对话组织成可嵌套、可检索、本地生长的树——隐私优先、模型自选。

**核心价值**：让人机协作地构建「长在自己身上的」结构化知识体系——像树一样有机生长，而不是被信息洪流淹没。

### 简介

<a href="https://www.bilibili.com/video/BV1Lp3P6PE8k" target="_blank" rel="noopener noreferrer">▶ 在 Bilibili 观看 ThkTree 简介</a>

---

> 在假期里面我想vide coding一个APP，不多想，选了一个心里面冒出来的第一个想法：树形对话 + Flutter。
>
> 产品定位：
> 典型的LLM对话基本都是临时的，而这个APP也不例外！它只是方便组织思想而已，而且没有服务端，意味着数据不容易泄露；在构建tree的过程中用户对信息的理解会加深；而APP的输出是wiki，wiki可以导出到PC，用用户喜欢的工具去沉底和分析，进行学习巩固，例如claude code，Grok build， codex， kimi code ， WorkBuddy ...
>
> 现存最大的问题：
> 由于个人开发难以保证每个功能都good，而且尤其在iOS端，APP切换后台后可能就无法完整接收完LLM的输出；也没有做不同机型的兼容性测试
>
> Plan：
> 
> 1.x 版本是简单的工具
>
> 2.x 并非替代1.x ，而是会增加的服务端，但应该不是传统的Web开发的简单call API的方式
>
> **项目状态：** 假期即将结束，生活重心会回到工作上，接下来一段时间更新节奏可能会慢一些。ThkTree 仍会持续维护，欢迎提 Issue 和 PR。如果你对这个方向感兴趣，愿意一起完善功能、修 bug、补文档或测试，非常欢迎一起协作。
>
> 关于Lab，它是各种实验性功能的入口，面向开发者
>
> 关于默认配色：临发布前发现莫兰迪色系跟我刚做 App 时选的配色很像，看起来比较舒服，于是让 AI 把它设为 App 的默认配色。
>
> why Flutter？ 
>
> 1.是我曾经给某团队的技术选型
>
> 2.之前在看3D方面的资料，看到丰田有一个叫 Fluorite 的“支持主机级 3D 渲染的项目 ”
> 丰田正在使用 Flutter 开发游戏引擎 Fluorite - 恋猫的文章 - 知乎
> https://zhuanlan.zhihu.com/p/2007240745833210390
>
> BTW： 最近 也有另一个有趣的项目：
> Flutter 3D 渲染的全新选择和应用场景 - 恋猫的文章 - 知乎
> https://zhuanlan.zhihu.com/p/2063773097333895339
>
> 但严格意义上我并不会Flutter or Dart，只是曾经简单写过一个Dart 与 Java 之间的bridge 
> 这种既熟悉又陌生实际很陌生的感觉，不正好是适合vide coding 练手吗？

---

## 功能特性

### 以 Markdown 为核心的信息管理

- **正文即 Markdown**：对话存为 `session.md`，笔记本地 Markdown 编辑；SQLite 只管元数据、关系与 FTS 检索
- **可读可导出**：对话可查看原始 Markdown、复制全文；Tree 可聚合成 Wiki 并 zip 导出到 PC
- **Markdown 进、Markdown 出**：文档拆分把 Markdown 文档拆成树节点；Lab 分析报告也以 Markdown 沉淀

### 知识树（Themes）

- **多主题管理**：每个「主题」是一棵节点树，承载一组相关思考
- **树形 Session / 节点**：一个节点 = 一条对话或一个笔记；支持嵌套、展开、拖拽
- **合并 & 创建新 Chat**：把最多 3 个对话合并成新分支，重新组织思路

  在知识树视图中多选最多 3 个 Chat，合并完整对话历史并创建新节点。合并内容作为新对话起点；输入新问题后，与这些历史一并发给 LLM，把分散思路收成一条线。

- **Tree 转 Wiki 快照**：把一棵树的对话聚合成可阅读的「书」，章节式浏览并导出 zip
- **文档拆分（Doc Split）**：把一段 Markdown 文档交给 LLM，自动拆成树形对话节点

从 tree 的「生长」思考；如果要创建分支，就有可能有继承关系。

1. **0 继承关系**：只是结构上的关联，内容由用户自由发挥
2. **弱继承关系**：对整个上下文或所选 text 的总结
3. **半强继承关系**：继承所选的 text
4. **强继承关系**：继承完整上下文或所选的 text

![ThkTree 树的逻辑 — 继承类型与节点合并](./assets/readme/tree-logic.png)

### 对话（Chat）

- **流式对话**：SSE 流式回复，Markdown / LaTeX 渲染，图片上传与视觉模型
- **分支（Branch）**：从任意消息或一段选区即时开一个分支，对比不同思路

  <a href="https://youtube.com/shorts/ek68qDjBKrw?feature=share" target="_blank" rel="noopener noreferrer"><img src="https://img.youtube.com/vi/ek68qDjBKrw/hqdefault.jpg" alt="创建分支演示"></a>

- **联网搜索**：KIMI / MIMO / DeepSeek / 豆包 / xAI Grok 等原生联网
- **深度思考开关**：Per-session 切换（DeepSeek、MiniMax 等），部分模型服务端锁定
- **Pin 对照栏**：把关键消息或笔记钉在屏幕边缘，跨对话对照而不丢失上下文

  在对话或笔记中 Pin 关键内容（最多 5 条），点屏幕右缘把手展开对照面板，跨分支、跨 Tab 并排参考；可跳回原文、存为笔记或取消 Pin。

  <a href="https://youtube.com/shorts/cnm61xIWyK8?feature=share" target="_blank" rel="noopener noreferrer"><img src="https://img.youtube.com/vi/cnm61xIWyK8/hqdefault.jpg" alt="Pin 对照栏演示"></a>

- **iOS 后台中断恢复**：切后台续命 30s、回前台自动重发，防止长回复被系统杀掉

### 笔记（Notes）

- **Markdown 笔记**：本地编辑、标题必填、表格与标题工具栏
- **Chat-to-Note**：把对话里满意的回答一键存为笔记，沉淀而非流失
- **LLM 生成标题 / 转移主题**：让结构保持清晰，跨主题整理

### 检索（Search）

- **全文搜索**：SQLite FTS5 + BM25，跨对话与笔记检索
- **主题 / 节点标题过滤**：在树内按标题快速定位

### Lab（实验场）

- **关键词排行榜**：LLM 提取关键词 → 聚合评分 → 排行榜，看见自己在想什么
- **用户输入总结**：扫描历史输入，生成 Markdown 分析报告
- **思维碰撞**：随机配对关键词，LLM 生成一句话火花，点击即开新对话

---

## 技术栈

| 类别 | 选型 |
|------|------|
| 框架 | Flutter（纯 Cupertino 风格） |
| 状态管理 | Riverpod |
| 路由 | go_router（声明式 + deep linking） |
| 本地存储 | Markdown 正文 + SQLite 元数据 / 关系 / FTS5 |
| 写入安全 | FileWriteQueue 单写者队列（流式追加原子化） |
| LLM 调用 | SSE 流式 + `flutter_secure_storage` 存 Key |
| 渲染 | `gpt_markdown` + `flutter_math_fork`（LaTeX） |
| 平台能力 | `image_picker`、iOS MethodChannel（后台续命 / TTS） |

### 代码结构

```
lib/
  domain/                   # 领域实体：Theme、Node、ids
  data/
    models/                 # 数据模型：LLM 配置、序列化 DTO
    services/               # 核心服务：LLM 客户端、SQLite/FTS、文件 I/O、Pin、Clips、关键词、Wiki 导出…
    stores/                 # Riverpod 状态（session、theme、settings…）
  ui/
    core/
      router.dart           # go_router 路由与 shell
      app_services.dart     # 数据库 / 路径初始化
      shared/               # composer、分支流程、标题建议、选区…
      theme/                # AppColors、AppTheme
      widgets/              # 设计系统组件
    features/
      themes/               # 主题列表、树视图、合并 Chat、整树视图
      chat/                 # 流式对话、自动标题、Pin 对照栏组件
      notes/                # 浏览、编辑、详情、位置选择
      search/               # FTS 搜索页与共享 SearchContent
      lab/                  # 关键词排行、输入总结、思维碰撞
      llm/                  # Provider 列表与详情
      settings/             # LLM 配置、默认模型、备份、首次引导
      wiki/                 # Tree → Wiki 阅读器
      doc_split/            # Markdown 文档拆分为树节点
      backup_restore/       # zip 导入 / 导出
      about/
    platform/               # Android 平台 UI 适配
  l10n/                     # 国际化（ARB + generated，中英双语）
```

底部 4 个 tab：**搜索 / 主题 / 笔记 / Lab**；设置从搜索页顶栏齿轮进入。

---

## 快速开始

```bash
# 1. 克隆项目
git clone <repo-url>
cd thk_tree

# 2. 运行环境检查（自动提示你还缺什么）
python3 tools/check_onboarding.py

# 3. 安装依赖
flutter pub get
cd ios && pod install && cd ..

# 4. 运行
flutter run
```

> **首次使用**：打开 **ThkTree** 会弹出一次性引导，提示你在「设置 → 大模型」中添加模型提供商并配置默认模型。ThkTree 的聊天、标题生成与对话总结都需要 LLM；可选择「稍后再说」，随时在设置中补配。

<a href="https://youtube.com/shorts/vckfravPXek?feature=share" target="_blank" rel="noopener noreferrer"><img src="https://img.youtube.com/vi/vckfravPXek/hqdefault.jpg" alt="配置大模型演示"></a>

> 详细环境要求、技能配置说明和项目架构见 [`docs/PROJECT.md`](./docs/PROJECT.md)、[`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) 与 [`docs/FEATURES.md`](./docs/FEATURES.md)。

---

## 核心理念

> 让人机协作地构建「长在自己身上的」结构化知识体系——像树一样有机生长，而不是被信息洪流淹没。

我们身处 AI-native 时代，但大多数工具把对话、笔记、资料丢进一个扁平的流里，越聊越乱。ThkTree 的答案是一个隐喻：**知识是一棵树**。

- **有机生长（Organic）** — 知识如树，结构化但不僵化。支持嵌套、分支、实验，不强迫单一结构。
- **克制有序（Restraint & Order）** — 少即是多，层级即清晰。靠留白与字号做层级，而非喧哗的色彩。
- **实验包容（Experimental）** — 鼓励试错，Lab 精神。坦诚「为什么这么设计」，分享取舍与踩坑。
- **人文温度（Humanist）** — 理性之外有温度。隐私尊重、技术服务于人、不冷冰冰。

**对用户的承诺**：你的知识，始终属于你；你的结构，始终清晰；你的工具，始终克制。

---

## 定位

| 维度 | 立场 |
|------|------|
| 平台 | iOS（语音播放、后台中断恢复为 iOS 原生能力） |
| 数据 | 本地优先、无 ThkTree 服务端；iOS 上 `Documents/thktree/` 在开启 iCloud 备份时会纳入 **iCloud 设备备份**；API Key 不落明文 |
| 模型 | 你自选 Provider 与模型，而非绑定某一家 |
| 人格 | 「安静但可靠的建筑师」——克制、有序、有人味 |

**iOS 备份：** 应用数据位于 `Documents/thktree/`。开启 iCloud 备份后，数据会备份到**您自己的** iCloud 账户（而非 ThkTree 服务器）。详见[隐私政策](./docs/legal/privacy-policy-zh.md)。

---

## 品牌与文档

- 架构决策与文档地图：[`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md)
- 功能状态总表：[`docs/FEATURES.md`](./docs/FEATURES.md)
- 安全与隐私说明：[`docs/SECURITY-zh.md`](./docs/SECURITY-zh.md)

## 开源协议

ThkTree 以 [MIT 协议](./LICENSE) 开源发布。

| 文档 | English | 中文 |
|------|---------|------|
| 隐私政策 | [privacy-policy-en.md](./docs/legal/privacy-policy-en.md) | [privacy-policy-zh.md](./docs/legal/privacy-policy-zh.md) |
| 用户服务协议 | [terms-of-service-en.md](./docs/legal/terms-of-service-en.md) | [terms-of-service-zh.md](./docs/legal/terms-of-service-zh.md) |

> 命名强制为 **ThkTree**（大驼峰），禁止 `thk_tree` / `thktree` / `Thk Tree` 等写法。

