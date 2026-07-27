#!/usr/bin/env bash
# Build a versioned Android APK for GitHub Releases (not Google Play).
#
# Prerequisites:
#   - flutter, gh (GitHub CLI)
#   - android/key.properties (copy from key.properties.example)
#   - git tag already pushed, or pass TAG explicitly
#
# Usage:
#   ./scripts/release-android-github.sh              # tag from pubspec 0.9.0+1 → v0.9.0-beta.1
#   ./scripts/release-android-github.sh v0.9.0-beta.2
#   ./scripts/release-android-github.sh --build-only  # skip gh release create

set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_ONLY=false
TAG=""
for arg in "$@"; do
  case "$arg" in
    --build-only) BUILD_ONLY=true ;;
    v*) TAG="$arg" ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

VERSION_LINE="$(grep '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
VERSION_NAME="${VERSION_LINE%%+*}"
BUILD_NUMBER="${VERSION_LINE#*+}"
if [[ "$BUILD_NUMBER" == "$VERSION_LINE" ]]; then
  BUILD_NUMBER="1"
fi

if [[ -z "$TAG" ]]; then
  TAG="v${VERSION_NAME}-beta.${BUILD_NUMBER}"
fi

APK_NAME="ThkTree-${VERSION_NAME}-build${BUILD_NUMBER}-android.apk"
DIST_DIR="dist"
mkdir -p "$DIST_DIR"

echo "==> Version: ${VERSION_NAME} (${BUILD_NUMBER})"
echo "==> Tag: ${TAG}"
echo "==> Output: ${DIST_DIR}/${APK_NAME}"

flutter pub get
flutter build apk --release

cp build/app/outputs/flutter-apk/app-release.apk "${DIST_DIR}/${APK_NAME}"
echo "==> Built ${DIST_DIR}/${APK_NAME}"

if [[ "$BUILD_ONLY" == true ]]; then
  echo "==> --build-only: skipping GitHub Release"
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Install gh CLI, then:" >&2
  echo "  gh release create ${TAG} ${DIST_DIR}/${APK_NAME} --title \"ThkTree ${VERSION_NAME} Beta ${BUILD_NUMBER}\"" >&2
  exit 0
fi

NOTES_FILE="$(mktemp)"
cat >"$NOTES_FILE" <<EOF
## ThkTree ${VERSION_NAME} (Android 公测 build ${BUILD_NUMBER})

- 下载 \`${APK_NAME}\` 安装
- 版本号：${VERSION_NAME} (build ${BUILD_NUMBER})
- 反馈：[GitHub Issues](https://github.com/Ykworm/thktree/issues)
EOF

gh release create "$TAG" "${DIST_DIR}/${APK_NAME}" \
  --repo Ykworm/thktree \
  --title "ThkTree ${VERSION_NAME} Beta ${BUILD_NUMBER}" \
  --notes-file "$NOTES_FILE"

rm -f "$NOTES_FILE"
echo "==> Release published: https://github.com/Ykworm/thktree/releases/tag/${TAG}"
