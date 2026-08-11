#!/usr/bin/env bash
# Remueve NvDynamicBoost de asusd.ron para evitar que el registro D-Bus
# de asus_armoury falle al bootear en batería. Ver README.md en este
# mismo directorio para el diagnóstico completo.
# Idempotente: si ya no hay NvDynamicBoost en el archivo, no hace nada.

set -uo pipefail

F=/etc/asusd/asusd.ron

if [[ ! -f "$F" ]]; then
    echo "ERROR: $F no existe" >&2
    exit 1
fi

if ! grep -q "NvDynamicBoost" "$F"; then
    echo "Ya aplicado: NvDynamicBoost no está en $F, nada que hacer."
    exit 0
fi

TMP=$(mktemp)
BACKUP="$F.bak-$(date +%s)"

sudo cp "$F" "$BACKUP" || { echo "ERROR: no se pudo crear backup" >&2; exit 1; }
echo "Backup creado: $BACKUP"

python3 - "$F" "$TMP" <<'PYEOF'
import re, sys

src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    content = f.read()

count_before = content.count("NvDynamicBoost")
new_content = re.sub(r'[ \t]*NvDynamicBoost:\s*-?\d+,\n', '', content)
count_after = new_content.count("NvDynamicBoost")

assert count_before >= 1, "no se encontró NvDynamicBoost en el archivo"
assert count_after == 0, f"quedaron {count_after} ocurrencias sin remover"

with open(dst, "w") as f:
    f.write(new_content)

print(f"Patch generado: {count_before} ocurrencia(s) removida(s)")
PYEOF

if [[ $? -ne 0 ]]; then
    echo "ERROR: patch falló, $F sin modificar" >&2
    rm -f "$TMP"
    exit 1
fi

sudo cp "$TMP" "$F" && rm -f "$TMP"

echo "Aplicado. Reiniciando asusd..."
sudo systemctl restart asusd
sleep 2

echo "=== Verificación ==="
if journalctl -b -u asusd --no-pager --since "10 seconds ago" | grep -qE "nv_dynamic.*einval|einval.*nv_dynamic"; then
    echo "ADVERTENCIA: sigue apareciendo EINVAL para nv_dynamic_boost, revisar manualmente." >&2
else
    echo "OK: sin EINVAL en el restart."
fi

busctl tree xyz.ljones.Asusd 2>/dev/null | grep -q "asus_armoury/panel_overdrive" \
    && echo "OK: objeto D-Bus asus_armoury registrado completo." \
    || echo "ADVERTENCIA: asus_armoury no aparece completo en busctl tree." >&2

echo "✓ terminado"
