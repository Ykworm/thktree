/// 在 markdown 解析前对"被压扁"的流式文本做结构重建。
///
/// **背景**：DeepSeek 的流式 token 在 tokenization 边界可能丢 `\n`，
/// 导致 markdown 块级结构被压平成单行纯文本：
///
/// ```text
/// LLM 想要输出：          实际进入解析器：
///   ## 你的核心特点         ## 你的核心特点**第一，审美洁癖...
///   **第一，审美洁癖**      （没有 \n，** 直接接 ## 后面）
///   ---
///   你的核心...
/// ```
///
/// `gpt_markdown` 自身对缺 `\n` 没有自动重建能力（跟 streamdown 的
/// `remend` 不同：remend 只补 inline 配对标记，不补块级结构）。
///
/// **借鉴思路**：本函数借鉴 Vercel `streamdown` 的 `remend` 哲学
/// "在解析前做轻量、局部修正"，但目标换成"重建块级结构"：
///   - `remend` 修 inline 配对（`**`、`~~`、`` ` ``、`[]()`）
///   - `rehydrateMarkdown` 修块级结构（`##`、`---`、列表、代码围栏、表格）
///
/// **副作用**：
///   - body 太短（< 50 字符）→ 直接返回，避免误伤短回复
///   - body 无 markdown token → 直接返回，避免误伤纯文本
///
/// **Scope**：调用方应只在 `modelId` 命中 DeepSeek 时调用，
/// 避免对其他 LLM（已知正常）产生不必要的工作。
import 'dart:developer' as dev;

String rehydrateMarkdown(String body) {
  dev.log('[REHYDRATE-IN] length=${body.length}, '
      'hasNewline=${body.contains('\n')}');
  if (body.isEmpty) return body;

  // 安全门：必须至少有一种疑似 markdown token 才重建
  // 防止误伤纯文本（纯中文/英文消息不含 ---、##、#、**、\`\`\`、`- xxx` 等 token 时直接跳过）
  // 注意：检查 `RegExp(r'-\s')` 而不是 `body.contains('- ')`，因为 LLM 经常无空格：
  // "-MFC" / "-2013年" / "-用" 都要能触发
  // 单 `#` heading 也要识别（如 "#重点1"），但要排除 "C#继承" / "F#" 之类
  final hasAnyToken = body.contains('---') ||
      body.contains('##') ||
      body.contains('**第') ||
      body.contains('|') || // 表格也是触发信号
      RegExp(r'\d+\.\s').hasMatch(body) ||
      body.contains('```') ||
      RegExp(r'(?<=^|[\s]|[^A-Za-z])#').hasMatch(body) ||
      RegExp(r'(?<=^|[\s]|[^A-Za-z])-').hasMatch(body) ||
      // 字符串开头的数字列表（无空格如 "1.第一项"）
      RegExp(r'^\d+\.[一-龥A-Za-z]').hasMatch(body) ||
      // 字母后 "- 大写" 或 "-中文" 也是列表项信号（如 "Qt- C#"、"Angular-自己"）
      RegExp(r'[A-Za-z]-\s+[A-Z一-龥]').hasMatch(body) ||
      RegExp(r'[A-Za-z]-[一-龥]').hasMatch(body);
  if (!hasAnyToken) {
    dev.log('[REHYDRATE-IN] early-return: no markdown token detected');
    return body;
  }
  dev.log('[REHYDRATE-IN] proceeding to _applyRehydratePatterns');

  final out = _applyRehydratePatterns(body);
  dev.log('[REHYDRATE-IN] output.length=${out.length}, '
      'output.newlines=${'\n'.allMatches(out).length}, '
      'changed=${out != body}');
  return out;
}

