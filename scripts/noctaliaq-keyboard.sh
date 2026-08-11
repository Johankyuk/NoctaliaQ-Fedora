#!/usr/bin/env bash
# noctaliaq-keyboard.sh — retroiluminacion del teclado, NoctaliaQ.
#
# Reemplaza asusctl/rog-control-center por sysfs directo, sin ningun daemon.
# Solo color solido + brillo por ahora (sin breathing/rainbow/strobe todavia
# — es lo que pediste como prioridad). El "mode = static (0)" es el unico
# dato 100% consistente entre TODAS las fuentes consultadas para hardware
# asus-wmi/TUF, asi que es seguro confiar en el; el resto (interfaz nueva vs
# vieja) se detecta en caliente.
#
# Interfaces posibles (se detecta cual existe en tu equipo, en este orden):
#   A) moderna:  /sys/class/leds/asus::kbd_backlight/kbd_rgb_mode
#      formato:  echo "<cmd> 0 <r> <g> <b> 0" > kbd_rgb_mode   (r/g/b 0-255, cmd ignorado)
#   B) legacy:   /sys/devices/platform/asus-nb-wmi/kbbl/kbbl_{red,green,blue,mode,speed,flags,set}
#      formato:  se escribe cada componente por separado, mode=0, y kbbl_set=1 al final para confirmar
# Brillo (0-3) siempre por: /sys/class/leds/asus::kbd_backlight/brightness
#
# Sin sudo en el uso normal: el udev rule (ver install.sh) le da permiso de
# escritura al grupo `video` sobre estos nodos. Si tu usuario no esta en ese
# grupo: sudo usermod -aG video "$USER" (requiere cerrar sesion).
#
#   noctaliaq-keyboard.sh                wizard interactivo (sin argumentos)
#   noctaliaq-keyboard.sh accent         sincroniza con el accent activo de Noctalia (con boost, ver abajo)
#   noctaliaq-keyboard.sh color RRGGBB   fija color solido EXACTO (sin # al inicio, sin boost)
#   noctaliaq-keyboard.sh brillo <0-3>   fija el nivel de brillo
#   noctaliaq-keyboard.sh apply          re-aplica el ultimo color+brillo guardado
#   noctaliaq-keyboard.sh --diag         lista los nodos detectados en tu equipo
#   noctaliaq-keyboard.sh --actual       estado (una linea por dato)
#
# El "accent" que genera Noctalia esta pensado para UI (moderado a proposito,
# para no cansar la vista) y en un LED de teclado se ve mas lavado/pastel de
# lo esperado -- confirmado en hardware real: el orden de canales R/G/B es
# correcto, pero el tono se percibe más lavado de lo esperado en el LED.
# Por eso "accent" (el que usa el sync automatico via hook/recolor-all.sh) le
# aplica un boost de saturacion+brillo en HSV antes de mandarlo al LED; "color"
# manda el hex tal cual, sin tocar nada. El boost es ajustable (opcion 6/7 del
# wizard) y se guarda en $HOME/.config/noctaliaq/keyboard.conf (SAT_BOOST).
set -uo pipefail
P='\033[0;35m'; G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'
C='\033[0;36m'; D='\033[2m'
log(){ echo -e "${P}[kbd]${N} $1"; }; ok(){ echo -e "${G}[+]${N} $1"; }
warn(){ echo -e "${Y}[i]${N} $1"; }; err(){ echo -e "${R}[x]${N} $1"; }

LED_DIR=/sys/class/leds/asus::kbd_backlight
BRIGHT="$LED_DIR/brightness"
RGB_MODERNO="$LED_DIR/kbd_rgb_mode"
KBBL_DIR=/sys/devices/platform/asus-nb-wmi/kbbl
CONF="$HOME/.config/noctaliaq/keyboard.conf"
DEFAULT_BRIGHT=2
DEFAULT_SAT_BOOST=1.6
DEFAULT_VAL_FLOOR=0.85

_leer_boost(){ grep -oP '(?<=SAT_BOOST=)[0-9.]+' "$CONF" 2>/dev/null || echo "$DEFAULT_SAT_BOOST"; }

