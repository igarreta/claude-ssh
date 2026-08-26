# Zigbee: comando perdido en `luces medianera z` — degradación RF del coordinador (2026-08-24)

**Status:** open
**Host:** docker03, gr-srv03
**Supersedes:** —
**Superseded-by:** —

**Status detail (es):** causa raíz identificada con alta confianza. Ubicación final del
dongle fijada el 08-25 (atornillada a la pared, puerto USB dedicado); LQI recuperado y
estable desde entonces. **Decisión sobre el cable apantallado en espera de la revisión del
2026-09-09** (dos semanas) — sin apuro, la compra ya estaba a ~2 meses.

Investigación disparada por un `switch.turn_on` de Home Assistant que nunca llegó al
relé, el 2026-08-22 18:46:11 (hora local, UTC-3).

---

## 1. El incidente

HA publicó `{"state":"ON"}` en `zigbee2mqtt/luces medianera z/set` a las
`2026-08-22T21:46:11.537Z`. El relé nunca conmutó; el sensor de potencia siguió en 0 W
hasta que el usuario lo accionó a mano a las 19:59:32. El `linkquality` del dispositivo
se mantuvo normal (112–140) y siguió reportando cada minuto durante todo el episodio.

Dispositivo: Tongou DIN smart relay `TO-Q-SY1-JZT` (`TS011F` / `_TZ3000_qeuvnohg`),
friendly name `luces medianera z`, IEEE `0x385cfbfffed14d3c`, NWK `25060`.

### Secuencia según los logs de zigbee2mqtt

| Hora local | Evento |
|---|---|
| 18:46:11 | `z2m:mqtt: Received MQTT message on 'zigbee2mqtt/luces medianera z/set' with data 'ON'` |
| 18:46:11 | `ZCL command 0x385cfbfffed14d3c/1 genOnOff.on(...)` |
| 18:46:11 | `~~~> [SENT type=DIRECT apsSequence=226 messageTag=5 status=OK]` — el NCP aceptó el unicast |
| 18:46:11 | `ezspIncomingNetworkStatusHandler: errorCode=ROUTE_ERROR_SOURCE_ROUTE_FAILURE target=25060` |
| 18:46:11 | `ezspIncomingRouteErrorHandler: status=ZIGBEE_SOURCE_ROUTE_FAILURE target=25060` |
| 18:46:21 | `error: z2m: Publish 'set' 'state' to 'luces medianera z' failed: ... timed out after 10000ms` |
| 18:46:39 | `ezspMessageSentHandler: status=ZIGBEE_DELIVERY_FAILED ... clusterId:6, sequence:226, messageTag=5` |

### Conclusiones del incidente

- **MQTT → Z2M funcionó perfectamente.** El comando llegó y se procesó.
- **Z2M → dispositivo falló a nivel malla.** El coordinador reintentó ~28 s por su
  cuenta y terminó en `ZIGBEE_DELIVERY_FAILED` (nunca hubo APS ack).
- **Causa inmediata: source route obsoleta.** `ROUTE_ERROR_SOURCE_ROUTE_FAILURE` llegó
  a los milisegundos del envío.
- **Z2M no reintenta.** Un solo intento de `genOnOff.on` en toda la ventana.
- **Z2M reportó el fallo correctamente** — nunca publicó un estado optimista, el payload
  siguió diciendo `"state":"OFF"`. El `error:` fue a `zigbee2mqtt/bridge/logging`, que
  HA no exponía como entidad → nadie se enteró durante 73 minutos.
- **La dirección dispositivo → coordinador nunca falló**, por eso el `linkquality`
  parecía sano. Sólo se rompió la ruta de salida.

### Ruta del dispositivo

`luces medianera z` (25060) es de **2 saltos**, con un único relay:

```
coordinador (0x1cc089fffedfc56f) → Enchufe_1 (20396, Aqara lumi.plug) → luces medianera z (25060)
```

Las 12 route records de la ventana muestran todas `relayList=20396`. Es un punto único
de fallo, y los `lumi.plug` de Aqara tienen mala reputación como routers Zigbee.

---

## 2. Causa raíz: el ruido de fondo del coordinador subió

El dato decisivo no es de un dispositivo, es de **todos a la vez**. LQI medio diario:

