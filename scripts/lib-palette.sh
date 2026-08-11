#!/usr/bin/env bash
# Fuente unica de la paleta activa de Noctalia. Uso: source lib-palette.sh && extract_palette
extract_palette() {
    local css="$HOME/.config/gtk-4.0/noctalia.css"
    [ -f "$css" ] || { echo "no encontre $css" >&2; return 1; }

    ACCENT=$(grep -oP '(?<=@define-color accent_color )#[0-9a-fA-F]{6}' "$css" | head -1)
    WINDOW_BG=$(grep -oP '(?<=@define-color window_bg_color )#[0-9a-fA-F]{6}' "$css" | head -1)
    VIEW_FG=$(grep -oP '(?<=@define-color view_fg_color )#[0-9a-fA-F]{6}' "$css" | head -1)

    for v in ACCENT WINDOW_BG VIEW_FG; do
        [ -n "${!v}" ] || { echo "no pude extraer $v de noctalia.css" >&2; return 1; }
    done

    SECONDARY=$(python3 -c "
h='$ACCENT'.lstrip('#')
r,g,b=(int(h[i:i+2],16) for i in (0,2,4))
print(f'#{int(r*0.75):02x}{int(g*0.75):02x}{int(b*0.75):02x}')
")
    export ACCENT SECONDARY WINDOW_BG VIEW_FG
    echo "Paleta detectada: accent=$ACCENT secondary=$SECONDARY window_bg=$WINDOW_BG view_fg=$VIEW_FG"
}
