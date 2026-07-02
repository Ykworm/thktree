# 关键词排行榜功能设计 + 实现计划

> **状态**：草稿（freemode）
> **日期**：2026-07-02
> **流程**：brainstorming → 草稿归档 → 用户确认 → 实现（freemode，跳过 worktree）
> **关联 backlog**：P.9 实验室 tab 子功能（候选）

---

## 1. 功能概述

### 1.1 目标

在 Lab tab 内部新增「关键词排行榜」子功能，让用户**回顾自己最近的思考脉络**：系统自动抽取每个 chat 的核心关键词，跨 theme/leaf 聚合，按 score 排序，让用户一眼看到自己反复在想什么。

### 1.2 核心交互链路

```
Lab tab
  ↓ 点击「关键词排行榜」
关键词排行榜主视图（List）
  ↓ 点击「分析」→ 选择 leaf 页面 → 选 leaf → LLM 抽取
  ↓ 分析完毕后自动聚合 + 计算 score
  ↓ 排行榜按 score 倒序排列关键词
  ↓ 显示：排名 + 关键词 + score + 跨域统计
  ↓ 点击某关键词
关键词详情视图（Detail）
  ↓ 按关键词分组的所有 chat 卡片（含分类徽章 + 状态徽章）
  ↓ 每个卡片：chat title + 分类 + 状态（fresh/stale）+ 主题 + 分析时间
  ↓ 点击某 chat 卡片
跳转 ThemeDetailScreen
  ↓ 自动滚动到该 chat 节点
  ↓ ChatScreen 的 search input 预填关键词（不触发搜索）
```

**catalog 的定位**：
- catalog（分类体系）仅用于 **Detail 视图** 的 chat 卡片上显示分类徽章（如"哲学"、"教育"）
- 排行榜主视图**不做分类筛选**（DropDown / tag cloud）
- catalog List 仍然维护（用于 Prompt A 抽取时的分类匹配 + 动态新增）

### 1.3 价值

- 让用户从"内容管理工具"升级为"思考反思工具"
- 不改变现有 chat/theme 工作流，只在 Lab tab 提供聚合视角
- 用户完全掌控（手动选 leaf、手动触发分析），不强制自动化

### 1.4 与现有功能的关系

- **LLM 基建**：复用 `TitleSuggestionService`、`LlmClient.forConfig()`、`LlmConfigStore`
- **Markdown 真相源**：chat 内容从 `session.md` 读取（与现有 chat 一致）
- **主题节点模型**：复用 `Theme` / `Node` 模型，leaf 即 `kind == 'chat'` 节点
- **Lab tab**：本功能是 Lab tab 内部子页面（不是替代 Lab tab）

---

## 2. 核心概念约束

### 2.1 leaf = chat（概念等同）

在所有设计与沟通中：
- `leaf` = `chat` 节点 = `kind == 'chat'` 的 Node
- 三者是同一概念的不同表述（按使用场景选择术语）
- **禁止**在排行榜等非 tree 浏览场景中使用 tree 结构化缩进视觉
- ThemeDetailScreen 仍保留 tree 视觉（这是 tree 浏览场景）

### 2.2 三态状态机

| 状态 | 含义 | 进入条件 | 退出条件 |
|------|------|---------|---------|
| `pending` | 未分析 | leaf 新建且从未分析 | LLM 抽取完成 |
| `fresh` | 已分析，内容未变 | LLM 抽取完成 | user 发送新消息 |
| `stale` | 已分析，内容已变 | user 发送新消息 | 用户重新触发分析 |

### 2.3 stale 100% 显示

- stale 项**必须**在所有视图（List / Detail）中显示
- 用**醒目徽章**标识（如 ⚠️ + 黄色背景）
- **参与聚合计算**（score 包含 stale 项）
- 不提供隐藏 stale 的开关
- 用户主动重分析是唯一消除 stale 的方式

### 2.4 不做时间筛选

排行榜界面**不提供**时间范围筛选（近 7/30 天等）。理由：
- 用户主动选择 leaf 参与分析已表达时间心智
- 时间维度由用户心智自主判断，不替用户做时间切割

---

## 3. 数据模型

### 3.1 文件清单

| 文件路径 | 范围 | 写入时机 |
|---------|------|---------|
| `themes/<theme_id>/keyword_analysis.json` | 项目内，每个 theme 一个 | 用户触发"分析选中 leaf" |
| `~/.thktree/keyword_global.json` | 用户全局（`~/`） | 聚合 + score 计算后 |
| `~/.thktree/keyword_category_catalog.json` | 用户全局（`~/`） | LLM 抽取时动态新增 |

跨设备同步策略：**覆盖**（新设备完全替换旧设备文件）。

### 3.2 文件 1：`themes/<theme_id>/keyword_analysis.json`

```json
{
  "version": 1,
  "theme_id": "uuid",
  "updated_at": "2026-07-02T10:30:00Z",
  "leaves": {
    "<leaf_id>": {
      "leaf_id": "uuid",
      "status": "pending|fresh|stale",
      "last_analyzed_at": "2026-07-02T10:30:00Z",
      "last_user_message_at": "2026-07-02T11:00:00Z",
      "keywords": [
        {"keyword": "苏格拉底对话法", "category_id": "a1b2c3d4"},
        {"keyword": "辩证思维", "category_id": "a1b2c3d4"}
      ]
    }
  }
}
```

**字段说明**：
- `status`：当前状态，由状态机管理
- `last_analyzed_at`：LLM 抽取完成时间（fresh 时设置）
- `last_user_message_at`：该 leaf 最后一条 user message 时间（用于判定 stale）
- `keywords`：该 leaf 的关键词 + 分类映射

**关键方法**：
- `addOrUpdateLeaf(leafId, analysisResult)`：新增或更新 leaf 分析
- `markStale(leafId)`：当 user message 时调用
- `getStaleLeaves()`：获取所有 stale leaf

### 3.3 文件 2：`~/.thktree/keyword_global.json`

```json
{
  "version": 1,
  "updated_at": "2026-07-02T12:00:00Z",
  "score_prompt": "基于以下因素综合判断 0-1 分数：\n- 跨主题数\n- 总 leaf 数\n- stale leaf 占比\n- 关键词语义抽象度",
  "score_prompt_is_default": true,
  "keywords": [
    {
      "keyword": "学习方法",
      "category_id": "a8x9k2m1",
      "cross_theme_count": 3,
      "cross_leaf_count": 5,
      "depth_avg": 2.4,
      "stale_ratio": 0.4,
      "score": 0.87
    }
  ],
  "keyword_leaf_map": {
    "学习方法": [
      {"theme_id": "uuid-1", "leaf_id": "uuid-a", "category_id": "a8x9k2m1"},
      {"theme_id": "uuid-2", "leaf_id": "uuid-b", "category_id": "a8x9k2m1"}
    ]
  }
}
```

