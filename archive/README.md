# archive/

Todo lo de aquí es histórico: código intacto que **no instala ni corre**
`scripts/install.sh`. Se conserva por dos razones — transparencia del
diagnóstico (por qué se tomó cada decisión) y por si algún día hace falta
volver atrás.

## Qué pasó (resumen, 2026-08-05 → 2026-08-06)

1. **horus-energy/** — módulo de fan-curves + PRIME offload dinámico por
   AC/batería, portado de horus-nix. Pausado el 2026-08-05: el offload
   forzado en AC se sentía menos fluido en juegos (se resolvió desactivando
   vsync en el juego, no aquí). Se optó por control nativo vía
   rog-control-center + asusd mientras tanto.

2. **asusd-fixes/** — mientras el punto 1 seguía pausado, rog-control-center
   empezó a fallar en cada arranque en batería ("asus-armoury driver is not
   loaded"). Se diagnosticó y arregló: era una falla de registro D-Bus de
   asusd por un atributo (`NvDynamicBoost`) bloqueado por firmware en DC,
   no un driver faltante.

3. **Decisión final (2026-08-06, esta sesión):** el fix del punto 2
   funcionaba, pero rog-control-center seguía siendo más problema que
   solución en general. Se decidió prescindir de rog-control-center **y**
   de asusd/asusctl por completo — no solo la GUI — reemplazando cada pieza
   que de verdad se usaba (GPU, batería, teclado) por sysfs directo, sin
   ningún daemon de por medio. Fan-curves/perfiles de rendimiento no se
   repusieron: quedan fuera de alcance a propósito.

## Punto 5 (desinstalación física de asusd/asusctl/rog-control-center): en pausa

**2026-08-06:** archivado por problemas técnicos reales — daban más
problema que ayuda (arranques fallidos, fixes puntuales que había que
re-aplicar). El servicio propio (`scripts/noctaliaq-gpu.sh`,
`noctaliaq-battery.sh`, `noctaliaq-keyboard.sh`, todo por sysfs directo)
es más que suficiente y ya cubre todo lo que se usaba en la práctica.
Están inertes, nadie los invoca. Desinstalarlos del sistema (pacman -R)
queda abierto sin urgencia — los comandos siguen impresos al final de
`install.sh` por si se decide más adelante.

## Dónde quedó cada cosa

| Módulo archivado          | Reemplazado por (activo, en `scripts/`)   |
|----------------------------|--------------------------------------------|
| `horus-energy/` (GPU+fans) | `scripts/noctaliaq-gpu.sh` (solo modo GPU, sin fans/perfiles) |
| `asusd-fixes/`             | ya no aplica — no hay asusd que arreglar     |
| (nada, era nuevo)          | `scripts/noctaliaq-battery.sh`, `scripts/noctaliaq-keyboard.sh` |

Ver el README de cada subcarpeta para el detalle técnico completo de cada
decisión.
