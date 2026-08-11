# horus-energy — ARCHIVADO (no se instala por defecto)

Portado de horus-nix (fan curves quiet/balanced/performance, perfiles
power-profiles-daemon, switch PRIME dinamico por AC/bateria, cap de CPU).
Binarios renombrados de `horus-*` a `noctaliaq-*` el 2026-08-06 por
consistencia de branding, pero el modulo sigue sin activarse.

## Linea de tiempo

**2026-08-05 (pausa inicial):** desactivado en favor del control nativo via
rog-control-center + asusd. Motivo: `noctaliaq-gpu-watch` (entonces
`horus-gpu-watch`) forzaba offload PRIME en AC, lo que introducia un paso de
copia dGPU->iGPU que se sentia menos fluido en juegos con vsync activo pese a
que el contador de FPS marcara alto. Se resolvio desactivando vsync en el
juego, no en este modulo.

**2026-08-05 (revision same-day):** se investigo si el boton Ultimate de
rog-control-center realmente hacia algo (se penso que no, por falta de
supergfxd). Evidencia de asusd/dmesg confirmo que el MUX si conmuta de
verdad via el atributo `gpu_mux_mode` (valor 0 = Ultimate en este firmware),
sin necesidad de supergfxd. Quedo pendiente medir consumo real en Ultimate.

**2026-08-06 (decision final, esta sesion):** rog-control-center generaba un
error en cada arranque ("asus-armoury driver is not loaded" — en realidad
falla de registro D-Bus de asusd, no un driver faltante; ver
`archive/asusd-fixes/`). Se decidio prescindir de rog-control-center Y de
asusd/asusctl por completo, reemplazando cada pieza que realmente se usaba
por control directo via sysfs, sin daemon de por medio:

| Necesidad                        | Antes (asusd/asusctl)      | Ahora                                  |
|-----------------------------------|-----------------------------|------------------------------------------|
| GPU: iGPU / Hibrida / Ultimate    | rog-control-center GUI      | `scripts/noctaliaq-gpu.sh` (sysfs `dgpu_disable` + `gpu_mux_mode` directo) |
| Limite de carga de bateria        | asusd.ron `charge_control_end_threshold` | `scripts/noctaliaq-battery.sh` (sysfs directo + udev, sin asusd) |
| Teclado (brillo + color solido)   | asusctl aura / rog-control-center | `scripts/noctaliaq-keyboard.sh` (sysfs `asus::kbd_backlight` directo) |
| Fan curves / perfil rendimiento   | asusctl fan-curve            | **fuera de alcance**, no se repone (ver nota abajo) |

**Fan curves y perfiles de rendimiento no se reponen.** No hay equivalente
sysfs directo razonable para curvas de ventilador personalizadas (requieren
el daemon o acceso EC que asusd si sabe hacer con seguridad). Al no usar
asusd, el equipo corre con las curvas de fabrica del firmware para el
`platform_profile` activo (quiet/balanced/performance via
`power-profiles-daemon`, que es independiente de asusd y sigue funcionando
igual). Si en el futuro se vuelve a necesitar control fino de ventiladores,
este modulo es el punto de partida — `noctaliaq-fan-curves-apply` y
`noctaliaq-gpu-watch` (la parte de fan-curve) siguen intactos abajo.

## Codigo intacto, nada instalado

Los binarios (`bin/`), unidades systemd (`systemd/`) y sudoers
(`sudoers.d/`) siguen aqui tal cual, solo renombrados. Nada de esto se
instala por el instalador principal (`scripts/install.sh`). Si alguna vez
hace falta reactivar esta ruta (requiere asusd + asusctl instalados y
corriendo):

```bash
./install-noctaliaq-energy.sh
```

Pedira confirmacion explicita porque depende de asusd, que la instalacion
activa de NoctaliaQ ya no usa.

## Revision Ultimate/supergfxd (detalle tecnico heredado)

Log de asusd al activar Ultimate: "Queueing GPU attribute gpu_mux_mode = 0
for delayed apply" seguido de "Applied queued GPU attribute gpu_mux_mode = 0".
dmesg confirma un reinit completo de amdgpu (VBIOS, Display Core) en el
mismo segundo. El conector eDP fisico salta: card0-eDP-2 (amdgpu) pasa a
"disconnected" y card1-eDP-1 (nvidia) pasa a "connected". No se probo
explicitamente volver a hibrido en esa sesion para confirmar el valor
opuesto de `gpu_mux_mode` — `scripts/noctaliaq-gpu.sh` asume `1 = no
Ultimate` (Hibrida/Integrada, diferenciado por `dgpu_disable`) por ser la
unica alternativa binaria razonable, pero esto sigue pendiente de confirmar
en una corrida real. Ver `scripts/README.md` (seccion GPU) para como
probarlo con cuidado.