**字段说明**：
- `score_prompt`：用户可编辑的 score 计算逻辑（默认内置）
- `score_prompt_is_default`：是否为默认值（false 时显示"恢复默认"按钮）
- `keywords`：全局聚合后的关键词列表
- `score`：由 LLM 根据用户 prompt 计算的排序分（0-1）
- `keyword_leaf_map`：**反向索引**，keyword → 所有关联的 leaf 列表；聚合时从所有 theme 的 `keyword_analysis.json` 收集后写入；Detail 视图直接读此映射，无需遍历 theme 文件

**反向索引维护规则**：
- 聚合时全量重建（从所有 theme 的 keyword_analysis.json 收集）
- 删除 theme 时同步清理该 theme 的映射项，同时删除对应的 `keyword_analysis.json`
- `category_id` 取该 keyword 在该 leaf 中对应的分类 id（同一 keyword 在不同 leaf 可能属于不同分类，不做冲突仲裁）

#### 3.3.1 `depth_avg` 计算规则

leaf 在 theme tree 中的**绝对深度**：根节点 depth=0，子=1，孙=2，以此类推。

对包含该关键词的所有 leaf，计算各自在所属 theme tree 中的深度，取算术平均值。

**示例**：关键词"学习方法"关联 3 个 leaf，深度分别为 2、3、1 → depth_avg = (2+3+1)/3 = 2.0。
值越大说明用户围绕该关键词的思考越深入。

### 3.4 文件 3：`~/.thktree/keyword_category_catalog.json`

```json
{
  "version": 1,
  "updated_at": "2026-07-02T10:30:00Z",
  "categories": [
    {"id": "a1b2c3d4", "name": "哲学", "aliases": ["哲学思辨", "哲学思考"], "source": "default"},
    {"id": "e5f6g7h8", "name": "科技", "aliases": ["技术", "IT", "编程"], "source": "default"},
    {"id": "i9j0k1l2", "name": "教育", "aliases": ["学习", "教学"], "source": "default"},
    {"id": "m3n4o5p6", "name": "社科", "aliases": ["社会学", "心理学"], "source": "default"},
    {"id": "q7r8s9t0", "name": "情感", "aliases": ["情绪", "感受"], "source": "default"},
    {"id": "u1v2w3x4", "name": "个人成长", "aliases": ["自我提升"], "source": "default"},
    {"id": "y5z6a7b8", "name": "商业", "aliases": ["工作", "职场"], "source": "default"},
    {"id": "c9d0e1f2", "name": "艺术", "aliases": ["创意", "设计"], "source": "default"},
    {"id": "g3h4i5j6", "name": "健康", "aliases": ["健身", "医疗"], "source": "default"},
    {"id": "k7l8m9n0", "name": "生活", "aliases": ["日常"], "source": "default"},
    {"id": "o1p2q3r4", "name": "语言学习", "aliases": ["外语", "英语"], "source": "llm_added", "added_at": "2026-07-02T10:30:00Z"}
  ]
}
```

**字段说明**：
- `id`：程序生成的**8 位随机短 ID**（字母+数字，如 `a1b2c3d4`），保证唯一性；default 分类首次初始化时自动生成；llm_added 分类由程序在接收 new_category 后分配
- `source`：区分 default（内置 10 个）与 llm_added（动态新增）
- `aliases`：别名，用于匹配（LLM 优先复用现有）

**catalog 定位**：
- 仅用于 **Detail 视图**中 chat 卡片上的分类徽章显示
- Prompt A 抽取时用作分类匹配池
- 排行榜主视图**不做分类筛选**（无 Dropdown / tag cloud）

### 3.5 starter catalog（首次初始化）

如果 `keyword_category_catalog.json` 不存在，自动写入默认 10 个分类。

---

## 4. LLM 交互契约

### 4.1 Prompt A：关键词抽取（固定，用户不可编辑）

**输入**：
- 单个 chat 的 markdown 内容
- 现有 catalog JSON
- chat title

**System Prompt**：

```
你是一名 chat 内容分析助手。任务是从用户与 LLM 的对话中提取核心关键词。

输入：
- chat title
- chat 内容（markdown 格式）
- 现有分类 catalog

任务：
1. 抽取 1-5 个核心关键词（语义抽象层，不是词频统计；不要"地、得、的、吗"这类虚词）
2. 给该 chat 打分类标签：
   - 优先复用现有 catalog 的分类（用 id）
   - 如果属于真正新领域（现有 catalog 无相似分类），可新增 1 个分类
   - 一次分析最多新增 1 个，避免 catalog 爆炸
   - 别名尽量贴合已有分类体系

现有 catalog（JSON）：
{{ category_catalog }}

chat title：
{{ chat_title }}

chat 内容：
{{ chat_content }}

输出严格 JSON 格式：
{
  "keywords": [
    {"keyword": "苏格拉底对话法", "category_id": "a1b2c3d4"}
  ],
  "new_category": null
}

如果需要新增分类（仅当真正新领域时）：
{
  "keywords": [...],
  "new_category": {
    "name": "语言学习",
    "aliases": ["外语", "英语"]
  }
}

new_category 说明：
- 它是 Prompt A 输出的临时字段，存在内存中，用于**增量更新** catalog List
- 不包含 id（id 由程序分配 8 位随机短 ID）
- LLM 输出的 category_id 必须来自输入中给定的 catalog 的 id
- 如果声明了 new_category，对应 keyword 的 category_id 填程序分配的新 id（后续写入阶段完成）

约束：
- keywords 数量 1-5
- category_id 必须从现有 catalog 的 id 中选择
- new_category 最多 1 个（null 表示不新增）
```

### 4.2 Prompt B：聚合 + score 计算（template 化，用户可编辑 score 部分）

**输入**：
- unique keywords 列表（每个含程序预计算的统计）
- 用户自定义的 score 计算逻辑

**完整模板**：

