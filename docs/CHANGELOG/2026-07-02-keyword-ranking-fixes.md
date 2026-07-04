# Keyword Ranking 修复汇总（2026-07-02）

## 1. KeywordGlobalFile.fromJson 兼容 Map/List

- **文件**：`lib/data/services/keyword_global_storage.dart`
- **问题**：`toJson()` 把 `keywords` 序列化为 Map（`{keyword: entry}`），但 `fromJson()` 强转为 `List`，导致类型转换错误
- **修复**：`fromJson()` 同时兼容 Map 和 List 两种格式，向后兼容旧数据

## 2. Provider fallback：遍历所有已配置 key 的提供商

- **文件**：`lib/ui/features/lab/keyword_ranking/keyword_analysis_controller.dart`
- **问题**：`startAnalysis()` 硬编码 `providers.first`，如果第一个 provider 没有 API key 直接报错
- **修复**：遍历所有 providers，找到第一个同时有 API key 和模型的 provider，与 chat controller 行为一致

## 3. Keyword detail 路由修复

- **文件**：`lib/ui/features/lab/keyword_ranking/keyword_detail_screen.dart`
- **问题**：
  - 路由路径缺少 `/tree`，跳转到 `/themes/:themeId` 但实际路由是 `/themes/:themeId/tree`
  - `themeId` 含空格（如 `thm_ 01KW...`）未做 URL 编码，GoRouter 解析失败
  - 点击"跳转到对话"错误导航到 theme detail 而非 chat screen
- **修复**：补 `/tree` 路径 + URL 编码 themeId/leafId/keyword + 路由改为 `/themes/:themeId/nodes/:nodeId`

## 4. Fresh leaf 禁用选择

- **文件**：
  - `lib/ui/features/lab/keyword_ranking/leaf_selection_screen.dart` — UI 层
  - `lib/ui/features/lab/keyword_ranking/keyword_analysis_controller.dart` — 逻辑层
- **问题**：fresh（已分析、内容未变）的 chat 仍可被选中并送去 LLM 分析，浪费 API 额度
- **修复**：
  - UI：fresh 的 checkbox 灰掉不可点击，标题变灰
  - 全选按钮：只统计 pending + stale，跳过 fresh
  - `selectAllForTheme`：跳过 fresh leaf
  - `startAnalysis`：兜底跳过 fresh leaf

## 5. Chat 表格工具栏

- **文件**：`lib/ui/core/shared/message_bubble.dart`
- **问题**：复制/全屏按钮在 message 顶部，且一个 message 有多张 table 时只有一组按钮
- **修复**：通过 `tableBuilder` 回调为每张 table 独立包裹工具栏（复制 + 全屏按钮），按钮贴着每张 table 顶部右侧