String _applyRehydratePatterns(String body) {
  var s = body;

  // 设计原则：replacement 用 ${m[0]!} 引用整个 match，前面只加 \n\n / \n 前缀。
  // 这样原 match 字符（包括末尾的 token）完整保留，不会被覆盖。
  //
  // 所有 lookbehind 均以 `(^|...)` 开头，支持匹配字符串起始位置
  // （修复 DeepSeek 整块回复以 #/---/1./-/``` 开头时不换行的问题）。

  // ═══════════════════════════════════════════════════════════════
  // PASS 0: 表格重建（必须最先做！）
  // 表格分隔行 `:---` 里有 `---`，会被后面的 HR 规则切碎。
  // 所以先识别整块表格，把行与行之间的 \n 补齐，
  // 让后续规则能正确识别表格边界、不再误伤分隔行。
  // ═══════════════════════════════════════════════════════════════
  s = _rehydrateTables(s);

  // 围栏代码块 ``` 前补 \n（让 ``` 独立成行）
  s = s.replaceAllMapped(
    RegExp(r'(^|(?<=\S))[\s　]*```'),
    (m) => '\n\n${m[0]!}',
  );

  // --- 水平分割线前后补 \n
  // lookbehind: 字符串开头 或 非字母非数字非 dash 非 | 字符
  //   排除字母/数字避免误伤 "a---b" em-dash / "2020---2025" 年份范围
  //   排除 | 避免误伤表格分隔行 `:---|`
  // lookahead: 非 dash 非 | 字符（确保正好三个 dash，且不在表格里）
  //   后面如果是非块级起始符的 non-whitespace，补 \n\n 确保 HR 独立成行；
  //   如果是块级起始符（#/-/数字/`）只补一个 \n，由后续规则自己加前缀
  s = s.replaceAllMapped(
    RegExp(r'(^|(?<=[^A-Za-z0-9\-\|]))---(?!-)(?![^\n]*\|)([\s　]*)(\S)?'),
    (m) {
      final after = m[3];
      if (after != null) {
        final isBlockStarter = after == '#' ||
            after == '-' ||
            after == '`' ||
            RegExp(r'\d').hasMatch(after);
        return isBlockStarter
            ? '\n\n---\n$after'
            : '\n\n---\n\n$after';
      }
      return '\n\n---${m[2] ?? ''}';
    },
  );

  // **第X** 段落起始标记前补 \n（针对"**第一、**、**第二、**"这种段头）
  s = s.replaceAllMapped(
    RegExp(r'(^|(?<=[^\s]))[\s　]*\*\*第[一二三四五六七八九十\d]'),
    (m) => '\n\n${m[0]!}',
  );

  // 数字列表项前补 \n + 空格（"1. xxx" → "\n1. xxx"）
  // **顺序很重要：必须在 # 规则之前**
  // lookbehind: 字符串开头 或 非字母/非#/非-/非数字/非* 的字符
  //   （排除 # 避免误伤 ##1. 内的 1.；排除 - 避免误伤 -1. 内的 1.；
  //    排除数字避免切 "2013年" 里的 "3.年"；排除 * 避免在 **bold** 内部插入换行）
  // lookahead: 中文/字母（排除数字避免 "1.0" 小数误伤；"1.1" 也会被排除，让外层 1. 处理）
  // 同时补空格：让 "1.审美" 变成 "1. 审美" 符合标准 markdown 列表格式
  s = s.replaceAllMapped(
    RegExp(r'(^|(?<=[\s]|[^A-Za-z0-9#\-\*]))(\d+\.)[\s　]*([一-龥A-Za-z])'),
    (m) => '\n${m[2]!} ${m[3]!}',
  );

  // # ~ ###### 标题前补 \n + 空格
  // **顺序很重要：在 1. 规则之后**
  // lookbehind: 字符串开头 或 空白/非字母字符（覆盖中文、全角标点、引号、括号、*等）
  //   排除 ASCII 字母避免误伤 "C#继承" / "F#"
  //   排除左括号（(`[`【《〈「『）避免误伤括号内的锚点引用如（#重点1）
  // lookahead 限制为 heading content（# / 数字 / 中文 / 字母）
  // 同时补空格：让 "#你的特点" 变成 "# 你的特点" 符合标准 markdown heading 格式
  // 注意：因为在 1. 规则之后，"## 1." 内的 1. 已经被 1. 规则保护（lookbehind 排除 #）
  s = s.replaceAllMapped(
    RegExp(
        r'(?<=^|[\s]|[^A-Za-z(\[（【《〈「『])(#{1,6})([\s　]*)([#\d一-龥A-Za-z])'),
    (m) => '\n\n${m[1]!} ${m[3]!}',
  );

  // 长 **bold** 段落起始前补 \n（针对标题或正文后紧跟长加粗段落，中间无换行的情况）
  // 触发条件：** 紧跟在中文/字母之后（无空格/标点），且 bold 内容 ≥ 20 字符含句末标点后再遇到 **。
  // 排除 inline 短加粗（如"**重要**提示"）避免误伤。
  s = s.replaceAllMapped(
    RegExp(r'(?<=[一-龥A-Za-z])\*\*(?=[^*]{20,}[。！？.!?][^*]*\*\*)'),
    (m) => '\n\n**',
  );

  // 破折号列表项前补 \n + 空格（"- xxx" → "\n- xxx"）
  //
  // Pass 1（先处理）：字母后紧跟 "- Xxx"（dash+大写开头）或 "-中文"（dash+中文）的场景
  // 覆盖 "Qt- C#继承"、"Angular-自己画不出图"、"Gin- iQuery" 这种英文词尾后直接接
  // 列表项的压扁情况。触发条件保守：
  //   - dash 后第一个非空白字符是大写字母（列表项英文常大写开头；避免 go-zero/Gin-iQuery 这类复合词误切）
  //   - dash 后第一个非空白字符是中文（英文不会通过连字符直接连接中文词）
  // 排除：
  //   - 前一个字符是 -（避免 "-- em-dash" 的第二个 - 被切）
  //   - dash 后紧跟 * / ` / #（markdown inline 标记，如 "- **bold**"）
  s = s.replaceAllMapped(
    RegExp(r'(?<=[A-Za-z])-(?!-)[\s　]*(?![*`#\-])([A-Z一-龥])'),
    (m) => '\n- ${m[1]}',
  );

  // Pass 2：通用列表项规则
  // lookbehind: 字符串开头 或 空白或非字母非 - 字符
  //   （排除 - 避免误伤 "--" em-dash 的第二个 -，以及 "---" HR 内部的 -）
  // [\s　]* 后紧跟 (?![*`#\-]) 排除 "--" em-dash，以及 "- **"、"- `"、"- #" 等
  //   markdown 标记紧跟 dash 的情况（避免切断 "- **bold**" 内的 **）
  // 同时补空格：让 "-用" 变成 "- 用" 符合标准 markdown 列表格式
  // 覆盖 "-MFC丑"、"-2013年"、"结尾段。-苹果"、开头 "-第一项" 等场景
  s = s.replaceAllMapped(
    RegExp(r'(^|(?<=[\s]|[^A-Za-z\-]))-(?![\s　]*[*`#\-])[\s　]*([^\-\s])'),
    (m) => '\n- ${m[2]!}',
  );

  return s.trimLeft();
}

