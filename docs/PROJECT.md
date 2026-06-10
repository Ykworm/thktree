# 项目元信息

> 人类 + AI 共同维护：AI 改代码时必须同步更新本文件。
> - **元信息字段**（项目名 / 平台 / 构建命令 / LLM 描述）：人工定，AI 不自动改
> - **文档结构图 / 维护约定**：人类 + AI 共同维护
> 代码级别的状态、进度、文件路径由 [`docs/FEATURES.md`](FEATURES.md) 维护。

| 字段 | 内容 |
|------|------|
| 项目名称 | ThkTree |
| 语言 / 框架 | Flutter / Dart |
| 构建命令 | `flutter run`（iOS 为主），`flutter build ios` |
| 主要依赖 | go_router, riverpod（StateNotifier）, sqflite, flutter_markdown, shared_preferences |
| 存储方式 | Markdown 文件（正文）+ SQLite（关系/元数据） |
| LLM | DeepSeek V4（用户自配 API Key，支持多 Provider） |
| 国际化 | 中英双语（flutter_localizations） |
| 目标平台 | iOS（Android 目录存在但 MVP 不保证可用） |

## 文档结构

```
docs/
├── PROJECT.md            # 本文件：项目元信息
├── ARCHITECTURE.md       # 架构骨架 + 代码结构 + 文档地图（AI 工作前必读）
├── DECISIONS.md          # 所有架构决策的完整记录（ADR-NNN 顺序号 + 纯文段）
├── FEATURES.md           # 功能状态总表（含 README/Visual 路径导航）
├── TECH-DEBT.md          # 技术债
├── CHANGELOG/            # 已完成的设计/重构/迁移历史记录
└── modules/              # 按模块聚合（与 lib/ui/features/ 对齐）
    ├── themes/    # 主题列表 + 树视图
    ├── notes/     # 笔记浏览/编辑/详情
    ├── chat/      # 对话 + 流式回复
    ├── search/    # 全文搜索
    ├── llm/       # LLM Provider 配置
    └── settings/  # 设置页
```

> 注：跨模块横向文档（设计 token / 存储格式 / i18n / 分支流程等）放在 `docs/_shared/`。

## 新人接入

### 环境要求

| 依赖 | 版本 | 说明 |
|------|------|------|
| Flutter SDK | ^3.12.0 | 见 `pubspec.yaml` |
| Dart | 随 Flutter 附带 | |
| CocoaPods | 最新版 | iOS 构建必需 |
| Python 3 | 3.8+ | 用于运行检查脚本 |

### 首次接入步骤

1. **克隆仓库**
   ```bash
   git clone <repo-url>
   cd thk_tree
   ```

2. **运行 onboarding 检查脚本**
   ```bash
   python3 tools/check_onboarding.py
   ```
   脚本会自动检查：
   - 技能配置是否同步（`.qoder/skills/`）
   - Flutter 环境是否就绪
   - 项目依赖是否已安装
   - IDE 和 Git 配置状态

3. **根据脚本提示修复缺失项**

4. **安装项目依赖**
   ```bash
   flutter pub get
   cd ios && pod install && cd ..
   ```

5. **运行项目**
   ```bash
   flutter run
   ```

### 技能配置说明

本项目使用 AI 助手技能（Skills）来规范开发流程。`skills-lock.json` 记录了项目依赖的技能列表。

- 技能文件位于 `.qoder/skills/` 目录
- 每个技能包含 `SKILL.md` 说明文档
- 新人运行 `check_onboarding.py` 即可验证技能是否完整同步

> 如需添加新技能，参考 `skills-lock.json` 格式，并将技能文件放入 `.qoder/skills/`。

## 维护约定

- **`docs/PROJECT.md`** / **`docs/TECH-DEBT.md`**：人类 + AI 共同维护；元信息字段（项目名/平台/构建命令）由人定，AI 不自动改。
- **`docs/ARCHITECTURE.md`**：骨架/文档地图/关键类型表由人/AI 共同维护；**技术决策一律走 DECISIONS.md**，不在 ARCHITECTURE 内重复。
- **`docs/DECISIONS.md`**：人类 + AI 共同维护。**所有架构决策**（状态管理/路由/存储/关键库替换/治理）追加 ADR（`## ADR-NNN` 格式），纯文段。旧决策不删，加"已取代"段。详见 ADR-011。
- **`docs/FEATURES.md`**：人类 + AI 共同维护；新增功能/状态变更由 AI 提示人类确认。
- **`docs/CHANGELOG/`**：每次有重大设计/重构/迁移，新开一个 `YYYY-MM-DD-简述.md` 归档。
- **`docs/_shared/`** 和 **`docs/modules/`**：人类 + AI 共同维护——AI 改代码时同步更新对应文档。
