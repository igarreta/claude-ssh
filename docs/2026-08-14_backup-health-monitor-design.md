# Diseño: monitor de salud de backups

**Fecha:** 2026-08-14 · **revisado:** 2026-08-15
**Estado:** implementado (Fases 1, 2 y 3 desplegadas 2026-08-15)
**Motivo:** el incidente de 2026-01-20 → 2026-08-14 (ver `host-backup/README.md` en
`igarreta/proxmox-grsrv03`, sección *Limitaciones conocidas*)

> **Revisión del 2026-08-15.** La versión original ponía toda la verificación en comet, una vez
> por semana. Se movió la verificación de magnitud **adentro del backup de ceres**, con heartbeat
> a Uptime Kuma, y comet quedó como capa posterior. El porqué está en *Arquitectura*; los dos
> errores que corrige están marcados con ⚠ más abajo.

## El modo de falla que hay que atrapar

Durante ~7 meses todos los tags que van de `backup_usb1` a BACKUP_A/B generaron snapshots
**vacíos**. **Ninguna capa reportó un error**: restic salía 0, el script logueaba
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

1. **Verificar el artefacto, no el proceso.** Leer lo que restic *escribió* — el
   `total_bytes_processed` del snapshot — nunca los logs ni el exit code del script. El exit
   code decía 0 mientras el snapshot estaba vacío.
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

**Glacier entra también**, sólo con verificación de frescura y magnitud. Medido el 2026-08-14:
un `restic snapshots` toca `snapshots/` (3.414 bytes), `config/` (155) y `keys/` (445), **todo
en STANDARD**, y tarda 4,5 s. Son ~4 KB por repo por corrida: menos de un centavo de dólar al
año entre egress y requests. Cero acceso a Deep Archive.

> **Restricción dura:** el chequeo de Glacier se limita a `restic snapshots`. Cualquier comando
> que camine el árbol — `ls`, `stats`, `check`, `restore`, `find`, `diff` — dereferencia hacia
> `data/`, que sí está en Deep Archive: tarifas de retrieval (~$0.02/GB) y 12–48 h de espera.
> Se pueden leer metadatos gratis, pero no verificar contenido. Por eso BACKUP_A/B sigue siendo
> la capa que se verifica de verdad.

Línea base de `backup-greven-usb1` (mensual, día 5), útil porque da varianza real y no una sola
muestra: 247,2 / 250,6 / 244,3 / 239,6 / 264,5 / 237,4 GB (marzo a agosto 2026) — una banda de
±6 % con la que calibrar el umbral de deriva. Confirma además que Glacier estuvo sano durante
todo el incidente, es decir que fue realmente la única copia offsite viva.

Fuera de alcance: `restic-wdmycloud` (nunca estuvo afectado).

## Arquitectura

Dos capas con responsabilidades distintas: ceres decide **esta noche**, comet juzga **la
tendencia**.

```
ceres — cada noche, dentro de backup-usb1-local.sh
  └─ por tag: restic backup → leer total_bytes_processed del summary
       ├─ pasa el piso  → forget --prune de ese tag
       └─ no pasa       → NO purgar, marcar el tag como fallado
  └─ al final del todo, un solo ping:
       ├─ todos pasaron → push status=up   a Kuma (contabo2)
       ├─ alguno falló  → push status=down&msg=<motivo>  + Pushover directo
       └─ sin disco     → no pinguea, no alarma

comet — log-monitor, todos los días 08:00
  └─ ssh gr-srv03 → restic snapshots --json -r /mnt/backup_a/restic-repo
       └─ frescura + deriva contra la mediana móvil + Glacier
            └─ hallazgos → Claude narra → email + Pushover
```

### ⚠ Por qué la verificación va adentro de ceres

El diseño original la descartaba así: *"ceres es el sujeto observado… un chequeo adentro habría
leído el mismo bind mount obsoleto y confirmado la mentira."*

