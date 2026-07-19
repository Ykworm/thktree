# 模块登记表（Module Registry）

> **合法模块 id 的唯一名单。** ctsync / 收尾 / 新功能归属 **只认本表 + 下表目录名**。  
> **禁止** LLM 自由发明 `docs/modules/<新名>/`。  
> 规范总述：根目录 `AGENTS.md`（模块身份 + Flow 全景）。

## 登记表

| id | 主代码路径 | 文档路径 | 一句话职责 |
|----|------------|----------|------------|
| `themes` | `lib/ui/features/themes/` | `docs/modules/themes/` | 主题列表、树节点、合并 chat 入口 |
| `chat` | `lib/ui/features/chat/` | `docs/modules/chat/` | 对话 UI、流式、composer、分支交互 |
| `notes` | `lib/ui/features/notes/` | `docs/modules/notes/` | 笔记浏览/编辑/详情与 NoteStore 边界 |
| `lab` | `lib/ui/features/lab/` | `docs/modules/lab/` | 实验室（关键词、碰撞、输入摘要等） |
| `llm` | `lib/ui/features/llm/` + data LLM 客户端 | `docs/modules/llm/` | Provider / Key / 模型能力与协议 |
| `search` | `lib/ui/features/search/` | `docs/modules/search/` | 全文搜索与跨模块跳转 |
| `settings` | `lib/ui/features/settings/` | `docs/modules/settings/` | 设置、TTS、认证相关入口 |
| `doc_split` | `lib/ui/features/doc_split/` | （可后补 `docs/modules/doc_split/`） | 文档拆分工具 |
| `about` | `lib/ui/features/about/` | （可后补） | 关于页 |
| `backup_restore` | `lib/ui/features/backup_restore/` | （可后补） | 备份恢复 |
| `wiki` | `lib/ui/features/wiki/` + `lib/data/services/wiki_store.dart` | `docs/modules/wiki/` | Tree 转 Wiki（快照生成、阅读、导出） |
| `_shared` | `lib/ui/core/`、`lib/data/`、`docs/_shared/` | `docs/_shared/` | 跨模块共享（非业务 feature 目录） |

> 上表 **id 必须与** `docs/modules/<id>/`（若已建）及 FEATURES「模块」列一致。  
> 代码在 `lib/ui/features/X` 但尚无 docs 目录时：ctsync 可标「待确认：补登记/建 README」，**不得**另起近义 id。

## 新模块登记 — 谁干活？

**默认不麻烦人类手填仪式。** Agent 在 `register-module` 节点或你说「登记模块 X」时按序改表/建目录；人最多确认 **slug 叫什么**。

```text
① slug  ② 本表增行  ③ FEATURES 模块列  ④ mkdir README  ⑤ 代码
```

### 双人起两名 / 野目录

- **不要求**人跑脚本。  
- Agent / ctsync 发现冲突 → **列出选项**。  
- 人只说：**保留哪个 id**。  

可选（CI/agent）：`bash tools/check_module_registry.sh` — **agent 跑**，人只看结果。

## ctsync 怎么用本表

1. 读本表 → 合法 id。  
2. `git diff` → 映射到 id。  
3. 跑目录↔表一致性检查。  
4. 只更新已登记 `docs/modules/<id>/`；清单确认后再改。

## 维护

- 增删模块：同 PR 改 **本表 + FEATURES + 目录**。  
- 他处只 **链接本文件**，不复制第二份名单。
