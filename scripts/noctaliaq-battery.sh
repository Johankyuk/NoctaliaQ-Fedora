#!/usr/bin/env bash
# noctaliaq-battery.sh — limite de carga de bateria, NoctaliaQ.
#
# Reemplaza el control via asusd.ron (charge_control_end_threshold) por
# escritura directa al nodo sysfs del kernel, sin ningun daemon de por
# medio. Motivo: con asusd corriendo se observo al menos una carga a 100%
# pese a tener el limite configurado en 80% — no se llego a diagnosticar
# si la causa era asusd o el nodo mismo, asi que la meta de este script es
# no depender de asusd en absoluto y reforzar el valor via udev, no solo
# al arrancar.
#
# El valor deseado vive en /etc/noctaliaq/battery.conf (THRESHOLD=NN), leido
# tanto por el wizard (usuario) como por el hook de udev (root, sin sudo).
# El udev rule (ver install.sh) llama a "noctaliaq-battery apply" en cada
# evento add/change de la bateria — ademas de al arrancar, se re-aplica
# solo si el kernel llegara a resetear el valor (p.ej. tras resume).
#
#   noctaliaq-battery.sh                wizard interactivo (sin argumentos)
#   noctaliaq-battery.sh set <1-100>    fija el limite y lo guarda en config
#   noctaliaq-battery.sh apply          re-aplica el valor guardado (idempotente)
#   noctaliaq-battery.sh --actual       estado (una linea por dato)
set -uo pipefail
P='\033[0;35m'; G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'
C='\033[0;36m'; D='\033[2m'
log(){ echo -e "${P}[bat]${N} $1"; }; ok(){ echo -e "${G}[+]${N} $1"; }
warn(){ echo -e "${Y}[i]${N} $1"; }; err(){ echo -e "${R}[x]${N} $1"; }

CONF=/etc/noctaliaq/battery.conf
DEFAULT_THRESHOLD=80

_bat_node(){
    local f
    for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
        [ -e "$f" ] && { echo "$f"; return 0; }
    done
    return 1
}

_leer_config(){
    if [ -r "$CONF" ]; then
        # shellcheck disable=SC1090
        source "$CONF"
    fi
    echo "${THRESHOLD:-$DEFAULT_THRESHOLD}"
}

_guardar_config(){ # $1 = valor
    local tmp; tmp=$(mktemp)
    echo "THRESHOLD=$1" > "$tmp"
    if [ "$EUID" -eq 0 ]; then
        mkdir -p "$(dirname "$CONF")"
        install -m 644 "$tmp" "$CONF"
    else
        sudo mkdir -p "$(dirname "$CONF")"
        sudo install -m 644 "$tmp" "$CONF"
    fi
    rm -f "$tmp"
}

_escribir_nodo(){ # $1 = nodo, $2 = valor
    if [ "$EUID" -eq 0 ]; then
        echo "$2" > "$1" 2>/dev/null
    else
        echo "$2" | sudo tee "$1" >/dev/null 2>&1
    fi
    local post; post=$(cat "$1" 2>/dev/null)
    [ "$post" = "$2" ]
}

_apply(){
    local node valor actual
    node=$(_bat_node) || { err "No encontre charge_control_end_threshold — ¿tu kernel/laptop lo soporta?"; return 1; }
    valor=$(_leer_config)
    actual=$(cat "$node" 2>/dev/null || echo '?')
    if [ "$actual" = "$valor" ]; then
        ok "Ya esta en ${valor}% (sin cambios)."
        return 0
    fi
    if _escribir_nodo "$node" "$valor"; then
        ok "Limite de carga -> ${valor}% aplicado (era ${actual}%)."
    else
        err "El kernel no acepto ${valor}% en $node (sigue en $(cat "$node" 2>/dev/null))."
        return 1
    fi
}

_set(){ # $1 = nuevo valor
    local v="$1"
    case "$v" in
        ''|*[!0-9]*) err "el valor debe ser un numero entero (1-100)."; return 1 ;;
    esac
    [ "$v" -ge 1 ] && [ "$v" -le 100 ] || { err "el valor debe estar entre 1 y 100."; return 1; }
    _guardar_config "$v"
    _apply
}

_pausa(){ echo ""; read -rsn1 -p "$(echo -e "  ${D}[cualquier tecla para volver]${N}")"; echo ""; }

_wizard(){
    [ -t 0 ] || { echo "uso: noctaliaq-battery.sh [set <1-100>|apply|--actual]"; return 0; }
    local node opt actual configurado
    while true; do
        node=$(_bat_node 2>/dev/null || echo "")
        actual=$([ -n "$node" ] && cat "$node" 2>/dev/null || echo '?')
        configurado=$(_leer_config)

        printf '\033[2J\033[H'
        echo -e "  ${P}NoctaliaQ · LÍMITE DE BATERÍA${N}"
        echo -e "  ${D}─────────────────────────────────────────────${N}"
        if [ -z "$node" ]; then
            echo -e "  ${R}No encontre el nodo charge_control_end_threshold en este equipo.${N}"
        else
            echo -e "  Nodo actual ${C}${actual}%${N}   ·   Configurado ${C}${configurado}%${N}"
            [ "$actual" != "$configurado" ] && echo -e "  ${Y}⟳ desincronizado, elegi 'Aplicar ahora' para forzarlo${N}"
        fi
        echo ""
        echo -e "   ${C}1${N}  60%   ${D}maxima autonomia de la bateria a largo plazo${N}"
        echo -e "   ${C}2${N}  80%   ${D}recomendado, uso diario con cargador casi siempre puesto${N}"
        echo -e "   ${C}3${N}  100%  ${D}carga completa (mas desgaste si vive enchufada)${N}"
        echo -e "   ${C}4${N}  Otro valor..."
        echo -e "   ${C}5${N}  Aplicar ahora (re-forzar el configurado)"
        echo ""
        echo -e "     ${C}0${N}  Salir"
        echo ""
        read -rsn1 -p "$(echo -e "  ${P}>${N} ")" opt
        echo ""
        case "$opt" in
            1) _set 60; _pausa ;;
            2) _set 80; _pausa ;;
            3) _set 100; _pausa ;;
            4) read -rp "  Valor (1-100): " v; _set "$v"; _pausa ;;
            5) _apply; _pausa ;;
            0|q|Q) printf '\033[2J\033[H'; return 0 ;;
            *) ;;
        esac
    done
}

case "${1:-}" in
    set)
        [ -n "${2:-}" ] || { err "uso: noctaliaq-battery.sh set <1-100>"; exit 1; }
        _set "$2" ;;
    apply) _apply ;;
    --actual|actual)
        node=$(_bat_node 2>/dev/null || echo "")
        if [ -z "$node" ]; then
            echo "Límite de batería: no soportado en este equipo"
        else
            echo "Límite actual:     $(cat "$node" 2>/dev/null)%"
            echo "Configurado:       $(_leer_config)%"
        fi
        ;;
    --help|-h) echo "uso: noctaliaq-battery.sh [set <1-100>|apply|--actual]" ;;
    "") _wizard ;;
    *) err "opción desconocida: $1"; echo "uso: noctaliaq-battery.sh [set <1-100>|apply|--actual]"; exit 1 ;;
esac
