#!/usr/bin/env bash
# Corre lock-panel-refresh.sh al arrancar niri, y de nuevo cada vez que
# niri reporta un cambio en los outputs (conexion/reconexion de pantallas
# -- incluye el reinit de amdgpu/nvidia que dispara un toggle de MUX
# Ultimate/Hibrido). Pensado para lanzarse una vez desde
# cfg/autostart.kdl y quedar corriendo en segundo plano.
#
# Nota sobre el filtro de eventos: la doc publica de niri-ipc no deja
# 100% documentado el nombre exacto del variant de Event para cambios de
# outputs (si tu version lo llama distinto), asi que filtramos por
# cualquier linea del event-stream que mencione "output" en vez de un
# nombre exacto -- mas robusto ante variaciones entre versiones de niri,
# a costa de alguna corrida de mas (barata: si ya esta en el modo
# correcto, lock-panel-refresh.sh no hace nada).

set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v niri >/dev/null 2>&1 || { echo "no encontre 'niri' en PATH" >&2; exit 1; }

# Chequeo inicial (por si el panel ya arranco en el modo equivocado).
"$DIR/lock-panel-refresh.sh"

LAST_RUN=0
MIN_INTERVAL=3  # segundos; evita machacar niri si el event-stream es ruidoso

niri msg --json event-stream 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *[Oo]utput*)
            now=$(date +%s)
            if [ $((now - LAST_RUN)) -ge "$MIN_INTERVAL" ]; then
                # Dar tiempo a que termine el reinit de GPU/renegociacion
                # de conector antes de leer los modos disponibles.
                sleep 1
                "$DIR/lock-panel-refresh.sh"
                LAST_RUN=$(date +%s)
            fi
            ;;
    esac
done