```
[SYSTEM - 固定]
你是关键词聚合评分助手。输入是一组 unique keywords 及其跨域统计。

[TASK - 固定]
对每个 keyword：
1. 统计字段（cross_theme_count / cross_leaf_count / depth_avg / stale_ratio）必须原样输出输入值，不得修改
2. score 字段根据下方"用户模板"计算（0.0-1.0 浮点）

[USER_TEMPLATE - 用户可编辑]
{{ score_calculation_logic }}

[OUTPUT_FORMAT - 固定]
严格 JSON 数组，每个元素含字段：
keyword (string), cross_theme_count (int), cross_leaf_count (int), depth_avg (number), stale_ratio (number 0-1), score (number 0-1)

字段顺序固定，类型严格。

[CONSTRAINT - 固定]
- 统计字段（除 score 外）必须等于输入值：
  - cross_theme_count (int)：严格整数比较
  - cross_leaf_count (int)：严格整数比较
  - depth_avg (number)：浮点容差比较（abs(a - b) < 1e-6）
  - stale_ratio (number)：浮点容差比较（abs(a - b) < 1e-6）
  - **重要**：浮点字段原样复制，不要四舍五入或截断
- score ∈ [0.0, 1.0]
- keyword 必须来自输入数据
- 不得新增、删除、修改 keyword
- 输出 JSON 数组，不要 markdown 代码块包裹

输入数据（JSON）：
{{ input_keywords }}

输出：
```

**默认 score_calculation_logic**：

```
基于以下因素综合判断 0-1 分数：
- 跨主题数 cross_theme_count：越多越重要（最高权重）
- 总 leaf 数 cross_leaf_count：越多越重要
- 涉及主题平均树深度 depth_avg：越深越说明用户在深度思考该主题
- stale 占比 stale_ratio：stale 越多适当降权（说明内容频繁变化、未稳定）

综合权衡，输出 0-1 浮点。
```

### 4.3 输出校验器（100% 合规校验）

**策略**：100% 合规才算正确，不符合 → 整体拒绝 + 保留旧 score + UI banner 告知用户 + 用户重试。

校验流程：

| 步骤 | 校验项 | 失败处理 |
|------|--------|---------|
| 1 | JSON 解析（去掉 <think> 标签、md 代码块） | 整体拒绝，保留旧 score，banner「输出格式错误」 |
| 2 | 是 JSON 数组 | 整体拒绝 |
| 3 | 数组非空 | 整体拒绝 |
| 4 | 输出数量 = 输入数量 | 整体拒绝，banner「输出数量不匹配」 |
| 5 | 每个元素含全部 6 个字段 | 整体拒绝，banner「输出字段不完整」 |
| 6 | keyword 非空且在输入集合中 + keyword 唯一 | 整体拒绝，banner「关键词不匹配」 |
| 7 | cross_theme_count/cross_leaf_count **严格等于**输入；depth_avg/stale_ratio **浮点容差比较**（abs(a - b) < 1e-6） | **整体拒绝**，banner「统计字段不一致」 |
| 8 | score ∈ [0.0, 1.0] | clamp + banner「score 已修正」 |

**步骤顺序说明**：
- 步骤 4（数量匹配）移到步骤 5（字段完整性）之前，逻辑更清晰：先检查数组长度，再逐个检查
- 步骤 6 合并了 old 的步骤 5（keyword 非空、在输入集合中）和步骤 6（keyword 唯一）
- 删除了 old 步骤 9（重复检查数量）
- 删除了"部分失败降级"策略，改为 100% 合规

**降级（全部走整体拒绝）**：

| 失败类型 | UI 反馈 |
|---------|---------|
| LLM 调用失败 | Toast「LLM 调用失败」+ 保留旧 score |
| JSON 解析失败 | Banner「输出格式错误，已使用旧数据」+ 保留旧 score |
| 输出数量不匹配 | Banner「输出数量不匹配，请重试」+ 保留旧 score |
| 字段不完整 | Banner「输出字段不完整，请重试」+ 保留旧 score |
| 关键词不匹配 | Banner「关键词不匹配，请重试」+ 保留旧 score |
| 统计字段不一致 | Banner「统计字段不一致，请重试」+ 保留旧 score |
| score 超界 | Banner「score 已修正」+ clamp + 使用修正值 |

**参考实现**：`TitleSuggestionService.parseResponse` 的清洗模式。

---

## 5. UI 视觉

### 5.1 List 视图（关键词排行榜主视图）

```
┌─────────────────────────────────────────────────┐
│ < Lab                  关键词排行榜              │
├─────────────────────────────────────────────────┤
│ [分析]                            上次: 2026-07-02│
├─────────────────────────────────────────────────┤
│                                                 │
│ ① 学习方法                    score 0.87        │
│   跨 3 theme · 5 leaf · 含 2 stale ⚠️           │
│   ──────────────────────────────── →           │
│                                                 │
│ ② 认知偏差                    score 0.74        │
│   跨 2 theme · 3 leaf · 全部 fresh              │
│   ──────────────────────────────── →           │
│                                                 │
│ ③ 时间管理                    score 0.68        │
│   跨 1 theme · 2 leaf · 全部 fresh              │
│   ──────────────────────────────── →           │
│                                                 │
│ ④ 编程范式                    score 0.45        │
│   跨 2 theme · 4 leaf · 含 3 stale ⚠️           │
│   ──────────────────────────────── →           │
│                                                 │
└─────────────────────────────────────────────────┘
```

**关键元素**：
- 顶部 toolbar：返回按钮 + 标题
- 第二行：**「分析」按钮** + 上次计算时间
- 点击「分析」→ 进入 § 5.6「选择 leaf」页面 → 选 leaf → 触发 LLM 抽取 → 分析完毕后自动聚合 + score 计算 → 排行榜更新
- 主体：按 score 倒序排列的关键词列表
- 每行：排名 + 关键词 + score + 跨域统计
- 整行可点击（→ Detail 视图）
- ⚠️ 徽章标识含 stale leaf
- **不做分类筛选**（catalog 仅用于 Detail 视图的卡片分类徽章）

### 5.2 Detail 视图（点击关键词后）

```
┌─────────────────────────────────────────────────┐
│ < 返回           学习方法    score 0.87          │
├─────────────────────────────────────────────────┤
│ 跨 3 theme · 5 leaf · 含 2 stale ⚠️             │
├─────────────────────────────────────────────────┤
│                                                 │
│ ┌─────────────────────────────────────────┐     │
│ │ 苏格拉底对话法     [哲学] [fresh]        │     │
│ │ 主题: 哲学入门                          │     │
│ │ 分析于: 2026-07-02 12:00                │     │
│ │ 关键词: 苏格拉底对话法, 辩证思维         │     │
│ │ [跳转到 chat]                            │     │
│ └─────────────────────────────────────────┘     │
│                                                 │
│ ┌─────────────────────────────────────────┐     │
│ │ 沉浸式练习         [教育] [stale ⚠️]    │     │
│ │ 主题: 英语学习                          │     │
│ │ 分析于: 2026-06-28 09:30                │     │
│ │ 关键词: 学习方法, 沉浸式                │     │
│ │ [跳转到 chat]                            │     │
│ └─────────────────────────────────────────┘     │
│                                                 │
└─────────────────────────────────────────────────┘
```

