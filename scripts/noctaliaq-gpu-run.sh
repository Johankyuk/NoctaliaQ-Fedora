#!/usr/bin/env bash
# noctaliaq-gpu-run.sh — lanza un comando en la GPU discreta (RTX) via switcheroo-control.
# Todo lo demas (apps normales) sigue en la iGPU por default sin tocar nada.
# uso: noctaliaq-gpu-run.sh <comando> [args...]
set -euo pipefail
[ $# -ge 1 ] || { echo "uso: $(basename "$0") <comando> [args...]" >&2; exit 1; }
exec switcherooctl launch "$@"
