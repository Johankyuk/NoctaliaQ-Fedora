#!/usr/bin/env bash
# Instala Bibata-Modern-Classic (negro, oficial de ful1e5/Bibata_Cursor) tal
# cual lo publica upstream. Reemplaza el recolor dinamico anterior
# (cursor-recolor.sh + clickgen + hash por paleta): el cursor deja de
# seguir el accent de Noctalia a proposito, asi no hay que regenerarlo en
# cada cambio de wallpaper. Los folders (Papirus, via papirus-recolor.sh)
# siguen siendo dinamicos como antes -- esto es solo para el cursor.
#
# Idempotente: se puede correr de nuevo para reinstalar/actualizar.

set -euo pipefail

NAME="Bibata-Modern-Classic"
URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/${NAME}.tar.xz"
DEST="$HOME/.local/share/icons"

command -v curl >/dev/null 2>&1 || { echo "falta curl"; exit 1; }

mkdir -p "$DEST"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "-> Descargando $NAME (release mas reciente de ful1e5/Bibata_Cursor)..."
curl -fsSL "$URL" -o "$TMP/bibata.tar.xz"

echo "-> Extrayendo..."
tar -xf "$TMP/bibata.tar.xz" -C "$TMP"
[ -d "$TMP/$NAME" ] || { echo "el tarball no trae la carpeta $NAME esperada"; exit 1; }

rm -rf "${DEST:?}/$NAME"
cp -r "$TMP/$NAME" "$DEST/$NAME"

gsettings set org.gnome.desktop.interface cursor-theme "$NAME" 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-size 30 2>/dev/null || true

echo "✓ $NAME instalado en $DEST/$NAME"
echo "  (misc.kdl y gtk-3.0/gtk-4.0 settings.ini ya apuntan a este nombre fijo -- no hace falta editarlos de nuevo)"
