#!/usr/bin/env bash
#
# build-dmg.sh — Compila la app en Release (firma ad-hoc) y genera un .dmg
# para repartir en pruebas (alpha). No notariza: el receptor debe quitar la
# cuarentena (ver README / instrucciones).
#
# Uso:  ./build-dmg.sh
#
set -euo pipefail

# --- Configuración ---
PROJECT="GestionTutorial.xcodeproj"
SCHEME="GestionTutorial"
APP_NAME="TutorHub"                 # nombre del .app que produce Xcode (PRODUCT_NAME)
VOL_NAME="TutorHub"                 # nombre visible del volumen/instalador
DERIVED="build_release"
STAGE="dmg_stage"
DMG="${VOL_NAME}.dmg"

cd "$(dirname "$0")"

echo "▸ Limpiando artefactos anteriores…"
rm -rf "$DERIVED" "$STAGE" "$DMG"

echo "▸ Compilando en Release (firma ad-hoc)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES \
  clean build >/dev/null

APP_PATH="$DERIVED/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "✗ No se encontró $APP_PATH" >&2
  exit 1
fi

echo "▸ Firmando ad-hoc en profundidad…"
codesign --force --deep --sign - "$APP_PATH"

echo "▸ Preparando contenido del .dmg…"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "▸ Creando ${DMG}…"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

rm -rf "$STAGE"

echo "✓ Listo: $DMG"
echo "  El receptor, al abrirlo por primera vez, debe quitar la cuarentena:"
echo "  xattr -dr com.apple.quarantine \"/Applications/${APP_NAME}.app\""
