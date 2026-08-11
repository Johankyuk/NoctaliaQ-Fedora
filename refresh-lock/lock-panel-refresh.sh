#!/usr/bin/env bash
# Re-aplica el modo (resolucion+refresh) nativo del panel interno si niri
# quedo en otro modo -- p.ej. tras el reinit de GPU que dispara un toggle
# de MUX (Ultimate/Hibrido) desde rog-control-center/asusd, donde niri cae
# a su modo "preferred" segun el EDID (a veces 60Hz aunque el panel llegue
# a mas).
#
# No asume marca, modelo ni resolucion de ningun equipo en particular:
# en cada corrida le pregunta a niri (via IPC) cual es el panel interno
# (conector eDP-*) y cual es, de sus modos disponibles, el de mayor
# resolucion y, dentro de esa resolucion, mayor refresh -- y lo aplica
# solo si hace falta. Pensado para correr en cualquier laptop sin editar
# nada de este script.
#
# Uso: ./lock-panel-refresh.sh (un solo chequeo+fix, silencioso si no hace
# falta nada). Para que se re-aplique solo despues de cada toggle de MUX,
# usar lock-panel-refresh-watch.sh (corre esto en loop via autostart).

set -uo pipefail

command -v niri >/dev/null 2>&1 || { echo "no encontre 'niri' en PATH" >&2; exit 1; }

PLAN=$(python3 - <<'PYEOF'
import json, re, subprocess, sys

try:
    raw = subprocess.run(
        ["niri", "msg", "--json", "outputs"],
        capture_output=True, text=True, check=True,
    ).stdout
    data = json.loads(raw)
except Exception as e:
    print(f"ERR no pude leer 'niri msg --json outputs': {e}", file=sys.stderr)
    sys.exit(1)

# Panel interno: convencion universal en drm/kms es que el conector se
# llame eDP-N (Intel/AMD/NVIDIA lo respetan por igual). Si hay varios,
# nos quedamos con el primero -- no deberia haber mas de un panel interno.
candidates = sorted(n for n in data if re.match(r'(?i)^edp', n))
if not candidates:
    # No es un error: puede que este corriendo en un equipo sin panel
    # interno detectado con ese nombre, o en modo Ultimate/discreto con
    # el conector todavia sin enumerar.
    sys.exit(0)

name = candidates[0]
out = data[name]
modes = out.get("modes") or []
if not modes:
    sys.exit(0)

# "Nativo" = mayor resolucion; entre modos de esa resolucion, mayor refresh.
# Evita hardcodear cualquier valor especifico de panel/laptop.
best = max(modes, key=lambda m: (m["width"] * m["height"], m["refresh_rate"]))

cur_idx = out.get("current_mode")
cur = modes[cur_idx] if cur_idx is not None and 0 <= cur_idx < len(modes) else None

if cur is not None and cur["width"] == best["width"] and cur["height"] == best["height"] and cur["refresh_rate"] == best["refresh_rate"]:
    sys.exit(0)  # ya esta en el modo correcto

# niri exige el refresh con exactamente 3 decimales, tal cual lo reporta
# 'niri msg outputs' (refresh_rate viene en mHz).
hz = best["refresh_rate"] / 1000
mode_str = f'{best["width"]}x{best["height"]}@{hz:.3f}'
print(f'{name}\t{mode_str}')
PYEOF
)

[ -n "$PLAN" ] || exit 0

echo "$PLAN" | while IFS=$'\t' read -r name mode_str; do
    [ -n "$name" ] || continue
    echo "refresh-lock: $name fuera de su modo nativo, re-aplicando $mode_str"
    niri msg output "$name" mode "$mode_str"
done
