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

# ── Qoder ──
if [ -d "$REPO_ROOT/.qoder/skills" ]; then
  for master in "$MASTER_DIR"/*.md; do
    [ -f "$master" ] || continue
    name=$(basename "$master" .md)
    target_dir="$REPO_ROOT/.qoder/skills/$name"
    mkdir -p "$target_dir"
    cp "$master" "$target_dir/SKILL.md"
    echo -e "${GREEN}✅ Qoder${NC}: $name → .qoder/skills/$name/SKILL.md"
    synced=$((synced + 1))
  done
else
  echo -e "${YELLOW}⏭️  Qoder${NC}: .qoder/skills/ 不存在，跳过"
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
agents_file="$REPO_ROOT/AGENTS.md"
for master in "$MASTER_DIR"/*.md; do
  [ -f "$master" ] || continue
  name=$(basename "$master" .md)
  # 检查 AGENTS.md 里是否已有该 rule 的引用
  if [ -f "$agents_file" ] && rg -q "$name" "$agents_file"; then
    echo -e "${YELLOW}⏭️  Codex${NC}: AGENTS.md 已包含 $name 引用，跳过"
  else
    {
      echo ""
      echo "## $name"
      echo ""
      echo "详见 \`.ai/$name.md\`。"
    } >> "$agents_file"
    echo -e "${GREEN}✅ Codex${NC}: $name → AGENTS.md（追加引用段落）"
    synced=$((synced + 1))
  fi
done

echo ""
echo -e "${GREEN}✅ 同步完成${NC}：共 $synced 项"