**关键元素**：
- 顶部 toolbar：返回按钮 + 关键词 + score
- 副标题：跨域统计
- 主体：该关键词关联的所有 chat 卡片列表
- 每卡片：chat title + **分类徽章**（如[哲学]、[教育]——这是 catalog 的唯一 UI 作用）+ 状态徽章 + 主题 + 分析时间 + 关键词列表 + 跳转按钮
- stale 卡片有 ⚠️ 徽章（醒目）
- 点击「跳转到 chat」→ 跳转 ThemeDetailScreen，search input 预填关键词（不触发搜索）

### 5.3 跳转流程（点击 chat 卡片）

```
关键词 Detail 视图
  ↓ 点击「跳转到 chat」
Navigator.push → ThemeDetailScreen(themeId)
  ↓ 传递参数：scrollToNodeId, searchPrefill=keyword
  ↓ ThemeDetailScreen 启动时滚动到该节点
  ↓ ChatScreen 的 search input 预填关键词（不触发搜索）
```

**关键设计**：
- 跳转不触发自动搜索，只预填输入框
- 用户可以手动按回车触发搜索，或修改关键词
- search input 的预填逻辑复用 ChatScreen 现有搜索功能

### 5.4 Settings 编辑 score prompt

入口：Settings → Lab → 关键词排行榜 score 计算（暂定）

```
┌─────────────────────────────────────────────────┐
│ < 设置       关键词排行榜 score 计算            │
├─────────────────────────────────────────────────┤
│ 说明：                                           │
│ 此 prompt 用于 LLM 计算每个关键词的排序分。      │
│ 下方可编辑区域是「如何计算 score」的逻辑。        │
│ 上方数据示例、下方输出格式均固定，不可修改。     │
│                                                 │
│ ┌─────────────────────────────────────────┐     │
│ │ [输入数据示例 - 只读]                    │     │
│ │ [                                       │     │
│ │   {"keyword": "学习方法",                │     │
│ │    "cross_theme_count": 3,              │     │
│ │    "cross_leaf_count": 5,               │     │
│ │    ...}                                 │     │
│ │ ]                                       │     │
│ └─────────────────────────────────────────┘     │
│                                                 │
│ ┌─────────────────────────────────────────┐     │
│ │ [用户可编辑区]                          │     │
│ │                                         │     │
│ │ 基于以下因素综合判断 0-1 分数：         │     │
│ │ - 跨主题数 cross_theme_count：...      │     │
│ │ - ...                                   │     │
│ │                                         │     │
│ └─────────────────────────────────────────┘     │
│                                                 │
│ ┌─────────────────────────────────────────┐     │
│ │ [输出格式 - 只读]                       │     │
│ │ [                                       │     │
│ │   {"keyword": "...",                    │     │
│ │    "score": 0.87}                       │     │
│ │ ]                                       │     │
│ └─────────────────────────────────────────┘     │
│                                                 │
│ [恢复默认]                  [保存]               │
│                                                 │
└─────────────────────────────────────────────────┘
```

**关键约束**：
- 上方「输入数据示例」+ 下方「输出格式」均为**只读灰色**
- 中间可编辑区为用户唯一可改区域
- 「恢复默认」重置为内置 sample logic
- 「保存」持久化到 `keyword_global.json.score_prompt`

### 5.5 状态徽章规范

| 状态 | 徽章 | 颜色 |
|------|------|------|
| pending | [未分析] | 灰色 |
| fresh | [fresh] | 绿色 |
| stale | [stale ⚠️] | 黄色 + 警示图标 |

### 5.6 「选择 leaf」UI 设计

**设计原则**：
- 不支持在 theme 层做选择（避免维护 theme 状态徽章的复杂性）
- 进入 theme 内部的 chat tree 后做选择（多选/全选）
- 顶部有使用说明

**流程**：

```
排行榜主视图（List）
  ↓ 点击「分析」按钮
选择 leaf 页面
  ↓ 顶部使用说明（教用户怎么用）
  ↓ Theme 列表（不可选择，只展示 theme 名称）
  ↓ 点击某个 theme
进入该 theme 的 chat tree
  ↓ 每个 leaf 显示 checkbox + 状态徽章
  ↓ 支持多选/全选
  ↓ 选中后点击「开始分析」
LLM 抽取 → 聚合 → 排行榜更新
```

**选择 leaf 页面 UI**：

```
┌─────────────────────────────────────────────────┐
│ < 选择分析的叶子       [开始分析]              │
├─────────────────────────────────────────────────┤
│ 💡 使用说明：                                   │
│ 1. 点击 theme 进入 chat tree                   │
│ 2. 选择要分析的 leaf（支持多选/全选）           │
│ 3. 点击「开始分析」触发 LLM 抽取                │
├─────────────────────────────────────────────────┤
│                                                 │
│ 📁 哲学入门                                     │
│    苏格拉底对话法 [fresh] ✓                     │
│    认知偏差 [pending]                           │
│    辩证思维 [stale ⚠️] ✓                        │
│                                                 │
│ 📁 英语学习                                     │
│    沉浸式练习 [pending]                         │
│    语法纠正 [fresh]                             │
│                                                 │
│ [全选] [取消全选]                               │
│                                                 │
└─────────────────────────────────────────────────┘
```

**关键设计**：
- Theme 列表：只展示 theme 名称，不可选择
- 进入 theme：点击后展开/折叠 chat tree
- Leaf 列表：显示 checkbox + 状态徽章（pending/fresh/stale）
- 全选/取消全选：当前 theme 内的快捷操作
- 开始分析按钮：顶部固定，点击后触发 LLM 抽取
- 状态徽章复用 § 5.5 规范

---

## 6. 状态机实现

### 6.1 状态流转图

```
[新建 leaf]
    ↓
[pending]
    ↓ 用户点「分析选中叶子」
[LLM 抽取中...]
    ↓
[fresh] ←────────────────────┐
    ↓ user 发送新消息         │
[stale]                       │ 用户重分析
    └────────────────────────┘
```

### 6.2 触发条件实现

**stale 触发**：在 `chat_controller.dart` 的 `sendUserMessage` 方法中，`sessionStore.appendUserMessage` 之后调用。通过 nodeId 反查 themeId（方案 B，不改 `ChatControllerParams` 签名）：

```dart
// 在 chat_controller.dart 的 sendUserMessage 中
await sessionStore.appendUserMessage(nodeId: nodeId, content: trimmed);

// 新增：触发 stale 检测
final nodeStore = await ref.read(nodeStoreProvider.future);
final themeId = await nodeStore.getThemeIdByNodeId(nodeId);
if (themeId != null) {
  try {
    final keywordService = await ref.read(keywordAnalysisServiceProvider.future);
    await keywordService.markStaleIfAnalyzed(leafId: nodeId, themeId: themeId);
  } catch (e) {
    // 静默失败，不影响主流程
    print('Failed to mark stale: $e');
  }
}
```

