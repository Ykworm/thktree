<p align="center">
  <a href="../README.md">English</a> ·
  <strong>简体中文</strong>
</p>

<p align="center">
  <img src="../assets/readme/banner_en.png" width="100%"
       alt="ThkTree - Let Thoughts Grow into a Tree">
</p>

---

## 什么是 ThkTree？

ThkTree 是一款 iOS 优先的 AI 知识树 App，把 LLM 对话组织成可嵌套、可检索、本地生长的树——隐私优先、模型自选。

**核心价值**：让人机协作地构建「长在自己身上的」结构化知识体系——像树一样有机生长，而不是被信息洪流淹没。

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
> 关于Lab，它是各种实验性功能的入口，面向开发者
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

![ThkTree 树的逻辑 — 继承类型与节点合并](../assets/readme/tree-logic.png)

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

> 详细环境要求、技能配置说明和项目架构见 [`docs/PROJECT.md`](../docs/PROJECT.md)、[`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) 与 [`docs/FEATURES.md`](../docs/FEATURES.md)。

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
| 平台 | iOS 优先（语音播放、后台中断恢复为 iOS 原生能力） |
| 数据 | 本地优先 + 隐私安全，API Key 不落明文 |
| 模型 | 你自选 Provider 与模型，而非绑定某一家 |
| 人格 | 「安静但可靠的建筑师」——克制、有序、有人味 |

---

## 品牌与文档

- 架构决策与文档地图：[`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md)
- 功能状态总表：[`docs/FEATURES.md`](../docs/FEATURES.md)

> 命名强制为 **ThkTree**（大驼峰），禁止 `thk_tree` / `thktree` / `Thk Tree` 等写法。
