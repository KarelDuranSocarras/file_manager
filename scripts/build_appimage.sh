#!/usr/bin/env bash
# Construye la AppImage de Respaldo Drive para Linux x86_64.
# Requisitos: libnotify-dev (paquete del sistema), appimagetool (se
# descarga automáticamente si falta).

set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="${1:-x64}"
APPDIR="build/appimage/RespaldoDrive.AppDir"
BUNDLE="build/linux/$ARCH/release/bundle"
DIST="dist"

echo "== flutter build linux --release =="
flutter build linux --release

echo "== preparando AppDir =="
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps" \
  "$APPDIR/usr/share/applications"

cp -r "$BUNDLE/." "$APPDIR/usr/bin/"
cp assets/app_icon.png "$APPDIR/usr/share/icons/hicolor/256x256/apps/respaldo_drive.png"
cp assets/app_icon.png "$APPDIR/respaldo_drive.png"

cat > "$APPDIR/respaldo-drive.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Respaldo Drive
Comment=Respalda tu carpeta en Google Drive
Exec=file_manager
Icon=respaldo_drive
Categories=Utility;
EOF
cp "$APPDIR/respaldo-drive.desktop" "$APPDIR/usr/share/applications/"

echo "== appimagetool =="
mkdir -p tools
if [ ! -x tools/appimagetool ]; then
  curl -L --fail -o tools/appimagetool \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x tools/appimagetool
fi

RUNTIME="tools/runtime-x86_64"
if [ ! -f "$RUNTIME" ]; then
  curl -L --fail -o "$RUNTIME" \
    "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64"
fi

mkdir -p "$DIST"
tools/appimagetool --appimage-extract-and-run \
  --runtime-file "$RUNTIME" \
  "$APPDIR" "$DIST/RespaldoDrive-x86_64.AppImage"

echo "== listo: $DIST/RespaldoDrive-x86_64.AppImage =="
