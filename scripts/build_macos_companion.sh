#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
DAEMON_DIR="$ROOT_DIR/daemon"
BUILT_OUTPUT_APP="$APP_DIR/build/macos/Build/Products/Release/agent_workbench.app"
OUTPUT_APP="$APP_DIR/build/macos/Build/Products/Release/极 coding.app"
BUNDLED_DAEMON_DIR="$BUILT_OUTPUT_APP/Contents/Resources/daemon"
BUNDLED_NODE_DIR="$BUILT_OUTPUT_APP/Contents/Resources/bin"
BUNDLED_CODEX_DIR="$BUILT_OUTPUT_APP/Contents/Resources/codex"
BREW_OPENSSL_CERT_FILE="/opt/homebrew/etc/openssl@3/cert.pem"
BREW_OPENSSL_CERT_DIR="/opt/homebrew/etc/openssl@3/certs"
SIGNING_ENTITLEMENTS_FILE=""

trap 'status=$?; if [[ -n "${SIGNING_ENTITLEMENTS_FILE:-}" && -f "$SIGNING_ENTITLEMENTS_FILE" ]]; then rm -f "$SIGNING_ENTITLEMENTS_FILE"; fi; if [[ $status -ne 0 ]]; then
  cat >&2 <<EOF
macOS build failed.

If the failure happened during CocoaPods resolution with "certificate verify failed",
check the trust chain used by Ruby/CocoaPods or retry without the current proxy for
cdn.cocoapods.org.
EOF
fi' EXIT

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is required to build the macOS app." >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required to install daemon dependencies." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node is required to bundle the macOS app runtime." >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex is required to bundle the macOS app runtime." >&2
  exit 1
fi

if [[ -f "$BREW_OPENSSL_CERT_FILE" ]]; then
  export SSL_CERT_FILE="$BREW_OPENSSL_CERT_FILE"
fi

if [[ -d "$BREW_OPENSSL_CERT_DIR" ]]; then
  export SSL_CERT_DIR="$BREW_OPENSSL_CERT_DIR"
fi

echo "Installing daemon runtime dependencies..."
if [[ -f "$DAEMON_DIR/package-lock.json" ]]; then
  npm --prefix "$DAEMON_DIR" ci --omit=dev
else
  npm --prefix "$DAEMON_DIR" install --omit=dev
fi

echo "Building Flutter macOS app..."
(
  cd "$APP_DIR"
  flutter pub get
  flutter build macos --release
)

echo "Bundling daemon into app resources..."
rm -rf "$BUNDLED_DAEMON_DIR"
mkdir -p "$BUNDLED_DAEMON_DIR"
rsync -a \
  --delete \
  --exclude '.env' \
  --exclude '.env.*' \
  --exclude 'tests' \
  --exclude '*.log' \
  "$DAEMON_DIR/" "$BUNDLED_DAEMON_DIR/"

echo "Bundling Node runtime into app resources..."
rm -rf "$BUNDLED_NODE_DIR"
mkdir -p "$BUNDLED_NODE_DIR"
cp "$(command -v node)" "$BUNDLED_NODE_DIR/node"
chmod +x "$BUNDLED_NODE_DIR/node"

HOST_CODEX_PACKAGE_DIR="$(
  node -e 'const fs = require("node:fs"); const path = require("node:path"); const bin = fs.realpathSync(process.argv[1]); console.log(path.resolve(path.dirname(bin), ".."));' \
    "$(command -v codex)"
)"

echo "Bundling Codex runtime into app resources..."
rm -rf "$BUNDLED_CODEX_DIR"
mkdir -p "$BUNDLED_CODEX_DIR"
rsync -a --delete "$HOST_CODEX_PACKAGE_DIR/" "$BUNDLED_CODEX_DIR/"

cat >"$BUNDLED_NODE_DIR/codex" <<'EOF'
#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
RESOURCES_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

exec "$SCRIPT_DIR/node" "$RESOURCES_DIR/codex/bin/codex.js" "$@"
EOF
chmod +x "$BUNDLED_NODE_DIR/codex"

echo "Re-signing bundled app..."
SIGNING_ENTITLEMENTS_FILE="$(mktemp)"
if /usr/bin/codesign -d --entitlements :- "$BUILT_OUTPUT_APP" >"$SIGNING_ENTITLEMENTS_FILE" 2>/dev/null; then
  /usr/bin/codesign --force --deep --sign - --entitlements "$SIGNING_ENTITLEMENTS_FILE" "$BUILT_OUTPUT_APP"
else
  /usr/bin/codesign --force --deep --sign - "$BUILT_OUTPUT_APP"
fi
/usr/bin/codesign --verify --deep --strict "$BUILT_OUTPUT_APP"

rm -rf "$OUTPUT_APP"
mv "$BUILT_OUTPUT_APP" "$OUTPUT_APP"
/usr/bin/codesign --verify --deep --strict "$OUTPUT_APP"

cat <<EOF
Built app:
  $OUTPUT_APP

Finder launch notes:
  - The app now bundles the daemon, Node runtime, and Codex runtime under
    Contents/Resources.
  - Runtime data should be stored under
    ~/Library/Application Support/agent_workbench/.
  - Runtime logs should be stored under
    ~/Library/Logs/agent_workbench/.
EOF
