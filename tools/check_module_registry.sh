#!/usr/bin/env bash
# Fail if docs/modules/<id> exists but id not listed in docs/modules/README.md.
# Usage: bash tools/check_module_registry.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
README="$ROOT/docs/modules/README.md"
MOD_DIR="$ROOT/docs/modules"

if [[ ! -f "$README" ]]; then
  echo "ERROR: missing $README"
  exit 1
fi

# Extract ids from rows: | `chat` | ...
TABLE_IDS=$(grep -E '^\| `' "$README" | sed -E 's/^\| `([^`]+)`.*/\1/' | grep -v '^id$' || true)

ORPHANS=""
for d in "$MOD_DIR"/*/; do
  [[ -d "$d" ]] || continue
  base="$(basename "$d")"
  if ! echo "$TABLE_IDS" | grep -qx "$base"; then
    ORPHANS="${ORPHANS}${base}"$'\n'
  fi
done

if [[ -n "${ORPHANS// }" ]]; then
  echo "ERROR: docs/modules/ has directories NOT in registry (docs/modules/README.md):"
  echo "$ORPHANS" | sed '/^$/d' | sed 's/^/  - /'
  echo "Fix: add row to registry OR remove/rename orphan. Silent mkdir is not allowed."
  exit 1
fi

COUNT=$(echo "$TABLE_IDS" | sed '/^$/d' | wc -l | tr -d ' ')
echo "OK: module dirs ⊆ registry table ($COUNT ids in table)."