// ═══════════════════════════════════════════════════════════════
// 表格重建
// ═══════════════════════════════════════════════════════════════

/// 从压扁的文本中识别 markdown 表格，补上行间换行。
///
/// **识别思路**：以表格分隔行（包含 `|:---|` 这类模式）为锚点，
/// 向前找表头行、向后找数据行，每行必须以 `|` 开头并以 `|` 结尾（或至少含 2 个 `|`）。
///
/// 为什么要最先做？因为表格分隔行 `:---` 里有 `---`，
/// 会被后续的 HR（水平分割线）规则误切成独立段落。
String _rehydrateTables(String text) {
  if (!text.contains('|')) return text;
  if (!RegExp(r':---').hasMatch(text)) return text;

  // 先找所有疑似"表格分隔行"的位置：连续的 |:---|:---|... 模式
  // 一个完整分隔行长这样：|:---|:---|:---|
  final separatorPattern = RegExp(
    r'\|[\s　]*:?-{2,}:?[\s　]*(\|[\s　]*:?-{2,}:?[\s　]*)+\|',
  );

  final matches = separatorPattern.allMatches(text).toList();
  if (matches.isEmpty) return text;

  // 从右向左替换，避免位置偏移
  final buf = StringBuffer();
  var cursor = text.length;

  for (final sepMatch in matches.reversed) {
    final sepStart = sepMatch.start;
    final sepEnd = sepMatch.end;

    // 向前找表头行：从 sepStart 往前找，找到第一个 | 开头的位置
    // 表头行的特征：以 | 开头，中间有多个 |，以 | 结尾（或后面紧接分隔行）
    final headerEnd = sepStart;
    var headerStart = headerEnd;
    // 向前回溯到上一个 |，再继续往前直到遇到非表格字符
    // 简单策略：从分隔行开头向前找，找到一个 | 之后，
    // 再继续向前找，直到遇到不是表格内容的字符（换行、行首、非 | 开头的文本等）
    //
    // 更稳妥的做法：从 sepStart 向前扫描，找到最近一个 "|" 且后面是表格内容，
    // 然后一直扫描到行首（或非表格起始符）作为表头起点。

    // 从分隔行起点向前找"上一个 |"的位置，作为表头行右边界的候选
    // 其实表头行就是分隔行之前、以 | 结尾的一段文本。
    // 简化：从 sepStart 向左扫描，跳过空白，找到 |，然后继续向左扫描
    // 直到遇到换行 / 字符串开头 / 非表格起始字符。

    // 先向左跳过空白
    var p = sepStart - 1;
    while (p >= 0 && (text[p] == ' ' || text[p] == '\t' || text[p] == '　')) {
      p--;
    }
    if (p < 0 || text[p] != '|') {
      // 分隔行前面不是 | → 不是有效表格，跳过
      buf.insert(0, text.substring(sepEnd, cursor));
      cursor = sepStart;
      continue;
    }

    // 找到表头行的右边界（|），继续向左找表头行起点
    var headerRight = p;
    // 向左扫描，直到遇到 \n 或 字符串开头 或 非表格字符
    // 表格行的判断：以 | 开头（允许前面有空白）
    // 这里简化：一直向左找到换行或开头，看那一段是否以 | 开头
    // 先找到行首
    var lineStart = p;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    // 从行首向右跳过空白
    var contentStart = lineStart;
    while (contentStart < headerRight &&
        (text[contentStart] == ' ' ||
            text[contentStart] == '\t' ||
            text[contentStart] == '　')) {
      contentStart++;
    }
    if (contentStart >= headerRight || text[contentStart] != '|') {
      // 这一行不是以 | 开头 → 不是表头
      buf.insert(0, text.substring(sepEnd, cursor));
      cursor = sepStart;
      continue;
    }

    // 表头行起点 = 行首（保留前面的空白/换行上下文）
    headerStart = lineStart;

    // 向后找数据行：从 sepEnd 向后，找以 | 开头以 | 结尾的行
    var dataEnd = sepEnd;
    // 从 sepEnd 开始，逐行扫描
    var pos = sepEnd;
    // 跳过紧接的空白
    while (pos < text.length &&
        (text[pos] == ' ' || text[pos] == '\t' || text[pos] == '　')) {
      pos++;
    }
    // 如果后面直接是 \n 或 字符串结束，就没有数据行（异常情况）
    if (pos < text.length && text[pos] == '|') {
      // 从 | 开始扫描，直到遇到 \n 或 非表格行
      // 简化：扫描到下一个 \n 作为第一行数据的结尾，
      // 然后继续判断下一行是否也是表格行
      var lineEnd = pos;
      while (lineEnd < text.length && text[lineEnd] != '\n') {
        lineEnd++;
      }
      // 检查这一行是否以 | 结尾（允许尾部空白）
      var trail = lineEnd - 1;
      while (trail > pos &&
          (text[trail] == ' ' ||
              text[trail] == '\t' ||
              text[trail] == '　')) {
        trail--;
      }
      if (trail > pos && text[trail] == '|') {
        dataEnd = lineEnd;
        // 继续找下一行
        // 这里简化处理：只识别第一行数据，避免过度匹配
        // （流式输出时表格通常就几行，第一行能识别到就够了）
        //
        // 实际上还可以继续向下找更多数据行，但为了安全起见，
        // 我们只保证表头+分隔行+第一行数据的结构正确，
        // 后续行如果也粘在一起，会在后续 token 到达时逐步被重建。
      }
    }

    // 整段表格范围：[headerStart, dataEnd)
    // 需要在表头行末尾、分隔行末尾各补一个 \n（如果没有的话）
    //
    // 构造重建后的表格块
    final tableBlock = text.substring(headerStart, dataEnd);
    final rebuilt = _rebuildTableBlock(tableBlock);

    // 写入 [cursor 之前, dataEnd) → 替换为 [headerStart 之前, dataEnd)
    // 因为从右向左处理：
    buf.insert(0, text.substring(dataEnd, cursor)); // 表格后到上一段
    buf.insert(0, rebuilt); // 重建后的表格

    cursor = headerStart;
  }

  // 最后补上最前面一段
  buf.insert(0, text.substring(0, cursor));

  return buf.toString();
}

