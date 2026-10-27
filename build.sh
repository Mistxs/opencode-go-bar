#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="OpenCode Go Bar"
APP="build/$APP_NAME.app"
MIN_MACOS="13.0"

if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(-arch arm64 -arch x86_64)
  ARCH_LABEL="universal"
else
  ARCH_FLAGS=(-arch "$(uname -m)")
  ARCH_LABEL="$(uname -m)"
fi

echo "==> Сборка $APP_NAME ($ARCH_LABEL, macOS $MIN_MACOS+)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

clang \
  -fobjc-arc \
  -O2 \
  "${ARCH_FLAGS[@]}" \
  -mmacosx-version-min="${MIN_MACOS}" \
  -framework Cocoa \
  -framework ServiceManagement \
  -lsqlite3 \
  Sources/*.m \
  -o "$APP/Contents/MacOS/OpenCodeGoBar"

cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [[ -n "${APP_VERSION:-}" ]]; then
  VERSION="${APP_VERSION#v}"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$APP/Contents/Info.plist"
  echo "==> Версия $VERSION"
fi

# Ad-hoc подпись: нужна для запуска и для регистрации в автозапуске.
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || true

echo "==> Готово: $APP"

case "${1:-}" in
  --run)
    open "$APP"
    ;;
  --install)
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/$APP_NAME.app"
    cp -R "$APP" "$HOME/Applications/$APP_NAME.app"
    echo "==> Установлено: $HOME/Applications/$APP_NAME.app"
    open "$HOME/Applications/$APP_NAME.app"
    ;;
  --probe)
    "$APP/Contents/MacOS/OpenCodeGoBar" --probe
    ;;
esac
