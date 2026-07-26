#!/usr/bin/bin/dart

// Step 4 · Tier 2/4 · sync-design-tokens.dart
// code-first 单向生成器：
//  1) 从 lib/ui/core/theme/*.dart 生成 docs/_shared/design-tokens.yaml
//  2) 从同一个真源注入 docs/_shared/design-audit/thktree-design-spec.html 的 第 9 节 token 对照表
// 用法：dart run scripts/sync-design-tokens.dart
// 改色流程：改 app_colors.dart → 跑本脚本 → yaml + HTML 第 9 节 自动同步（不漂）。
import 'dart:io';

// Repo root = parent of scripts/（worktree / 主仓均可，禁止写死绝对路径）
final root = File(Platform.script.toFilePath()).parent.parent.path;
final outPath = '$root/docs/_shared/design-tokens.yaml';
final htmlPath = '$root/docs/_shared/design-audit/thktree-design-spec.html';
const htmlMarkerStart = '<!-- AUTOGEN_TOKEN_TABLE_START -->';
const htmlMarkerEnd = '<!-- AUTOGEN_TOKEN_TABLE_END -->';

final colorFile = '$root/lib/ui/core/theme/app_colors.dart';
final paletteFile = '$root/lib/ui/core/theme/app_palette_tokens.dart';
final spacingFile = '$root/lib/ui/core/theme/app_spacing.dart';
final durationFile = '$root/lib/ui/core/theme/app_durations.dart';

final hexRe = RegExp(r'0x([0-9A-Fa-f]{8})');

final constRe = RegExp(
  r'static const (\w+)\s*=\s*Color\((0x[0-9A-Fa-f]{8})\);[ \t]*(?://\s*(.*))?',
);
final getterRe = RegExp(
  r'static Color get (\w+) =>\s*_brightness == Brightness\.light\s*\?\s*const Color\((0x[0-9A-Fa-f]{8})\)\s*(?://[^\n]*)?\s*:\s*const Color\((0x[0-9A-Fa-f]{8})\);',
);
final singleGetterRe = RegExp(
  r'static Color get (\w+) =>\s*const Color\((0x[0-9A-Fa-f]{8})\);',
);
final refGetterRe = RegExp(r'static Color get (\w+) =>\s*(\w+);');

Map<String, String> _parsePaletteAliases(String src) {
  final out = <String, String>{};
  final re = RegExp(r'static const (_\w+) = Color\((0x[0-9A-Fa-f]{8})\)');
  for (final m in re.allMatches(src)) {
    out[m.group(1)!] = m.group(2)!;
  }
  return out;
}

Map<String, String> _parsePaletteBlock(
  String src,
  String blockName,
  Map<String, String> aliases,
) {
  final marker = 'static const $blockName = AppPaletteTokens(';
  final start = src.indexOf(marker);
  if (start < 0) return {};
  var depth = 0;
  var i = start + marker.length;
  final buf = StringBuffer();
  while (i < src.length) {
    final ch = src[i];
    if (ch == '(') depth++;
    if (ch == ')') {
      if (depth == 0) break;
      depth--;
    }
    buf.write(ch);
    i++;
  }
  final out = <String, String>{};
  final fieldRe = RegExp(r'(\w+):\s*(?:Color\((0x[0-9A-Fa-f]{8})\)|(_\w+)),');
  for (final m in fieldRe.allMatches(buf.toString())) {
    final name = m.group(1)!;
    if (name == 'nodePalettes') continue;
    final hex = m.group(2) ?? aliases[m.group(3)!];
    out[name] = hex!;
  }
  return out;
}

/// 解析 app_colors.dart + app_palette_tokens.dart → color 段 entries
Map<String, Map<String, String>> parseColors(
  String colorSrc,
  String paletteSrc,
) {
  final primitives = <String, String>{};
  final semantic = <String, String>{};
  final decor = <String, String>{};

  final aliases = _parsePaletteAliases(paletteSrc);
  final warmPaper = _parsePaletteBlock(paletteSrc, 'warmPaper', aliases);
  final slate = _parsePaletteBlock(paletteSrc, 'slate', aliases);

  for (final name in warmPaper.keys) {
    final light = warmPaper[name]!;
    final dark = slate[name] ?? light;
    final entry = light == dark
        ? 'value: "$light"'
        : 'light: "$light", dark: "$dark"';
    if (_isPrimitive(name)) {
      primitives[name] = entry.contains('light:') ? 'value: "$light"' : entry;
    } else {
      semantic[name] = entry;
    }
  }

  semantic['success'] = 'value: "${warmPaper['paletteSage']!}"';
  semantic['clay'] = 'ref: "paletteClay"';
  semantic['gold'] = 'ref: "paletteGold"';
  semantic['plum'] = 'ref: "palettePlum"';

  for (final m in constRe.allMatches(colorSrc)) {
    final name = m.group(1)!;
    final hex = m.group(2)!;
    final label = m.group(3)?.trim() ?? '';
    final entry = label.isEmpty
        ? 'value: "$hex"'
        : 'value: "$hex", label: "$label"';
    if (_isDecor(name)) {
      decor[name] = entry;
    } else if (_isPrimitive(name)) {
      primitives[name] = entry;
    } else {
      semantic[name] = entry;
    }
  }

  for (final m in refGetterRe.allMatches(colorSrc)) {
    final target = m.group(2)!;
    if (target == '_current') continue;
    semantic[m.group(1)!] = 'ref: "$target"';
  }

  return {'primitive': primitives, 'semantic': semantic, 'decor': decor};
}

