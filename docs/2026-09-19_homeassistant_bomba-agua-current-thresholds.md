# Bomba de agua: el TS011F no reporta corriente, y los umbrales de HA reescalados (2026-09-19)

**Status:** active
**Host:** homeassistant, CT206, gr-srv03
**Supersedes:** —
**Superseded-by:** —

**Status detail (es):** aplicado y validado. Falta **una sola medición**: la corriente real de
la bomba nueva con las válvulas cerradas (§7). Hasta tenerla, el umbral de 1.37 A es un
escalado del valor empírico de la bomba anterior, no una medida.

## 1. Contexto

Se reemplazó la bomba elevadora de agua. La nueva consume **1.15 A / 259 W** bombeando; la
anterior consumía **1.3 A**. Las tres automatizaciones de HA que vigilan la bomba estaban
calibradas contra 1.3 A y funcionaban bien detectando **rotor bloqueado** y **cierre del
flotante**.

El flotante es **puramente mecánico**: no corta la bomba, corta el *caudal*. La bomba sigue
girando y HA detecta la condición por el **cambio de corriente**, no por una parada.

Además, `bomba agua z` estuvo **físicamente desconectada desde el 2026-09-09 22:06** y se
re-emparejó manualmente el 2026-09-19 14:44:37, con **NWK nuevo 46746** (antes 43800). Eso
reescribe los recuentos de route errors de la §9 del doc de degradación RF —
ver `2026-08-24_docker03_zigbee-coordinator-rf-degradation.md` §10.

## 2. El hallazgo: el TS011F acepta la configuración de reporting y no la cumple

`database.db` muestra los *attribute reportings* configurados en el clúster de medida
eléctrica (0x0B04) y en el de metering (0x0702):

| Atributo | attrId | Cluster | Min | Max | Reportable change |
|---|---|---|---|---|---|
| `rmsVoltage` | 1285 | 0x0B04 | 5 s | 3600 s | 5 |
| `rmsCurrent` | 1288 | 0x0B04 | 5 s | 3600 s | 50 (= 50 mA, divisor 1000) |
| `activePower` | 1291 | 0x0B04 | 5 s | 3600 s | 10 (W) |
| `currentSummDelivered` | 0 | 0x0702 | 5 s | 3600 s | 257 |

Sobre el papel, un cambio de corriente mayor a 50 mA debería producir un reporte en ≤ 5 s. **No
ocurre.** Esas filas sólo prueban que el dispositivo **respondió** al `configureReporting`, no
que emita reportes — un comportamiento conocido de esta familia de firmware.

### 2.1 La medición que lo demuestra

Ciclo forzado el 2026-09-19 (relé ON 20 s, luego OFF) con el poll todavía en 120 s:

```
15:11:19   0 A     0 W   ON     <- relé ON
15:11:45   1.15 A  259 W ON     <- +26 s, aparece la carga
15:12:53   1.15 A  259 W OFF    <- relé OFF
15:12:53   1.15 A  259 W OFF
15:13:22   1.15 A  259 W OFF
15:13:27   1.15 A  259 W OFF
15:13:45   0 A     0 W   OFF    <- +52 s tras el OFF, recién ahora cae a cero
```

Dos pruebas, ambas concluyentes:

1. **La corriente siguió leyendo 1.15 A durante 52 s después de abrir el relé.** La bomba no
   estaba consumiendo nada; el valor es una caché que el dispositivo republica en cada cambio
   de estado sin refrescarla.
2. **Los dos cambios reales (0 → 1.15 y 1.15 → 0) están exactamente a 120 s** y caen sobre la
   rejilla del poll — los polls en reposo iban a las 14:51:44, 14:53:44, 14:55:44 … 15:05:44,
   todos en el segundo :44–:45. **Ningún cambio vino de un reporte del dispositivo.**

Los publishes intermedios son eventos de cambio de estado y de `onOff` que arrastran el número
cacheado. El mismo patrón apareció durante el re-emparejamiento: nueve lecturas idénticas de
**2.49 A / 500 W** a lo largo de 62 s y a través de un cambio de estado — el usuario ya las
había identificado como lectura mala.

### 2.2 Consecuencia

`measurement_poll_interval` es la **única** vía de actualización de `current` / `power` /
`energy` en este dispositivo. En particular:

- **`-1` congelaría el valor para siempre**, no lo dejaría "sólo un poco desactualizado".
- La latencia de detección es el intervalo de poll, no los 5 s del reporting.
- Durante hasta un intervalo de poll **después de cualquier cambio de estado**, el valor no es
  viejo: es **activamente falso** (corresponde al régimen anterior).

## 3. Cambio aplicado en zigbee2mqtt

`measurement_poll_interval` de `bomba agua z`: **120 → 10 s**. Verificado en vivo, cadencia
exacta de 10 s (15:23:50, 15:24:00, 15:24:10 …). Eso reduce la ventana de valor falso de ~52 s
a ≤ 10 s.