| día | luces medianera z | bomba agua z | Enchufe_1 | Enchufe_2 | temp_living | Portón |
|---|---|---|---|---|---|---|
| 08-17 | 182 | 182 | 182 | 182 | 181 | 184 |
| 08-18 | **200** | **205** | **198** | **199** | **200** | **207** |
| 08-19 | 169 | 178 | 167 | 170 | 169 | 174 |
| 08-20 | 159 | 159 | 159 | 159 | 158 | 162 |
| 08-21 | 148 | 152 | 147 | 149 | 148 | 155 |
| 08-22 | **134** | **136** | **134** | **135** | **136** | **137** |
| 08-23 | 142 | 144 | 142 | 143 | 140 | 145 |
| 08-24 | 163 | 163 | 162 | 162 | 163 | 161 |

Interiores y exteriores, 1 salto y 2 saltos, a red y a pila — todos en bloque, dentro de
±3. **El LQI se mide en el receptor**, así que una caída uniforme de toda la flota
significa que el que perdió sensibilidad es el radio del coordinador, no un enlace.

El incidente cae exactamente en el fondo de la pendiente.

Errores de ruta por día, misma forma: 08-18: 175 · 08-20: 9 · 08-21: 228 ·
**08-22: 825** · 08-23: 0 · 08-24: 22. En seis semanas de log, el **63 %** apunta a
`luces medianera z` — el camino más débil es el primero que se rompe.

### Qué cambió (log del kernel de gr-srv03)

- **2026-08-17 21:11:44** — se retiró el hub USB y el Sonoff Zigbee 3.0 Dongle Plus V2
  quedó **enchufado directo al chasis** (`usb 1-1`), sin cable de extensión, pegado a la
  carcasa metálica del NucBox G5.
- **2026-08-18 19:11 / 19:47** — el HDD Toshiba Canvio **USB 3.0** se conectó a `usb 2-1`,
  el hermano SuperSpeed de ese mismo número de puerto. El Kingston XS1000 (UAS) está en
  `usb 2-2`. Tres puertos, los tres ocupados, todos contiguos.
- **Desde el 08-19** el LQI de la flota cae de forma monótona hasta el piso del 08-22.

La señalización USB 3.0 SuperSpeed irradia ruido de banda ancha centrado en 2,4–2,5 GHz
(documentado por Intel). El canal Zigbee es el **11 = 2405 MHz**. Un receptor de 2,4 GHz
a centímetros de conectores USB3 activos pierde sensibilidad. Esa es exactamente la
geometría que se creó el 17/18 de agosto.

### Descartado

- **No es el enlace USB/serie.** Contadores ASH (`ASH_OVERFLOW/FRAMING/OVERRUN`) en **0**,
  sin resets del NCP ni re-enumeraciones. Es puramente RF — no tiene relación con el
  problema de riel de 5 V por hot-plug de julio
  ([memory_gr-srv03_powered-hub-instability.md](memory_gr-srv03_powered-hub-instability.md)).
- **No es el primer salto.** `MAC_TX_UNICAST_FAILED = 0` mientras
  `APS_DATA_TX_UNICAST_FAILED = 5`: el coordinador siempre entregó al primer salto, la
  pérdida fue aguas abajo.
- **No es MQTT ni el broker.**

### Dos eventos distintos, no uno

El baseline completo (`data/lqi_baseline.csv`) muestra que hubo **dos** degradaciones
con firmas diferentes:

| | 08-02 → 08-12 | 08-19 → 08-22 |
|---|---|---|
| dispositivos a 2 saltos | 205 → ~155-165 | 199 → 134 |
| `bomba agua z` (1 salto, directo) | **se mantuvo en ~190-198** | 205 → **136** |
| interpretación | mesh/entorno, no el coordinador | **coordinador** |

Sólo la segunda es uniforme e incluye al dispositivo directo. Esto refuerza que la
pendiente del 19–22 de agosto es del lado del coordinador, y sugiere que lo del 2 de
agosto fue otra cosa (sin resolver).

### Salvedades honestas

- La caída es **gradual sobre cuatro días**, no un escalón en el instante del cambio
  físico. Es evidencia circunstancial fuerte, no prueba.
- El 08-23 tuvo LQI 142 y **cero** errores de ruta: el piso bajo por sí solo no alcanza,
  hace falta un disparador adicional encima.
- **Alternativa que produciría la misma firma de flota: WiFi.** Zigbee está en el canal 11
  (2405 MHz); los APs visibles desde raspberrypi2z están en WiFi ch 10 (2457) y **ch 3
  (2422)**, cuyo borde inferior queda a sólo ~5 MHz. Una actualización de firmware del
  router, un auto-channel que se mueva al ch 1, o un AP de 40 MHz caerían justo encima.

