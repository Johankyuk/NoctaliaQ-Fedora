# refresh-lock/

Generaliza el fix puntual que vivía hardcodeado en
`.config/niri/cfg/display.kdl` (`output "eDP-1" { mode "1920x1200@144.001" }`).

## El problema original

En hardware con MUX (cambio Ultimate/Híbrido vía rog-control-center o
`asusctl`/`supergfxctl`), activar Ultimate dispara un reinit completo del
GPU (VBIOS, Display Core) y el conector del panel interno se
desconecta/reconecta. niri, al reconectar, vuelve a su modo "preferred"
según el EDID — que en algunos paneles reporta 60Hz como preferido aunque
el panel soporte más (144Hz en este caso), aunque ese modo alto siga
disponible en la lista.

El fix original resolvía esto forzando ese modo exacto en `display.kdl`.
Funciona, pero solo en la laptop donde se escribió: otro equipo con otro
panel (otra resolución, otro refresh nativo) necesitaría editar el
archivo a mano.

## El fix generalizado

`lock-panel-refresh.sh` no asume ninguna resolución ni modelo: le
pregunta a niri por IPC (`niri msg --json outputs`) cuál es el panel
interno (conector `eDP-*`, convención universal en drm/kms sin importar
el driver — Intel/AMD/NVIDIA) y cuál es, de sus modos disponibles, el de
mayor resolución y, dentro de esa resolución, mayor refresh. Si niri no
está en ese modo, lo reaplica (`niri msg output <nombre> mode <modo>`).

`lock-panel-refresh-watch.sh` corre ese chequeo al arrancar niri y de
nuevo cada vez que el event-stream de niri reporta un cambio de outputs
(reconexión del panel tras el toggle de MUX), con un pequeño debounce
para no machacar niri y un `sleep 1` para dejar que el reinit del GPU
termine antes de leer los modos.

## Instalación

Ya viene enganchado en `cfg/autostart.kdl`:

```
spawn-sh-at-startup "$HOME/NoctaliaQ/refresh-lock/lock-panel-refresh-watch.sh"
```

No hace falta tocar `display.kdl` — el bloque `output "eDP-1"` hardcodeado
se sacó, precisamente porque ya no hace falta y no es portable.

## Uso manual

```bash
./refresh-lock/lock-panel-refresh.sh   # un solo chequeo+fix
```

## Nota abierta

La doc pública de `niri-ipc` no deja 100% documentado el nombre exacto
del evento de cambio de outputs en el event-stream (versiones distintas
de niri podrían nombrarlo distinto). El watcher filtra por cualquier
línea del stream que mencione "output" en vez de un nombre exacto de
evento — más robusto ante esa incertidumbre, a costa de alguna corrida
de más (barata: si ya está en el modo correcto, no hace nada). Si en tu
versión de niri el filtro no dispara nunca, revisá con
`niri msg --json event-stream` qué evento llega realmente al reconectar
el panel y ajustá el `case` en `lock-panel-refresh-watch.sh`.