Coste: ~8 640 polls/día en este dispositivo. Su enlace es fuerte (LQI 225-232, directo), así que
el dispositivo lo soporta; lo que hay que vigilar es la carga total de la malla, porque
`luces medianera z` es **el mismo modelo** y sigue reparando ruta en casi cada poll.

## 4. La guardia de obsolescencia en HA

### 4.1 Por qué `last_reported` no sirve aquí

La regla habitual de esta casa es *guardar sobre `last_reported`, no sobre `last_changed`*
(ver `2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md`). **Aquí esa regla no
aplica.** El dispositivo republica el valor cacheado en cada cambio de estado y en cada poll, así
que `last_reported` se actualiza igual cuando el número es falso. HA **no puede distinguir** un
1.15 A recién polleado de un 1.15 A cacheado y republicado: los dos parecen igual de frescos.

El único discriminante fiable es **el tiempo desde que el interruptor cambió de estado**, porque
un valor cacheado sólo puede haberse originado antes de ese cambio.

### 4.2 La condición añadida

```yaml
  conditions:
  - condition: state
    entity_id: switch.bomba_agua_z
    state: 'on'
    for:
      seconds: 10
```

Hace dos cosas: bloquea la ventana posterior al OFF en la que el sensor todavía reporta la
corriente del régimen anterior, y garantiza que al menos un poll fresco haya llegado desde que
arrancó la bomba.

### 4.3 Por qué 10 s y no más — la trampa

Un trigger `numeric_state` dispara **sólo en la transición** de entrada al rango. Si la condición
lo rechaza en ese instante, la automatización **no reintenta**: el valor tendría que salir del
rango y volver a entrar.

Con una guardia más larga que el `for:` del propio trigger, una bomba que arranca **ya
bloqueada** dispara el trigger a t≈10 s, la condición lo rechaza, y después **no vuelve a
dispararse nunca** porque la corriente ya no vuelve a cruzar el umbral. La protección quedaría
anulada justo en el caso que más importa.

10 s es seguro porque un cruce exige un cambio de valor, que exige un poll fresco: el disparo más
temprano posible es ~10 s después del encendido, así que la condición pasa, y aun así la ventana
de valor cacheado queda completamente excluida.

## 5. Umbrales reescalados

Bomba anterior 1.3 A nominal → nueva 1.15 A (factor 0.885). Cada umbral conserva su distancia
proporcional al nominal:

| Automatización | id | Antes | Ratio al nominal | Ahora | Margen vs 1.15 A |
|---|---|---|---|---|---|
| Corriente Alta Crítica (rotor bloqueado) | `1757101174065` | > 2.0 A / 10 s | 1.538 | **1.77 A** | +54 % |
| Válvulas Cerradas | `1757101238903` | > 1.55 A / 20 s | 1.192 | **1.37 A** | +19 % |
| Corriente Anormal Baja (superior) | `1757101279161` | < 1.1 A / 30 s | 0.846 | **0.97 A** | −16 % |
| Corriente Anormal Baja (inferior) | idem | > 0.1 A | — | **0.1 A** sin cambio | — |

El piso de 0.1 A no se escala: es un "¿consume algo en absoluto?", no una fracción del nominal.
Las duraciones `for:` no se tocaron — están calibradas contra la física de la falla, no contra el
nivel de corriente.

Los umbrales estaban **también escritos en el `description` y en el cuerpo del mensaje Pushover**
de cada automatización; se actualizaron los tres para que las alertas no citen números viejos.

## 6. Cómo se aplicó

`/config` no es escribible desde el conector ssh-mcp desde el 09-11
(`2026-09-13_homeassistant_config-write-path-lost.md`), así que:

1. Backup: `automations.yaml.bak-bomba-20260919`, md5 verificado contra el original.
2. Script Python de parcheo transferido por base64 troceado + `zcat`, md5 verificado
   (`06901a3b9c43082e87d4a980129e8539`). El script **valida cada reemplazo antes de escribir** y
   aborta sin tocar el archivo si algo no coincide.
3. Ejecutado dentro del contenedor core:
   `qm guest exec 104 -- /bin/sh -c "/usr/bin/docker exec homeassistant python3 /config/patch_bomba.py"`
   → `OK: patched 3 automations`.
4. `ha core check` → `Command completed successfully.`
5. Scripts temporales borrados. Recarga de YAML hecha por el usuario desde la UI (no hay token de
   API de HA en gr-srv03, así que la recarga sigue siendo acción manual).

UTF-8 preservado (`⚠️`, `ℹ️`, `Válvulas`, `Crítica`) — por eso se usó el `python3` del contenedor
core y no el `awk` de busybox de HAOS.

## 7. Pendiente

**Medir la corriente real con válvulas cerradas en esta bomba.** El 1.37 A es un escalado del
1.55 A empírico de la bomba anterior, no una medida de ésta. Si esta bomba a válvula cerrada se
queda por debajo de 1.37 A, esa automatización **deja de proteger en silencio** — y es la que más
se usa. Lo mismo, con menos urgencia, para el 1.77 A de rotor bloqueado.

Con el poll a 10 s, basta con mirar `sensor.bomba_agua_z_current` durante un cierre real del
flotante.