---

## 3. Acciones aplicadas el 2026-08-24

### Reducción de tráfico — `measurement_poll_interval` 60 s → 120 s

Los dos `TS011F` se pollean por `haElectricalMeasurement.read`
(`tuyaModernExtend.electricityMeasurementPoll`, `defaultIntervalSeconds: 60`), ~2.880
transacciones coordinador→dispositivo por día, cada una reteniendo la cola del
dispositivo hasta 10 s si falla. A las 18:46:16, cinco segundos después del `on` fallido,
ya había otro poll encolado detrás.

Aplicado **en vivo, sin reinicio**, vía la API del bridge:

```bash
docker exec mosquitto mosquitto_pub -h localhost \
  -t 'zigbee2mqtt/bridge/request/device/options' \
  -m '{"id":"0x385cfbfffed14d3c","options":{"measurement_poll_interval":120}}'
```

Respuesta `{"status":"ok", ..., "restart_required":false}`. Se persiste solo en
`configuration.yaml`. Verificado en el log: `09:07:31 → 09:09:31` y `09:07:47 → 09:09:47`.

> No bajar a 300 s: ese sensor de potencia es justamente cómo se detectó que el relé no
> había conmutado.

### Detección — Pushover ante errores de zigbee2mqtt

Nueva automatización en HA (`id: '1787573900000'`, alias `Zigbee2MQTT: error del bridge`)
que dispara con MQTT sobre `zigbee2mqtt/bridge/logging` filtrando `level == error`.

Comprobaciones previas:
- `bridge/logging` publica ~9 msg/min (info/warn/error), **no** es el firehose de debug.
- **Cero** mensajes de nivel `error` en las últimas 22 h → sin riesgo de spam, sin dedupe.
- Mensaje truncado a 700 caracteres (Pushover corta en 1024) y con la convención
  hostname / script.

Probado end-to-end publicando un `level: error` sintético; la notificación llegó.

### Corrección de un fallo silencioso preexistente

`Zigbee: Notificar dispositivo offline` y `... online` tenían una condición
`{{ (now() - states.sensor.zigbee2mqtt_bridge_state.last_changed).total_seconds() > 120 }}`.

**`sensor.zigbee2mqtt_bridge_state` no existe** — ni en el entity registry ni en ningún
YAML. `states.<entidad_inexistente>` es `None`, y `None.last_changed` lanza excepción →
la condición falla → la automatización **nunca se ejecuta**. Último disparo registrado:
**2026-04-30**, casi cuatro meses.

Corregido a la entidad real (`binary_sensor.zigbee2mqtt_bridge_connection_state_2`; la
versión sin sufijo está `disabled_by: device`) y reescrito como **fail-open**, para que
una entidad ausente no vuelva a desactivar la notificación en silencio:

```jinja
{{ true if states.binary_sensor.zigbee2mqtt_bridge_connection_state_2 is none
   else (now() - states.binary_sensor.zigbee2mqtt_bridge_connection_state_2.last_changed).total_seconds() > 120 }}
```

Ambas pasaron a `priority: -1` (antes 0 y -2).

> Pendiente menor: `Monitor Desconexión Zigbee2MQTT Bridge` usa la forma función
> `states('sensor.zigbee2mqtt_bridge_state')`, que devuelve `unknown` en vez de lanzar.
> Esa automatización **sí** funciona, sólo imprime "Connection state: unknown".

### Límite al log de Docker

`daemon.json` no tenía `log-opts`, así que el json-log de zigbee2mqtt creció sin tope
hasta **2,1 GB** desde el 16 de julio (~54 MB/día en debug). Se añadió en `compose.yaml`
un tope de 1 GB (`max-size: 100m`, `max-file: 10`) ≈ 18 días, suficiente para investigar
cualquier incidente.

Los logs de archivo propios de z2m (`data/log/*/log*.log`) sólo retienen ~22 h en debug
(10 MB × 3 rotaciones) y son redundantes con el json-log — **no** se ampliaron.

---

## 4. Pendiente

