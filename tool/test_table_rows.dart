import 'package:thk_tree/ui/core/shared/markdown_rehydrate.dart';

void main() {
  // 只测 2 行数据的表格
  final input = '|A |B ||:---|:---|| row1-a | row1-b || row2-a | row2-b |';
  
  print('=== 输入 ===');
  print(input);
  
  // 手动调 _rehydrateTables 看看
  final rehydrated = _rehydrateTablesOnly(input);
  print('\n=== 仅表格重建后 ===');
  print(rehydrated);
  print('\n--- 用 --- 分行查看 ---');
  final lines = rehydrated.split('\n');
  for (var i = 0; i < lines.length; i++) {
    print('L$i: "${lines[i]}"');
  }
  
  print('\n=== 完整 rehydrate 后 ===');
  final full = rehydrateMarkdown(input);
  print(full);
  print('\n--- 用 --- 分行查看 ---');
  final fullLines = full.split('\n');
  for (var i = 0; i < fullLines.length; i++) {
    print('L$i: "${fullLines[i]}"');
  }
}

String _rehydrateTablesOnly(String text) {
  // 复制 _rehydrateTables 的逻辑来调试
  if (!text.contains('|')) return text;
  if (!RegExp(r':---').hasMatch(text)) return text;

  final separatorPattern = RegExp(
    r'\|[\s　]*:?-{2,}:?[\s　]*(\|[\s　]*:?-{2,}:?[\s　]*)+\|',
  );

  final matches = separatorPattern.allMatches(text).toList();
  if (matches.isEmpty) return text;

  final result = StringBuffer();
  var cursor = 0;

  for (final sepMatch in matches) {
    final sepStart = sepMatch.start;
    final sepEnd = sepMatch.end;
    final separatorText = sepMatch.group(0)!;
    final pipeCount = separatorText.split('').where((c) => c == '|').length;

    var headerEndIdx = sepStart - 1;
    while (headerEndIdx > cursor &&
        (text[headerEndIdx] == ' ' ||
            text[headerEndIdx] == '\t' ||
            text[headerEndIdx] == '　')) {
      headerEndIdx--;
    }
    if (headerEndIdx < cursor || text[headerEndIdx] != '|') {
      result.write(text.substring(cursor, sepEnd));
      cursor = sepEnd;
      continue;
    }

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
      result.write(text.substring(cursor, sepEnd));
      cursor = sepEnd;
      continue;
    }

    if (pipeCount <= 3 && headerStartIdx > cursor) {
      final prev = text[headerStartIdx - 1];
      if (prev != '\n' &&
          prev != ' ' &&
          prev != '\t' &&
          prev != '　' &&
          RegExp(r'[A-Za-z0-9\u4e00-\u9fa5]').hasMatch(prev)) {
        result.write(text.substring(cursor, sepEnd));
        cursor = sepEnd;
        continue;
      }
    }

    var dataStartIdx = sepEnd;
    while (dataStartIdx < text.length &&
        (text[dataStartIdx] == ' ' ||
            text[dataStartIdx] == '\t' ||
            text[dataStartIdx] == '　')) {
      dataStartIdx++;
    }

    var dataEndIdx = sepEnd;
    var scanPos = dataStartIdx;
    while (scanPos < text.length && text[scanPos] == '|') {
      var pos = scanPos;
      var pipesFound = 0;
      var lineHasNewline = false;
      while (pos < text.length && pipesFound < pipeCount) {
        if (text[pos] == '|') {
          pipesFound++;
        }
        if (text[pos] == '\n') {
          lineHasNewline = true;
          break;
        }
        pos++;
      }
      if (pipesFound == pipeCount) {
        dataEndIdx = pos;
        if (lineHasNewline) {
          scanPos = pos;
          if (scanPos < text.length && text[scanPos] == '\n') {
            scanPos++;
          }
          while (scanPos < text.length &&
              (text[scanPos] == ' ' ||
                  text[scanPos] == '\t' ||
                  text[scanPos] == '　')) {
            scanPos++;
          }
        } else {
          break;
        }
      } else {
        break;
      }
    }

    result.write(text.substring(cursor, headerStartIdx));
    final headerLine = text.substring(headerStartIdx, headerEndIdx + 1);
    result.writeln();
    result.writeln(headerLine);
    if (dataEndIdx > sepEnd) {
      result.writeln(separatorText);
      result.write(text.substring(dataStartIdx, dataEndIdx));
    } else {
      result.write(separatorText);
    }

    cursor = dataEndIdx;
  }

  result.write(text.substring(cursor));
  return result.toString();
}
