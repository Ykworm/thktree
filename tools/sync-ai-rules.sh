#!/bin/bash
# sync-ai-rules.sh
# 将 .ai/ 下的 master rule 文件同步到各 AI agent 配置目录
# 用法：bash tools/sync-ai-rules.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER_DIR="$REPO_ROOT/.ai"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

synced=0

# ── Qoder Skills ──
if [ -d "$REPO_ROOT/.qoder/skills" ]; then
  for master in "$MASTER_DIR"/*.md; do
    [ -f "$master" ] || continue
    name=$(basename "$master" .md)
    target_dir="$REPO_ROOT/.qoder/skills/$name"
    mkdir -p "$target_dir"
    cp "$master" "$target_dir/SKILL.md"
    echo -e "${GREEN}✅ Qoder Skill${NC}: $name → .qoder/skills/$name/SKILL.md"
    synced=$((synced + 1))
  done
else
  echo -e "${YELLOW}⏭️  Qoder${NC}: .qoder/skills/ 不存在，跳过"
fi

# ── Qoder Rules (always_on，加 frontmatter) ──
if [ -d "$REPO_ROOT/.qoder/rules" ]; then
  for master in "$MASTER_DIR"/*.md; do
    [ -f "$master" ] || continue
    name=$(basename "$master" .md)
    {
      echo '---'
      echo 'trigger: always_on'
      echo 'alwaysApply: true'
      echo '---'
      echo ''
      cat "$master"
    } > "$REPO_ROOT/.qoder/rules/$name.md"
    echo -e "${GREEN}✅ Qoder Rule${NC}: $name → .qoder/rules/$name.md"
    synced=$((synced + 1))
  done
else
  echo -e "${YELLOW}⏭️  Qoder${NC}: .qoder/rules/ 不存在，跳过"
fi

# ── Claude Code ──
claude_dir="$REPO_ROOT/.claude/commands"
mkdir -p "$claude_dir"
for master in "$MASTER_DIR"/*.md; do
  [ -f "$master" ] || continue
  name=$(basename "$master" .md)
  cp "$master" "$claude_dir/$name.md"
  echo -e "${GREEN}✅ Claude Code${NC}: $name → .claude/commands/$name.md"
  synced=$((synced + 1))
done

# ── Trae ──
trae_dir="$REPO_ROOT/.trae/rules"
mkdir -p "$trae_dir"
for master in "$MASTER_DIR"/*.md; do
  [ -f "$master" ] || continue
  name=$(basename "$master" .md)
  cp "$master" "$trae_dir/$name.md"
  echo -e "${GREEN}✅ Trae${NC}: $name → .trae/rules/$name.md"
  synced=$((synced + 1))
done

# ── Codex (AGENTS.md) ──
# 多副本策略：AGENTS.md 包含完整内容，不是引用段落
agents_file="$REPO_ROOT/AGENTS.md"
> "$agents_file"
for master in "$MASTER_DIR"/*.md; do
  [ -f "$master" ] || continue
  name=$(basename "$master" .md)
  {
    echo "## $name"
    echo ""
    # 去掉 master 文件的一级标题（AGENTS.md 用 ## 作为标题）
    tail -n +3 "$master"
    echo ""
  } >> "$agents_file"
  echo -e "${GREEN}✅ Codex${NC}: $name → AGENTS.md（完整副本）"
  synced=$((synced + 1))
done

# 追加 tool-priority 到 AGENTS.md
{
  echo "## tool-priority"
  echo ""
  echo "- **查符号、调用关系、影响分析** → \`codegraph\`（详见 \`.ai/tool-priority.md\`）"
  echo "  - \`codegraph query \"符号名\"\` — 搜索符号"
  echo "  - \`codegraph callers \"符号名\"\` — 谁调用了它"
  echo "  - \`codegraph impact \"符号名\"\` — 改它会影响什么"
  echo "  - \`codegraph sync\` — 代码改动后增量更新索引"
  echo "- **文本搜索** → \`rg\`（ripgrep），不可用则 fallback \`grep -r\`"
  echo "- **文件查找** → \`fd\`，不可用则 fallback \`find\`"
} >> "$agents_file"

echo ""
echo -e "${GREEN}✅ 同步完成${NC}：共 $synced 项"
