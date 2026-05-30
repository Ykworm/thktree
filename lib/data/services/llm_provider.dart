enum LlmProvider {
  deepseek,
  openai,
  claude,
  gemini,
  minimax,
  kimi;

  String get displayName {
    switch (this) {
      case LlmProvider.deepseek:
        return 'DeepSeek';
      case LlmProvider.openai:
        return 'OpenAI';
      case LlmProvider.claude:
        return 'Claude';
      case LlmProvider.gemini:
        return 'Gemini';
      case LlmProvider.minimax:
        return 'MiniMax';
      case LlmProvider.kimi:
        return 'Kimi';
    }
  }

  String get defaultModel {
    switch (this) {
      case LlmProvider.deepseek:
        return 'deepseek-chat';
      case LlmProvider.openai:
        return 'gpt-4o';
      case LlmProvider.claude:
        return 'claude-sonnet-4-20250514';
      case LlmProvider.gemini:
        return 'gemini-2.5-flash';
      case LlmProvider.minimax:
        return 'MiniMax-Text-01';
      case LlmProvider.kimi:
        return 'moonshot-v1-8k';
    }
  }

  String get baseUrl {
    switch (this) {
      case LlmProvider.deepseek:
        return 'https://api.deepseek.com/v1';
      case LlmProvider.openai:
        return 'https://api.openai.com/v1';
      case LlmProvider.claude:
        return 'https://api.anthropic.com/v1';
      case LlmProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case LlmProvider.minimax:
        return 'https://api.minimaxi.com/v1';
      case LlmProvider.kimi:
        return 'https://api.moonshot.cn/v1';
    }
  }

  bool get isOpenAiCompatible {
    switch (this) {
      case LlmProvider.deepseek:
      case LlmProvider.openai:
      case LlmProvider.minimax:
      case LlmProvider.kimi:
        return true;
      case LlmProvider.claude:
      case LlmProvider.gemini:
        return false;
    }
  }

  int get contextWindowTokens {
    switch (this) {
      case LlmProvider.deepseek:
        return 64000;
      case LlmProvider.openai:
        return 128000;
      case LlmProvider.claude:
        return 200000;
      case LlmProvider.gemini:
        return 1048576;
      case LlmProvider.minimax:
        return 1048576;
      case LlmProvider.kimi:
        return 8000;
    }
  }

  String formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(0)}K';
    return tokens.toString();
  }
}

int estimateTokens(String text) {
  var tokens = 0.0;
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (code <= 0x7F) {
      tokens += 0.25;
    } else if (code <= 0x7FF) {
      tokens += 0.5;
    } else {
      tokens += 1.2;
    }
  }
  return tokens.ceil();
}
