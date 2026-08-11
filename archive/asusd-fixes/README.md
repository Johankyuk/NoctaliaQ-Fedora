# asusd-fixes/ — ARCHIVADO, ya no aplica

**2026-08-06:** NoctaliaQ dejó de usar asusd/asusctl/rog-control-center por
completo (ver `archive/README.md` y `archive/horus-energy/README.md`) — GPU,
batería y teclado ahora se controlan por sysfs directo. Estos fixes
documentan bugs puntuales *de asusd mismo*; se conservan por transparencia
del diagnóstico, pero no hay nada que instalar ni mantener aquí salvo que en
algún momento se vuelva a depender de asusd.

Fixes puntuales para bugs de asusd/asusctl/rog-control-center en este
hardware (ASUS TUF A16 FA607NUG — Ryzen 7 7445HS + Radeon 740M + RTX 4050
Max-Q). No relacionado con `horus-energy/` (mecanismo dinámico de
fan-curves/PRIME portado de horus-nix, también archivado).

## Diagnóstico inicial (superado, ver `nv-dynamic-boost-battery/` para la causa raíz real)

**Síntoma:** rog-control-center, pestaña System Control, GPU Configuration
muestra en rojo "The asus-armoury driver is not loaded" — pese a que el
módulo del kernel SÍ está cargado y los atributos sysfs se leen bien.

**Primer diagnóstico (2026-08-05, incompleto):** se asumió que
`NvDynamicBoost: 0` en `dc_profile_tunings.Balanced` estaba fuera de rango
(el firmware acepta 5-25) y que subirlo a 5 resolvía el problema. Ese
cambio se validó en un boot en AC, lo cual enmascaró la causa real —
`nv_dynamic_boost` está bloqueado por firmware en batería sin importar el
valor. Ver `nv-dynamic-boost-battery/README.md` para el diagnóstico
correcto y el fix vigente (`fix-nv-dynamic-boost-dbus-registration/`,
remueve la key por completo en vez de ajustar su valor).

Este primer intento (`fix-nv-dynamic-boost-range.sh`) ya no existe en el
repo — quedó superseded el mismo día por el fix de registro D-Bus. Se deja
esta nota únicamente para que el historial de diagnóstico quede completo.