**为何选方案 B（nodeId 反查）**:
- `ChatControllerParams` 不含 `themeId`，且 `sendUserMessage` 是唯一用户主动发送入口
- 不改变现有类签名，通过 SQL `SELECT themeId FROM nodes WHERE nodeId = ?` 获取
- 需在 `NodeStore` 新增方法 `getThemeIdByNodeId(String nodeId)`

**fresh 触发**：在关键词抽取服务完成后调用：

```dart
KeywordAnalysisService.markFresh(
  leafId: leafId,
  themeId: themeId,
  keywords: extractedKeywords,
);
```

**关键设计**：状态变更**同步触发**，不依赖 LLM 检测内容变化。

### 6.3 数据完整性

- 状态变更失败不影响主流程（try-catch + log）
- 状态文件写入失败时，下次启动重新检测（基于 last_user_message_at vs last_analyzed_at）

---

## 7. MVP 边界

### 7.1 不做（本次）

| 不做项 | 理由 |
|--------|------|
| catalog UI 编辑（Settings） | MVP 简化，用户可手动编辑文件 |
| 置信度字段 | 简化设计，score 一个指标够用 |
| 时间范围筛选 | 用户心智承担 |
| tree 缩进视觉 | leaf=chat 概念约束 |
| 跨设备同步机制 | 仅记录"覆盖"策略，依赖后续同步基建 |
| 自动重分析（LLM 检测变更） | 手动触发 + user message 触发 |
| 全局自动分析 | 用户主动选择 leaf |

### 7.2 已敲定（必做）

| 必做项 | 备注 |
|--------|------|
| 3 个 JSON 文件持久化 | schema 已设计 |
| Prompt A 关键词抽取 | 用户不可编辑 |
| Prompt B 聚合 + score | 用户可编辑 score 部分 |
| 严格 JSON 校验器 | 8 步 100% 合规校验 |
| 三态状态机 | pending/fresh/stale |
| List/Detail 两层视图 | List 无分类筛选，catalog 仅用于 Detail 卡片徽章 |
| keyword → leaf 反向索引 | keyword_global.json 中维护 |
| ThemeDetailScreen 跳转 + search input 预填 | search input 预填关键词（不触发搜索） |
| Settings 编辑 score prompt | 只暴露 score 计算部分 |
| stale 100% 显示 + 徽章 | 醒目 |
| 不做时间筛选 | 硬约束 |
| category id 唯一性 | 程序生成 8 位随机短 ID |
| theme 删除同步 | 清理 keyword_global.json 引用 + 删除 keyword_analysis.json |
| 跨设备覆盖策略 | 简化为单一策略 |

### 7.3 后续迭代（v2+）

- catalog UI 编辑（Settings 入口）
- 关键词搜索（排行榜内）
- 关键词趋势（按时间变化）
- 主题内聚合视图（不只是全局）
- 自定义关键词黑/白名单
- LLM 调用频率限制与缓存策略

---

## 8. 实现计划（freemode）

### 8.1 任务清单（按依赖顺序）

| # | 任务 | 估时 | 依赖 | 验证 |
|---|------|------|------|------|
| 1 | 基础设施：JSON 文件 IO + catalog ID 生成 + 反向索引结构 | 0.5d | — | 单测 |
| 2 | KeywordAnalysisService：leaf 状态机 + keyword_analysis.json | 0.5d | 1 | 单测 |
| 3 | Prompt A 服务：关键词抽取 + 分类匹配 + new_category 增量 | 1d | 1, 2 | 手工验证 |
| 4 | Prompt B 服务：聚合统计 + score 计算 + 100% 合规校验器 | 1.5d | 1, 2 | 单测 |
| 5 | user message 触发 stale（chat_controller hook） | 0.5d | 2 | 单测 + 手工验证 |
| 6 | NodeStore 新增 getThemeIdByNodeId | 0.25d | — | 单测 |
| 7 | Lab tab 子页面路由：KeywordRankingScreen | 0.5d | — | 编译通过 |
| 8 | List 视图 + 分析按钮 + 选择 leaf 页面 | 1.5d | 2, 6, 7 | 手工验证 |
| 9 | Detail 视图 + chat 卡片（含分类徽章） | 1d | 6, 8 | 手工验证 |
| 10 | ThemeDetailScreen 跳转 + search input 预填 | 1d | 9 | 单测 + 手工验证 |
| 11 | Settings 编辑 score prompt 页面 | 1d | 4 | 手工验证 |
| 12 | theme 删除同步清理逻辑 | 0.25d | 1 | 单测 |
| 13 | 单元测试：核心逻辑覆盖 | 1d | 全部 | 单测 |
| 14 | context-sync：FEATURES.md / DECISIONS.md / 模块 README | 0.5d | 全部 | — |

**总计**：约 11.5 天（按单人估时）

### 8.2 任务详情

#### 任务 1：基础设施

**目标**：3 个 JSON 文件的读写 IO + 默认 catalog 初始化。

**新增文件**：
- `lib/data/services/keyword_analysis_storage.dart` — keyword_analysis.json IO
- `lib/data/services/keyword_global_storage.dart` — keyword_global.json IO
- `lib/data/services/keyword_category_storage.dart` — keyword_category_catalog.json IO

**关键方法**：
- `loadOrInit()`：文件不存在时自动初始化
- `read()` / `write()`：原子写入（先写 tmp 再 rename）
- `updateAsync(callback)`：读 → 修改 → 写

**验证**：
- 单测：写入读取一致性
- 单测：默认 catalog 内容正确
- 单测：原子写入（中途崩溃不破坏文件）

#### 任务 2：KeywordAnalysisService

**目标**：leaf 状态机 + keyword_analysis.json CRUD。

**新增文件**：
- `lib/data/services/keyword_analysis_service.dart`

**关键方法**：
- `getOrInitLeaf(themeId, leafId)`：获取或初始化 leaf
- `markStale(themeId, leafId)`：标记 stale
- `markFresh(themeId, leafId, keywords)`：标记 fresh + 保存关键词
- `getAnalyzableLeaves(themeId)`：获取用户选中的 leaf（pending/stale）
- `getLeavesForKeyword(themeId, keyword)`：反向查询

**验证**：
- 单测：状态流转正确
- 单测：last_user_message_at 更新
- 单测：stale 检测（基于时间对比）

#### 任务 3：Prompt A 服务（关键词抽取）

