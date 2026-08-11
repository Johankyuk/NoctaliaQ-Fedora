#!/usr/bin/env bash
# Recolor universal: folders de Thunar/Papirus + color solido del teclado.
# El cursor (Bibata-Modern-Classic) no es dinamico -- ver install-cursor.sh,
# se instala una sola vez y queda fuera de esto (decision ya tomada).
#
# Uso manual (fallback si por lo que sea el watcher no esta corriendo):
#   ./recolor-all.sh
# El uso normal es automatico via noctaliaq-recolor-watch.sh, que llama a
# este mismo script cuando detecta un cambio de paleta.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$DIR/papirus-recolor.sh"

"$DIR/noctaliaq-keyboard.sh" accent || echo "aviso: no pude recolorear el teclado (¿--diag para ver por que?)"

echo "recolor completo (folders + teclado)"