bool _isPrimitive(String n) => [
  'white',
  'black',
  'transparent',
  'champagneGold',
  'warmGray',
  'dustyRose',
  'sageGray',
  'slateBlue',
].contains(n);
bool _isDecor(String n) => [
  'labBg',
  'labAccentBlue',
  'labAccentOrange',
  'labAccentPurple',
  'waveTeal',
  'waveOrange',
  'wavePurple',
].contains(n);

/// 解析 AppSp → dimension 段
Map<String, String> parseSpacing(String src) {
  final out = <String, String>{};
  final re = RegExp(r'static const (\w+) = ([\d.]+)(?:\s*//.*)?;');
  for (final m in re.allMatches(src)) {
    final name = m.group(1)!;
    final val = m.group(2)!;
    final unit = val.contains('.') ? 'px' : 'px';
    out[name] = 'value: $val, unit: "$unit"';
  }
  return out;
}

/// 解析 AppDur → time 段
Map<String, String> parseDuration(String src) {
  final out = <String, String>{};
  final durRe = RegExp(
    r'static const (\w+) = Duration\(milliseconds: (\d+)\);',
  );
  for (final m in durRe.allMatches(src)) {
    out[m.group(1)!] = 'value: ${m.group(2)}, unit: "ms"';
  }
  final curveRe = RegExp(r'static const (\w+) = Curves\.(\w+);');
  for (final m in curveRe.allMatches(src)) {
    out[m.group(1)!] = 'value: "${m.group(2)}", type: "curve"';
  }
  return out;
}

String emitGroup(
  String title,
  Map<String, String> map, {
  String indent = '  ',
}) {
  final buf = StringBuffer()..writeln('$indent$title:');
  final inner = '$indent  ';
  for (final e in map.entries) {
    buf.writeln('$inner${e.key}: { ${e.value} }');
  }
  return buf.toString();
}

// ── HTML 第 9 节 注入 ────────────────────────────────────────────────

/// 0xRRGGBBAA → #RRGGBB（丢掉 alpha，预览用）
String _cssHex(String raw) {
  final m = hexRe.firstMatch(raw);
  if (m == null) return raw;
  return '#${m.group(1)!.substring(2)}';
}

String _swatch(String css) =>
    '<span style="display:inline-block;width:14px;height:14px;border-radius:3px;'
    'border:1px solid var(--border);vertical-align:middle;background:$css;"></span>';

String _td(String s) => '<td style="padding:6px;">$s</td>';

String _buildSemanticTable(Map<String, String> semantic) {
  final rows = <String>[];
  for (final e in semantic.entries) {
    final v = e.value;
    final lightM = RegExp(r'light:\s*"(0x[0-9A-Fa-f]{8})"').firstMatch(v);
    final darkM = RegExp(r'dark:\s*"(0x[0-9A-Fa-f]{8})"').firstMatch(v);
    final valM = RegExp(r'value:\s*"(0x[0-9A-Fa-f]{8})"').firstMatch(v);
    final refM = RegExp(r'ref:\s*"(\w+)"').firstMatch(v);
    final labelM = RegExp(r'label:\s*"(.*?)"').firstMatch(v);
    final label = labelM?.group(1) ?? '';
    late final String lightCss, darkCss;
    if (lightM != null && darkM != null) {
      lightCss = _cssHex(lightM.group(1)!);
      darkCss = _cssHex(darkM.group(1)!);
    } else if (valM != null) {
      lightCss = darkCss = _cssHex(valM.group(1)!);
    } else {
      lightCss = darkCss = '#000000';
    }
    final valueCell = refM != null
        ? 'ref → ${refM.group(1)}'
        : '$lightCss / $darkCss';
    rows.add(
      '<tr>${_td('<code>${e.key}</code>')}${_td(lightCss)}'
      '${_td(darkCss)}${_td('${_swatch(lightCss)} $valueCell')}'
      '${_td(label)}</tr>',
    );
  }
  return '''
  <h3>语义 token（随亮度变化）</h3>
  <table style="border-collapse: collapse; width: 100%; font-size: 13px;">
    <thead><tr style="text-align: left; border-bottom: 1px solid var(--border);"><th style="padding:6px;">Token</th><th style="padding:6px;">Light</th><th style="padding:6px;">Dark</th><th style="padding:6px;">预览 / 值</th><th style="padding:6px;">说明</th></tr></thead>
    <tbody>
${rows.join('\n')}
    </tbody>
  </table>''';
}