**目标**：复用 `LlmClient.forConfig` + `TitleSuggestionService` 模式，实现关键词抽取。

**新增文件**：
- `lib/data/services/keyword_extraction_service.dart`

**关键方法**：
- `extract(chatContent, catalog)`：调用 LLM，输出 JSON，校验

**复用**：
- `LlmClient.forConfig(LlmProviderConfig)` — 三种 LLM
- `LlmConfigStore.loadAll()` — 默认模型
- `LlmErrorCard` — 错误展示

**Prompt**：见 § 4.1（用户不可编辑）

**校验**：
- JSON 解析（去 <think>、md 代码块）
- keywords 1-5 个
- category_id 在 catalog 的 id 中（LLM 输出 catalog 中已有的 id）
- new_category 最多 1 个，不含 id（程序后续分配）

**验证**：
- 手工验证：用真实 LLM API，验证抽取结果正确

#### 任务 4：Prompt B 服务（聚合 + score）

**目标**：聚合 unique keywords + 调用 LLM 计算 score + 严格校验。

**新增文件**：
- `lib/data/services/keyword_aggregation_service.dart`

**关键方法**：
- `aggregate(themeAnalyses)`：聚合所有 theme 的分析 → unique keywords + 统计
- `computeScores(uniqueKeywords, prompt)`：调用 LLM 输出 score
- `validateAndMerge(llmOutput, inputKeywords)`：严格校验 + 合并

**Prompt**：见 § 4.2（template 化，用户可编辑 score 部分）

**校验器**：见 § 4.3（8 步 100% 合规校验）

**默认 prompt**：
```
基于以下因素综合判断 0-1 分数：
- 跨主题数 cross_theme_count：越多越重要（最高权重）
- 总 leaf 数 cross_leaf_count：越多越重要
- 涉及主题平均树深度 depth_avg：越深越说明用户在深度思考该主题
- stale 占比 stale_ratio：stale 越多适当降权（说明内容频繁变化、未稳定）
```

**验证**：
- 单测：校验器各分支（JSON 解析、字段缺失、统计不一致、score 超界、keyword 不匹配）
- 单测：默认 prompt 渲染正确
- 手工验证：完整聚合流程

#### 任务 5：user message 触发 stale

**目标**：在用户主动发送消息时同步标记 stale。

**代码分析结论**：
- `appendUserMessage` 被 5 个入口调用：
  1. `chat_controller.dart` line 324 — **用户主动发送消息主入口** ✅
  2. `title_suggestion_screen.dart` line 937 — 创建新 chat 时写入初始消息 ❌
  3. `note_detail_screen.dart` line 342 — 笔记创建 chat 时写入内容 ❌
  4. `doc_split_service.dart` line 74, 102 — 文档拆分时写入内容 ❌
  5. `theme_detail_screen.dart` line 89 — 文档拆分预览节点 ❌
- 只有 `chat_controller.dart` 的 `sendUserMessage` 是用户主动发送消息的主入口
- 其他 4 个入口都是创建新 chat 时写入初始内容，**不需要触发 stale**

**修改文件**：
- `lib/ui/features/chat/chat_controller.dart` line 324

**关键改动**：
```dart
// 在 chat_controller.dart 的 sendUserMessage 中
await sessionStore.appendUserMessage(nodeId: nodeId, content: trimmed);

// 新增：触发 stale 检测（方案 B：通过 nodeId 反查 themeId）
final nodeStore = await ref.read(nodeStoreProvider.future);
final themeId = await nodeStore.getThemeIdByNodeId(nodeId);
if (themeId != null) {
  try {
    final keywordService = await ref.read(keywordAnalysisServiceProvider.future);
    await keywordService.markStaleIfAnalyzed(leafId: nodeId, themeId: themeId);
  } catch (e) {
    print('Failed to mark stale: $e');
  }
}
```

**关键设计**：
- 只在 `sendUserMessage` 中 hook，不影响其他 `appendUserMessage` 入口
- `ChatControllerParams` 不含 `themeId` → 通过 `NodeStore.getThemeIdByNodeId(nodeId)` 反查
- try-catch 包裹，不影响主流程

**验证**：
- 单测：发送 user message → leaf 状态变 stale
- 手工验证：发送消息后 → 排行榜中该 leaf 状态变 stale

#### 任务 6：NodeStore 新增 getThemeIdByNodeId

**目标**：支持通过 nodeId 反查 themeId（stale 触发需要）。

**修改文件**：
- `lib/data/stores/node_store.dart`

**新增方法**：
```dart
/// 通过 nodeId 反查所属的 themeId
/// 遍历所有 theme 的 nodes 表，找到包含该 nodeId 的 theme
Future<String?> getThemeIdByNodeId(String nodeId) async {
  // SELECT themeId FROM nodes WHERE nodeId = ?
}
```

**验证**：
- 单测：已知 nodeId → 返回正确的 themeId
- 单测：未知 nodeId → 返回 null

#### 任务 7：Lab tab 子页面路由

**目标**：在 Lab tab 内部新增「关键词排行榜」入口。

**修改文件**：
- `lib/ui/features/lab/lab_screen.dart` — 新增入口卡片
- `lib/ui/router.dart`（或对应路由文件） — 新增 KeywordRankingScreen 路由

**关键改动**：
- Lab screen 新增卡片：「关键词排行榜」
- 点击 → push 到 KeywordRankingScreen
- 路由：`/lab/keyword-ranking`

**验证**：
- 编译通过
- 手工：Lab tab 可见入口，点击跳转

#### 任务 8：List 视图 + 分析按钮 + 选择 leaf 页面

**目标**：实现 List 视图（关键词排名）+ 分析按钮 → 选择 leaf → 触发 LLM。

**新增文件**：
- `lib/ui/features/lab/keyword_ranking/keyword_ranking_screen.dart`
- `lib/ui/features/lab/keyword_ranking/keyword_list_view.dart`
- `lib/ui/features/lab/keyword_ranking/leaf_selection_screen.dart`

**关键组件**：
- `KeywordRankingScreen`（StatefulWidget）— 主容器
- `KeywordListView` — 关键词列表
- `LeafSelectionScreen` — 选择 leaf 页面（§ 5.6）
- Provider/Riverpod 集成 — 数据源

**数据流**：
1. 进入页面 → 读取 `keyword_global.json`
2. 按 score 倒序展示
3. 顶部显示「分析」按钮 + 「上次计算时间」
4. 点击「分析」→ 跳转 LeafSelectionScreen → 选 leaf → 触发 Prompt A → 分析完毕 → 触发 Prompt B → 排行榜更新

**验证**：
- 手工：点击「分析」→ 进入选择 leaf 页面
- 手工：分析完毕 → 排行榜更新