_color_vivido(){ # $1 = RRGGBB (sin #) -> imprime RRGGBB con boost de saturacion/brillo en HSV
    local hex="$1" boost; boost=$(_leer_boost)
    command -v python3 >/dev/null 2>&1 || { echo "$hex"; return; }
    python3 -c "
import colorsys
h='$hex'
r,g,b=(int(h[i:i+2],16) for i in (0,2,4))
hh,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
s=min(1.0, s*$boost)
v=max(v, $DEFAULT_VAL_FLOOR)
r2,g2,b2=colorsys.hsv_to_rgb(hh,s,v)
print(f'{round(r2*255):02x}{round(g2*255):02x}{round(b2*255):02x}')
" 2>/dev/null || echo "$hex"
}

_interfaz(){
    # imprime: moderna | legacy | ninguna
    [ -e "$RGB_MODERNO" ] && { echo moderna; return; }
    [ -d "$KBBL_DIR" ] && [ -e "$KBBL_DIR/kbbl_red" ] && { echo legacy; return; }
    echo ninguna
}

_hex_a_dec(){ # $1 = componente de 2 hex chars -> imprime decimal
    printf '%d' "0x$1"
}

_set_color(){ # $1 = RRGGBB (sin #)
    local hex="${1#\#}"
    [[ "$hex" =~ ^[0-9a-fA-F]{6}$ ]] || { err "color invalido, usa formato RRGGBB (ej. 7aa2f7)."; return 1; }
    local r g b interfaz
    r=$(_hex_a_dec "${hex:0:2}"); g=$(_hex_a_dec "${hex:2:2}"); b=$(_hex_a_dec "${hex:4:2}")
    interfaz=$(_interfaz)
    case "$interfaz" in
        moderna)
            if ! echo "1 0 $r $g $b 0" | tee "$RGB_MODERNO" >/dev/null 2>&1; then
                if ! echo "1 0 $r $g $b 0" | sudo tee "$RGB_MODERNO" >/dev/null 2>&1; then
                    err "El write a $RGB_MODERNO fallo (permisos o firmware lo rechazo)."
                    return 1
                fi
            fi
            ;;
        legacy)
            printf '%02x' "$r" | tee "$KBBL_DIR/kbbl_red" >/dev/null 2>&1 || printf '%02x' "$r" | sudo tee "$KBBL_DIR/kbbl_red" >/dev/null
            printf '%02x' "$g" | tee "$KBBL_DIR/kbbl_green" >/dev/null 2>&1 || printf '%02x' "$g" | sudo tee "$KBBL_DIR/kbbl_green" >/dev/null
            printf '%02x' "$b" | tee "$KBBL_DIR/kbbl_blue" >/dev/null 2>&1 || printf '%02x' "$b" | sudo tee "$KBBL_DIR/kbbl_blue" >/dev/null
            echo 0 | tee "$KBBL_DIR/kbbl_mode" >/dev/null 2>&1 || echo 0 | sudo tee "$KBBL_DIR/kbbl_mode" >/dev/null
            echo 1 | tee "$KBBL_DIR/kbbl_set" >/dev/null 2>&1 || echo 1 | sudo tee "$KBBL_DIR/kbbl_set" >/dev/null
            ;;
        ninguna)
            err "No encontre ni $RGB_MODERNO ni $KBBL_DIR — corre '--diag' y revisa que existe en tu equipo."
            return 1 ;;
    esac
    mkdir -p "$(dirname "$CONF")"
    local brillo_actual boost_actual
    brillo_actual=$(grep -oP '(?<=BRIGHTNESS=)\d+' "$CONF" 2>/dev/null || echo "$DEFAULT_BRIGHT")
    boost_actual=$(_leer_boost)
    printf 'COLOR=%s\nBRIGHTNESS=%s\nSAT_BOOST=%s\n' "$hex" "$brillo_actual" "$boost_actual" > "$CONF"
    ok "Color de teclado -> #${hex} (interfaz $interfaz)."
}

_sync_accent(){
    local dir; dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck disable=SC1091
    source "$dir/lib-palette.sh" && extract_palette >/dev/null 2>&1 || { err "No pude leer la paleta activa de Noctalia."; return 1; }
    local vivido; vivido=$(_color_vivido "${ACCENT#\#}")
    _set_color "$vivido"
}