1. ~~Cable de extensión USB 2.0 apantallado con ferrita (~2 meses).~~ **En espera.** El
   08-25 se fijó una ubicación final con el cable reciclado: dongle atornillado a la pared,
   en un puerto USB dedicado (bus separado del de los discos de backup — `usb 1-3` en bus
   001, los discos están en bus 002). El LQI se recuperó y sostuvo ~220–226 desde entonces
   (§6). Como la mejora vino de la distancia, no del apantallamiento — consistente con lo
   ya previsto acá — **la compra de la ferrita queda en espera de la revisión del
   2026-09-09**; se cancela si dos semanas sin degradación la confirman innecesaria.
2. **Mover el AP de WiFi ch 3 → ch 6 u 11** y fijarlo (desactivar auto-channel, para que
   no se vaya al ch 1). Gratis y descarta la hipótesis alternativa.
   - **No** cambiar el canal Zigbee: los routers suelen seguir el cambio, pero los end
     devices a pila con frecuencia no, y habría que re-emparejar sensores y el Portón.
3. **Reevaluar en unos días** con los datos nuevos, y recién ahí decidir el monitoreo
   permanente de LQI.
4. Bajar `log_level` de `debug` a `info` cuando el LQI se recupere. Debug es lo que hizo
   posible este diagnóstico.

### Criterio de verificación

Tras alejar el dongle, el **LQI medio de la flota debe volver hacia ~200** en un día.
Si no se mueve, la hipótesis USB3 es incorrecta y el culpable es el WiFi.

Referencia para el antes/después:

- [`data/lqi_baseline.csv`](data/lqi_baseline.csv) — LQI medio y mínimo por dispositivo y
  por día, 2026-07-15 → 2026-08-24 (316 filas).
- [`data/routeerr_baseline.csv`](data/routeerr_baseline.csv) — errores de ruta por día y
  por NWK destino (38 filas).

Umbrales sugeridos sobre la media de flota a 24 h: sano 180–205, warning < 160,
alerta < 145.

---

## 5. Acciones aplicadas el 2026-08-25

### Reubicación del dongle (mitigación informal, previa al cable apantallado)

Secuencia física, confirmada por kernel log en gr-srv03 y docker03 (VM 102):

| Hora local | Evento |
|---|---|
| 18:11:58 | Disco BACKUP retirado (`usb 2-1` disconnect) — reduce el ruido USB3 total en el chasis |
| 21:21:06 | Dongle re-conectado con cable corto (reciclado, funda plástica blanca), mismo puerto `usb 1-1` |
| 08-25 06:47:23 | Dongle desconectado para moverlo a una ubicación mejor — **no volvió a enumerar solo** |
| 08-25 ~08:26 | Detectado: `zigbee2mqtt` caído (`Exited (2)`) hace ~1h40, sin dispositivo en `lsusb` ni en host ni en la VM. Outage real, no solo pendiente de medición |
| 08-25 18:13:42 | Reconectado manualmente por el usuario → enumera en `usb 1-3` (puerto físico distinto al `1-1` anterior) → passthrough a docker03 OK → `zigbee2mqtt` up, dispositivos reconectando en <2 min |

Primer LQI post-reconexión: `luces medianera z` = **200**, en línea con el piso sano
(08-18). Una sola muestra, no es tendencia — falta un día completo de datos para
comparar contra la tabla de la sección 2.

> El movimiento del 06:47 dejó el dongle sin enumerar por ~11.5 h hasta la reconexión
> manual a las 18:13 — el primer intento de reubicación no quedó bien asentado.
> Verificar que el conector encastre a fondo en la nueva ubicación.

### WiFi interno de gr-srv03 deshabilitado

La NucBox tiene una tarjeta WiFi PCIe interna (`Realtek RTL8821CE`, `wlp1s0`) configurada
como respaldo de red pero sin uso real (ya estaba `inet manual`, sin `auto`, y el link
en `DOWN`). Es una fuente de RF en 2,4 GHz **dentro del mismo chasis** que el dongle
Zigbee — mismo mecanismo de proximidad que el diagnóstico de la sección 2, pero para un
radio propio en vez de ruido de señalización USB3.

Deshabilitada por completo (no solo link down, sino el driver):

```bash
echo "blacklist rtw88_8821ce" > /etc/modprobe.d/blacklist-wifi.conf
modprobe -r rtw88_8821ce
```

No afecta la conectividad actual (la interfaz no se usaba). Distinto de la hipótesis
alternativa de la sección 2 (AP externo en ch 3/10 visible desde raspberrypi2z) — esa
sigue pendiente (`Pendiente` ítem 2), esto solo descarta el propio equipo como emisor.

