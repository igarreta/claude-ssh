# Solución WiFi - Linux Mint en Hospital Alemán

**Fecha:** 13 de diciembre de 2025
**Equipo:** NUC con Linux Mint XFCE, Kernel 6.14.0-36-generic

---

## PROBLEMA

**Tarjeta WiFi interna incompatible con red del hospital:**
- Realtek RTL8723AE PCIe (Interfaz: wlp2s0)
- Pérdida de paquetes: 25-67%
- Latencia: 250-500ms
- Driver rtl8723ae con bugs conocidos en redes empresariales

**Red del hospital:**
- SSID: INTERNET_HA
- Seguridad: Abierta (portal cautivo)
- Frecuencias: 2.4GHz y 5GHz

---

## SOLUCIÓN IMPLEMENTADA

### Adaptador USB WiFi Externo

**Hardware:**
- Marca: Netmak
- Chipset: Realtek RTL8821CU
- ID USB: 0bda:c811
- Driver: rtw_8821cu (incluido en kernel)
- Interfaz: wlx00e032c0a2d6
- MAC: 00:e0:32:c0:a2:d6
- Estándar: 802.11ac WiFi 5 (dual band)

**Resultados:**
- ✅ 0% pérdida de paquetes
- ✅ Latencia: 13-24ms
- ✅ Plug & play (detección automática)

**Problema conocido (2026-03-01): Fallo de detección USB**
El dongle dejó de ser detectado por el sistema tras varios reboots. `lsusb` no mostraba el dispositivo (0bda:c811) y `iwconfig wlx00e032c0a2d6` devolvía "No such device". Causas posibles:
- Conector USB con desgaste físico / conexión intermitente
- Puerto USB en estado de ahorro de energía
- Hardware del dongle fallando

**Solución:** Desconectar y reconectar el dongle físicamente. Usar iPhone USB tethering como fallback mientras se restablece la conexión. El dongle RTL8821CU es considerado hardware de reemplazo a corto plazo.

---

## CONFIGURACIÓN APLICADA

### 1. Deshabilitación permanente de tarjeta WiFi interna

**Archivo creado:** `/etc/modprobe.d/blacklist-rtl8723ae.conf`

Contenido:
```
blacklist rtl8723ae
```

Aplicar cambios:
```bash
sudo update-initramfs -u
sudo reboot
```

### 2. Conexión al WiFi (automática via NetworkManager)

Si es necesario conectar manualmente:
```bash
nmcli device wifi connect "INTERNET_HA" ifname wlx00e032c0a2d6
```

---

## VERIFICACIÓN DEL SISTEMA

### Ver estado del adaptador USB:
```bash
iwconfig wlx00e032c0a2d6
```

### Test de conectividad:
```bash
ping -c 10 google.com
```
Resultado esperado: 0% pérdida, latencia 13-25ms

### Ver todas las interfaces:
```bash
ip link show
```

---

## REVERTIR A CONFIGURACIÓN ORIGINAL

### Reactivar tarjeta WiFi interna:

```bash
# 1. Eliminar blacklist
sudo rm /etc/modprobe.d/blacklist-rtl8723ae.conf
sudo update-initramfs -u

# 2. Desconectar adaptador USB (físicamente)

# 3. Reiniciar
sudo reboot
```

La interfaz `wlp2s0` volverá a estar disponible (con los problemas de conectividad originales).

---

## USAR AMBAS TARJETAS SIMULTÁNEAMENTE

Para tener disponibles tanto la interna como el USB:

```bash
# 1. Eliminar blacklist
sudo rm /etc/modprobe.d/blacklist-rtl8723ae.conf
sudo update-initramfs -u
sudo reboot

# 2. Mantener USB conectado

# 3. Priorizar USB sobre tarjeta interna (opcional)
nmcli connection modify "INTERNET_HA" ipv4.route-metric 100
```

NetworkManager permitirá elegir cuál usar.

---

## INFORMACIÓN ADICIONAL

### Acceso remoto configurado
- **AnyDesk** instalado (versión 6.3.2-1)
- Inicio automático: Configurado
- Permite acceso remoto desde Windows

### Actualización de firmware pendiente
**Logitech Unifying Receiver:**
```bash
# Ver actualizaciones disponibles
fwupdmgr get-upgrades

# Instalar actualización
sudo fwupdmgr update
```
Duración: 30 segundos | No desconectar durante actualización

---

## COMANDOS ÚTILES

### Diagnóstico WiFi
```bash
# Ver redes disponibles
nmcli device wifi list

# Estado de conexión
iwconfig

# Test pérdida de paquetes
ping -c 20 google.com

# Información adaptadores
lsusb
lshw -C network

# Señal WiFi en tiempo real
watch -n 1 'iwconfig wlx00e032c0a2d6 | grep -E "Quality|Signal"'
```

### Gestión de NetworkManager
```bash
# Listar conexiones
nmcli connection show

# Estado de dispositivos
nmcli device status

# Conectar a red específica
nmcli device wifi connect "SSID" ifname wlx00e032c0a2d6

# Desconectar
nmcli device disconnect wlx00e032c0a2d6
```

### Gestión de módulos
```bash
# Ver módulos cargados
lsmod | grep rtl

# Información del módulo
modinfo rtl8723ae
modinfo rtw_8821cu
```

---

## RECOMENDACIONES FUTURAS

### Adaptadores USB WiFi recomendados:
- Realtek RTL8821CU (actual - fallas de detección USB intermitentes ⚠️)
- MediaTek MT7612U (altamente recomendado)
- Intel AX200/AX210 (máxima compatibilidad)

### Evitar:
- Realtek RTL8723xx (serie problemática)
- Broadcom BCM43xx (soporte limitado en Linux)

### Soluciones alternativas para redes problemáticas:
1. USB tethering desde iPhone (ya configurado, 100% confiable)
2. Adaptador USB WiFi (implementado)
3. Reemplazo de tarjeta interna mini-PCIe (costo ~USD 20-40)

---

**Documento creado:** 13/12/2025
**Sistema operativo:** Linux Mint XFCE
**Kernel:** 6.14.0-36-generic