_set_boost(){ # $1 = nuevo valor (ej. 1.6)
    case "$1" in ''|*[!0-9.]*) err "el boost debe ser un numero (ej. 1.6)."; return 1 ;; esac
    mkdir -p "$(dirname "$CONF")"
    local color_actual brillo_actual
    color_actual=$(grep -oP '(?<=COLOR=)[0-9a-fA-F]{6}' "$CONF" 2>/dev/null || echo "")
    brillo_actual=$(grep -oP '(?<=BRIGHTNESS=)\d+' "$CONF" 2>/dev/null || echo "$DEFAULT_BRIGHT")
    { [ -n "$color_actual" ] && echo "COLOR=$color_actual"; echo "BRIGHTNESS=$brillo_actual"; echo "SAT_BOOST=$1"; } > "$CONF"
    ok "Boost de saturación -> x$1 (corré 'accent'/opción 1 de nuevo para verlo aplicado)."
}

_set_brillo(){ # $1 = 0-3
    case "$1" in 0|1|2|3) ;; *) err "el brillo debe ser 0, 1, 2 o 3."; return 1 ;; esac
    [ -e "$BRIGHT" ] || { err "No encontre $BRIGHT en este equipo."; return 1; }
    echo "$1" | tee "$BRIGHT" >/dev/null 2>&1 || echo "$1" | sudo tee "$BRIGHT" >/dev/null
    local post; post=$(cat "$BRIGHT" 2>/dev/null)
    [ "$post" = "$1" ] || { err "El firmware no acepto el brillo $1 (sigue en $post)."; return 1; }
    mkdir -p "$(dirname "$CONF")"
    local color_actual boost_actual
    color_actual=$(grep -oP '(?<=COLOR=)[0-9a-fA-F]{6}' "$CONF" 2>/dev/null || echo "")
    boost_actual=$(_leer_boost)
    { [ -n "$color_actual" ] && echo "COLOR=$color_actual"; echo "BRIGHTNESS=$1"; echo "SAT_BOOST=$boost_actual"; } > "$CONF"
    ok "Brillo de teclado -> $1."
}

_apply(){
    [ -r "$CONF" ] || { warn "No hay configuracion guardada todavia (usa el wizard o 'color'/'brillo')."; return 0; }
    local color brillo
    color=$(grep -oP '(?<=COLOR=)[0-9a-fA-F]{6}' "$CONF" 2>/dev/null || echo "")
    brillo=$(grep -oP '(?<=BRIGHTNESS=)\d+' "$CONF" 2>/dev/null || echo "$DEFAULT_BRIGHT")
    [ -n "$color" ] && _set_color "$color"
    _set_brillo "$brillo"
}

_diag(){
    echo -e "  ${P}Diagnostico de hardware — teclado${N}"
    echo -e "  ${D}─────────────────────────────────────────────${N}"
    if [ -d "$LED_DIR" ]; then
        ok "Existe $LED_DIR"
        ls -la "$LED_DIR" 2>/dev/null | sed 's/^/    /'
    else
        err "No existe $LED_DIR"
    fi
    echo ""
    if [ -d "$KBBL_DIR" ]; then
        ok "Existe $KBBL_DIR (interfaz legacy)"
        ls -la "$KBBL_DIR" 2>/dev/null | sed 's/^/    /'
    else
        warn "No existe $KBBL_DIR (normal si tu kernel usa solo la interfaz moderna)"
    fi
    echo ""
    log "Interfaz RGB detectada: $(_interfaz)"
    [ -e "$BRIGHT" ] && log "Brillo actual: $(cat "$BRIGHT" 2>/dev/null)" || warn "No encontre el nodo de brillo."
    log "Boost de saturación (solo afecta a 'accent'/sync): x$(_leer_boost)"
}

_pausa(){ echo ""; read -rsn1 -p "$(echo -e "  ${D}[cualquier tecla para volver]${N}")"; echo ""; }