String _buildPrimDecorTable(String title, Map<String, String> group) {
  final rows = <String>[];
  for (final e in group.entries) {
    final v = e.value;
    final valM = RegExp(r'value:\s*"(0x[0-9A-Fa-f]{8})"').firstMatch(v);
    final labelM = RegExp(r'label:\s*"(.*?)"').firstMatch(v);
    final hex = valM != null ? _cssHex(valM.group(1)!) : '';
    final label = labelM?.group(1) ?? '';
    rows.add(
      '<tr>${_td('<code>${e.key}</code>')}${_td(hex)}'
      '${_td('${_swatch(hex)} $hex')}${_td(label)}</tr>',
    );
  }
  return '''
  <h3 style="margin-top: 24px;">$title</h3>
  <table style="border-collapse: collapse; width: 100%; font-size: 13px;">
    <thead><tr style="text-align: left; border-bottom: 1px solid var(--border);"><th style="padding:6px;">Token</th><th style="padding:6px;">Hex</th><th style="padding:6px;">预览</th><th style="padding:6px;">说明</th></tr></thead>
    <tbody>
${rows.join('\n')}
    </tbody>
  </table>''';
}

/// 把生成的 token 表注入 HTML 的标记之间（标记内旧内容整体替换）。
void injectHtmlTokenTable(String generated) {
  final html = File(htmlPath).readAsStringSync();
  final start = html.indexOf(htmlMarkerStart);
  final end = html.indexOf(htmlMarkerEnd);
  if (start < 0 || end < 0) {
    print('WARN: HTML 第 9 节 标记未找到，跳过注入');
    return;
  }
  final before = html.substring(0, start + htmlMarkerStart.length);
  final after = html.substring(end);
  File(htmlPath).writeAsStringSync('$before\n$generated\n  $after');
  print('INJECTED 第 9 节 token table → $htmlPath');
}

void main() {
  final colorSrc = File(colorFile).readAsStringSync();
  final paletteSrc = File(paletteFile).readAsStringSync();
  final colors = parseColors(colorSrc, paletteSrc);
  final spacing = parseSpacing(File(spacingFile).readAsStringSync());
  final duration = parseDuration(File(durationFile).readAsStringSync());

  final buf = StringBuffer();
  buf.writeln('# ThkTree Design Tokens — 自动镜像（code-first 真源）');
  buf.writeln(
    '# 由 scripts/sync-design-tokens.dart 从 lib/ui/core/theme/*.dart 生成',
  );
  buf.writeln(
    '# 不要手改本文件；改色请改 app_colors.dart 后重跑 `dart run scripts/sync-design-tokens.dart`。',
  );
  buf.writeln(
    '# 真源：app_palette_tokens.dart (palette) / app_colors.dart (const) / app_spacing.dart (dimension) / app_durations.dart (time)',
  );
  buf.writeln();

  buf.writeln('color:');
  buf.write(emitGroup('primitive', colors['primitive']!, indent: '  '));
  buf.write(emitGroup('semantic', colors['semantic']!, indent: '  '));
  buf.write(emitGroup('decor', colors['decor']!, indent: '  '));

  buf.writeln();
  buf.write(emitGroup('dimension', spacing, indent: '  '));
  buf.writeln();
  buf.write(emitGroup('time', duration, indent: '  '));

  File(outPath).writeAsStringSync(buf.toString());
  print('WROTE $outPath');
  print(
    'colors: ${colors.values.expand((m) => m.keys).length} '
    'spacing: ${spacing.length} duration: ${duration.length}',
  );

  // ── HTML 第 9 节 注入（与 yaml 同源，永不漂）──
  final generated =
      _buildSemanticTable(colors['semantic']!) +
      _buildPrimDecorTable('原语 / scrim / 装饰 token', {
        ...colors['primitive']!,
        ...colors['decor']!,
      });
  injectHtmlTokenTable(generated);
}
