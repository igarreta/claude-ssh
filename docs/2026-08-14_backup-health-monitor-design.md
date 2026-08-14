# Diseño: monitor de salud de backups

**Fecha:** 2026-08-14
**Estado:** diseño acordado, sin implementar
**Motivo:** el incidente de 2026-01-20 → 2026-08-14 (ver `host-backup/README.md` en
`igarreta/proxmox-grsrv03`, sección *Limitaciones conocidas*)

## El modo de falla que hay que atrapar

Durante ~7 meses todos los tags que van de `backup_usb1` a BACKUP_A/B generaron snapshots
vacíos. **Ninguna capa reportó un error**: restic salía 0, el script logueaba
"completed successfully", Pushover no tenía qué disparar, y log-monitor no veía nada porque
el journal estaba limpio. El `SUPPRESS_PATTERN` de `gr-srv03.conf` además silencia a
propósito todo lo que mencione `BACKUP_A|backup_a|BACKUP_B|...`.

Consecuencia de diseño: **cualquier servicio construido sobre detectar errores es
estructuralmente incapaz de atrapar esto.** Hay que verificar resultados, y hay que tratar
el silencio como falla.

El daño real no fue tardar en enterarse, fue que la **retención borró el historial bueno**:
los snapshots vacíos seguían llegando y desplazando a los reales. Cuando se detectó, los 12
snapshots retenidos de `proxmox-config` estaban todos vacíos.

## Principios

1. **Verificar el artefacto, no el proceso.** Leer el repo restic (el destino), nunca los
   logs ni el exit code de ceres. El exit code decía 0 mientras el snapshot estaba vacío.
2. **Afirmar magnitud esperada, no presencia.** Un chequeo de "¿hay snapshot de hoy?" habría
   dado verde los 7 meses.
3. **El silencio alarma.** Siete meses de nada fueron indistinguibles de salud.
4. **Detección y preservación son independientes.** Que una falla no pueda destruir historial
   mientras nadie mira.

## Alcance

Sólo el repo **BACKUP_A/B** (`$BACKUP_MOUNT/restic-repo`).

La política es: cada servicio deposita en `backup_usb1` → ceres copia a BACKUP_A/B → Glacier
como terciario. Como todo fluye por ese embudo, BACKUP_A/B es un **único punto de observación
que cubre la cadena entera**: si un host deja de depositar, su tag se estanca o encoge ahí.

No distingue "el host dejó de mandar" de "ceres dejó de copiar", pero entrega el hecho
accionable: *estos datos no están protegidos*.

Fuera de alcance por ahora: Glacier (terciario; `restic snapshots` es instantáneo porque los
metadatos están en STANDARD, así que agregar una verificación de frescura es barato si más
adelante se quiere) y `restic-wdmycloud` (nunca estuvo afectado).

## Arquitectura

Módulo dentro de `log-monitor/`, reusando `run.sh`, `lib/notify.sh`, el dedup por fingerprint,
el archive y la retención de reportes.

```
comet — sábado a la mañana (ventana 00:30–15:00, disco montado)
  └─ ssh gr-srv03 → restic snapshots --json -r /mnt/backup_a/restic-repo
       └─ evaluar en comet (aritmética pura, sin LLM)
            ├─ limpio    → push a Uptime Kuma (contabo2) → verde
            ├─ hallazgos → Claude narra → email + Pushover
            └─ sin disco → no pinguea, no alarma (ver más abajo)
```

**Por qué comet y no ceres:** ceres es el sujeto observado, y fue además la máquina cuya
visión del mundo estaba equivocada — un chequeo adentro habría leído el mismo bind mount
obsoleto y confirmado la mentira. Si ceres se cae, el chequeo se cae con él.

**Por qué se entra por gr-srv03 y no por ceres:** el host es donde el disco está montado de
verdad, e independiente del contenedor.

**Cadencia sábado:** ese día uno de los dos discos está siempre puesto. El disco se monta a
las 00:30 y `pre-swap-unmount.sh` lo desmonta a las 15:00, así que la corrida va a la mañana.

## Heartbeat

