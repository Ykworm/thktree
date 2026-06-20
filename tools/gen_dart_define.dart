#!/usr/bin/env dart
// gen_dart_define.dart
//
// 把开发者友好的 LLM 配置 JSON（顶层 activeProvider / providers）包装成
// Flutter `--dart-define-from-file` 期望的 {"KEY":"VALUE"} 简单映射格式。
//
// 为什么需要这个工具：
// Flutter 的 --dart-define-from-file 只支持 {"KEY":"VALUE"} 形式的 key-value pairs，
// 不会直接把任意 JSON 当成 dart-define value。如果把 LLM 配置 JSON 原样传给
// --dart-define-from-file，Flutter 找不到 TEST_LLM_CONFIG_JSON 这个 key，会
// 静默返回空字符串。
//
// 用法：
//   dart run tools/gen_dart_define.dart <input.json> <output.json>
//
// 例：
//   dart run tools/gen_dart_define.dart \
//     ~/.thktree/test_llm_config.json \
//     build/dart_define.json
//   flutter test integration_test/ \
//     --dart-define-from-file=build/dart_define.json
//
// 注意：output.json 是临时文件，CI / 本地都不应该入仓；推荐放到 build/ 下。
// build/ 本身在 .gitignore 里。

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('用法: dart run tools/gen_dart_define.dart <input.json> <output.json>');
    stderr.writeln('');
    stderr.writeln('  <input.json>  开发者友好的 LLM 配置（activeProvider / providers）');
    stderr.writeln('  <output.json> Flutter dart-define-from-file 期望的 {"KEY":"VALUE"} 格式');
    exit(64); // EX_USAGE
  }

  final inputPath = args[0];
  final outputPath = args[1];

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('输入文件不存在: $inputPath');
    exit(66); // EX_NOINPUT
  }

  // 读输入文件，trim 去掉首尾空白。
  final rawInput = inputFile.readAsStringSync().trim();
  if (rawInput.isEmpty) {
    stderr.writeln('输入文件为空: $inputPath');
    exit(65); // EX_DATAERR
  }

  // 解析输入 JSON，得到结构化对象。
  // 早期失败：JSON 不合法时立刻报错，不要让 Flutter 工具链后面才报错。
  Object parsed;
  try {
    parsed = jsonDecode(rawInput);
  } on FormatException catch (e) {
    stderr.writeln('输入 JSON 不合法: $e');
    exit(65);
  }

  // ⚠️ 关键：必须把输入压缩为单行紧凑 JSON，否则 dart-define value
  // 会包含字面 \n（换行符 escape），触发 frontend_server 的 URI 解析错误：
  //   FormatException: Scheme not starting with alphabetic character
  //   -DTEST_LLM_CONFIG_JSON={...
  //
  // 原因：Flutter 把 --dart-define-from-file 的 value 当命令行参数透传给
  // frontend_server，frontend_server 在 resolveInputUri 里把每个 arg 当
  // URI 解析，URI 不允许包含真换行符。
  //
  // 用 jsonEncode(separators: compact) 重新序列化，去掉所有 \n + 缩进。
  final compact = jsonEncode(parsed);
  if (compact.contains('\n')) {
    stderr.writeln('内部错误: 紧凑化后仍含 \\n，请检查 Dart 行为');
    exit(70); // EX_SOFTWARE
  }

  // 包装成 Flutter 期望的 {"TEST_LLM_CONFIG_JSON": "<compact>"} 格式。
  final wrapped = jsonEncode({'TEST_LLM_CONFIG_JSON': compact});

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync('$wrapped\n');

  stdout.writeln('已生成: $outputPath');
  stdout.writeln('  注入内容字节数: ${compact.length} (compact JSON, 无换行)');
  stdout.writeln('  → 接下来可以跑:');
  stdout.writeln('       flutter test integration_test/ \\');
  stdout.writeln('         --dart-define-from-file=$outputPath');
}