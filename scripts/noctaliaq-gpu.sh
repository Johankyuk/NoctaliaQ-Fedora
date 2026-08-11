#!/usr/bin/env bash
# noctaliaq-gpu.sh — cambio de modo GPU (iGPU / Hibrida / Ultimate), NoctaliaQ.
#
# Reemplaza rog-control-center + asusd para esto especificamente. Todo por
# sysfs directo (atributos asus-armoury), sin ningun daemon corriendo:
#   - dgpu_disable  -> apaga/enciende la dGPU por firmware (Integrada vs el resto)
#   - gpu_mux_mode   -> conmuta el MUX fisico (0 = Ultimate en este firmware,
#                       confirmado por log; el valor contrario que usamos para
#                       "no Ultimate" —1— NO se confirmo explicitamente en una
#                       corrida real, ver README de scripts/ antes de fiarte
#                       100% la primera vez que uses Hibrida/Integrada)
#
# A proposito NO toca perfiles de energia (quiet/balanced/performance) ni fan
# curves — eso quedo fuera de alcance (ver archive/horus-energy/README.md).
# Todos los modos requieren reinicio para aplicar (limitacion de firmware,
# igual que con rog-control-center).
#
# Requiere sudo para escribir los nodos. Para no escribir la contraseña cada
# vez, agrega en /etc/sudoers.d/noctaliaq (sudo visudo -f /etc/sudoers.d/noctaliaq):
#   tu_usuario ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/firmware-attributes/asus-armoury/attributes/dgpu_disable/current_value
#   tu_usuario ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/firmware-attributes/asus-armoury/attributes/gpu_mux_mode/current_value
# (ajusta si tu kernel usa el nodo legacy /sys/devices/platform/asus-nb-wmi/dgpu_disable)
#
#   noctaliaq-gpu.sh               wizard interactivo (sin argumentos)
#   noctaliaq-gpu.sh igpu           modo Integrada (dGPU apagada por firmware)
#   noctaliaq-gpu.sh hibrida        modo Hibrida (iGPU maneja panel, dGPU offload)
#   noctaliaq-gpu.sh ultimate       modo Ultimate (dGPU maneja panel directo)
#   noctaliaq-gpu.sh --actual       estado (una linea por dato, para el launcher)
set -uo pipefail
P='\033[0;35m'; G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'
C='\033[0;36m'; D='\033[2m'
log(){ echo -e "${P}[gpu]${N} $1"; }; ok(){ echo -e "${G}[+]${N} $1"; }
warn(){ echo -e "${Y}[i]${N} $1"; }; err(){ echo -e "${R}[x]${N} $1"; }

DGPU_ARMOURY=/sys/class/firmware-attributes/asus-armoury/attributes/dgpu_disable/current_value
DGPU_LEGACY=/sys/devices/platform/asus-nb-wmi/dgpu_disable
MUX=/sys/class/firmware-attributes/asus-armoury/attributes/gpu_mux_mode/current_value
PENDING=/sys/class/firmware-attributes/asus-armoury/attributes/pending_reboot
if [ -e "$DGPU_ARMOURY" ]; then DGPU="$DGPU_ARMOURY"; else DGPU="$DGPU_LEGACY"; fi