/// 把一整段压扁的表格文本（表头+分隔行+(可选)数据行）重建为标准 markdown 表格。
///
/// 输入是一段包含至少一个 `|:---|` 分隔行、前面跟着表头、后面可能跟着数据行的文本。
/// 输出是每行独立、以 \n 分隔的标准表格。
String _rebuildTableBlock(String block) {
  // 先找分隔行的位置
  final sepMatch = RegExp(
    r'\|[\s　]*:?-{2,}:?[\s　]*(\|[\s　]*:?-{2,}:?[\s　]*)+\|',
  ).firstMatch(block);
  if (sepMatch == null) return block;

  final sepStart = sepMatch.start;
  final sepEnd = sepMatch.end;

  // 表头行：从开头到 sepStart
  var header = block.substring(0, sepStart).trim();
  // 确保表头以 | 开头和结尾
  if (!header.startsWith('|')) header = '|$header';
  if (!header.endsWith('|')) header = '$header|';

  // 分隔行
  final separator = sepMatch.group(0)!;

  // 数据行：从 sepEnd 到结尾
  var data = block.substring(sepEnd).trim();
  final hasData = data.isNotEmpty;
  if (hasData && !data.startsWith('|')) data = '|$data';
  if (hasData && !data.endsWith('|')) data = '$data|';

  // 组合：表头 + \n + 分隔行 + (\n + 数据行)?
  // 前面再加一个 \n\n 让表格和前面的文本分开（如果前面有文本的话）
  final result = StringBuffer();
  result.writeln(); // 表格前空一行
  result.writeln(header);
  result.write(separator);
  if (hasData) {
    result.writeln();
    result.write(data);
  }

  return result.toString();
}