Para revertir: `rm /etc/modprobe.d/blacklist-wifi.conf && modprobe rtw88_8821ce`.

### Pendiente de esta ronda

- Confirmar con un día completo de LQI si la reubicación (+ WiFi apagado) mueve la media
  de flota de vuelta a ~180–205.
- Si el dongle vuelve a desconectarse solo en la nueva ubicación, revisar el asentado
  físico del conector antes de sospechar de la ubicación en sí.

---

## 6. Confirmación 2026-08-26: el ajuste de posición del 08-25 21:30 mejoró el LQI

Extraído de `zigbee2mqtt` (`MQTT publish` en `info`, logs `/app/data/log/2026-08-25.18-15-08/{log1,log}.log`),
promedio horario de `linkquality` desde la reconexión del 08-25 18:13 hasta el 08-26 09:00.
Mismo patrón en los 4 dispositivos con reporte frecuente — 1 salto (`bomba agua z`,
`Enchufe_1/2`) y 2 saltos (`luces medianera z`):

| Hora local | `luces medianera z` | `bomba agua z` | `Enchufe_1` | `Enchufe_2` |
|---|---|---|---|---|
| 18:00–20:00 | 189–190 | 187–191 | 188–189 | 186–189 |
| 21:00 | 198 | 198 | 197 | 198 |
| 22:00–03:00 | 220–226 | 220–222 | 220–222 | 220–222 |
| 04:00–08:00 (08-26) | 212–225 | — | — | — |

El salto real ocurre en dos escalones, minuto a minuto sobre `luces medianera z`:
`21:31:09` 188→192, y el salto grande `21:43:26`→`21:45:26` 188→220. Coincide con "ajuste
de posición ~21:30" del usuario — unos 15 min de holgura entre el ajuste y que se estabilice
la nueva ruta/RF es razonable.

**Es fleet-wide, no de un solo dispositivo** — mismo salto simultáneo en 1 salto y 2 saltos
— la misma firma que identificó al coordinador como la fuente en la sección 2, ahora en la
dirección de mejora en vez de degradación. Se mantuvo estable ~220 durante toda la noche y
la mañana siguiente (**+30 sobre el piso del 08-22 = 134, en línea con el piso sano
180–205**).

Errores de ruta en la ventana completa (~15 h): sólo **2**, uno antes del ajuste
(`19:31`, `ROUTE_ERROR_MANY_TO_ONE`, hacia un end device a pila) y uno después (`05:57`,
`ROUTE_ERROR_INDIRECT_TRANSACTION_EXPIRY`, hacia el Portón) — ambos de severidad baja y sin
relación aparente con el ajuste, muy lejos de los 825 del 08-22.

**Conclusión:** el ajuste de posición del 08-25 21:30 mejoró el LQI, no lo empeoró.

### Ubicación final (2026-08-25)

El usuario fijó la ubicación de forma permanente: dongle atornillado a la pared, en un
puerto USB dedicado (no compartido con los discos BACKUP_A/B, que rotan semanalmente).
Cable reciclado, en buen estado visual. Con esto la mayor incertidumbre pendiente —que la
posición fuera accidental y se perdiera en el próximo cambio de disco— queda resuelta: ya
no depende de que nadie mueva nada.

**Próxima revisión: 2026-09-09** (dos semanas). Si el LQI se mantiene ~200+ sin señales de
la degradación gradual de cuatro días vista en agosto, cerrar este documento y cancelar la
compra del cable apantallado (sección 4, ítem 1).

---

## Apéndice: mapeo NWK ↔ dispositivo

| NWK | IEEE | modelo | friendly name |
|---|---|---|---|
| 0 | `0x1cc089fffedfc56f` | Sonoff ZBDongle-E | coordinador |
| 20396 | `0x00158d00039e6c25` | `lumi.plug` | Enchufe_1 (pasillo garage) |
| 25060 | `0x385cfbfffed14d3c` | `TS011F` | **luces medianera z** |
| 43800 | `0x385cfbfffec868fb` | `TS011F` | bomba agua z |
| 54505 | `0x00158d000393603d` | `lumi.plug` | Enchufe_2 |
| 60764 | `0xa4c138bbde82f3e2` | `TS0505B` | luz exterior garage |
| 27260 | `0xa4c138123e89ffff` | `SNZB-04PR2` | Porton levadizo |