_wizard(){
    [ -t 0 ] || { echo "uso: noctaliaq-keyboard.sh [accent|color RRGGBB|brillo <0-3>|apply|--diag|--actual]"; return 0; }
    local opt color brillo interfaz boost
    while true; do
        interfaz=$(_interfaz)
        color=$(grep -oP '(?<=COLOR=)[0-9a-fA-F]{6}' "$CONF" 2>/dev/null || echo "sin definir")
        brillo=$([ -e "$BRIGHT" ] && cat "$BRIGHT" 2>/dev/null || echo "?")
        boost=$(_leer_boost)

        printf '\033[2J\033[H'
        echo -e "  ${P}NoctaliaQ · TECLADO${N}"
        echo -e "  ${D}─────────────────────────────────────────────${N}"
        echo -e "  Interfaz ${C}${interfaz}${N}   ·   Color ${C}#${color}${N}   ·   Brillo ${C}${brillo}/3${N}   ·   Boost ${C}x${boost}${N}"
        [ "$interfaz" = ninguna ] && echo -e "  ${R}No detecto ningun nodo compatible — usa la opcion 5 para diagnosticar.${N}"
        echo ""
        echo -e "   ${C}1${N}  Usar el accent activo de Noctalia   ${D}con boost de saturación (recomendado para LED)${N}"
        echo -e "   ${C}2${N}  Color manual (RRGGBB)               ${D}exacto, sin boost${N}"
        echo -e "   ${C}3${N}  Subir brillo"
        echo -e "   ${C}4${N}  Bajar brillo"
        echo -e "   ${C}5${N}  Diagnostico"
        echo -e "   ${C}6${N}  Más boost de saturación   ${D}y re-sincroniza con el accent${N}"
        echo -e "   ${C}7${N}  Menos boost de saturación ${D}y re-sincroniza con el accent${N}"
        echo ""
        echo -e "     ${C}0${N}  Salir"
        echo ""
        read -rsn1 -p "$(echo -e "  ${P}>${N} ")" opt
        echo ""
        case "$opt" in
            1) _sync_accent || err "No pude leer la paleta activa de Noctalia."; _pausa ;;
            2) read -rp "  Color (RRGGBB, sin #): " c; _set_color "$c"; _pausa ;;
            3) b=$(cat "$BRIGHT" 2>/dev/null || echo 0); [ "$b" -lt 3 ] && _set_brillo $((b+1)) || warn "ya esta al maximo."; _pausa ;;
            4) b=$(cat "$BRIGHT" 2>/dev/null || echo 0); [ "$b" -gt 0 ] && _set_brillo $((b-1)) || warn "ya esta al minimo."; _pausa ;;
            5) printf '\033[2J\033[H'; _diag; _pausa ;;
            6) _set_boost "$(awk "BEGIN{b=$boost+0.2; if(b>4)b=4; printf \"%.2f\", b}")"; _sync_accent; _pausa ;;
            7) _set_boost "$(awk "BEGIN{b=$boost-0.2; if(b<0.2)b=0.2; printf \"%.2f\", b}")"; _sync_accent; _pausa ;;
            0|q|Q) printf '\033[2J\033[H'; return 0 ;;
            *) ;;
        esac
    done
}

case "${1:-}" in
    accent) _sync_accent ;;
    color) [ -n "${2:-}" ] || { err "uso: noctaliaq-keyboard.sh color RRGGBB"; exit 1; }; _set_color "$2" ;;
    brillo) [ -n "${2:-}" ] || { err "uso: noctaliaq-keyboard.sh brillo <0-3>"; exit 1; }; _set_brillo "$2" ;;
    apply) _apply ;;
    --diag|diag) _diag ;;
    --actual|actual)
        echo "Interfaz RGB:  $(_interfaz)"
        [ -e "$BRIGHT" ] && echo "Brillo:        $(cat "$BRIGHT" 2>/dev/null)/3" || echo "Brillo:        no soportado"
        echo "Boost accent:  x$(_leer_boost)"
        [ -r "$CONF" ] && echo "Guardado:      $(cat "$CONF" | tr '\n' ' ')"
        ;;
    --help|-h) echo "uso: noctaliaq-keyboard.sh [accent|color RRGGBB|brillo <0-3>|apply|--diag|--actual]" ;;
    "") _wizard ;;
    *) err "opción desconocida: $1"; echo "uso: noctaliaq-keyboard.sh [accent|color RRGGBB|brillo <0-3>|apply|--diag|--actual]"; exit 1 ;;
esac
