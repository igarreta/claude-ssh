# HDMI Audio Fix - living1

**Fecha:** 04/03/2026
**Equipo:** NUC con Linux Mint XFCE (living1)

---

## PROBLEMA

Sin sonido por HDMI hacia el TV (Philips FTV) a pesar de que el video funcionaba correctamente.

**Causa:** PipeWire tenía como salida por defecto el dispositivo S/PDIF (`iec958`) en lugar de HDMI. Además, el sink HDMI estaba silenciado (muted).

```
Destino por defecto: alsa_output.pci-0000_00_1b.0.iec958-stereo  ← incorrecto
```

---

## SOLUCIÓN IMPLEMENTADA

### Fix manual (sesión actual)

```bash
pactl set-default-sink alsa_output.pci-0000_00_03.0.hdmi-stereo
pactl set-sink-mute alsa_output.pci-0000_00_03.0.hdmi-stereo 0
pactl set-sink-volume alsa_output.pci-0000_00_03.0.hdmi-stereo 90%
```

### Fix permanente (autostart)

**Script:** `~/etc/hdmi-audio.sh`
**Autostart:** `~/.config/autostart/hdmi-audio.desktop`

El script corre al iniciar sesión con un delay de 5 segundos para que PipeWire inicialice.

---

## DISPOSITIVOS DE AUDIO

| Sink | Descripción | Estado correcto |
|------|-------------|-----------------|
| `alsa_output.pci-0000_00_1b.0.iec958-stereo` | S/PDIF (no usado) | SUSPENDED |
| `alsa_output.pci-0000_00_03.0.hdmi-stereo` | HDMI → Philips FTV | DEFAULT ✅ |

---

## VERIFICACIÓN

```bash
# Ver sink activo
pactl info | grep "Destino por defecto"

# Verificar no silenciado
pactl list sinks | grep -A5 "hdmi-stereo" | grep -E "Silenciado|Volumen"

# Test de sonido
paplay /usr/share/sounds/freedesktop/stereo/complete.oga
```