#### 任务 9：Detail 视图 + chat 卡片（含分类徽章）

**目标**：点击关键词 → 进入 Detail 视图，展示 chat 卡片（含分类徽章）。

**新增文件**：
- `lib/ui/features/lab/keyword_ranking/keyword_detail_screen.dart`
- `lib/ui/features/lab/keyword_ranking/chat_card.dart`

**关键组件**：
- `KeywordDetailScreen` — Detail 主容器
- `ChatCard` — 单个 chat 卡片
- Provider/Riverpod — 关联 leaf 数据

**数据流**：
1. 进入 Detail → 读取 keyword_global.json + 所有相关 theme 的 keyword_analysis.json
2. 反向索引：找出所有包含该 keyword 的 leaf
3. 按 leaf 展示卡片
4. 点击「跳转到 chat」→ 跳转 ThemeDetailScreen

**验证**：
- 手工：从 List 点击进入 Detail
- 手工：stale leaf 卡片正确显示
- 手工：点击跳转按钮

#### 任务 10：ThemeDetailScreen 跳转 + search input 预填

**目标**：从 Detail 跳转到 ThemeDetailScreen，自动滚动 + search input 预填关键词（不触发搜索）。

**修改文件**：
- `lib/ui/features/themes/theme_detail_screen.dart` — 支持 scrollToNodeId 参数
- `lib/ui/features/chat/chat_screen.dart` — search input 预填关键词

**关键改动**：
- ThemeDetailScreen 启动时检查路由参数 `scrollToNodeId`
- 滚动到该节点
- ChatScreen 的 search input 预填关键词（不触发搜索）

**search input 预填实现**：
- 路由参数传递 `searchPrefill=keyword`
- ChatScreen 初始化时检查 `searchPrefill`
- 如果有值，填入 search input，但不触发搜索
- 用户可以手动按回车触发搜索，或修改关键词

**复用**：
- ChatScreen 现有的搜索功能（search input + 搜索逻辑）
- 只增加预填逻辑，不改变现有搜索行为

**验证**：
- 单测：search input 预填逻辑正确
- 手工验证：点击跳转 → 滚动到正确节点 → search input 显示关键词

#### 任务 11：Settings 编辑 score prompt 页面

**目标**：Settings 页面新增 score prompt 编辑入口。

**新增文件**：
- `lib/ui/features/settings/keyword_score_prompt_screen.dart`

**修改文件**：
- `lib/ui/features/settings/settings_screen.dart`（或对应 Settings 入口）

**关键组件**：
- `KeywordScorePromptScreen` — 编辑页面
- 只读区（输入示例、输出格式）+ 可编辑区（score 计算逻辑）
- 「恢复默认」+ 「保存」按钮

**数据流**：
1. 读取 `keyword_global.json.score_prompt`
2. 默认填充
3. 用户编辑
4. 保存 → 持久化到 `keyword_global.json`
5. 同时设置 `score_prompt_is_default = false`

**验证**：
- 手工：编辑后保存 → 重启 App → 仍然生效
- 手工：恢复默认 → 重置为内置 prompt

#### 任务 12：theme 删除同步清理

**目标**：theme 删除时同步清理关联数据。

**修改位置**：theme 删除逻辑（现有删除方法入口）

**清理内容**：
- `keyword_global.json.keyword_leaf_map` — 删除该 theme 的所有映射项
- `keyword_global.json.keywords` — 若某 keyword 仅剩该 theme 的引用则删除
- `<themeId>/keyword_analysis.json` — 直接删除文件

**验证**：
- 单测：删除 theme → keyword_leaf_map 不残留该 theme 数据
- 单测：删除 theme → keyword_analysis.json 不存在

#### 任务 13：单元测试

**目标**：核心逻辑单元测试（不写集成测试）。

**新增文件**：
- `test/keyword_analysis_service_test.dart`
- `test/keyword_aggregation_service_test.dart`
- `test/keyword_extraction_service_test.dart`

**测试用例**：
1. **状态机**：pending → fresh → stale 状态流转
2. **stale 检测**：user message 后状态变 stale
3. **JSON 校验器**：各分支（JSON 解析、字段缺失、统计不一致、score 超界、keyword 不匹配）
4. **聚合逻辑**：unique keywords 统计正确
5. **search input 预填**：路由参数传递正确

**验证**：
- `flutter test test/` 通过
- 核心逻辑覆盖完整

#### 任务 14：context-sync

**目标**：同步文档。

**修改文件**：
- `docs/FEATURES.md` — 新增关键词排行榜功能说明
- `docs/DECISIONS.md` — 新增 ADR（设计决策记录）
- `docs/modules/lab/README.md`（或对应模块文档） — 新增子功能说明
- `docs/war-stories/`（如适用） — 重大技术坑

**硬约束**（按 AGENTS.md context-sync 规则）：
- 改 doc 是唯一允许的副作用
- 不执行 git add / commit / push
- 不做表格（用列表 + 卡片）
- 每个 doc 给出影响/不影响/待确认判断

---

## 9. 验收方式

### 9.1 编译通过 + diagnostics 无错误

- `flutter analyze` 通过
- iOS build 通过
- Android build 通过（虽然仅 iOS 优先，但需确保不破坏）

### 9.2 单元测试

- `test/keyword_analysis_service_test.dart` 通过
- `test/keyword_aggregation_service_test.dart` 通过
- `test/keyword_extraction_service_test.dart` 通过
- 核心逻辑覆盖完整

### 9.3 手工验证清单

| # | 场景 | 预期 |
|---|------|------|
| 1 | Lab tab 可见「关键词排行榜」入口 | ✅ |
| 2 | 点击进入 List 视图 | ✅ |
| 3 | 点击「分析」→ 选择 leaf 页面 | ✅ |
| 4 | 选择 leaf → 点击「开始分析」→ 触发 LLM | ✅ |
| 5 | 分析完毕 → 聚合 + score → 排行榜更新 | ✅ |
| 6 | 点击关键词 → 进入 Detail | ✅ |
| 7 | Detail 显示 chat 卡片 + 分类徽章 | ✅ |
| 8 | stale leaf 显示 ⚠️ | ✅ |
| 9 | 点击「跳转到 chat」→ 跳转 ThemeDetailScreen | ✅ |
| 10 | 跳转后滚动到正确节点 + search input 预填关键词 | ✅ |
| 11 | Settings 编辑 score prompt → 保存生效 | ✅ |
| 12 | 恢复默认 → 重置 | ✅ |
| 13 | 发送 user message → leaf 变 stale | ✅ |
| 14 | LLM 调用失败 → UI 显示错误，不崩溃 | ✅ |
| 15 | 校验失败 → banner 提示 + 保留旧 score | ✅ |
| 16 | 删除 theme → keyword_global.json 清理 + keyword_analysis.json 删除 | ✅ |