Uptime Kuma **de contabo2**, no el de docker03. docker03 es una VM del propio gr-srv03, igual
que comet: un corte de luz los tumba juntos. El de contabo2 está fuera de casa y sobrevive.

Regla clave: **se pinguea sólo si el resultado es limpio**, no si el script corrió. Si no, un
chequeo que corre y encuentra problemas dejaría Kuma en verde. Quedan separadas las dos
preguntas:

- *¿hay problemas?* → Pushover
- *¿alguien está mirando?* → Uptime Kuma

Intervalo esperado en Kuma: **9–10 días**, no 7. Así una semana en que legítimamente no haya
disco (swap prolongado) no dispara falsa alarma, pero dos seguidas sí.

## Reglas de evaluación

Por tag, sobre `total_bytes_processed` del summary del snapshot:

| Regla | Qué atrapa |
|---|---|
| **Frescura**: último snapshot ≤ 8 días | El job dejó de correr |
| **Piso absoluto**: ≥ mínimo por tag | El caso de los 7 meses — lo atrapa la primera vez |
| **Deriva**: ≥ X% de la mediana móvil | Regresiones parciales tipo `gickup` |

Línea base medida el 2026-08-14 (primera corrida sana en 7 meses), para calibrar los pisos:

| Tag | Tamaño |
|---|---|
| `vm-images` | 173.003 GiB |
| `raspberrypi` | 28.113 GiB |
| `homeassistant` | 12.943 GiB |
| `containers` | 5.804 GiB |
| `gickup` | 303.338 MiB (parcial esperado) |
| `proxmox-config` | 1.341 MiB |
| `castor-pg` | 1.191 MiB |

## Falsos positivos a evitar

Esto define si el servicio se gana la confianza o se vuelve ruido ignorable.

- **Rotación de discos.** Que ninguno esté montado es normal hasta ~48 h. `lib-disk.sh` en
  ceres ya tiene la lógica de gracia; replicarla, no reinventarla. Verificado en vivo el
  2026-08-14: sale limpio y en silencio.
- **Dedup de restic.** `Added to the repository` es ~0 B en noches sin cambios. Un monitor
  sobre bytes agregados alarmaría *todas las noches*. Usar siempre `total_bytes_processed`.
- **`gickup` es parcial a propósito** desde 2026-08-14 (`8aeb691`): su piso va calibrado
  bajo el tamaño parcial, no el completo.
- **Sin disco ≠ sano.** Si no hay disco, el chequeo no puede concluir: no alarma, pero
  **tampoco pinguea** — si no, "no pude mirar" se vería igual que "está todo bien".

## Cambio estructural: la retención pasa a comet

El cambio más importante, y el que hace que detección y preservación sean independientes.

**Hoy:** `backup-usb1-local.sh` corre `restic forget ... --prune` después de cada job, todas
las noches. Si el backup se rompe, el prune sigue corriendo y va comiendo el historial bueno.

**Nuevo:** ceres respalda y **nunca purga**. comet, el sábado, primero verifica y *sólo si los
snapshots son sanos* corre la retención. La purga se vuelve una operación supervisada: si el
backup se rompe, el historial simplemente no se toca hasta que alguien lo mire.

Motivación concreta — el tag más frágil es `raspberrypi`, con `--keep-last 3`. La **imagen**
de la Pi se genera mensualmente, pero el job de restic corre **todas las noches** sobre
`/mnt/backup_usb1/raspberrypi1`, cree o no una imagen nueva; cada noche nace un snapshot. Así
que `--keep-last 3` son las últimas **3 noches**, no 3 meses: tres noches malas seguidas y los
28 GiB reales quedan fuera de la ventana.

Costo aceptado: el repo crece entre sábados. Con dedup, el delta semanal es chico.

Nota de implementación: `restic forget` agrupa por `host,paths` por omisión, así que un cambio
en las rutas de un job (como cuando se agregó `raspberrypi2z`) crea un grupo nuevo con su
propia cuenta de retención. Tenerlo en cuenta al mover la lógica.

## Abierto

- Calibrar los umbrales de deriva (el % y la ventana de la mediana).
- Definir si la retención en comet corre sobre todos los tags o sólo los que pasaron su
  verificación individual.
- Glacier queda sin monitorear.
