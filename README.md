# NoctaliaQ

Addon sobre una instalación existente de niri + Noctalia (Q = kyu — mi rice de Noctalia). No quita ni reemplaza nada de Noctalia — agrega encima: cursor Bibata negro, recolor dinámico de folders + teclado, transparencia/blur en apps GTK, terminal (kitty) con blur, branding en fastfetch que sigue el acento activo, un fix para que el panel interno no pierda su refresh rate nativo tras un toggle de MUX, y wizards propios (sin GUI de terceros) para modo GPU, límite de batería y retroiluminación del teclado.

**Filosofía: cero asusd.** Desde 2026-08-06, NoctaliaQ no depende de
`asusd`/`asusctl`/`rog-control-center` para nada — todo (GPU, batería,
teclado) se controla por escritura directa a sysfs. El motivo y el detalle
completo de la migración están en `archive/README.md`.

## Requisitos

- niri instalado y corriendo.
- Noctalia instalado y corriendo al menos una vez (necesita haber generado `~/.config/gtk-4.0/noctalia.css`).
- `inotify-tools` (para el recolor automático). El instalador no lo mete por vos si no está — `sudo pacman -S inotify-tools`.
- **No** hace falta `asusd`/`asusctl` para nada de lo activo en `scripts/`. Si los tenés instalados por otra razón, no estorban, pero podés desinstalarlos (ver el final de `scripts/install.sh`).

