# 工具优先级规则

完整命令参考、使用场景、fallback 策略：
> 读取 `docs/_shared/tool-reference.md`

核心规则：
- 代码智能优先 `codegraph`，fallback `rg`
- 文本搜索优先 `rg`，fallback `grep`
- 文件查找优先 `fd`，fallback `find`
- 工具不可用时必须告知用户（CodeGraph）或静默 fallback（rg → grep）
- ⚠️ rg 必须优先于 grep，任何场景不得跳过
