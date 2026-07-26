import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// Resolves the language code used for LLM system/user prompts.
///
/// Follows the app locale when set; otherwise falls back to the system locale.
class LlmPromptLocale {
  LlmPromptLocale._();

  static bool isEnglish(String languageCode) => languageCode == 'en';

  static String resolve({String? savedLanguageCode}) {
    if (savedLanguageCode == 'en') return 'en';
    if (savedLanguageCode == 'zh') return 'zh';
    final systemLang = PlatformDispatcher.instance.locale.languageCode;
    return systemLang.startsWith('zh') ? 'zh' : 'en';
  }
}

extension LlmPromptLocaleRef on Ref {
  String get llmLanguageCode =>
      LlmPromptLocale.resolve(savedLanguageCode: read(localeProvider)?.languageCode);
}

extension LlmPromptLocaleWidgetRef on WidgetRef {
  String get llmLanguageCode =>
      LlmPromptLocale.resolve(savedLanguageCode: read(localeProvider)?.languageCode);
}

/// Locale-aware LLM prompt templates.
class LlmPrompts {
  LlmPrompts._();

  static String defaultChatSystemPrompt(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return 'You are a helpful assistant. Always respond using correct and well-structured Markdown format — use proper headings, lists, code fences, tables, and inline formatting as appropriate. Do not return raw text when Markdown syntax is applicable.\n'
          'Respond in English by default; if the user explicitly requests another language, follow their request.';
    }
    return '你是一个有帮助的助手。请始终使用正确且结构良好的 Markdown 格式回复——在合适时使用标题、列表、代码块、表格和行内格式，不要在该用 Markdown 时返回纯文本。\n'
        '默认使用中文回复；若用户明确要求使用其他语言，则按用户要求。';
  }

  static String titleSystemPrompt(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return '''
You are a title naming assistant. Analyze the conversation content provided by the user, extract the core discussion topics and key questions, and generate candidate titles suitable for a new conversation.

Analysis requirements:
1. Focus on the user's core questions, main topics, and the conversation's goals or direction.
2. Identify key concepts, technical terms, and decision points.
3. Titles should help the user quickly recall the core content of this conversation.

Output requirements:
1. Decide the number of candidates based on content complexity (1–20); richer or more branching content can have more candidates.
2. Each title must be at most 30 characters.
3. Titles should be concise, focused, and information-dense.
4. Output strictly one title per line, without numbering, quotes, or extra explanation.
5. Output titles in English by default; if the user explicitly requests another language in the content or direction, follow their request.''';
    }
    return '''
你是一个标题命名助手。你的任务是分析用户提供的对话内容，提取其中的核心讨论主题和关键问题，然后生成适合作为新对话标题的候选列表。

分析要求：
1. 重点关注用户在对话中提出的核心问题、讨论的主要话题、以及对话的目标或方向。
2. 识别对话中的关键概念、技术术语、或决策点。
3. 标题应该能让用户快速回忆起这段对话的核心内容。

输出要求：
1. 候选数量由你根据内容复杂度自行判断（1~20 个），内容越丰富/分支越多可以多给几个。
2. 每个标题必须控制在 30 个字符以内（中文按字数、英文按字符数）。
3. 标题要简洁、聚焦、信息密度高，能让用户一眼看出新对话的主题或切入角度。
4. 严格按"每行一个标题"输出，不要带编号、不要带引号、不要带任何额外说明文字。
5. 默认使用中文输出标题；若用户在内容或方向引导中明确要求使用其他语言，则按用户要求。''';
  }

  static String titleUserPrompt({
    required String languageCode,
    required String content,
    String? direction,
  }) {
    final buf = StringBuffer();
    if (LlmPromptLocale.isEnglish(languageCode)) {
      buf.writeln('Generate candidate titles based on the following content:');
    } else {
      buf.writeln('请基于以下内容生成候选标题：');
    }
    buf.writeln();
    buf.writeln('---');
    buf.writeln(content);
    buf.writeln('---');
    if (direction != null && direction.trim().isNotEmpty) {
      buf.writeln();
      if (LlmPromptLocale.isEnglish(languageCode)) {
        buf.writeln('Direction: ${direction.trim()}');
      } else {
        buf.writeln('方向引导：${direction.trim()}');
      }
    }
    return buf.toString();
  }

  static String conversationSummarySystemPrompt(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return '''
You are a conversation summarization assistant. Given a full conversation between the user and the assistant, produce a concise summary to serve as the starting context for a new conversation.

Requirements:
1. Preserve key facts, conclusions, terminology, and decisions from the conversation.
2. Keep a reasonable length (generally 300–800 characters), concise and clear.
3. Do not add information that was not in the original conversation, and do not make judgments for the user.
4. Write the summary in English by default; if the user explicitly requested another language in the conversation, follow their request.''';
    }
    return '''
你是一个对话总结助手。给定一段用户与助手的完整对话，请生成一段简洁的总结，
作为新对话的上下文起点。要求：
1. 保留对话中讨论的关键事实、结论、术语、决定。
2. 控制在合理篇幅（一般 300~800 字），语言简洁清晰，不要冗长。
3. 不要添加原对话中没有的信息，不要替用户做判断。
4. 默认使用中文输出总结；若对话中用户明确要求使用其他语言，则按用户要求。''';
  }

  static String conversationSummaryUserPrompt({
    required String languageCode,
    required String transcript,
  }) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return 'Summarize the following conversation:\n\n---\n$transcript';
    }
    return '请总结以下对话：\n\n---\n$transcript';
  }

  static String userInputSummarySystemPrompt(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return '''
You are a user-input analysis assistant. Given all user inputs from a recent period, complete the following tasks:

1. Group the inputs by topic/domain (decide categories automatically; no predefined list required).
2. For each category, use one title line plus bullet points summarizing the user's main concerns.
3. Bullet points must faithfully reflect the original inputs; do not add information the user did not mention.
4. Write the output in English.
5. If there are fewer than 3 inputs, list them directly without grouping.

Output format (strict):
- Start each category with "Topics related to <category name>:"
- Start each bullet with "  * " (two spaces + asterisk + space)
- Do not output other formatting (no headings, numbering, or dividers)
- Do not output ``` code fences''';
    }
    return '''
你是一个用户输入分析助手。给定用户在过去一段时间内的所有输入内容，请完成以下任务：

1. 将这些输入按主题/领域归类（自动判断类别，不需要预定义）
2. 每个类别用一行标题 + 若干要点概括用户的主要关注点
3. 要点应忠实反映用户的原始输入，不要添加用户没有提到的信息
4. 使用中文输出
5. 如果用户输入很少（少于 3 条），直接逐条列出，不需要归类

输出格式要求（严格遵守）：
- 每个类别以 "类别名称相关内容：" 开头
- 每个要点以 "  * " 开头（两个空格 + 星号 + 空格）
- 不要输出其他格式化内容（不要标题、不要编号、不要分隔线）
- 不要输出 ``` 代码块标记''';
  }

  static String userInputSummaryUserPrompt({
    required String languageCode,
    required List<({DateTime timestamp, String content})> inputs,
  }) {
    final buf = StringBuffer();
    if (LlmPromptLocale.isEnglish(languageCode)) {
      buf.writeln(
        'Below are all user inputs from the recent period (${inputs.length} total):',
      );
    } else {
      buf.writeln('以下是用户在过去一段时间内的所有输入（共 ${inputs.length} 条）：');
    }
    buf.writeln();
    for (final input in inputs) {
      final dateStr = input.timestamp.toLocal().toString().substring(0, 16);
      buf.writeln('[$dateStr] ${input.content}');
    }
    return buf.toString();
  }

  static String keywordExtractionSystemPrompt(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return '''
You are a chat content analysis assistant. Extract core keywords from a conversation between the user and the LLM.

Input:
- chat title
- chat content (markdown)
- existing category catalog

Tasks:
1. Extract 1–5 core keywords (semantic abstraction, not word frequency; avoid filler words)
2. Assign a category label to the chat:
   - Prefer reusing existing catalog categories (by id)
   - Add at most 1 new category only for a genuinely new domain
   - Keep aliases aligned with the existing category system

Output strict JSON:
{
  "keywords": [
    {"keyword": "Socratic method", "category_id": "a1b2c3d4"}
  ],
  "new_category": null
}

When a new category is needed:
{
  "keywords": [...],
  "new_category": {
    "name": "Language Learning",
    "aliases": ["foreign language", "English"]
  }
}

new_category notes:
- It is a temporary field for incrementally updating the catalog
- It does not include id (the program assigns an 8-character id)
- category_id in keywords must come from the provided catalog ids
- If new_category is declared, the corresponding keyword uses the newly assigned id after persistence

Constraints:
- keywords count: 1–5
- category_id must come from the provided catalog ids
- at most 1 new_category (null means no new category)''';
    }
    return '''
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
''';
  }

  static String keywordExtractionUserPrompt({
    required String languageCode,
    required String catalogJson,
    required String chatTitle,
    required String chatContent,
  }) {
    final buf = StringBuffer();
    if (LlmPromptLocale.isEnglish(languageCode)) {
      buf
        ..writeln('Existing catalog (JSON):')
        ..writeln(catalogJson)
        ..writeln()
        ..writeln('Chat title:')
        ..writeln(chatTitle)
        ..writeln()
        ..writeln('Chat content:')
        ..writeln(chatContent)
        ..writeln();
    } else {
      buf
        ..writeln('现有 catalog（JSON）：')
        ..writeln(catalogJson)
        ..writeln()
        ..writeln('chat title：')
        ..writeln(chatTitle)
        ..writeln()
        ..writeln('chat 内容：')
        ..writeln(chatContent)
        ..writeln();
    }
    return buf.toString();
  }

  static String keywordAggregationSystemPrefix(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return '''
[SYSTEM - fixed]
You are a keyword aggregation scoring assistant. The input is a set of unique keywords and their cross-domain statistics.

[TASK - fixed]
For each keyword:
1. Statistical fields (cross_theme_count / cross_leaf_count / depth_avg / stale_ratio) must be copied exactly from the input
2. Compute the score field from the user template below (0.0–1.0 float)

[USER_TEMPLATE - user editable]
''';
    }
    return '''
[SYSTEM - 固定]
你是关键词聚合评分助手。输入是一组 unique keywords 及其跨域统计。

[TASK - 固定]
对每个 keyword：
1. 统计字段（cross_theme_count / cross_leaf_count / depth_avg / stale_ratio）必须原样输出输入值，不得修改
2. score 字段根据下方"用户模板"计算（0.0-1.0 浮点）

[USER_TEMPLATE - 用户可编辑]
''';
  }

  static String keywordAggregationSystemSuffix(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return '''

[OUTPUT_FORMAT - fixed]
Strict JSON array. Each element must contain:
keyword (string), cross_theme_count (int), cross_leaf_count (int), depth_avg (number), stale_ratio (number 0-1), score (number 0-1)

Field order is fixed; types must be strict.

[CONSTRAINT - fixed]
- Statistical fields (except score) must equal the input values:
  - cross_theme_count (int): strict integer comparison
  - cross_leaf_count (int): strict integer comparison
  - depth_avg (number): float tolerance (abs(a - b) < 1e-6)
  - stale_ratio (number): float tolerance (abs(a - b) < 1e-6)
  - Important: copy float fields exactly; do not round or truncate
- score ∈ [0.0, 1.0]
- keyword must come from the input data
- Do not add, remove, or modify keywords
- Output a JSON array only; do not wrap it in markdown code fences
''';
    }
    return '''

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
  - 重要：浮点字段原样复制，不要四舍五入或截断
- score ∈ [0.0, 1.0]
- keyword 必须来自输入数据
- 不得新增、删除、修改 keyword
- 输出 JSON 数组，不要 markdown 代码块包裹
''';
  }

  static String keywordAggregationUserPrompt({
    required String languageCode,
    required String inputJson,
  }) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return 'Input data (JSON):\n$inputJson\n\nOutput:';
    }
    return '输入数据（JSON）：\n$inputJson\n\n输出：';
  }

  static String defaultKeywordScorePrompt(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return 'Score each keyword from 0.0 to 1.0 based on:\n'
          '- cross_theme_count: more themes means higher importance (highest weight)\n'
          '- cross_leaf_count: more leaves means higher importance\n'
          '- depth_avg: deeper average depth suggests deeper thinking on the topic\n'
          '- stale_ratio: higher stale ratio should reduce the score slightly\n\n'
          'Balance these factors and output a float between 0.0 and 1.0.';
    }
    return '基于以下因素综合判断 0-1 分数：\n'
        '- 跨主题数 cross_theme_count：越多越重要（最高权重）\n'
        '- 总 leaf 数 cross_leaf_count：越多越重要\n'
        '- 涉及主题平均树深度 depth_avg：越深越说明用户在深度思考该主题\n'
        '- stale 占比 stale_ratio：stale 越多适当降权（说明内容频繁变化、未稳定）\n\n'
        '综合权衡，输出 0-1 浮点。';
  }

  static String docSplitSystemPrompt(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return '''
You are a document structure analysis assistant. The user will provide a document, and you should:
1. Analyze the content and propose 2–3 different splitting dimensions (such as topic, logical structure, timeline, etc.)
2. Show a complete tree structure for each dimension
3. Output the tree structure using this Markdown format:

## Dimension A: [dimension name]
[dimension description]

- **[Node title]**
  [Node content: 2–4 sentences summarizing the core information]
  - **[Child node title]**
    [Child node content]
  - **[Child node title]**
    [Child node content]
- **[Node title]**
  [Node content]

4. Separate each dimension with a divider (---)
5. Use bold for node titles (**title**), with content immediately after (not bold, indented)
6. Indentation represents hierarchy (2 spaces = one child level)
''';
    }
    return '''
你是一个文档结构分析助手。用户会提供一段文档文本，你需要：
1. 分析文档内容，提出 2-3 种不同的拆分维度（如按主题、按逻辑结构、按时间线等）
2. 每种维度展示完整的树结构
3. 树结构使用以下 Markdown 格式输出：

## 维度A：[维度名称]
[维度说明]

- **[节点标题]**
  [节点内容：该节点的详细说明，2-4句话概括核心信息]
  - **[子节点标题]**
    [子节点内容]
  - **[子节点标题]**
    [子节点内容]
- **[节点标题]**
  [节点内容]

4. 每个维度之间用分隔线（---）隔开
5. 节点标题用加粗（**标题**），内容紧跟标题后（不加粗，缩进对齐）
6. 缩进表示层级关系（2空格 = 一级子节点）
''';
  }

  static String truncatedTranscriptPrefix(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return '[Earlier messages omitted due to length]\n\n';
    }
    return '[因长度限制省略较早消息]\n\n';
  }

  static String truncatedContentSuffix(String languageCode) {
    if (LlmPromptLocale.isEnglish(languageCode)) {
      return '\n\n[...content truncated due to length...]';
    }
    return '\n\n[...因长度限制截断...]';
  }
}
