---
trigger: always_on
alwaysApply: true
---

# 工具优先级规则

## 文本搜索工具

**优先使用 `rg`（ripgrep），不可用则 fallback 到 `grep`**。

### 原因
- `rg` 默认递归、自动忽略 `.gitignore`、速度更快
- `rg` 的正则表达式语法更现代（`|` 无需转义）
- 项目已统一文档中的示例命令为 `rg`

### fallback 策略

```bash
# 优先尝试 rg
rg "pattern" docs/ 2>/dev/null || grep -r "pattern" docs/
```

或在脚本中：

```bash
if command -v rg &> /dev/null; then
    SEARCH_CMD="rg"
else
    SEARCH_CMD="grep -r"
fi
```

## 其他工具优先级

| 工具类型 | 优先 | fallback |
|---------|------|----------|
| 文本搜索 | `rg` | `grep -r` |
| 文件查找 | `fd` | `find` |
| JSON 处理 | `jq` | `python -m json.tool` |
