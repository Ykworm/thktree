import 'dart:developer' as dev;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/services/session_markdown.dart';

/// 扫描到的单条 user input 记录。
class UserInputRecord {
  const UserInputRecord({
    required this.nodeId,
    required this.themeId,
    required this.content,
    required this.timestamp,
  });

  final String nodeId;
  final String themeId;
  final String content;
  final DateTime timestamp;
}

/// 用户输入总结服务。
///
/// 职责：
/// 1. 扫描所有 themes/*/nodes/*/session.md
/// 2. 文件修改日期粗筛 + 消息时间戳精筛
/// 3. 收集 user role 消息，调用 LLM 分类总结
class UserInputSummaryService {
  const UserInputSummaryService._();

  static const _summarySystemPrompt = '''
你是一个用户输入分析助手。给定用户在过去一段时间内的所有输入内容，请完成以下任务：

1. 将这些输入按主题/领域归类（自动判断类别，不需要预定义）
2. 每个类别用一行标题 + 若干要点概括用户的主要关注点
3. 要点应忠实反映用户的原始输入，不要添加用户没有提到的信息
4. 使用与用户输入相同的语言输出
5. 如果用户输入很少（少于 3 条），直接逐条列出，不需要归类

输出格式要求（严格遵守）：
- 每个类别以 "类别名称相关内容：" 开头
- 每个要点以 "  * " 开头（两个空格 + 星号 + 空格）
- 不要输出其他格式化内容（不要标题、不要编号、不要分隔线）
- 不要输出 ``` 代码块标记''';

  /// 扫描指定天数内的所有 user inputs。
  ///
  /// [themesDir] 是 `<rootDir>/themes/` 目录。
  /// [days] 是回溯天数。
  static Future<List<UserInputRecord>> collectUserInputs({
    required Directory themesDir,
    required int days,
  }) async {
    if (!await themesDir.exists()) return const [];

    final cutoff = DateTime.now().toUtc().subtract(Duration(days: days));
    final results = <UserInputRecord>[];

    await for (final themeEntry in themesDir.list(followLinks: false)) {
      if (themeEntry is! Directory) continue;
      final themeId = p.basename(themeEntry.path);

      // 节点目录在 <themeId>/nodes/ 下，子节点嵌套在父节点目录内
      // 递归扫描所有 session.md 文件
      final nodesDir = Directory(p.join(themeEntry.path, 'nodes'));
      if (!await nodesDir.exists()) continue;

      await for (final entry in nodesDir.list(recursive: true, followLinks: false)) {
        if (entry is! File) continue;
        if (p.basename(entry.path) != 'session.md') continue;

        final file = File(entry.path);

        // 粗筛：文件修改日期在 cutoff 之前则跳过
        final stat = await file.stat();
        if (stat.modified.isBefore(cutoff)) continue;

        // 从路径提取 nodeId（session.md 所在目录名）
        final nodeId = p.basename(p.dirname(entry.path));

        try {
          final content = await file.readAsString();
          final doc = parseSessionMarkdown(content);

          for (final msg in doc.messages) {
            if (msg.role != SessionRole.user) continue;

            final msgTime = DateTime.tryParse(msg.timestampUtcIso8601);
            if (msgTime == null || msgTime.isBefore(cutoff)) continue;

            final body = msg.body.trim();
            if (body.isEmpty) continue;

            results.add(UserInputRecord(
              nodeId: nodeId,
              themeId: themeId,
              content: body,
              timestamp: msgTime,
            ));
          }
        } catch (e) {
          dev.log('[UserInputSummary] Failed to parse ${entry.path}: $e');
        }
      }
    }

    // 按时间排序
    results.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return results;
  }

  /// 将 user inputs 拼接为 LLM 输入文本。
  static String _buildUserPrompt(List<UserInputRecord> inputs) {
    final buf = StringBuffer();
    buf.writeln('以下是用户在过去一段时间内的所有输入（共 ${inputs.length} 条）：');
    buf.writeln();
    for (var i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      final dateStr = input.timestamp.toLocal().toString().substring(0, 16);
      buf.writeln('[$dateStr] ${input.content}');
    }
    return buf.toString();
  }

  /// 调用 LLM 生成分类总结报告。
  ///
  /// 返回 Markdown 格式的报告文本。
  static Future<String> generateReport({
    required List<UserInputRecord> inputs,
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    required int contextWindow,
    CancelToken? cancelToken,
  }) async {
    final client = LlmClient.forConfig(provider, model: modelId);

    final messages = <Map<String, Object?>>[
      {'role': 'system', 'content': _summarySystemPrompt},
      {
        'role': 'user',
        'content': _buildUserPrompt(inputs),
      },
    ];

    final buffer = StringBuffer();
    final stream = client.streamChatCompletion(
      apiKey: apiKey,
      model: modelId,
      messages: messages,
      cancelToken: cancelToken,
    );
    await for (final delta in stream) {
      buffer.write(delta.content);
    }

    var result = buffer.toString().trim();
    // 去除 LLM 可能返回的 <think> 标签
    result =
        result.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
    result = result.replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '');
    return result.trim();
  }
}