_en_ac(){ for p in /sys/class/power_supply/*/online; do
        [ -r "$p" ] && [ "$(cat "$p" 2>/dev/null)" = "1" ] && return 0; done; return 1; }

_dgpu_presente(){ ls /proc/driver/nvidia/gpus/ 2>/dev/null | grep -q . ; }

# Modo REAL (post-reinicio): se infiere del hardware, no de lo escrito en los
# nodos (eso es solo lo "pendiente" hasta el proximo reinicio).
#   - dGPU no enumerada en absoluto             -> Integrada
#   - dGPU enumerada + panel eDP en amdgpu vivo -> Hibrida
#   - dGPU enumerada + panel eDP en amdgpu caido -> Ultimate (dGPU maneja el panel)
_modo_actual(){
    if ! _dgpu_presente; then echo Integrada; return; fi
    local card drv amdgpu_card="" edp status
    for card in /sys/class/drm/card[0-9]*; do
        [ -e "$card/device/driver" ] || continue
        drv=$(basename "$(readlink -f "$card/device/driver" 2>/dev/null)" 2>/dev/null)
        [ "$drv" = amdgpu ] && { amdgpu_card=$(basename "$card"); break; }
    done
    [ -n "$amdgpu_card" ] || { echo Ultimate; return; }
    edp=$(ls -d /sys/class/drm/"$amdgpu_card"-eDP-* 2>/dev/null | head -1)
    [ -n "$edp" ] || { echo "?"; return; }
    status=$(cat "$edp/status" 2>/dev/null)
    [ "$status" = "connected" ] && echo Hibrida || echo Ultimate
}

_modo_pendiente(){
    local mux dis
    mux=$(cat "$MUX" 2>/dev/null || echo '?')
    dis=$(cat "$DGPU" 2>/dev/null || echo '?')
    case "$mux" in
        0) echo Ultimate ;;
        1) case "$dis" in
               0) echo Hibrida ;;
               1) echo Integrada ;;
               *) echo '?' ;;
           esac ;;
        *) echo '?' ;;
    esac
}

_estado_dgpu(){
    if ! _dgpu_presente; then echo "apagada por firmware (no enumerada)"
    elif command -v nvidia-smi &>/dev/null && nvidia-smi -q -d POWER &>/dev/null; then
        echo "DESPIERTA ($(nvidia-smi --query-gpu=power.draw --format=csv,noheader 2>/dev/null))"
    else echo "dormida (D3cold) / sin nvidia-smi"; fi
}

_escribir(){ # $1=nodo $2=valor
    [ -e "$1" ] || { err "No existe el nodo: $1"; return 1; }
    local cur; cur=$(cat "$1" 2>/dev/null)
    [ "$cur" = "$2" ] && return 0
    if ! echo "$2" | sudo tee "$1" >/dev/null 2>&1; then
        err "El write a $1 fallo (sudo o firmware lo rechazaron de inmediato)."
        return 1
    fi
    if [ "${3:-}" = "requiere_reboot" ]; then
        ok "Escrito en $1 -> $2 (gpu_mux_mode no refleja el cambio en current_value hasta reiniciar, es por diseño del driver asus-armoury)."
        return 0
    fi
    local post; post=$(cat "$1" 2>/dev/null)
    [ "$post" = "$2" ] || { err "El firmware rechazo el cambio en $1 (sigue en $post)."; return 1; }
    return 0
}

_set_modo(){ # $1 = Integrada|Hibrida|Ultimate
    [ -e "$MUX" ] || { err "No existe gpu_mux_mode en este equipo — tu firmware podria no tener MUX fisico."; return 1; }
    case "$1" in
        Ultimate)
            _escribir "$MUX" 0 requiere_reboot || return 1
            ;;
        Hibrida)
            _escribir "$MUX" 1 requiere_reboot || return 1
            _escribir "$DGPU" 0 || return 1
            ;;
        Integrada)
            _escribir "$MUX" 1 requiere_reboot || return 1
            _escribir "$DGPU" 1 || return 1
            ;;
    esac
    ok "Modo GPU -> $1 aplicado. REINICIA para que surta efecto."
    [ -r "$PENDING" ] && log "pending_reboot: $(cat "$PENDING" 2>/dev/null)"
    return 0
}

_pausa(){ echo ""; read -rsn1 -p "$(echo -e "  ${D}[cualquier tecla para volver]${N}")"; echo ""; }

_ofrecer_reboot(){
    echo ""
    read -rp "  ¿Reiniciar ahora para aplicar? [s/N] " r
    case "$r" in
        [sS]) log "Reiniciando..."; systemctl reboot ;;
        *) warn "Cambio guardado; aplica en el próximo reinicio." ; _pausa ;;
    esac
}

_wizard(){
    [ -t 0 ] || { echo "uso: noctaliaq-gpu.sh [igpu|hibrida|ultimate|--actual]"; return 0; }
    local opt modo pend ac g1 g2 g3
    while true; do
        modo=$(_modo_actual); pend=$(_modo_pendiente)
        _en_ac && ac="conectado" || ac="batería"
        [ "$pend" = Ultimate ]  && g1="●" || g1="○"
        [ "$pend" = Hibrida ]   && g2="●" || g2="○"
        [ "$pend" = Integrada ] && g3="●" || g3="○"

        printf '\033[2J\033[H'
        echo -e "  ${P}NoctaliaQ · GPU${N}"
        echo -e "  ${D}─────────────────────────────────────────────${N}"
        echo -e "  Modo actual ${C}${modo}${N}   ·   Cargador ${C}${ac}${N}"
        [ "$modo" != "$pend" ] && echo -e "  ${Y}⟳ pendiente: ${pend} tras reiniciar${N}"
        echo ""
        echo -e "  ${D}(todos requieren reinicio para aplicar)${N}"
        echo -e "   ${g1} ${C}1${N}  Ultimate     ${D}dGPU maneja el panel directo, mas rendimiento/consumo${N}"
        echo -e "   ${g2} ${C}2${N}  Hibrida      ${D}iGPU + dGPU disponible para offload: uso normal${N}"
        echo -e "   ${g3} ${C}3${N}  Integrada    ${D}dGPU apagada por firmware, +batería${N}"
        echo ""
        echo -e "     ${C}0${N}  Salir"
        echo ""
        read -rsn1 -p "$(echo -e "  ${P}>${N} ")" opt
        echo ""
        case "$opt" in
            1) if [ "$pend" = Ultimate ]; then ok "Ultimate ya está seleccionada."; _pausa
               else _set_modo Ultimate && _ofrecer_reboot || _pausa; fi ;;
            2) if [ "$pend" = Hibrida ]; then ok "Hibrida ya está seleccionada."; _pausa
               else _set_modo Hibrida && _ofrecer_reboot || _pausa; fi ;;
            3) if [ "$pend" = Integrada ]; then ok "Integrada ya está seleccionada."; _pausa
               else
                 warn "La dGPU quedará apagada: sin CUDA, sin PRIME offload."
                 read -rp "  ¿Continuar? [s/N] " r
                 case "$r" in [sS]) _set_modo Integrada && _ofrecer_reboot || _pausa ;; *) log "Cancelado."; _pausa ;; esac
               fi ;;
            0|q|Q) printf '\033[2J\033[H'; return 0 ;;
            *) ;;
        esac
    done
}

case "${1:-}" in
    igpu|integrada|integrated) _set_modo Integrada ;;
    hibrida|hybrid|hib)        _set_modo Hibrida ;;
    ultimate|ult)              _set_modo Ultimate ;;
    --actual|actual)
        _act=$(_modo_actual); _pend=$(_modo_pendiente)
        if [ "$_act" = "$_pend" ]; then echo "Modo GPU:   $_act"
        else echo "Modo GPU:   $_act -> $_pend (tras reinicio)"; fi
        echo "dGPU:       $(_estado_dgpu)"
        _en_ac && echo "AC:         conectado" || echo "AC:         batería"
        ;;
    --help|-h) echo "uso: noctaliaq-gpu.sh [igpu|hibrida|ultimate|--actual]" ;;
    "") _wizard ;;
    *) err "opción desconocida: $1"; echo "uso: noctaliaq-gpu.sh [igpu|hibrida|ultimate|--actual]"; exit 1 ;;
esac