### 9.4 边界条件

| 场景 | 期望行为 |
|------|---------|
| LLM 输出无法解析 | 保留旧 score + UI banner「输出格式错误」 |
| 校验失败（统计幻觉） | 整体拒绝 + banner「统计字段不一致，请重试」+ 保留旧 score |
| score 超界 [0,1] | clamp + banner「score 已修正」 |
| 关键词不在输入集合 | 整体拒绝（100% 合规策略） |
| 输出数量不匹配 | 整体拒绝 + banner「输出数量不匹配」 |
| catalog 无匹配分类 | LLM 提议 new_category（无 id，程序后续分配） |
| user message 触发 stale 失败 | 不影响主流程，log error |
| 文件 IO 失败 | 保留旧数据 + log error |
| 跨设备同步冲突 | 覆盖策略，新设备完全替换 |
| theme 删除 | 同步清理 keyword_global.json 引用 + 删除 keyword_analysis.json |

---

## 10. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| LLM 输出不稳定导致校验失败 | score 计算失败 | 100% 合规校验 + 整体拒绝 + banner 提示用户重试 |
| catalog 爆炸增长 | 分类过多，难维护 | starter + LLM 约束（一次最多新增 1 个） |
| 跨设备同步覆盖冲突 | 用户数据丢失 | MVP 接受此风险，后续迭代做合并 |
| 关键词抽取 token 消耗大 | 用户 API 费用 | 用户手动触发 + 缓存结果 |
| 状态机状态不一致 | stale 误判 | 基于 last_user_message_at vs last_analyzed_at 检测，启动时重同步 |
| search input 预填逻辑 | 跳转后预填失败 | 复用 ChatScreen 现有搜索功能，fallback 为不预填 |
| ThemeDetailScreen 滚动定位失败 | 跳转后位置不对 | fallback：定位失败时滚动到顶部 |
| theme 删除后关联数据残留 | keyword_global.json 中出现悬挂引用 | 同步清理 keyword_leaf_map + keyword_analysis.json |
| new_category 新增后下次聚合缺失 | 新增分类的 keyword 在下次聚合时无对应 category | 插入到 catalog List date 并分配 id，下次聚合时自然参与 |

---

## 11. 关键决策溯源（按对话轮次）

| 决策 | 来源 |
|------|------|
| leaf = chat 概念等同 | 用户反馈"leaf 其实就是 chat" |
| stale 100% 显示 | 用户"stale 是不是过期？如果是没必要隐藏" |
| 不做时间筛选 | 用户"用户会在自己脑海里面感受" |
| 用户主动选择 + 状态驱动 | 用户"用户应该可以对 theme 做选择" |
| 文件级 JSON（非 SQLite） | 用户"多写一份文件就可以" |
| 三态状态机（pending/fresh/stale） | 用户"加一个叫过期的状态" |
| user message 触发 stale | 用户"在每个 chat 完成一个对话后去 set status" |
| 分类 catalog LLM 动态维护 | 用户"按 JSON 内容去 update catalog List" |
| Prompt B template 化 | 用户"用户怎么知道要计算什么" |
| 分类筛选用 Dropdown | 用户"横向 chip 列表隐藏 items 是让人很难受的 UX" |
| 严格 JSON 校验 | 用户"必须有个 program 去检查 prompt 生成的结果" |
| freemode | 用户"我们要开启 freemode" |
| 去掉关键词高亮，改为 search input 预填 | 用户"我没说过要在 chat 里面对关键词做高亮" |
| 选择 leaf UI 设计 | 用户"不支持用户在 theme 这一层做选择，可以进入 theme 里面的 chat tree 做选择" |
| 删除 tag cloud / 分类筛选 Dropdown | 用户"catalog 的初心是知道每个 chat 的话题性质" → UI 沉淀到 Detail 视图卡片徽章 |
| 100% 合规校验（含步骤 4/9 互斥修复） | 用户"校验逻辑必须 100% 合规，不符合告知用户重试" |
| category id 唯一性（8 位随机短 ID） | 用户"ID 就应该属于某种 ID，不能是'philosophy'" → 程序生成保证唯一 |
| depth_avg 计算规则 | 新增：根=0 绝对深度，算术平均，跨 theme 可比 |
| keyword → leaf 反向索引 | AI 发现：Detail 视图需要快速查 leaf，新增 keyword_leaf_map |
| NodeStore.getThemeIdByNodeId | AI 发现：stale 触发需要 themeId，ChatControllerParams 无此字段 → 反查 DB |
| theme 删除同步清理 | AI 发现 + 用户确认：删除 theme 需清理 keyword_global.json 引用 + 删除 keyword_analysis.json |
| new_category 不含 id | AI 建议 + 用户确认：id 由程序分配，LLM 不需要理解 id 体系 |

---

## 12. 后续步骤

1. 用户审阅本文档
2. 用户确认后进入实现（freemode，跳过 worktree）
3. 按 § 8.1 任务清单顺序实现
4. 每个任务完成后用户可独立审阅
5. 全部完成后做 context-sync
6. 用户决定 commit / push 时机

---

## 附录 A：参考代码位置

| 已有基建 | 文件 |
|---------|------|
| LLM 客户端 | `lib/data/services/llm_client.dart` |
| 标题生成参考 | `lib/data/services/title_suggestion_service.dart` |
| LLM 配置管理 | `lib/data/stores/llm_config_store.dart` |
| Doc Split LLM 调用 | `lib/data/services/doc_split_service.dart` |
| 错误展示组件 | LlmErrorCard（具体位置参考现有调用） |
| Markdown 真相源 | session.md（chat 内容存储） |
| stale 触发 hook 点 | `lib/ui/features/chat/chat_controller.dart` → `sendUserMessage` |
| nodeId → themeId 反查 | `lib/data/stores/node_store.dart` → 新增 `getThemeIdByNodeId` |
| ChatControllerParams 定义 | `lib/ui/features/chat/chat_controller.dart`（不含 themeId） |

## 附录 B：freemode 模式说明

按 AGENTS.md freemode 规则：

- ❌ 不创建 worktree
- ❌ 不走 rebase + fast-forward merge 收尾
- ❌ 不强制 `git worktree remove`
- ✅ 在主仓库（dev 分支）直接实现
- ✅ commit / push / 切分支 / 合并完全自由
- ✅ 文档合并 design + plan（本文档即合并版本）

freemode 触发：用户明确说「freemode」/「自由模式」/「不走 worktree」/「跳过 worktree」等关键词。