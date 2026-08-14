# Sonda abierta: snapshots vacíos de ceres → BACKUP_A/B

**Fecha:** 2026-08-14
**Estado:** diagnóstico ABIERTO, sonda instalada, pendiente de lectura
**Relacionado:** [[2026-08-14_backup-health-monitor-design]]

## Qué pasó

Entre ~2026-01-20 y 2026-08-14, todos los tags que van de `backup_usb1` a BACKUP_A/B
generaron snapshots **vacíos**, reportando éxito. El origen se veía vacío desde ceres a las
03:00, aunque los mismos comandos a mano funcionaban.

Se recuperó el 2026-08-14 tras un `pct reboot 203` (vía `remount-backup.sh`), que renovó el
bind mount de `/mnt/backup_usb1` en ceres.

**La causa no está probada.** Es correlación: cuando instalé la sonda ya lo había arreglado
sin saberlo, así que nunca observé el estado roto. El sospechoso principal es el ciclo de
desmontaje 15:00 / remontaje 00:30, que ya causó obsolescencia de bind mounts en el pasado
(ver `docs/memory_gr-srv03_stale-mount-investigation.md`).

## La sonda

Script temporal en ceres: `/home/rsi/probe-usb1-mount.sh`. Muestrea cada 10 s durante 4 min y
escribe en `~/backup_greven/logs/probe-usb1-mount.log`.

Tres ventanas en el crontab de `rsi` en ceres, elegidas para aislar el disparador:

| Cron | Hora | Qué aísla |
|---|---|---|
| `35 0 * * *` | 00:35 | Justo después del remontaje — el disparador sospechado |
| `10 2 * * *` | 02:10 | Antes de que `check-ceres-mount-sync` (02:20) pueda reiniciar ceres y borrar la evidencia |
| `59 2 * * *` | 02:59 | Antes del backup de las 03:00 |

La ventana de las 02:10 es la importante: `check-ceres-mount-sync.sh` reinicia ceres cuando
encuentra `backup_a` obsoleto, y ese reinicio arreglaría de paso un `/mnt/backup_usb1`
obsoleto — enmascarando justo lo que queremos ver.

## Cómo leerla

```bash
ssh ceres "cat ~/backup_greven/logs/probe-usb1-mount.log"
ssh ceres "grep -E 'Backing up|processed|failed' ~/backup_greven/logs/cron-backup.log | tail -30"
```

Línea **sana** (medida el 2026-08-13 19:16 y el 2026-08-14 02:59, con el backup funcionando):

```
src=/dev/sdb1 ext4   top=17   pcfg-daily=7   vm-containers=4   backup_a=/dev/sdc1
```

Interpretación:

- **Las tres ventanas sanas + backup con datos** → el problema era un estado persistente del
  contenedor, resuelto con el reinicio. Cerrar el diagnóstico, desinstalar la sonda.
- **00:35 roto y 02:10/02:59 sanos** → lo rompe el remontaje y algo lo cura después.
- **00:35 y 02:10 rotos, 02:59 sano** → lo cura el reinicio de `check-ceres-mount-sync` a las
  02:20; el backup andaría por casualidad, no por diseño.
- **Las tres rotas + snapshots en 0 B** → reproducción limpia del fallo original. Ahí la causa
  es el ciclo de mount y corresponde el arreglo estructural (NFS o 9p en vez del bind mount
  crudo, ya propuesto y nunca implementado en la investigación de julio).

`top=0` o `pcfg-daily=0` con `src=NOT-A-MOUNTPOINT` es el modo roto.

## Limpieza cuando se cierre

```bash
ssh ceres "crontab -l | grep -v probe-usb1-mount | crontab -"
ssh ceres "rm ~/probe-usb1-mount.sh"
```

El log puede quedar como evidencia. La sonda es temporal y está marcada como tal en su propio
encabezado.

## Nota

El 2026-08-14 se corrió el backup completo a mano (fuera de horario) para poner los 7 tags al
día, así que el repo quedó sano antes de esta primera noche de observación. Si la falla vuelve,
va a notarse como snapshots en 0 B contra una línea base buena — que es exactamente lo que el
monitor semanal debería atrapar cuando se implemente.