**Eso vale para verificar el origen, no el artefacto.** El bind obsoleto hacía que
`/mnt/backup_usb1` se viera vacío; restic entonces escribía honestamente
`total_bytes_processed: 0`. Ese número era *correcto* — el mundo estaba mal, no el registro.
ceres leyendo el summary del snapshot que acaba de escribir habría cazado los 7 meses **la
primera noche**. No hace falta mirar desde afuera para eso.

Lo que gana con el cambio:

- **El prune se puede condicionar en el acto**, que es la razón de fondo. `forget --prune` corre
  a las 03:00, dentro del mismo script y a segundos del backup: **ningún observador externo llega
  a tiempo**, ni siquiera uno diario a las 08:00, porque cuando mira el historial ya se recortó.
  El único punto donde se puede frenar la purga antes de que se ejecute es adentro. Importa
  concretamente por `raspberrypi --keep-last 3`, donde cada noche mala consume un tercio del
  historial bueno (ver más abajo).
- **Latencia.** El veredicto llega la misma noche en vez de a la mañana siguiente. Con la capa de
  comet ya diaria esto pasó a ser un beneficio menor, no el argumento principal.

Lo que **no** se puede hacer adentro y por eso queda en comet:

- **Glacier**, que es otro destino y otra corrida.
- **La deriva contra la mediana móvil**: es un juicio con contexto de semanas, una noche sola no
  lo puede emitir. Los pisos absolutos sí van adentro.
- **El riesgo del juez y la parte.** Es el costo real de esta arquitectura: un mismo script actúa
  y se califica. Se acota poniendo el ping **al final del todo**, después de todos los veredictos
  y nunca al lado del `exit 0`, y dejando a comet como segunda opinión independiente.

**Por qué comet entra por gr-srv03 y no por ceres:** el host es donde el disco está montado de
verdad, e independiente del contenedor.

### Cadencia de la capa de comet: diaria

La versión original corría los sábados, porque ese día siempre hay un disco puesto. Con la
verificación de magnitud ya adentro de ceres, esa restricción dejó de mandar: **corre todos los
días, dentro de la corrida de log-monitor de las 08:00**.

Encaja sin tocar horarios: el disco se monta a las 00:30 y `pre-swap-unmount.sh` lo desmonta a
las 15:00, así que a las 08:00 está siempre montado salvo el día del swap — y ese caso ya está
cubierto por la regla de "sin disco no concluye". Las noches sin disco dejan de necesitar
tratamiento especial por cadencia: pasan a ser un día más sin dato.

