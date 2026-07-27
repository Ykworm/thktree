<p align="center">
  <a href="../README.md">简体中文</a> ·
  <a href="./README_en_US.md">English</a>
</p>

<p align="center">
  <img src="../assets/readme/hero.svg" width="100%"
       alt="ThkTree - 让思考，长成一棵树，把 LLM 对话组织成可嵌套、可检索、本地生长的树">
</p>

<p align="center">
  <img src="../assets/readme/badges.svg" width="100%"
       alt="Flutter, iOS 优先, AI 驱动, 隐私优先, 开源">
</p>

---

## 什么是 ThkTree？

ThkTree 是一款 iOS 优先的 AI 知识树 App，把 LLM 对话组织成可嵌套、可检索、本地生长的树——隐私优先、模型自选。

**核心价值**：让人机协作地构建「长在自己身上的」结构化知识体系——像树一样有机生长，而不是被信息洪流淹没。

---

<p align="center">
  <img src="../assets/readme/section-features.svg" width="100%"
       alt="功能特性">
</p>

### 知识树（Themes）

- **多主题管理**：每个「主题」是一棵节点树，承载一组相关思考
- **树形 Session / 节点**：一个节点 = 一条对话或一个笔记；支持嵌套、展开、拖拽
- **合并 & 创建新 Chat**：把最多 3 个对话合并成新分支，重新组织思路
- **Tree 转 Wiki 快照**：把一棵树的对话聚合成可阅读的「书」，章节式浏览并导出 zip
- **文档拆分（Doc Split）**：把一段 Markdown 文档交给 LLM，自动拆成树形对话节点

### 对话（Chat）

- **流式对话**：SSE 流式回复，Markdown / LaTeX 渲染，图片上传与视觉模型
- **分支（Branch）**：从任意消息或一段选区即时开一个分支，对比不同思路
- **联网搜索**：KIMI / MIMO / DeepSeek / 豆包 / xAI Grok 等原生联网
- **深度思考开关**：Per-session 切换（DeepSeek、MiniMax 等），部分模型服务端锁定
- **Pin 对照栏**：把关键消息或笔记钉在屏幕边缘，跨对话对照而不丢失上下文
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

<p align="center">
  <img src="../assets/readme/section-tech-stack.svg" width="100%"
       alt="技术栈">
</p>

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
  domain/          # 领域实体：Theme, Node, ids
  data/
    models/        # 数据模型：LLM 配置、Meta 序列化
    services/      # 核心服务：LLM 客户端、文件写入、搜索、数据库
    stores/        # Riverpod 状态管理
  ui/
    core/          # 共享组件、widgets、设计系统（AppColors / AppTheme）
    features/      # themes / chat / notes / lab / llm / settings / search / doc_split
  l10n/            # 国际化（中英双语）
```

底部 4 个 tab：**搜索 / 主题 / 笔记 / Lab**；设置从搜索页顶栏齿轮进入。

---

<p align="center">
  <img src="../assets/readme/section-quickstart.svg" width="100%"
       alt="快速开始">
</p>

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

---

<p align="center">
  <a href="https://github.com/oil-oil/beautify-github-readme"><img src="../assets/readme/made-with-beautify.svg" width="300" alt="README made with beautify-github-readme"></a>
</p>
