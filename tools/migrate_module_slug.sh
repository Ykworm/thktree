#!/usr/bin/env bash
# Migrate a duplicate module slug to the registered one.
# Used when two parallel sessions created the same module under different names:
# the slug merged into dev first wins; the later one is migrated by this script.
# Usage: bash tools/migrate_module_slug.sh <old_slug> <new_slug>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
README="$ROOT/docs/modules/README.md"
MOD_DIR="$ROOT/docs/modules"

usage() {
  echo "Usage: bash tools/migrate_module_slug.sh <old_slug> <new_slug>"
  echo "  old_slug: 后到的、要迁走的 slug（docs/modules/<old_slug> 应存在）"
  echo "  new_slug: 已登记保留的 slug（必须在 docs/modules/README.md 登记表中）"
  exit 1
}

[[ $# -eq 2 ]] || usage
OLD="$1"
NEW="$2"

[[ "$OLD" != "$NEW" ]] || { echo "ERROR: old_slug 与 new_slug 相同（${OLD}）"; exit 1; }

# 1. new_slug must be registered in docs/modules/README.md
if ! grep -qE "^\| \`${NEW}\`" "$README"; then
  echo "ERROR: '$NEW' 不在登记表 $README 中。"
  echo "先登记 new_slug（FEATURES 加行 + 登记表加行），再跑本脚本。"
  exit 1
fi

# 2. old docs dir must exist; new docs dir must NOT exist
if [[ ! -d "$MOD_DIR/$OLD" ]]; then
  echo "ERROR: $MOD_DIR/$OLD 不存在，无可迁移内容。"
  exit 1
fi
if [[ -d "$MOD_DIR/$NEW" ]]; then
  echo "ERROR: $MOD_DIR/$NEW 已存在。请先人工合并两个目录的内容，再跑本脚本。"
  exit 1
fi

# 3. git mv docs dir（先 add 兼容未跟踪文件；git mv 只认已跟踪）
git -C "$ROOT" add -A "docs/modules/$OLD"
git -C "$ROOT" mv "docs/modules/$OLD" "docs/modules/$NEW"
echo "OK: git mv docs/modules/$OLD -> docs/modules/$NEW"

# 4. Replace textual references under docs/ (slug appears as `old` or modules/old or features/old)
HITS=$(grep -rlE "(\`${OLD}\`|modules/${OLD}\b|features/${OLD}\b)" "$ROOT/docs" || true)
if [[ -n "$HITS" ]]; then
  COUNT=0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    sed -i '' -E "s/\`${OLD}\`/\`${NEW}\`/g; s|modules/${OLD}[[:>:]]|modules/${NEW}|g; s|features/${OLD}[[:>:]]|features/${NEW}|g" "$f"
    COUNT=$((COUNT + 1))
    echo "  - ${f#"$ROOT"/}"
  done <<< "$HITS"
  echo "OK: 已替换 $COUNT 个 docs 文件中的引用（见上）。"
else
  echo "OK: docs/ 下无 '$OLD' 文本引用。"
fi

# 5. Warn about code dir — script does not touch code
if [[ -d "$ROOT/lib/ui/features/$OLD" ]]; then
  echo "WARN: lib/ui/features/$OLD/ 仍存在。代码目录迁移涉及 import 改动，请人工确认后处理："
  echo "  git mv lib/ui/features/$OLD lib/ui/features/$NEW"
  echo "  并全仓替换 import 路径。"
fi

echo "NEXT: 检查并更新 docs/modules/README.md 与 docs/FEATURES.md 中 '$OLD' 的行，然后 bash tools/check_module_registry.sh 复核。"
