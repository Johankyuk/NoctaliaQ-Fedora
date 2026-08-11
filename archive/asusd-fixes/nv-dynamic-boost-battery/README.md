# Fix: rog-control-center "asus-armoury driver is not loaded"

## Diagnóstico previo (incorrecto, documentado por transparencia)

Se asumió que `NvDynamicBoost: 0` estaba fuera de rango (min real: 5,
max real: 25) y que subirlo a `5` resolvía el problema. Ese cambio se
validó en un boot donde el sistema estaba en modo híbrido y conectado a
AC, lo cual enmascaró la causa real: nunca se probó el escenario que
realmente dispara el bug (batería).

## Causa raíz real

El firmware bloquea el atributo `nv_dynamic_boost` por completo cuando
el equipo corre en batería (DC), sin importar el valor solicitado.
`nvidia-powerd` lo confirma en su propio log al boot:

    ERROR! Client (presumably SBIOS) has requested to disable
    Dynamic Boost DC controller

Cuando `asusd` intenta escribir cualquier valor a `nv_dynamic_boost`
en DC (al boot, o al cambiar de perfil de energía en batería), el
kernel devuelve `EINVAL` (código 22). Ese fallo deja el registro del
objeto D-Bus `AsusArmoury` a medias, y rog-control-center cae a un
mensaje genérico y engañoso: "the asus-armoury driver is not loaded"
(el módulo del kernel sí está cargado — es un fallo de negociación
D-Bus, no de driver).

No tiene relación con el modo Ultimate/híbrido: se confirmó que
`NvDynamicBoost: 25` en AC aplica sin error estando en Ultimate.

## Fix

`group` dentro de cada perfil de `asusd.ron` es un mapa, no un struct
fijo — las keys son opcionales. Se removió la key `NvDynamicBoost` del
perfil `dc_profile_tunings.Balanced`, para que `asusd` ni intente
escribir ese atributo en batería.

Antes:
```ron
dc_profile_tunings: {
    Balanced: (
        enabled: true,
        group: {
            PptPl1Spl: 60,
            NvDynamicBoost: 5,
            PptPl3Fppt: 60,
            NvTempTarget: 75,
            PptPl2Sppt: 60,
        },
    ),
    ...
```

Después: la key `NvDynamicBoost` no aparece en el grupo.

## Validación

Restart de `asusd` en batería real (`ACAD/online: 0`), journal sin
ninguna mención de `nv_dynamic_boost` (ni error ni skip). Confirmado
también que sí sigue aplicando correctamente en AC (`Integer(25)`,
sin error).

## Revertir

```bash
sudo cp asusd.ron.reference /etc/asusd/asusd.ron  # o el .bak-* generado en /etc/asusd
sudo systemctl restart asusd
```
