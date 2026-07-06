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
  // PASS 0: 表格重建 + 保护（必须最先做！）
  //
  // 1. 先识别并重建表格（补上行间换行）
  // 2. 再把表格用占位符保护起来，避免后续的列表/标题/HR 规则
  //    误伤表格内容里的 `-`、`#`、`**` 等字符
  // 3. 所有其他规则跑完后，再还原表格
  // ═══════════════════════════════════════════════════════════════
  s = _rehydrateTables(s);

  // 用占位符保护已重建的表格
  final tablePlaceholders = <String, String>{};
  var tableCounter = 0;
  // 匹配已重建好的表格块：表头行 + 分隔行 + (可选)数据行
  // 每行以 | 开头和结尾，中间是 :--- 分隔行
  final tableBlockPattern = RegExp(
    r'^\|.+\|\n\|[\s　]*:?-{2,}:?[\s　]*(\|[\s　]*:?-{2,}:?[\s　]*)+\|(\n\|.+\|)*$',
    multiLine: true,
  );
  s = s.replaceAllMapped(tableBlockPattern, (m) {
    final placeholder = '\u0000TABLE_${tableCounter++}\u0000';
    tablePlaceholders[placeholder] = m.group(0)!;
    return placeholder;
  });

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

  // 还原被占位符保护的表格
  for (final entry in tablePlaceholders.entries) {
    s = s.replaceFirst(entry.key, entry.value);
  }

  return s.trimLeft();
}

// ═══════════════════════════════════════════════════════════════
// 表格重建
// ═══════════════════════════════════════════════════════════════

/// 从压扁的文本中识别 markdown 表格，补上行间换行。
///
/// **识别思路**：以表格分隔行（包含 `|:---|` 这类模式）为锚点，
/// 向前找表头行、向后找数据行，每行必须有相同数量的 `|`。
///
/// 为什么要最先做？因为表格分隔行 `:---` 里有 `---`，
/// 会被后续的 HR（水平分割线）规则误切成独立段落。
String _rehydrateTables(String text) {
  if (!text.contains('|')) return text;
  if (!RegExp(r':---').hasMatch(text)) return text;

  // 分隔行模式：连续的 |:---|:---|...
  final separatorPattern = RegExp(
    r'\|[\s　]*:?-{2,}:?[\s　]*(\|[\s　]*:?-{2,}:?[\s　]*)+\|',
  );

  final matches = separatorPattern.allMatches(text).toList();
  if (matches.isEmpty) return text;

  // 从左向右构建结果
  final result = StringBuffer();
  var cursor = 0;

  for (final sepMatch in matches) {
    final sepStart = sepMatch.start;
    final sepEnd = sepMatch.end;
    final separatorText = sepMatch.group(0)!;
    final pipeCount = separatorText.split('').where((c) => c == '|').length;

    // 向左找表头最后一个 |
    var headerEndIdx = sepStart - 1;
    while (headerEndIdx > cursor &&
        (text[headerEndIdx] == ' ' ||
            text[headerEndIdx] == '\t' ||
            text[headerEndIdx] == '　')) {
      headerEndIdx--;
    }
    if (headerEndIdx < cursor || text[headerEndIdx] != '|') {
      // 分隔行前面没有 | → 不是表格，原样写入
      result.write(text.substring(cursor, sepEnd));
      cursor = sepEnd;
      continue;
    }

    // 从 headerEndIdx 向左数 pipeCount 个 |，遇到换行就停（表格不跨行）
    var headerStartIdx = headerEndIdx;
    var pipesLeft = pipeCount;
    var hitNewline = false;
    while (headerStartIdx >= cursor && pipesLeft > 0) {
      if (text[headerStartIdx] == '\n') {
        hitNewline = true;
        break;
      }
      if (text[headerStartIdx] == '|') {
        pipesLeft--;
        if (pipesLeft == 0) break;
      }
      headerStartIdx--;
    }

    if (pipesLeft > 0 || headerStartIdx < cursor || hitNewline) {
      // 没找齐，或跨行了 → 不是表格
      result.write(text.substring(cursor, sepEnd));
      cursor = sepEnd;
      continue;
    }

    // 向右找数据行（可能多行，压扁时行与行之间直接用 | 连）
    var dataStartIdx = sepEnd;
    while (dataStartIdx < text.length &&
        (text[dataStartIdx] == ' ' ||
            text[dataStartIdx] == '\t' ||
            text[dataStartIdx] == '　')) {
      dataStartIdx++;
    }

    // 用 | 计数方式判断有多少行数据：
    // 每 pipeCount 个 | 为一行，连续匹配直到不够一行为止
    // （压扁的表格里行与行之间没有换行，只有 || 连接）
    var dataEndIdx = sepEnd;
    if (dataStartIdx < text.length && text[dataStartIdx] == '|') {
      var pos = dataStartIdx;
      var pipesFound = 0;
      var totalRowPipes = 0; // 累计匹配到的 | 数量
      while (pos < text.length) {
        if (text[pos] == '|') {
          pipesFound++;
          totalRowPipes++;
          if (pipesFound == pipeCount) {
            // 完成一行
            dataEndIdx = pos + 1; // 包含最后这个 |
            pipesFound = 0;
            // 继续看下一个字符是不是 |（下一行的开始）
            pos++;
            if (pos >= text.length || text[pos] != '|') {
              break; // 下一个不是 |，表格数据行结束
            }
            // 跳过行首空白（如果有的话）
            // 其实压扁时一般没有空白，直接继续
            continue;
          }
        }
        if (text[pos] == '\n') break; // 遇到换行就停（说明表格后面有正常文本）
        pos++;
      }
      // 如果一行都没匹配全，dataEndIdx 保持 sepEnd
      if (totalRowPipes < pipeCount) {
        dataEndIdx = sepEnd;
      }
    }

    // 写入：[cursor, headerStartIdx) + 重建的表格
    result.write(text.substring(cursor, headerStartIdx));

    // 重建表格：前面空一行 + 表头\n分隔行\n数据行(每行)
    // 表格最后也加一个换行，确保和后续内容分开（便于占位符匹配）
    final headerLine = text.substring(headerStartIdx, headerEndIdx + 1);
    result.writeln(); // 表格前空一行
    result.writeln(headerLine);
    if (dataEndIdx > sepEnd) {
      result.writeln(separatorText);
      // 数据行按 pipeCount 个 | 为一行，逐行写入
      final dataText = text.substring(dataStartIdx, dataEndIdx);
      var dataPos = 0;
      var firstRow = true;
      while (dataPos < dataText.length) {
        var rowPipes = 0;
        var rowStart = dataPos;
        while (dataPos < dataText.length && rowPipes < pipeCount) {
          if (dataText[dataPos] == '|') {
            rowPipes++;
          }
          dataPos++;
        }
        if (rowPipes == pipeCount) {
          if (!firstRow) result.writeln();
          result.write(dataText.substring(rowStart, dataPos));
          firstRow = false;
        } else {
          break; // 不够一行，丢弃
        }
      }
      result.writeln(); // 表格最后一行后加换行
    } else {
      result.writeln(separatorText); // 分隔行后也加换行
    }

    cursor = dataEndIdx;
  }

  // 写入剩余部分
  result.write(text.substring(cursor));

  return result.toString();
}
