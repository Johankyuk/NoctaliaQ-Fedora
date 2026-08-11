# Fix: NvDynamicBoost tumba el registro D-Bus de asus_armoury

## Síntoma
rog-control-center mostraba "The asus-armoury driver is not loaded" en
System Control, pese a que el módulo del kernel estaba cargado y los
atributos sysfs se leían sin problema. Persistente en cada boot con el
cargador desconectado.

## Causa raíz
NVIDIA Dynamic Boost está deshabilitado a nivel SBIOS/firmware cuando el
sistema corre en batería — documentado oficialmente por NVIDIA (solo se
activa en AC). Confirmado con escritura directa a sysfs sin pasar por
asusd: cualquier valor (0, 5, 15, 25) devuelve EINVAL en DC, sin importar
que esté dentro del rango válido reportado (min=5, max=25).

asusd intenta restaurar `nv_dynamic_boost` en su fase de arranque
temprana — antes de inicializar el bus D-Bus y sin condicionar el intento
a la fuente de poder. Ese EINVAL durante esa fase tumba el registro
completo del objeto `/xyz/ljones/asus_armoury`, no solo el atributo que
falla: ningún atributo queda expuesto en D-Bus (confirmado con
`busctl tree`, comparando el mismo boot con y sin el valor en el .ron).

## Fix aplicado
NvDynamicBoost removido por completo de asusd.ron (ac_profile_tunings y
dc_profile_tunings). Sin valor guardado, la fase de arranque hace skip
en vez de intentar escribir y fallar.

## Comportamiento residual (no fatal)
Al cambiar de perfil en vivo desde rog-control-center o asusctl, asusd
igual intenta aplicar un valor default interno (0) para nv_dynamic_boost
en batería, y falla con el mismo EINVAL — pero en ese punto el objeto
D-Bus ya está registrado y el daemon corriendo, así que el error queda
contenido en el log sin afectar la UI. Confirmado ciclando entre
Quiet/Balanced/Performance y GPU Mode (Ultimate/iGPU/Hybrid) en batería,
sin aviso rojo en ningún momento.

## Trade-off aceptado
asusd ya no fuerza NvDynamicBoost=25 automáticamente al bootear en AC de
forma declarativa vía config. Se prioriza eliminar el bug recurrente de
registro D-Bus sobre mantener ese control declarativo de un atributo que
de todas formas está inactivo en batería por diseño de firmware.

## Validación
- Múltiples boots/restarts en batería: journal limpio
  ("No saved value: skipping"), busctl tree con los 9 atributos completos.
- rog-control-center sin aviso rojo tras boot en batería.
- Ciclos de perfil de energía y GPU Mode en vivo, en batería: rog-control-center
  se mantiene limpio pese al EINVAL residual y contenido en log.

## Revertir
cp asusd.ron.bak-<timestamp> /etc/asusd/asusd.ron && systemctl restart asusd
