#!/usr/bin/env bash
# Corre recolor-all.sh al arrancar, y de nuevo cada vez que Noctalia
# regenera la paleta activa (~/.config/gtk-4.0/noctalia.css). Pensado para
# quedar corriendo en segundo plano via systemd --user
# (noctaliaq-recolor-watch.service, ver install.sh) — sin terminal visible,
# a diferencia del launcher manual anterior (que abria kitty --hold para
# correr papirus-recolor.sh a mano y se veia raro).
#
# Se vigila el DIRECTORIO, no el archivo directo: si Noctalia regenera
# noctalia.css via escritura-a-temporal + rename (comun para evitar leer un
# archivo a medio escribir), un watch sobre el archivo original perderia el
# evento porque el inode cambia. Vigilando el directorio con
# create/moved_to/close_write se cubre cualquiera de los dos patrones.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSS_DIR="$HOME/.config/gtk-4.0"
CSS_FILE="noctalia.css"

command -v inotifywait >/dev/null 2>&1 || { echo "no encontre 'inotifywait' (paquete inotify-tools) en PATH" >&2; exit 1; }
[ -d "$CSS_DIR" ] || { echo "no encontre $CSS_DIR" >&2; exit 1; }

# Chequeo inicial (por si el teclado/folders quedaron desincronizados de la
# paleta actual, p.ej. tras reinstalar este script).
"$DIR/recolor-all.sh"

LAST_RUN=0
MIN_INTERVAL=2  # segundos; evita recolorear dos veces si el editor de Noctalia dispara varios eventos seguidos

while true; do
    evento=$(inotifywait -q -e create,moved_to,close_write --format '%f' "$CSS_DIR" 2>/dev/null) || break
    [ "$evento" = "$CSS_FILE" ] || continue
    now=$(date +%s)
    [ $((now - LAST_RUN)) -ge "$MIN_INTERVAL" ] || continue
    sleep 1  # dar tiempo a que Noctalia termine de escribir todo el archivo
    "$DIR/recolor-all.sh"
    LAST_RUN=$(date +%s)
done