Lo que gana siendo diaria: la **frescura** deja de tener hasta 6 días de retraso, que es
justamente el agujero que el heartbeat sólo cubre en grueso (dice "algo no corrió", no "qué
tag"). Y la deriva se evalúa sobre la mediana con un día de resolución en vez de siete.

Requisito para que no se vuelva ruido: un hallazgo que persiste —una deriva que sigue ahí
mañana— **no puede volver a notificar todos los días**. El dedup por fingerprint que log-monitor
ya tiene resuelve esto y hay que usarlo; era irrelevante con cadencia semanal y pasa a ser
condición de diseño con cadencia diaria.

## Heartbeat

Uptime Kuma **de contabo2**, no el de docker03. docker03 es una VM del propio gr-srv03, igual
que comet: un corte de luz los tumba juntos. El de contabo2 está fuera de casa y sobrevive.

Verificado el 2026-08-15 contra el fuente de la versión que corre (`2.4.0`, leída del
`package.json` del contenedor), en `server/routers/api-router.js`:

```
/api/push/<token>?status=down&msg=<texto>
```

- `status` acepta `up` (default) o `down`; cualquier otro valor cuenta como `down`.
- En 2.x la ruta es `router.all`: sirve GET, POST, lo que sea.
- `msg` (default `OK`) **entra en el cuerpo de la notificación**, así que el aviso puede decir
  `vm-images 0 B` en vez de un "monitor is down" genérico.

Los tres estados quedan bien separados:

| Resultado | Acción | Efecto |
|---|---|---|
| Limpio | `status=up` | verde, sin ruido |
| Problema detectado | `status=down&msg=<motivo>` | rojo + notificación esa misma noche |
| No se pudo concluir (sin disco) | **no pinguear** | verde hasta que venza el intervalo |

El tercero es silencio deliberado: *"no pude mirar"* no puede verse igual que *"está todo bien"*.

### ⚠ Retries tiene que ser 0

La versión original decía *"se pinguea sólo si el resultado es limpio"*, porque asumía que el
fracaso no se podía expresar. Sí se puede — pero hay una trampa de configuración que lo
anularía. La cadena es `determineStatus()` → `isImportantForNotification()`, y:

```js
if (previousHeartbeat.status === UP && status === DOWN) {
    if ((maxretries > 0) && (previousHeartbeat.retries < maxretries)) {
        bean.status = PENDING;   // UP → PENDING NO es important: no notifica
```

Con un chequeo que corre una vez por noche, "reintentar" significa esperar a la noche siguiente:
con Retries=1 el aviso llega **24 h tarde**, con Retries=2, 48 h. En este monitor **Retries = 0**.

Otras dos consecuencias del mismo código:

- `DOWN → UP` también es important: cuando la noche siguiente sale limpia, el aviso de
  recuperación llega solo.
- `resendInterval > 0` re-notifica cada N latidos mientras siga en DOWN. Con ping nocturno, `1`
  es un recordatorio por noche hasta que se arregle.

### Intervalo

**~50 h**, no los 9–10 días de la versión original. Con ping nocturno, una noche sin disco (el
día del swap) es normal y no debe alarmar; dos seguidas sí. Si se dejara el intervalo semanal, el
heartbeat no detectaría nada útil.

Ahora su único trabajo es atrapar **"ceres no dijo nada"** — el caso donde ceres no puede avisar
de su propia muerte. Todo lo demás lo dice el `status=down`.

### Por qué el Pushover directo se queda

Un `status=down` que no sale (contabo2 caído, ceres sin internet) se pierde en silencio, y el
fallo recién se vería al vencer el intervalo de 50 h. Por eso el script mantiene **además** su
llamada directa a Pushover: dos caminos independientes para el mismo fallo, uno adentro de casa
y otro afuera. La duplicación de avisos es aceptable; perder el aviso no.

## Reglas de evaluación

Por tag, sobre `total_bytes_processed` del summary del snapshot:

| Regla | Qué atrapa | Dónde |
|---|---|---|
| **Piso absoluto**: ≥ mínimo por tag | El caso de los 7 meses — lo atrapa la primera vez | ceres, nocturno |
| **Frescura**: último snapshot ≤ 8 días | El job dejó de correr | comet |
| **Deriva**: ≥ X% de la mediana móvil | Regresiones parciales tipo `gickup` | comet |

La frescura queda en comet porque es justamente la pregunta que ceres no puede contestar sobre
sí mismo: si el job no corrió, no hay nadie adentro para notarlo. Con cadencia diaria llega como
mucho un día tarde. El heartbeat la cubre en paralelo, con menos resolución (dice "algo no
corrió", no "qué tag").

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
  **tampoco pinguea**.

## ⚠ La retención se condiciona, no se muda

**Hoy:** `backup-usb1-local.sh` corre `restic forget ... --prune` por tag, justo después del
backup de ese tag, todas las noches. Si el backup se rompe, el prune sigue corriendo y va
comiendo el historial bueno.

**La versión original** mudaba la retención a comet: ceres respaldaba y nunca purgaba, y el
sábado comet verificaba y sólo entonces purgaba.

**Nuevo:** el prune se queda donde está y se **condiciona al veredicto de su propio tag**. Un
tag que no pasa el piso, no purga.

Hay que ser honesto sobre el trade-off, porque **las dos opciones protegen el historial**. La
diferencia es otra:

| | Retención en comet (original) | Gating en ceres (elegido) |
|---|---|---|
| Independencia | total: un error en el chequeo de ceres no puede purgar mal | ninguna: ceres juzga su propio trabajo |
| Costo | el repo crece entre corridas; hay que replicar 7 políticas de retención fuera del script que las posee | ninguno, son tres líneas por tag |
| Grupos de `forget` | hay que manejar el agrupamiento por `host,paths` al mover la lógica | no aplica |

Con la capa de comet ya diaria, el costo de la opción original bajó mucho (el repo crecería un
día, no una semana), así que la decisión es más ajustada de lo que parecía. Se elige el gating
en ceres por simplicidad, y el riesgo residual queda **acotado**: si el piso de un tag estuviera
mal calibrado y dejara pasar un snapshot malo, comet lo ve por magnitud a la mañana siguiente,
habiendo perdido a lo sumo una noche de ventana de retención.

Una noche es tolerable incluso en el peor tag. `raspberrypi` usa `--keep-last 3`, y la **imagen**
de la Pi se genera mensualmente mientras el job de restic corre **todas las noches** sobre
`/mnt/backup_usb1/raspberrypi1`, cree o no una imagen nueva: cada noche nace un snapshot, así que
`--keep-last 3` son las últimas **3 noches**, no 3 meses. Perder una de tres deja margen; perder
las tres, no.

Si en la práctica los pisos resultan difíciles de calibrar y hay falsos verdes, la salida es
volver a la opción original — ahora barata, porque comet ya corre todos los días.

## Fase 3 — implementación (2026-08-15)

`log-monitor/backup-health.sh` (repo `igarreta/claude-ssh`), enganchado en `collect.sh` de
gr-srv03 detrás de `BACKUP_HEALTH_CHECK=yes`. Corre desde comet: BACKUP_A/B por SSH al host
gr-srv03 (nunca por ceres), Glacier por SSH a ceres. Umbrales: frescura 8 días (local) / 40
días (Glacier, que corre mensual el día 5). Deriva: mediana móvil de hasta 30 muestras,
sembrada la primera vez con el historial real que restic ya conservaba (`keep-daily 7` da ~7
días de partida, Glacier ~6 meses) — no arrancó en blanco como estaba previsto más abajo. Las
muestras en 0 bytes se excluyen del cálculo de la mediana a propósito: son la contaminación
que dejaron los snapshots vacíos del incidente, todavía dentro de la ventana de retención al
momento de implementar esto, y ningún tag produce legítimamente 0 bytes.

La clave del repo local no vive en gr-srv03 (esa máquina sólo guarda claves de recuperación en
Notion); vive en comet (`~/etc/restic-password-local`, copiada de ceres) y se pasa inline por
SSH en cada corrida.

## Abierto

- Calibrar el % de deriva (hoy 40%, arrancado a ojo) tras unas semanas de datos reales — ya
  hay historial desde el día 1 gracias al backfill, así que esto puede revisarse pronto en vez
  de esperar meses.
- Snapshots sin campo `summary` (restic anterior a 0.17) deben tratarse como **desconocido**,
  nunca como cero: los seis de Glacier lo tienen y ceres corre 0.18.0, pero un snapshot viejo
  sin summary leería 0 y dispararía una falsa alarma.
- ~~Crear el monitor push en el Kuma de contabo2 con Retries=0 y ~50 h de intervalo, y guardar
  el token en ceres.~~ **Hecho 2026-08-15.** Monitor `ceres-backup-health` (id 15) creado
  directo en `kuma.db` (sin API pública para esto en 2.x) — `interval`/`retry_interval`
  180000 s (50h), `maxretries=0`, `resend_interval=1`, notificación Pushover por defecto
  enganchada igual que los otros push monitors. Token en `~/etc/kuma-push.env` en ceres,
  probado end-to-end (`{"ok":true}` + heartbeat registrado). Requirió reiniciar el contenedor
  `uptime-kuma` de contabo2 para que el monitor nuevo quedara con su timer activo — los demás
  monitors de ese Kuma tuvieron un corte de ~10s.
