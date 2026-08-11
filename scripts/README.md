# scripts/

> **Nota Fedora**: `install.sh`/`install-cursor.sh` se copiaron tal cual desde
> CachyOS pero siguen usando `pacman` — pendiente reescribir para `dnf`. El resto
> de esta carpeta está activo y probado en Fedora.


Todo lo activo de NoctaliaQ corre directo desde acá (no se instalan copias en
`/usr/local/bin`; los `.desktop`, unidades systemd y reglas udev apuntan a
esta carpeta directamente, con la ruta de este equipo hardcodeada
— `/home/kyu/NoctaliaQ/...` — igual que ya hacía el repo antes de esta sesión).

## noctaliaq-gpu.sh — cómo probarlo con cuidado

Nadie corrió todavía en este equipo el nuevo camino de 3 modos (antes solo
existía el toggle Híbrida/Integrada). Antes de confiar en el wizard:

1. `./noctaliaq-gpu.sh --actual` — anotá qué dice `Modo GPU` ahora mismo.
2. Wizard -> Hibrida (aunque ya creas estar en Hibrida, para forzar la
   escritura) -> reiniciar -> `--actual` de nuevo. Confirmá que sigue
   diciendo Hibrida y que `nvidia-smi` funciona normal.
3. Wizard -> Ultimate -> reiniciar -> `--actual`. Debería decir Ultimate.
   Con esto queda confirmado el valor `gpu_mux_mode=0`.
4. Wizard -> Hibrida de nuevo -> reiniciar -> `--actual`. **Este paso es el
   que nunca se confirmó explícitamente** (ver `archive/horus-energy/README.md`,
   sección "Revisión Ultimate/supergfxd") — el script asume `gpu_mux_mode=1`
   vuelve a Híbrida, pero si tras este paso `--actual` no coincide, avisame
   y ajustamos el valor en `_set_modo`/`_modo_pendiente`.
5. Recién ahí, Integrada -> reiniciar -> `--actual` (dGPU debería desaparecer
   de `/proc/driver/nvidia/gpus/`).

Si en cualquier paso el equipo no arranca bien o no cambia de modo, lo peor
que puede pasar es quedar en Híbrida (el modo más compatible) reescribiendo
los nodos a mano — no hay riesgo de brickear el firmware, son los mismos
atributos que ya escribía rog-control-center.

## noctaliaq-battery.sh

`set` y `apply` no requieren reinicio (es un límite que el kernel aplica en
caliente). Sí conviene, tras instalarlo, desconectar y reconectar el
cargador una vez para confirmar que el udev rule (`ACTION=="change"`)
efectivamente reaplica el valor si algo lo resetea.

## noctaliaq-keyboard.sh — cómo probarlo con cuidado

`--diag` primero, siempre, en un equipo nuevo — te dice si tu kernel expone
la interfaz moderna (`kbd_rgb_mode`) o la legacy (`kbbl_*`), o ninguna. El
`mode=static (0)` que usa el script es el único dato confirmado igual en
**todas** las fuentes consultadas (kernel patch original de 2019 + reportes
de usuarios en TUF A17), así que la base es sólida — lo que puede variar
por modelo es si hay modos adicionales (breathing/rainbow/strobe), que a
propósito no se implementaron todavía.

Si `--diag` muestra `ninguna`: tu kernel puede no tener soporte asus-wmi
para RGB en este modelo puntual, o necesita un módulo/parámetro extra
(`asus_wmi.enable_rgb=1` existe en algunos setups) — decime qué muestra
`--diag` y lo ajustamos.

## Recolor: hooks nativos de Noctalia (preferido) vs. watcher inotify (fallback)

Noctalia trae su propio sistema de hooks (Ajustes -> Hooks, `~/.config/noctalia/settings.json` -> `hooks.colorGeneration` / `hooks.darkModeChange`) — es el disparador correcto para `recolor-all.sh`, no `noctaliaq-recolor-watch.sh`. Motivo por el que `install.sh` no lo configura solo: en el `settings.json` de este repo el bloque `hooks` solo tiene `colorGeneration`/`darkModeChange`/`enabled`/`wallpaperChange`/etc., pero versiones más nuevas de Noctalia agregan bastantes más campos (red, energía) que no están reflejados acá — pisar ese archivo a ciegas desde un script podría perder configuración en vivo que Noctalia ya haya agregado. Hacelo por GUI (dos campos, un switch) y avisame si el timing no cuadra: falta confirmar si el hook dispara antes o después de que Noctalia termine de escribir `noctalia.css` — si `recolor-all.sh` agarra el color viejo, avisame y le agrego un `sleep` de guarda como el que ya tiene el watcher.

## Convenciones compartidas

- Todo wizard sin argumentos entra en modo interactivo (`_wizard`, ANSI +
  menú numerado); con argumentos corre el subcomando directo, sin menú
  (pensado para scripts/otros wizards que se llamen entre sí).
- `--actual` siempre imprime texto plano, una cosa por línea — pensado para
  mostrarse en un launcher o widget, no para leer con ojos humanos en un
  menú bonito.
- Nada escribe a sysfs sin verificar el valor post-escritura y avisar si el
  firmware lo rechazó silenciosamente.
