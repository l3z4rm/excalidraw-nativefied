#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Excalidraw"
WEBSITE="https://excalidraw.com"

BUILD_DIR="$HOME/.local/share/nativefier-build/excalidraw"
INSTALL_DIR="/usr/lib/excalidraw"
WRAPPER="/usr/bin/excalidraw"

ICON_URL="https://cdn.simpleicons.org/excalidraw"
ICON_PATH="/usr/share/icons/hicolor/scalable/apps/excalidraw.svg"

DESKTOP_PATH="/usr/share/applications/excalidraw.desktop"

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

log "Checking tools..."
command -v npx >/dev/null 2>&1 || die "npx not found. Install Node.js first."
command -v curl >/dev/null 2>&1 || die "curl not found."
command -v sudo >/dev/null 2>&1 || die "sudo not found."

log "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

log "Nativefying website..."
npx nativefier \
    --name "$APP_NAME" \
    --disable-dev-tools \
    --single-instance \
    --tray \
    --internal-urls ".*" \
    --out "$BUILD_DIR" \
    "$WEBSITE"

APP_SRC="$(find "$BUILD_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
[ -n "$APP_SRC" ] || die "Nativefier output not found."

log "Installing app to $INSTALL_DIR..."
sudo rm -rf "$INSTALL_DIR"
sudo mkdir -p /usr/lib
sudo cp -r "$APP_SRC" "$INSTALL_DIR"

log "Creating wrapper script..."
sudo tee "$WRAPPER" >/dev/null <<'EOF'
#!/bin/sh
cd /usr/lib/excalidraw || exit 1

APP_BIN="$(find . -maxdepth 1 -type f -perm -111 ! -name 'chrome-sandbox' | head -n 1)"
[ -n "$APP_BIN" ] || exit 1

exec "$APP_BIN" --no-sandbox "$@"
EOF
sudo chmod 755 "$WRAPPER"

log "Downloading icon..."
sudo mkdir -p "$(dirname "$ICON_PATH")"
curl -fsSL "$ICON_URL" | sudo tee "$ICON_PATH" >/dev/null
sudo chmod 644 "$ICON_PATH"

log "Creating desktop file..."
sudo tee "$DESKTOP_PATH" >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=Virtual Whiteboard
Exec=$WRAPPER %U
TryExec=$WRAPPER
Icon=excalidraw
Terminal=false
Categories=Graphics;Utility;
StartupWMClass=Excalidraw
EOF
sudo chmod 644 "$DESKTOP_PATH"

log "Updating desktop database..."
if command -v update-desktop-database >/dev/null 2>&1; then
    sudo update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi

log "Updating icon cache..."
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    sudo gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

log "Done."