## Instalación

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Johankyuk/NoctaliaQ/main/scripts/install.sh)
```

Esto:

1. Clona (o actualiza) este repo en `~/NoctaliaQ`.
2. Respalda y symlinkea `~/.config/{niri,noctalia,gtk-3.0,gtk-4.0,fastfetch}` hacia el repo.
3. Instala las entradas del lanzador de Noctalia (GPU, batería, teclado, recolor manual).
4. Instala `kitty`, `thunar`, la fuente y `papirus-icon-theme` vía pacman.
5. Instala el cursor Bibata-Modern-Classic (una sola vez, ver sección Cursor).
6. Instala las reglas udev de batería/teclado (pide sudo) y avisa si tu usuario no está en el grupo `video`.
7. Fija el límite de batería en 80% por defecto (cambialo luego desde el wizard).
8. Habilita los servicios `--user` de recolor automático y de re-aplicar el teclado al iniciar sesión.
9. Corre un primer recolor (folders + teclado) con la paleta activa.

## Features

- **NoctaliaQ: GPU** — `scripts/noctaliaq-gpu.sh` — modo iGPU / Híbrida / Ultimate, sysfs directo, sin fan-curves ni perfiles de rendimiento (fuera de alcance a propósito). Requiere reinicio para aplicar.
- **NoctaliaQ: Límite de Batería** — `scripts/noctaliaq-battery.sh` — límite de carga configurable (default 80%), reforzado por udev en cada evento de batería, sin asusd de por medio.
- **NoctaliaQ: Teclado** — `scripts/noctaliaq-keyboard.sh` — brillo + color sólido (sin efectos todavía) siguiendo el accent activo, sysfs directo. `--diag` si tu equipo no responde igual.
- **Recolor universal (folders + teclado)** — disparado por el hook nativo de Noctalia ("Al cambiar los colores" / "Al cambiar el modo de tema" en Ajustes -> Hooks) apuntando a `scripts/recolor-all.sh`, sin terminal visible ni servicio propio corriendo. `scripts/noctaliaq-recolor-watch.sh` queda como fallback por inotify si tu Noctalia no tiene hooks. `NoctaliaQ: Recolor Folders (manual)` en el lanzador para forzarlo a mano.
- Cursor Bibata-Modern-Classic (estático, no sigue la paleta — decisión a propósito).
- Thunar + blur, terminal (kitty) con blur, ASCII + fastfetch minimalista con su propio blur.

Todos los wizards son ejecutables directo en terminal (con menú interactivo) o desde el lanzador de Noctalia (`NoctaliaQ: <feature>`), y también aceptan subcomandos no interactivos — corré cualquiera con `--help`.

## Pendiente: greetd/noctalia-greeter

Por ahora la instalacion asume **SDDM** como display manager (default de
CachyOS). El setup de `greetd` + `noctalia-greeter` (compositor propio,
sincroniza wallpaper/paleta con el login) requiere 3 fixes que todavia no
estan scripteados en este repo:

- drop-in `ExecStartPre=/usr/bin/sleep 1` en `greetd.service` (race con
  Plymouth por el DRM master del panel interno)
- `XKB_DEFAULT_LAYOUT=latam` (o el layout que corresponda) inyectado en el
  `command=` de `/etc/greetd/config.toml` -- el compositor standalone del
  greeter no hereda el layout de `systemd-localed`
- log persistente a `/var/log/noctalia-greeter/` via `NOCTALIA_GREETER_LOG`

Se agregan cuando se scriptee el setup completo de greetd. Mientras tanto,
quedate en SDDM.

## No es un color fijo (con una excepción a propósito: el cursor)

Folders (Papirus) y el logo de fastfetch siguen la paleta que Noctalia genera a partir del wallpaper activo — no hay un hex fijo en ningún lado. El cursor es la única pieza que **no** sigue el wallpaper: es Bibata-Modern-Classic (negro) fijo, a propósito, para no tener que regenerarlo cada vez que cambia el fondo.

## Cursor

`scripts/install-cursor.sh` baja el release oficial de `ful1e5/Bibata_Cursor` (negro, sin tintar) a `~/.local/share/icons/Bibata-Modern-Classic` y lo activa. Se corre una sola vez desde el instalador; correrlo de nuevo simplemente reinstala/actualiza. `misc.kdl` (niri) y `gtk-3.0`/`gtk-4.0` `settings.ini` ya apuntan a ese nombre fijo.

Esto reemplaza un enfoque anterior con recolor dinámico (clickgen + build por paleta); si preferís volver a un cursor que siga el acento, esa lógica sigue disponible en el historial de git (`git log -- scripts/cursor-recolor.sh`), pero no se usa por defecto.

## Recolor dinámico (folders + teclado)

Papirus (folders de Thunar) y el color del teclado leen el accent activo de Noctalia (`~/.config/gtk-4.0/noctalia.css`) al momento de correr, no un hex fijo. El disparador es el **sistema de hooks nativo de Noctalia** (Ajustes -> Hooks): activá el switch de hooks y apuntá "Al cambiar los colores" y "Al cambiar el modo de tema" a:

```
~/NoctaliaQ/scripts/recolor-all.sh
```

(mismo script en los dos campos — es idempotente). `install.sh` no lo hace por vos porque distintas versiones de Noctalia agregan más campos de hooks (red, energía) que no están en el `settings.json` versionado en este repo — mejor pedirlo por GUI que arriesgarse a pisar configuración en vivo con un script a ciegas.

Si preferís no depender de los hooks (o tu versión de Noctalia todavía no los tiene), `scripts/noctaliaq-recolor-watch.sh` + `systemd/user/noctaliaq-recolor-watch.service` siguen en el repo como fallback por `inotifywait`, sin habilitarse por defecto:

```bash
systemctl --user enable --now noctaliaq-recolor-watch.service
```

Para forzarlo a mano en cualquier momento:

```bash
~/NoctaliaQ/scripts/recolor-all.sh        # folders + teclado
~/NoctaliaQ/scripts/papirus-recolor.sh    # solo folders
```

También disponible como fallback manual desde el lanzador de Noctalia ("NoctaliaQ: Recolor Folders (manual)").

El tema de kitty (`~/.config/kitty/themes/noctalia.conf`) ya lo regenera Noctalia solo, sin scripts nuestros — NoctaliaQ solo le agrega opacidad dinámica (`background_opacity`) y fuente (JetBrainsMono Nerd Font) encima.

## Blur

Global en `.config/niri/config.kdl` (`window-rule` sin `match`, aplica a toda ventana). kitty lo soporta nativo vía el protocolo de niri. Para que se note en apps GTK como Thunar, `gtk.css` importa `noctaliaq-blur.css` con alpha sobre los colores base de Noctalia — si se ve muy sutil o muy fuerte, edítalo directo, no requiere rebuild de nada.

## fastfetch

`~/.config/fastfetch` corre automático al abrir terminal (vía el saludo default de `cachyos-fish-config`, no algo que NoctaliaQ dispare). El logo (`noctaliaq.txt`) usa `"color": {"1": "green"}` en `config.jsonc` — no un hex fijo: fastfetch emite el código ANSI del color 2, que kitty resuelve con `color2` de `themes/noctalia.conf`, el mismo slot que Noctalia ya usa para el accent (coincide con `url_color`/`active_border_color` en ese archivo). Cambia el wallpaper, cambia `color2`, cambia el logo — sin ningún script nuestro corriendo por el medio.

## refresh-lock (panel interno / MUX)

En equipos con MUX (toggle Ultimate/Híbrido vía rog-control-center o `asusctl`/`supergfxctl`), activar Ultimate dispara un reinit del GPU y niri puede volver al modo "preferred" del panel según su EDID — que en algunos paneles es más bajo que el refresh real que soportan (ej. 60Hz en vez de 144Hz), aunque el modo alto siga disponible.

`refresh-lock/` corrige esto sin asumir marca, modelo ni resolución de ningún equipo: le pregunta a niri por IPC cuál es el panel interno y cuál es su modo de mayor resolución+refresh, y lo reaplica si hace falta. Corre solo, enganchado en `cfg/autostart.kdl`. Ver `refresh-lock/README.md` para el detalle.

## archive/ (histórico, no se instala)

Todo lo que dependía de asusd (fan-curves/PRIME portado de horus-nix, y los
fixes puntuales de asusd/rog-control-center) vive ahora en `archive/`, sin
instalarse por defecto. Ver `archive/README.md` para la línea de tiempo
completa de por qué se abandonó ese camino.

## Estructura
```
.config/niri/        config de niri (keybinds, reglas de ventana, blur global)
.config/noctalia/    paletas y settings de Noctalia
.config/gtk-3.0/ .config/gtk-4.0/  tema GTK + transparencia para el blur
.config/kitty/        opacidad + fuente encima del tema que genera Noctalia
.config/fastfetch/    logo y config, corre via el saludo de fish
scripts/              wizards (GPU/batería/teclado), recolor, instalador
systemd/user/         recolor-watch + re-aplicar teclado al iniciar sesión
udev/                 permisos/hooks para batería y teclado, sin sudo ni asusd
refresh-lock/         fix generalizado de refresh-rate del panel interno tras MUX
archive/              horus-energy (fan-curves/PRIME) + asusd-fixes — histórico, no se instala
```

