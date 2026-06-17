# 工具参考手册

> 执行 context-sync 或代码分析时按需查阅。AGENTS.md 中有简要指引。

---

## CodeGraph（代码智能）

**优先级**：最高。查符号、调用关系、影响分析时首选。

### 常用命令

```bash
# 搜索符号（类、函数、方法、常量）
codegraph query "AppColors"
codegraph query "ThkListTile" --kind class
codegraph query "colorForTheme" --limit 20

# 谁调用了它（callers）
codegraph callers "colorForTheme"
codegraph callers "ThkListTile"

# 它调用了谁（callees）
codegraph callees "ChatScreen.build"

# 改它会影响什么（impact）
codegraph impact "AppColors.accent"
codegraph impact "ThkListTile" --depth 3

# 找受影响的测试文件
codegraph affected lib/ui/core/widgets/thk_list_tile.dart

# 查看项目文件结构
codegraph files --filter lib/ui/features/themes

# 查看索引状态
codegraph status

# 增量同步（代码改动后）
codegraph sync

# 全量重建索引
codegraph index --force
```

### 使用场景

| 场景 | 命令 | 说明 |
|------|------|------|
| 验证 dartRef 是否存在 | `codegraph query "符号名"` | 比 rg 精确，直接返回符号类型和位置 |
| 查看组件被谁使用 | `codegraph callers "组件名"` | 知道改组件会影响哪些页面 |
| 评估重构影响范围 | `codegraph impact "符号名"` | 知道改这个符号会波及哪些代码 |
| 理解模块依赖关系 | `codegraph callees "入口方法"` | 知道一个方法内部调用了什么 |
| 改代码后找要跑的测试 | `codegraph affected 改动的文件` | 自动找出关联的测试文件 |
| 查看模块文件结构 | `codegraph files --filter 目录` | 比 ls 更智能，带符号统计 |

### fallback 策略

```bash
codegraph query "AppColors" 2>/dev/null || rg "AppColors" lib/
```

### 索引维护

- 索引目录：`.codegraph/`（已在 .gitignore 中）
- 代码改动后运行 `codegraph sync` 增量更新
- 索引损坏时运行 `codegraph index --force` 全量重建

### MCP 模式

CodeGraph 也可以作为 MCP server 运行：
```bash
codegraph serve --mcp
```

---

## rg（文本搜索）

**优先级**：代码智能 fallback，文本搜索首选。

### 常用命令

```bash
# 搜索文本
rg "pattern" lib/
rg "pattern" docs/ --type md

# 只看文件名
rg -l "AppColors.accent" lib/

# 搜索 YAML/Markdown 中的引用
rg "dartRef" docs/_shared/design-tokens.yaml
rg "colorForTheme" docs/modules/

# 限制搜索深度
rg "pattern" lib/ --max-depth 3
```

### fallback 策略

```bash
rg "pattern" docs/ 2>/dev/null || grep -r "pattern" docs/
```

---

## 其他工具优先级

| 工具类型 | 优先 | fallback |
|---------|------|----------|
| 代码智能 | `codegraph` | `rg`（精度有限） |
| 文本搜索 | `rg` | `grep -r` |
| 文件查找 | `fd` | `find` |
| JSON 处理 | `jq` | `python -m json.tool` |

---

## 工具降级时的行为

- CodeGraph 不可用时，用 `rg` 搜索符号引用，但精度有限（可能误判），需告知用户
- rg 不可用时自动 fallback 到 grep，无需告知
