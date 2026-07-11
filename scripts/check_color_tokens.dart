#!/usr/bin/bin/dart
// Step 4 · Tier 4 · check_color_tokens.dart
// 防回归扫描：禁止 lib/ 内出现裸 CupertinoColors. / Color(0x…) / Color.from*。
// app_colors.dart 本身是唯一真源，排除。
// 用法：
//   dart run scripts/check_color_tokens.dart            # 默认 block 模式（发现即 exit 1）
//   dart run scripts/check_color_tokens.dart --mode=warn # 只报告不阻断（exit 0）
import 'dart:io';

const root = '/Users/yuweikang/dev/ykcode/ThkTree';
const libDir = '$root/lib';
const exclude = '$root/lib/ui/core/theme/app_colors.dart';

final patterns = [
  RegExp(r'CupertinoColors\.'),
  RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)'),
  RegExp(r'Color\.fromARGB\('),
  RegExp(r'Color\.fromRGBO\('),
  RegExp(r'Color\.from\('),
];

void main(List<String> args) {
  final mode = args.contains('--mode=warn') ? 'warn' : 'block';

  final hits = <String>[];
  for (final ent in Directory(libDir).listSync(recursive: true)) {
    if (ent is! File || !ent.path.endsWith('.dart')) continue;
    if (ent.path == exclude) continue;
    final lines = ent.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      for (final p in patterns) {
        if (p.hasMatch(lines[i])) {
          hits.add('${ent.path.replaceFirst('$root/', '')}:${i + 1}: ${lines[i].trim().length > 100 ? lines[i].trim().substring(0, 100) : lines[i].trim()}');
          break;
        }
      }
    }
  }

  if (hits.isEmpty) {
    print('OK · lib/ 内无裸色偏差（code-first 守住了）。');
    exit(0);
  }

  print('发现 ${hits.length} 处裸色偏差（应走 AppColors token）：');
  for (final h in hits) print('  $h');

  if (mode == 'warn') {
    print('\n[warn 模式] 仅报告，不阻断。修复后重跑 sync 脚本同步文档。');
    exit(0);
  }
  print('\n[block 模式] 提交被拦截。请改 lib/ui/core/theme/app_colors.dart 增/改 token，'
      '再把裸色改为 AppColors.<token>，最后 dart run scripts/sync-design-tokens.dart。');
  exit(1);
}
