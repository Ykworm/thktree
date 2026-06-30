class ParsedTreeNode {
  ParsedTreeNode({
    required this.title,
    required this.content,
    required this.depth,
  });

  final String title;
  final String content;
  final int depth;

  @override
  String toString() =>
      'ParsedTreeNode(depth=$depth, title=$title, content=${content.length}chars)';
}

List<ParsedTreeNode> parseMarkdownTree(String markdown) {
  final lines = markdown.split('\n');
  final nodes = <ParsedTreeNode>[];

  String? currentTitle;
  int currentDepth = 0;
  final contentBuffer = StringBuffer();

  void flushNode() {
    if (currentTitle == null) {
      contentBuffer.clear();
      return;
    }

    final content = contentBuffer.toString().trim();
    nodes.add(
      ParsedTreeNode(
        title: currentTitle!,
        content: content.isEmpty ? currentTitle! : content,
        depth: currentDepth,
      ),
    );
    currentTitle = null;
    contentBuffer.clear();
  }

  final nodeWithContentPattern = RegExp(r'^(\s*)- \*\*(.+?)\*\*\s+(.+)$');
  final nodePattern = RegExp(r'^(\s*)- \*\*(.+?)\*\*\s*$');
  final dimensionPattern = RegExp(r'^##\s+维度');
  final separatorPattern = RegExp(r'^---\s*$');

  for (final rawLine in lines) {
    final line = rawLine.replaceAll('\r', '');

    if (dimensionPattern.hasMatch(line) || separatorPattern.hasMatch(line)) {
      continue;
    }

    final nodeWithContentMatch = nodeWithContentPattern.firstMatch(line);
    if (nodeWithContentMatch != null) {
      flushNode();
      final indent = nodeWithContentMatch.group(1)!;
      currentTitle = nodeWithContentMatch.group(2)!.trim();
      final indentLength = indent.replaceAll('\t', '  ').length;
      currentDepth = (indentLength / 2).floor();
      contentBuffer.writeln(nodeWithContentMatch.group(3)!.trim());
      continue;
    }

    final nodeMatch = nodePattern.firstMatch(line);
    if (nodeMatch != null) {
      flushNode();
      final indent = nodeMatch.group(1)!;
      currentTitle = nodeMatch.group(2)!.trim();
      final indentLength = indent.replaceAll('\t', '  ').length;
      currentDepth = (indentLength / 2).floor();
      continue;
    }

    if (currentTitle != null && line.trim().isNotEmpty) {
      contentBuffer.writeln(line.trim());
    }
  }

  flushNode();
  return nodes;
}
