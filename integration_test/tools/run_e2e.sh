#!/usr/bin/env bash
#
# ThkTree E2E runner
# 跑指定 case 的指定平台，覆盖写回 results/<CASE-ID>/<platform>.md
# LLM 强制真实（禁止 mock）。
#
# 用法（在 app worktree 根目录）：
#   bash integration_test/tools/run_e2e.sh <CASE-ID> <platform: ios|android|macos>
#
set -uo pipefail

CASE_ID="${1:-}"
PLATFORM="${2:-}"

if [[ -z "$CASE_ID" || -z "$PLATFORM" ]]; then
  echo "用法: run_e2e.sh <CASE-ID> <platform: ios|android|macos>" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRATION_TEST_DIR="$(dirname "$SCRIPT_DIR")"   # .../integration_test
APP_ROOT="$(dirname "$INTEGRATION_TEST_DIR")"      # app worktree 根
CATALOG="$INTEGRATION_TEST_DIR/docs/test-cases-catalog.md"

case "$PLATFORM" in
  ios|android|macos) ;;
  *) echo "platform 必须是 ios/android/macos，收到: $PLATFORM" >&2; exit 2 ;;
esac

if [[ ! -f "$CATALOG" ]]; then
  echo "找不到 catalog: $CATALOG" >&2
  exit 3
fi

# ---- 从 catalog 解析 Related script + --plain-name ----
SECTION="$(awk "/^### $CASE_ID /{f=1} f&&/^### /&&!/^### $CASE_ID /{exit} f" "$CATALOG")"
if [[ -z "$SECTION" ]]; then
  echo "catalog 中找不到 case: $CASE_ID" >&2
  exit 4
fi
RELATED="$(echo "$SECTION" | grep -m1 "Related script" | grep -oE '`[^`]+`' | head -1 | tr -d '`')"
PLAIN="$(echo "$SECTION" | grep -m1 -- "--plain-name" | grep -oE '"[^"]+"' | head -1 | tr -d '"')"

if [[ -z "$RELATED" ]]; then
  echo "catalog 中找不到 $CASE_ID 的 Related script" >&2
  exit 4
fi
if [[ -z "$PLAIN" ]]; then
  echo "catalog 中找不到 $CASE_ID 的 --plain-name（多脚本 case 需手动指定）" >&2
  exit 4
fi

FULL_TEST_PATH="$INTEGRATION_TEST_DIR/$RELATED"   # RELATED 形如 common/branch_creation_test.dart
if [[ ! -f "$FULL_TEST_PATH" ]]; then
  echo "测试脚本不存在: $FULL_TEST_PATH" >&2
  exit 4
fi

# ---- LLM 强制真实（禁止 mock）----
DART_DEFINE="build/dart_define.json"
if [[ ! -f "$APP_ROOT/$DART_DEFINE" ]]; then
  echo "❌ LLM 禁止 mock：缺少真实 key 文件 $DART_DEFINE" >&2
  echo "   请在该 app worktree 根创建 $DART_DEFINE（含真实 LLM key）后再跑。" >&2
  exit 5
fi

# ---- 设备 ----
case "$PLATFORM" in
  ios)     DEVICE="${IOS_DEVICE:-<ios>}";;
  android) DEVICE="${ANDROID_DEVICE:-emulator-5554}";;
  macos)   DEVICE="${MACOS_DEVICE:-macos}";;
esac

FLUTTER_VER="$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')"
APP_BUILD="${APP_BUILD:-dev}"

OUT_DIR="$INTEGRATION_TEST_DIR/results/$CASE_ID"
mkdir -p "$OUT_DIR" "$INTEGRATION_TEST_DIR/results/artifacts"
RESULT_FILE="$OUT_DIR/$PLATFORM.md"

TITLE="$(echo "$SECTION" | grep -m1 '^### ' | sed "s/^### $CASE_ID · //")"

echo "==> 跑 $CASE_ID / $PLATFORM"
echo "    脚本: $FULL_TEST_PATH"
echo "    匹配: --plain-name \"$PLAIN\""
echo "    设备: $DEVICE"
echo "    LLM: real（强制，已注入 key，禁止 mock）"

START="$(date +%s)"
set +e
LOG_FILE="$(mktemp)"
( cd "$APP_ROOT" && flutter test "$FULL_TEST_PATH" --plain-name "$PLAIN" -d "$DEVICE" --dart-define-from-file="$DART_DEFINE" ) >"$LOG_FILE" 2>&1
RC=$?
set -e
END="$(date +%s)"
DURATION=$((END - START))

if [[ $RC -eq 0 ]]; then
  STATUS="✅ PASS"
  FAIL_BLOCK=""
else
  STATUS="❌ FAIL"
  LOG_TAIL="$(tail -n 20 "$LOG_FILE")"
  FAIL_BLOCK="
失败详情:
  - 报错: (见日志 tail)
  - 日志:
$(echo "$LOG_TAIL" | sed 's/^/      /')
  - 截图: ../artifacts/$CASE_ID-$PLATFORM.png
  ![失败截图](../artifacts/$CASE_ID-$PLATFORM.png)
  - 注: 真截图需 flutter_driver 截图能力，当前 runner 未接；CI/手动补（补后随结果提交进仓库）。"
fi

UPDATED="$(date +%Y-%m-%dT%H:%M%z)"
cat > "$RESULT_FILE" <<EOF
case:     $CASE_ID
title:    $TITLE
platform: $PLATFORM
updated:  $UPDATED

状态: $STATUS

运行方式:
  flutter test $FULL_TEST_PATH \\
    --plain-name "$PLAIN" -d $DEVICE
  LLM: real（强制，已注入 key，禁止 mock）

环境:
  device:    $DEVICE
  flutter:   $FLUTTER_VER
  app-build: $APP_BUILD

时长: ${DURATION}s
$FAIL_BLOCK
EOF

echo "==> 结果已写: $RESULT_FILE (状态: $STATUS)"
rm -f "$LOG_FILE"
exit $RC
