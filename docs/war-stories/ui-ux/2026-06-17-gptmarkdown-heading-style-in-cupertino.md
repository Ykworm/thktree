# GptMarkdown 标题样式在 CupertinoApp 中失效

**日期**：2026-06-17  
**模块**：notes / 笔记详情  
**标签**：Flutter, UI, Markdown, Cupertino, 主题

## 现象

笔记详情页中，Markdown 标题渲染为正文大小：

- `# 标题` 应该显示为大号 h1，但实际与正文一样大
- `## 副标题` 同样没有层级区分
- 标题下方还自动插入了一条分隔线

## 根因分析

`GptMarkdown` 的 `HTag` 组件依赖 `Theme.of(context).textTheme.headlineLarge` 获取标题样式。但项目使用 `CupertinoApp` 作为根 widget，Cupertino 主题不提供 Material 的 `textTheme`（`headlineLarge` / `headlineMedium` / `headlineSmall` 等），导致标题样式 fallback 为默认正文。

此外，`GptMarkdownThemeData.autoAddDividerLineAfterH1` 默认值为 `true`，导致每个 h1 下方自动出现分隔线，与设计不符。

## 解决方案

### 1. 全局配置 GptMarkdownTheme

在 `main.dart` 中，为整个 App 提供 `GptMarkdownTheme`：

```dart
import 'package:gpt_markdown/gpt_markdown.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      // ... 其他配置
      builder: (context, child) {
        return GptMarkdownTheme(
          data: GptMarkdownThemeData(
            h1: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.label.resolveFrom(context),
            ),
            h2: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label.resolveFrom(context),
            ),
            h3: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label.resolveFrom(context),
            ),
            highlightColor: AppColors.surfaceMuted,  // 反引号高亮背景色
            autoAddDividerLineAfterH1: false,  // 关闭 h1 自动横线
          ),
          child: child!,
        );
      },
    );
  }
}
```

### 2. 局部覆盖（如需特定页面特殊样式）

```dart
GptMarkdownTheme(
  data: GptMarkdownThemeData(
    h1: TextStyle(fontSize: 32),  // 特定页面更大标题
  ),
  child: GptMarkdown(markdownText),
)
```

## 关键代码

`lib/main.dart` 中的配置：

```dart
builder: (context, child) => GptMarkdownTheme(
  data: GptMarkdownThemeData(
    h1: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    h2: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    h3: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    highlightColor: AppColors.surfaceMuted,
    autoAddDividerLineAfterH1: false,
  ),
  child: child!,
),
```

## 相关文件

- `lib/main.dart` — GptMarkdownTheme 全局配置
- `lib/ui/features/notes/note_detail_screen.dart` — 笔记详情页使用 GptMarkdown

## 参考链接

- [NoteDetailScreen UI 修复文档](../modules/notes/specs/note-detail-ui-fix.md)
- [笔记详情页 UI 重构](../modules/notes/CHANGELOG.md) — 第 8 节

## 复盘

- **为什么一开始没发现**：开发初期 Markdown 内容多为纯文本，没有标题语法，所以未触发样式问题。当用户开始使用 `#` 写标题时，问题才暴露。
- **以后如何避免**：
  1. 引入任何依赖 Material Theme 的第三方 widget 时，先检查项目根 widget 是 MaterialApp 还是 CupertinoApp
  2. 在 `main.dart` 中统一配置第三方库的 theme，避免分散到各页面
  3. 测试时覆盖常见 Markdown 语法：标题、列表、代码块、引用等
- **扩展**：此问题模式适用于所有依赖 Material `textTheme` 的第三方 widget 在 CupertinoApp 中的使用场景。
