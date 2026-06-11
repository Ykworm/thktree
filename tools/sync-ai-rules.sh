#!/bin/bash
# sync-ai-rules.sh
# 将 .ai/ 下的 master rule 文件同步到各 AI agent 配置目录
# 用法：bash tools/sync-ai-rules.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER_DIR="$REPO_ROOT/.ai"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

synced=0

# 分类：哪些文件只需要 Skill（手动触发，不应 always_on），哪些只需要 Rule
# 不在任何列表中的文件 → 同时同步 Skill + Rule（默认行为）
SKILL_ONLY=("context-sync")   # 手动触发，不常驻上下文
RULE_ONLY=("tool-priority")   # 全局规则，每轮都加载

for master in "$MASTER_DIR"/*.md; do
  [ -f "$master" ] || continue
  name=$(basename "$master" .md)

  is_skill_only=false
  is_rule_only=false
  for s in "${SKILL_ONLY[@]}"; do [ "$s" = "$name" ] && is_skill_only=true; done
  for r in "${RULE_ONLY[@]}"; do [ "$r" = "$name" ] && is_rule_only=true; done

  # ── Qoder Skill ──
  if [ "$is_rule_only" = false ] && [ -d "$REPO_ROOT/.qoder/skills" ]; then
    target_dir="$REPO_ROOT/.qoder/skills/$name"
    mkdir -p "$target_dir"
    cp "$master" "$target_dir/SKILL.md"
    echo -e "${GREEN}✅ Qoder Skill${NC}: $name"
    synced=$((synced + 1))
  fi

  # ── Qoder Rule (always_on) ──
  if [ "$is_skill_only" = false ] && [ -d "$REPO_ROOT/.qoder/rules" ]; then
    {
      echo '---'
      echo 'trigger: always_on'
      echo 'alwaysApply: true'
      echo '---'
      echo ''
      cat "$master"
    } > "$REPO_ROOT/.qoder/rules/$name.md"
    echo -e "${GREEN}✅ Qoder Rule${NC}: $name"
    synced=$((synced + 1))
  fi

  # ── Claude Code ──
  claude_dir="$REPO_ROOT/.claude/commands"
  mkdir -p "$claude_dir"
  cp "$master" "$claude_dir/$name.md"
  echo -e "${GREEN}✅ Claude Code${NC}: $name"
  synced=$((synced + 1))

  # ── Trae ──
  trae_dir="$REPO_ROOT/.trae/rules"
  mkdir -p "$trae_dir"
  cp "$master" "$trae_dir/$name.md"
  echo -e "${GREEN}✅ Trae${NC}: $name"
  synced=$((synced + 1))
done

# ── Codex (AGENTS.md) ──
agents_file="$REPO_ROOT/AGENTS.md"
> "$agents_file"
for master in "$MASTER_DIR"/*.md; do
  [ -f "$master" ] || continue
  name=$(basename "$master" .md)
  {
    echo "## $name"
    echo ""
    tail -n +3 "$master"
    echo ""
  } >> "$agents_file"
  echo -e "${GREEN}✅ Codex${NC}: $name → AGENTS.md"
  synced=$((synced + 1))
done

echo ""
echo -e "${GREEN}✅ 同步完成${NC}：共 $synced 项"
