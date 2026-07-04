# Chat ↔ 笔记互通功能

## 背景

当前 Chat 和 Notes 之间只有 单向路径（笔记→对话），缺少"对话内容转为笔记"的入口。
同时笔记缺少跨主题转移和 AI 标题生成能力。

## 功能拆分

### F1: Chat → 笔记（存为笔记）

- 触发位置：助手消息操作栏（复制、TTS、分享旁边）
- 流程：点击"存为笔记" → 用消息正文前 N 字做临时标题 → 创建笔记 → 跳转 NoteEditorScreen
- 不弹 ThemePicker，直接保存到当前对话所在主题
- NoteEditorScreen 以 loadMode 打开，用户可顺手改标题

### F2: 笔记 → 生成标题（LLM）

- 触发位置：NoteDetailScreen 更多菜单（网格底栏）
- 流程：点击"生成标题" → 调 LLM 生成标题 → renameNote → 刷新 UI
- 复用 TitleSuggestionService 的 LLM 调用模式

### F3: 笔记 → 转移主题

- 触发位置：NoteDetailScreen 更多菜单（网格底栏）
- 流程：点击"转移" → 弹 ThemePicker → 移动文件到目标主题 notes/ 目录 → 更新 frontmatter themeId → 刷新 UI
- 需要 NoteStore.moveNote() 新方法

## 影响文件

- `lib/data/stores/note_store.dart` — 加 moveNote 方法
- `lib/ui/core/shared/message_bubble.dart` — 加"存为笔记"按钮
- `lib/ui/features/chat/chat_screen.dart` — 传递 onSaveToNote 回调
- `lib/ui/features/notes/note_detail_screen.dart` — 更多菜单加"生成标题"+"转移"
- `lib/l10n/app_en.arb` / `lib/l10n/app_zh.arb` — 新增 l10n 字符串

## 验收

- [ ] 助手消息底部出现笔记图标按钮
- [ ] 点击后笔记创建成功，跳转编辑页
- [ ] 更多菜单出现"生成标题"和"转移"
- [ ] "生成标题"调 LLM 成功替换标题
- [ ] "转移"弹出主题选择器，移动后笔记归属更新
