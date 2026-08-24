# Sonda abierta: snapshots vacíos de ceres → BACKUP_A/B

**Status:** open
**Host:** ceres, gr-srv03
**Supersedes:** —
**Superseded-by:** —

**Fecha:** 2026-08-14
**Status detail (es):** diagnóstico ABIERTO. Primera lectura el 2026-08-15 (ver abajo); la sonda queda
puesta hasta la noche del 2026-08-17.
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

Línea **sana** (formato desde el 2026-08-15, con BACKUP_A conectado y B afuera):

```
src=/dev/sdb1 ext4   top=17   pcfg-daily=7   vm-containers=4   backup_a=/dev/sdc1(3)   backup_b=/dev/mapper/pve-root[/mnt/backup_b](0)
```

Los destinos se reportan como `SOURCE(N)`, con N = entradas que ve el contenedor. Hacen falta
las dos mitades: `check-ceres-mount-sync` considera obsoleto un disco que **es** mountpoint pero
está **vacío**, así que un dispositivo con `(0)` es el estado roto, no el sano. Un source
`pve-root[...]` significa que el bind está dejando ver el directorio placeholder vacío del host
— el disco real no está. Es lo esperable para el disco que está afuera.

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

## Primera lectura: noche del 2026-08-15

Salió el **escenario 3** de la tabla de arriba, y con la cadena completa confirmada del lado
del host.

```
00:35  src=/dev/sdb1  top=17  pcfg-daily=7  vm-containers=4  backup_a=-
02:10  src=/dev/sdb1  top=17  pcfg-daily=7  vm-containers=4  backup_a=-
02:59  src=/dev/sdb1  top=17  pcfg-daily=7  vm-containers=4  backup_a=/dev/sdc1
```

Lo que muestra el journal de gr-srv03 y `/var/log/proxmox-backup.log`:

1. **00:30** el host monta BACKUP_A (sdc1) sin errores.
2. Ceres **no lo ve**: el remontaje del host no propaga al LXC. Es el mismo mecanismo de
   `docs/memory_gr-srv03_stale-mount-investigation.md`.
3. **02:20** `check-ceres-mount-sync.sh` detecta *"backup_a: mounted on host but stale/empty in
   ceres"*, remonta en el host y hace `pct reboot 203`. `uptime -s` en ceres = 02:20:10.
4. **02:59** sano, y el backup de las 03:00 corre con los 7 tags llenos.

O sea: el backup de anoche anduvo **porque la red de seguridad lo salvó**, no porque el montaje
funcione. Y no es esporádico — el mismo self-healing aparece el 12-08, el 13-08 y el 15-08. El
14-08 figura "in sync" porque venía del reinicio manual.

### Lo que esto NO explica

El origen (`/mnt/backup_usb1`, sdb1) estuvo **sano en las tres ventanas**: `top=17`,
`pcfg-daily=7`. Lo que se cae es el *destino* (backup_a), no el origen.

Pero los snapshots vacíos de 7 meses eran del **origen** — `/mnt/backup_usb1/gickup` en 0 B. Y
el 13-08 hubo reinicio a las 02:20 y aun así el snapshot de las 03:00 quedó en 0 B. **El
reinicio no explica la causa de los snapshots vacíos.** Sigue sin probarse, y por eso la sonda
se queda dos noches más: lo único que cerraría el caso es ver el origen caído alguna vez.

### El bind obsoleto es de BACKUP_A, no del ciclo de montaje

Contando los veredictos de `check-ceres-mount-sync` en `/var/log/proxmox-backup.log` desde el
2026-07-17:

| Disco | Noches montado | Obsoleto en ceres |
|---|---|---|
| BACKUP_A | 17 (22-07→03-08, 12-08, 13-08, 14-08, 15-08) | **16** |
| BACKUP_B | 10 (17-07→20-07, 05-08→10-08) | **0** |

B pasa por el mismo desmontaje de las 15:00 y el mismo remontaje de las 00:30 todas las noches
y nunca se cae. A se cae siempre, con una sola excepción (14-08). O sea que el bind obsoleto
**no es del ciclo de montaje en sí**, es algo propio de BACKUP_A.

Consecuencia práctica: el disco se cambia el lunes 17-08 a la noche, y a partir de ahí el
síntoma va a desaparecer solo. No sería una mejora — sería BACKUP_B tapándolo hasta la próxima
rotación.

### immich, de paso

La lectura destapó otro fallo de la misma forma: el tag `immich` venía "respaldando" desde el
2025-12-17 un directorio que no existe. La llamada a `restic backup` ya estaba comentada, pero
quedaban el `log_msg "Backing up immich..."` y el `forget --prune`, así que cada noche imprimía
un job que no copiaba nada y reportaba éxito. immich está fuera de uso: el job se eliminó
(`backup_greven` commit 8b094d3). Los dos snapshots de diciembre 2025 quedan en el repo por
ahora.

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
