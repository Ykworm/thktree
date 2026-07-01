/// 估算文本的 token 数量（1 中文字符 ≈ 2 tokens，1 英文单词 ≈ 1.3 tokens）。
int estimateTokens(String text) {
  if (text.isEmpty) return 0;
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    // CJK 统一表意文字范围
    if (rune >= 0x4E00 && rune <= 0x9FFF) {
      buffer.write('xx');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  final charCount = buffer.length;
  final wordCount = buffer.toString().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  return (charCount * 0.5 + wordCount * 0.3).ceil();
}
