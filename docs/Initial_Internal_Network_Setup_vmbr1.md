# Proxmox Internal Network Setup - vmbr1 Bridge

**Purpose:** One-time setup of internal network for containers/VMs  
**Network:** 10.0.100.0/24  
**Gateway:** 10.0.100.1 (Proxmox host on vmbr1)  
**External Access:** All traffic exits via 192.168.1.3 (vmbr0)

---

## Overview

Creates an isolated internal network that:
- Uses private IP space (10.0.100.0/24)
- Provides internet access via NAT through Proxmox host
- Reduces IP usage on main LAN (192.168.1.x)
- All traffic appears to come from 192.168.1.3 (vmbr0)

**This setup is done ONCE.**

---

## Part 1: Create vmbr1 Bridge (Web Interface)

1. **Open Proxmox Web Interface**
   - Navigate to https://192.168.1.3:8006
   - Login with root credentials

2. **Access Network Configuration**
   - Click your node name (gr-srv03)
   - Click "System" â†’ "Network"

3. **Create New Bridge**
   - Click "Create" â†’ "Linux Bridge"

4. **Configure Bridge**
```
   Name: vmbr1
   IPv4/CIDR: 10.0.100.1/24
   IPv6/CIDR: (leave empty)
   Gateway (IPv4): (leave empty)
   Gateway (IPv6): (leave empty)
   Autostart: âœ“ (checked)
   VLAN aware: â˜ (unchecked)
   Bridge ports: (leave empty)
   Comment: Internal network for containers (NAT to vmbr0)
```

5. **Apply Configuration**
   - Click "Create"
   - Click "Apply Configuration" (orange button at top)
   - Confirm changes

6. **Verify**
   - Bridge vmbr1 should appear with status "Active"
   - CIDR: 10.0.100.1/24

---

## Part 2: Enable NAT and IP Forwarding (CLI)

**Connect via SSH or Proxmox shell:**
```bash
# 1. Enable IP forwarding permanently
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# 2. Enable NAT masquerading
iptables -t nat -A POSTROUTING -s 10.0.100.0/24 -o vmbr0 -j MASQUERADE

# 3. Allow forwarding from internal network
iptables -A FORWARD -s 10.0.100.0/24 -j ACCEPT

# 4. Allow return traffic to internal network
iptables -A FORWARD -d 10.0.100.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT

# 5. Install and save rules
apt install -y iptables-persistent
netfilter-persistent save
```

---

## Part 3: Make Rules Persistent

**Edit network interfaces to add NAT rules:**
```bash
# Backup current config
cp /etc/network/interfaces /etc/network/interfaces.backup-$(date +%Y%m%d)

# Edit the file
nano /etc/network/interfaces
```

**Add post-up/post-down hooks to vmbr1 section:**
```
auto vmbr1
iface vmbr1 inet static
    address 10.0.100.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up   iptables -t nat -A POSTROUTING -s 10.0.100.0/24 -o vmbr0 -j MASQUERADE
    post-up   iptables -A FORWARD -s 10.0.100.0/24 -j ACCEPT
    post-up   iptables -A FORWARD -d 10.0.100.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT
    post-down iptables -t nat -D POSTROUTING -s 10.0.100.0/24 -o vmbr0 -j MASQUERADE
    post-down iptables -D FORWARD -s 10.0.100.0/24 -j ACCEPT
    post-down iptables -D FORWARD -d 10.0.100.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

Save and exit (Ctrl+X, Y, Enter).

```
# Bring up the bridge
ifup vmbr1
```

---

## Verification

### Verify IP Forwarding
```bash
# Should return: 1
cat /proc/sys/net/ipv4/ip_forward
```

### Verify NAT Rules
```bash
# Should show MASQUERADE for 10.0.100.0/24
iptables -t nat -L POSTROUTING -n -v

# Should show ACCEPT for 10.0.100.0/24
	iptables -L FORWARD -n -v | grep 10.0.100
```

### Verify Bridge
```bash
# Should show vmbr1 with IP 10.0.100.1/24
ip addr show vmbr1
```

---

## Test with Temporary Container
```bash
# Create test container
pct create 999 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname test-internal \
  --net0 name=eth0,bridge=vmbr1,ip=10.0.100.99/24,gw=10.0.100.1 \
  --nameserver 8.8.8.8 \
  --memory 512 --cores 1 --rootfs local-lvm:4 \
  --unprivileged 1

# Start container
pct start 999

# Test connectivity
pct exec 999 -- ping -c 3 10.0.100.1      # Gateway
pct exec 999 -- ping -c 3 192.168.1.1     # LAN
pct exec 999 -- ping -c 3 8.8.8.8         # Internet
pct exec 999 -- ping -c 3 google.com      # DNS

# All pings should succeed

# Cleanup
pct stop 999
pct destroy 999
```

---

## IP Address Allocation Plan

| Range | Purpose |
|-------|---------|
| 10.0.100.1 | Gateway (Proxmox host) |
| 10.0.100.10-19 | Critical containers |
| 10.0.100.20-99 | General LXC containers |
| 10.0.100.100-199 | VMs (if needed) |
| 10.0.100.200-254 | Reserved |

**Document assignments in separate file as you create containers.**

---

## Setup Checklist

- [ ] vmbr1 bridge created via web interface
- [ ] IP 10.0.100.1/24 assigned to vmbr1
- [ ] Autostart enabled for vmbr1
- [ ] IP forwarding enabled
- [ ] NAT MASQUERADE rule added
- [ ] FORWARD rules added
- [ ] iptables-persistent installed
- [ ] Rules saved via netfilter-persistent
- [ ] post-up/post-down hooks added to /etc/network/interfaces
- [ ] Test container verified connectivity
- [ ] Test container removed

---

## Next Steps

See: **Container_Internal_Network_Configuration.md** for adding containers to this network.

---

**Setup completed:** _______________