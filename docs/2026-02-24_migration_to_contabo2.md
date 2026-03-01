# Contabo1 → Contabo2 Migration Plan

## Context for Claude Code

This document was prepared by Claude Desktop after analyzing the source server (contabo1)
and planning the full migration. You have SSH access to the relevant servers.
Execute the plan step by step, verifying each phase before proceeding to the next.

**Deadline: February 27, 2026** Not reachable. Will extend contabo1 subscription for 30 additional days

---

## SSH Access

ssh is managed in comet by using ssh-mcp, which config file is stored in /home/rsi/claude-ssh/.mcp.json
contabo1 and contabo2 should ssh via port 1789

- **contabo1**:  (current server, being decommissioned)
- **contabo2**: 
- **gr-srv03**: Proxmox host, NFS server

All servers are Tailscale nodes. No password SSH auth in contabo1 or contabo2.

---

## Infrastructure Overview

### contabo1 (source — being deleted Feb 27)
- **OS**: Ubuntu (current)
- **User**: rsi (UID 1004 based on NFS dir ownership)
- **Docker containers running**:
  - `api-feriados` — FastAPI app, bind mounts to `~/api_feriados/data/` and `~/api_feriados/logs/`
  - `uptime-kuma` — monitoring dashboard, port 3001, named volume `uptime-kuma-data`
  - `dashy` — homepage dashboard, port 8088
  - `beszel` — server monitoring hub, port 8090, named volume (in docker-contabo1 compose)
  - `beszel-agent` — local agent for beszel
  - `portainer` — Docker management, ports 8000/9443, named volume `portainer_data`
  - `n8n` — workflow automation, port 5678, named volume `n8n_n8n_data`
  - `tailscale` — networking (Docker container)
- **Caddy**: system service, proxies `n8n.igarreta.net` → `localhost:5678`
- **DNS**: `n8n.igarreta.net` points to contabo1 public IP (Namecheap)
- **NFS backup**: mounts `100.89.202.69:/mnt/backup_usb1/contabo1` at `/mnt/backup`

### contabo2 (destination — to be provisioned)
- **OS**: Debian 13 (Trixie)
- **User**: rsi
- **SSH port**: 1789
- **Tailscale**: must be joined before NFS can be configured

### gr-srv03 (NFS server + Proxmox host)
- **Tailscale IP**: 100.89.202.69
- **NFS exports file**: `/etc/exports`
- **Backup USB mount**: `/mnt/backup_usb1/`
- contabo2 directory already created: `/mnt/backup_usb1/contabo2` (chmod 777)
- NFS export for contabo2 needs contabo2's Tailscale IP (placeholder in exports)

---

## Source Server Directory Structure

```
~/
├── api_feriados/          # git repo: git@github.com:igarreta/api_feriados.git
│   ├── data/              # bind mount — MUST COPY (gitignored)
│   └── logs/              # bind mount — MUST COPY (gitignored)
├── bin/                   # git repo (private) — scripts including backup.sh
├── bak/                   # backup logs — copy
├── docker-contabo1/       # git repo (private) — compose files for beszel/dashy/portainer/uptime-kuma
│   ├── beszel/docker-compose.yml
│   ├── dashy/docker-compose.yaml + conf.yml
│   ├── portainer/compose.yaml
│   └── uptime-kuma/compose.yml
├── etc/                   # secrets/config — NOT in git, MUST COPY DIRECTLY
│   ├── anthropic.env
│   ├── api_security.env
│   ├── authorized_keys
│   ├── backup.key         # GPG encryption key for backup.sh
│   ├── backup.sh          # copy of bin/backup.sh
│   ├── crontab            # saved crontab
│   ├── docker-inventory
│   ├── findata/password
│   ├── n8n_encryption_key.json  # CRITICAL — n8n won't start without this
│   ├── n8n.env
│   ├── notion.env
│   ├── pushover.env
│   ├── resend.env         # keep this
│   ├── sendgrid.env       # DEPRECATED — rename to sendgrid.env.deprecated
│   ├── samba/             # old samba credentials, update path for contabo2
│   ├── smtp.env
│   └── tailscale_docker.env
├── findata/               # git repo (private): git@github.com:igarreta/findata.git
│   └── var/               # actual data — MUST COPY (gitignored)
│       ├── findata.csv
│       └── rofex.csv
├── n8n/                   # git repo (private): git@github.com:igarreta/n8n-contabo1.git
│   ├── workflows/         # exported n8n workflows (in git)
│   ├── credentials/       # exported n8n credentials (in git)
│   ├── custom-nodes/
│   └── compose.yaml
├── notion/                # git repo (private): git@github.com:igarreta/notion.git
│   └── compose.yaml
└── temp/, var/, webxprt/, remote/  # likely not needed, verify before ignoring
```

### Docker Named Volumes (require export/import)
| Volume | Service | Priority |
|--------|---------|----------|
| `uptime-kuma-data` | uptime-kuma | HIGH — has all monitors configured |
| `portainer_data` | portainer | MEDIUM |
| `n8n_n8n_data` | n8n | HIGH — but also backed up to ~/n8n/ |
| `api_feriados_tailscale-state` | tailscale | LOW — can regenerate |

### Crontab (from ~/etc/crontab)
```
07 2 * * * ~/bin/backup.sh
15 18 * * 1-5 /home/rsi/findata/.venv/bin/python3 /home/rsi/findata/bin/findata.py cron >> ~/findata/log/findata.log 2>&1
10 8-23/2 * * * /usr/bin/docker compose -f /home/rsi/notion/compose.yaml up >> /home/rsi/notion/log/notion_repeat.log 2>&1
30 3 * * * /home/rsi/n8n/bin/backup.sh >> /home/rsi/n8n/log/backup.log 2>&1
```

---

## Migration Phases

### PHASE 0 — Pre-provisioning (do immediately)

#### On gr-srv03:
```bash
# Directory should already exist, verify:
ls -la /mnt/backup_usb1/contabo2

# If not created yet:
mkdir -p /mnt/backup_usb1/contabo2
chmod 777 /mnt/backup_usb1/contabo2
```

#### On contabo1 — push all repos:
```bash
cd ~/docker-contabo1 && git status && git push
cd ~/bin && git status && git push
cd ~/n8n && git status && git push
cd ~/notion && git status && git push
cd ~/findata && git status && git push
cd ~/api_feriados && git status && git push
```

#### Phase 0 completed on 2026-02-24
---

### PHASE 1 — contabo2 Base Setup (as root)

```bash

# Change hostname

hostnamectl set-hostname contabo2

nano /etc/hosts
# Find the line with the old hostname and replace it:
# 127.0.1.1    contabo2
echo "manage_etc_hosts: false" >> /etc/cloud/cloud.cfg

nano /etc/hosts
# Change:
# 127.0.1.1 vmi3108559.contaboserver.net vmi3108559
# To
# 127.0.1.1 contabo2 contabo2

# Make /etc/hosts immutable
chattr +i /etc/hosts
# to edit later /etc/hosts it should be unlocked first with
# chattr -i /etc/hosts

apt update && apt dist-upgrade -y 
apt autoremove && apt autoclean
apt install -y curl git gnupg2 rsync tmux ufw fail2ban nfs-common python3-pip python3-venv wget mc htop

# Create user
adduser rsi
usermod -aG sudo rsi

# Change user to rsi

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker rsi
docker run hello-world

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# >>> NOTE THE TAILSCALE IP — needed for NFS export on gr-srv03 <<<

# Install Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy
```

#### On gr-srv03:

```
# After getting contabo2 Tailscale IP, add NFS export:
nano /etc/exports 
# add:
# /mnt/backup_usb1/contabo2 100.77.125.40 (rw,sync,no_subtree_check,no_root_squash,nohide)
# Then run:
exportfs -ra
exportfs -v | grep contabo2
```
#### Phase 1 completed on 2026-02-26
---

### PHASE 2 — Security Hardening (as root on contabo2)

```bash
# SSH: change port, disable password auth
sudo sed -i 's/#Port 22/Port 1789/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
# IMPORTANT: verify new SSH connection works before closing current session

# fail2ban
sudo cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
banaction = iptables-multiport

[sshd]
enabled  = true
port     = 1789
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 24h
EOF
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

# UFW — only SSH and web publicly; everything else via Tailscale
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 1789/tcp   # SSH
sudo ufw allow 80/tcp     # Caddy HTTP (ACME + redirect)
sudo ufw allow 443/tcp    # Caddy HTTPS (n8n.igarreta.net)
sudo ufw enable
sudo ufw status
```
#### Phase 2 completed on 2026-02-27
---

### PHASE 3 — SSH and GitHub Setup (as rsi on contabo2)

#### Phase 3 completed on 2026-02-27

```bash
# Add authorized_keys (copy from previous server or paste your public key)
mkdir -p ~/.ssh
nano ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh

# Generate a new SSH key for GitHub (do NOT copy from previous server — use a fresh key per host)
ssh-keygen -t ed25519 -C "ramon.igarreta@gmail.com" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
# >>> Add the printed public key to GitHub: Settings → SSH and GPG keys → New SSH key <<<
# Title: contaboN (use the actual server name)

# Test GitHub connection
ssh -T git@github.com
# Expected: "Hi igarreta! You've successfully authenticated, but GitHub does not provide shell access."

# Git config
git config --global user.name "Ramon Igarreta"
git config --global user.email "ramon.igarreta@gmail.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor nano
```

**Note:** Use SSH keys (not `credential.helper store`) for GitHub auth. Each server gets its own key added to GitHub. This avoids storing plaintext tokens in `~/.git-credentials`.

---

### PHASE 4 — Clone Repositories (as rsi on contabo2)

#### Phase 4 completed on 2026-02-27

```bash
cd ~
git clone git@github.com:igarreta/api_feriados.git
git clone git@github.com:igarreta/n8n-contabo1.git n8n
git clone git@github.com:igarreta/notion.git
git clone git@github.com:igarreta/findata.git
git clone git@github.com:igarreta/docker-contabo1.git
git clone git@github.com:igarreta/bin.git
chmod +x ~/bin/*.sh
mkdir -p ~/bak ~/temp ~/var
chmod +x ~/etc/backup.sh
export PATH="$HOME/bin:$PATH"
grep -qxF "source ~/bin/bashrc.sh" ~/.bashrc || echo "source ~/bin/bashrc.sh" >> ~/.bashrc

```

---

### PHASE 5 — Copy Data Files from contabo1 (as rsi on contabo2)

#### Phase 5 completed on 2026-02-27

**Pre-requisite:** Grant contabo2 SSH access to contabo1 so rsync can run directly between them.

```bash
# On contabo2 — get its public key
cat ~/.ssh/id_ed25519.pub

# On contabo1 — append contabo2's public key to authorized_keys
echo "ssh-ed25519 AAAA... contabo2" >> ~/.ssh/authorized_keys

# Back on contabo2 — verify access (port 1789)
ssh -p 1789 rsi@CONTABO1_IP "hostname"
```

```bash
# Run all of the following from contabo2

# ~/etc/ — all secrets and config
rsync -av -e "ssh -p 1789" rsi@CONTABO1_IP:~/etc/ ~/etc/

# Shell config
rsync -av -e "ssh -p 1789" rsi@CONTABO1_IP:~/.bashrc rsi@CONTABO1_IP:~/.gitconfig rsi@CONTABO1_IP:~/.tmux.conf ~/

# Backup logs
rsync -av -e "ssh -p 1789" rsi@CONTABO1_IP:~/bak/ ~/bak/

# Application data (gitignored)
rsync -av -e "ssh -p 1789" rsi@CONTABO1_IP:~/api_feriados/data/ ~/api_feriados/data/
rsync -av -e "ssh -p 1789" rsi@CONTABO1_IP:~/api_feriados/logs/ ~/api_feriados/logs/
rsync -av -e "ssh -p 1789" rsi@CONTABO1_IP:~/findata/var/ ~/findata/var/

# Post-copy cleanup
# Deprecate sendgrid (migrated to resend)
mv ~/etc/sendgrid.env ~/etc/sendgrid.env.deprecated

# Update samba credentials filename
cp ~/etc/samba/backup_usb1_contabo1 ~/etc/samba/backup_usb1_contabo2
# Edit the new file to update any contabo1-specific paths

# Verify
ls ~/etc/
ls ~/api_feriados/data/
ls ~/findata/var/
```

---

### PHASE 6 — NFS Mount Setup (as rsi on contabo2)

#### NFS over Tailscale — MTU Issue                                                                                                                            
                                                                                                                                                                                            
NFS defaults to 1MB block sizes, but WireGuard (used by Tailscale) has a lower MTU (~1420 bytes). This causes NFS operations to silently time out even though the server is reachabl  (ping works, port 2049 open).
Solution: Always mount NFS shares over Tailscale with small block sizes and NFSv3:

  <tailscale-ip>:/path /mnt/mount nfs vers=3,rsize=8192,wsize=8192,nofail,x-systemd.automount,x-systemd.device-timeout=10 0 0

  Key options:
  - vers=3 — avoids NFSv4 session/backchannel complexity
  - rsize=8192,wsize=8192 — keeps packets well below WireGuard's MTU
  - nofail — won't block boot if the remote is unreachable
  - x-systemd.automount — mounts on-demand instead of at boot

```bash
# By this point, gr-srv03 /etc/exports should have contabo2's Tailscale IP
# Verify on gr-srv03 first: exportfs -v | grep contabo2

sudo mkdir -p /mnt/backup

# Add to fstab (gr-srv03 Tailscale IP is 100.89.202.69)
echo "# NFS over Tailscale: vers=3 + small rsize/wsize required due to WireGuard MTU limits" | sudo tee -a /etc/fstab
echo "100.89.202.69:/mnt/backup_usb1/contabo2 /mnt/backup nfs vers=3,rsize=8192,wsize=8192,nofail,x-systemd.automount,x-systemd.device-timeout=10 0 0" | sudo tee -a /etc/fstab

# Fix ownership for rsi user
sudo chown rsi:rsi /mnt/backup 2>/dev/null || true

sudo mount -a
ls /mnt/backup  # should be accessible (empty is fine)


```
#### Phase 5 completed on 2026-03-01
---

### PHASE 7 — Python Environment for findata (as rsi on contabo2)

```bash
cd ~/findata
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate

# Test
~/findata/.venv/bin/python3 --version
```

---

### PHASE 8 — Caddy Setup (as rsi on contabo2)

```bash
sudo tee /etc/caddy/Caddyfile << 'EOF'
# n8n Webhook Server
n8n.igarreta.net {                                                                                                                                                                        
    reverse_proxy localhost:5678
}                                                                                                                                                                                         
EOF

# Check there are no spaces before or after EOF

sudo systemctl enable caddy

# Don't start yet — wait until DNS is updated and n8n is running
```
#### Phase 8 completed on 2026-03-01

---

### PHASE 9 — Start Docker Services (as rsi on contabo2)

#### Phase 9 completed on 2026-03-01

Notes:
- `monitoring` docker network must be created manually before starting services: `docker network create monitoring`
- notion submodule `mylogger` must be initialized: `git config submodule.mylogger.url git@github.com:igarreta/mylogger.git && git submodule update --init`
- `~/notion/log/` directory must exist before starting notion_repeat
- uptime-kuma compose was updated to use `monitoring` network as `external: true` (committed to docker-contabo1 repo)
- api_feriados Tailscale auth key must be regenerated (old key from contabo1 is single-use); old node must be removed from Tailscale admin before registering new one

Start in this order, verify each before proceeding:

```bash
# api_feriados
cd ~/api_feriados
docker compose up -d
docker ps | grep api-feriados

# notion
cd ~/notion
docker compose up -d
docker ps | grep notion

# portainer
cd ~/docker-contabo1/portainer
docker compose up -d
docker ps | grep portainer

# beszel
cd ~/docker-contabo1/beszel
docker compose up -d
docker ps | grep beszel

# dashy
cd ~/docker-contabo1/dashy
docker compose up -d
docker ps | grep dashy

# uptime-kuma (start now, will restore volume data in Phase 10)
cd ~/docker-contabo1/uptime-kuma
docker compose up -d
docker ps | grep uptime-kuma

# n8n (start now, volume restore in Phase 10)
cd ~/n8n
docker compose up -d
docker ps | grep n8n
```

---

### PHASE 10 — Cutover Day: Volume Export/Import

**This phase stops contabo1 services. Do it on Feb 27.**

#### Step 1: Export volumes on contabo1
```bash
# Stop containers for clean export
docker stop uptime-kuma beszel portainer n8n

# Export volumes
mkdir -p ~/bak
for vol in uptime-kuma-data portainer_data n8n_n8n_data; do
  echo "Exporting $vol..."
  docker run --rm \
    -v ${vol}:/data \
    -v /home/rsi/bak:/backup \
    alpine tar czf /backup/${vol}.tar.gz -C /data .
  echo "Done: $vol → ~/bak/${vol}.tar.gz"
done
ls -lh ~/bak/*.tar.gz
```

#### Step 2: Copy volumes to contabo2
```bash
# Run from contabo2
rsync -av -e "ssh" rsi@contabo1:~/bak/*.tar.gz ~/bak/
ls -lh ~/bak/*.tar.gz
```

#### Step 3: Stop and restore volumes on contabo2
```bash
# Stop affected containers
docker stop uptime-kuma portainer n8n 2>/dev/null

# Restore volumes
for vol in uptime-kuma-data portainer_data n8n_n8n_data; do
  echo "Restoring $vol..."
  docker volume create $vol 2>/dev/null || true
  docker run --rm \
    -v ${vol}:/data \
    -v /home/rsi/bak:/backup \
    alpine sh -c "cd /data && tar xzf /backup/${vol}.tar.gz"
  echo "Done: $vol"
done

# Restart services
cd ~/docker-contabo1/uptime-kuma && docker compose up -d
cd ~/docker-contabo1/portainer && docker compose up -d
cd ~/n8n && docker compose up -d

# Verify all running
docker ps
```

---

### PHASE 11 — n8n Workflow Verification

```bash
# Check n8n is accessible on Tailscale
curl -s http://contabo2-tailscale-ip:5678 | head -5

# Verify workflows loaded (from volume restore)
# Access n8n UI at http://contabo2-tailscale-ip:5678
# Check: 3 workflows present, 4 credentials present

# If workflows missing, import manually:
docker exec -it n8n n8n import:workflow --separate --input=/home/node/.n8n/workflows
docker exec -it n8n n8n import:credentials --separate --input=/home/node/.n8n/credentials
```

---

### PHASE 12 — Crontab Setup (as rsi on contabo2)

```bash
# Review saved crontab
cat ~/etc/crontab

# Install (paths should be identical since same username/homedir structure)
crontab -e
# Paste:
# 07 2 * * * ~/bin/backup.sh
# 15 18 * * 1-5 /home/rsi/findata/.venv/bin/python3 /home/rsi/findata/bin/findata.py cron >> ~/findata/log/findata.log 2>&1
# 10 8-23/2 * * * /usr/bin/docker compose -f /home/rsi/notion/compose.yaml up >> /home/rsi/notion/log/notion_repeat.log 2>&1
# 30 3 * * * /home/rsi/n8n/bin/backup.sh >> /home/rsi/n8n/log/backup.log 2>&1

crontab -l  # verify
```

---

### PHASE 13 — DNS Cutover (Namecheap)

**Prerequisites before doing this:**
- contabo2 public IP obtained
- All Docker services running and verified on contabo2
- Caddy configured but not yet started

```bash
# 1. Start Caddy FIRST (must be running before DNS propagates for cert provisioning)
systemctl start caddy
systemctl status caddy

# 2. Get contabo2 public IP
curl -4 ifconfig.me
```

Then in Namecheap DNS for `igarreta.net`:
- Update A record: `n8n` → contabo2 public IP
- Set TTL to minimum (5 min) for fast propagation

```bash
# Monitor propagation
watch -n 30 'dig n8n.igarreta.net +short'

# Test once propagated
curl -I https://n8n.igarreta.net
```

---

### PHASE 14 — Update Dependent Services

#### uptime-kuma
Access uptime-kuma UI and update any monitors that reference:
- contabo1's IP or hostname → update to contabo2
- Verify all monitors are green

#### beszel
If other servers (gr-srv03, living1, etc.) run beszel-agent pointing to contabo1's beszel hub:
- Update hub URL in each agent's config to contabo2's Tailscale IP
- Restart agents

#### gr-srv03
```bash
# Remove or comment the old contabo1 NFS export if desired (after confirming contabo2 works)
# In /etc/exports, the contabo1 line can stay until server is confirmed deleted
```

#### Other servers calling api-feriados
```bash
# Search for any references to contabo1 in other server configs
grep -r "contabo1" /etc/ /home/ 2>/dev/null
# Update any found references to contabo2
```

---

### PHASE 15 — Final Validation

```bash
# On contabo2 — full verification
docker ps  # all containers running

# Test backup manually
~/bin/backup.sh
ls /mnt/backup/  # should show new timestamped backup directory

# Test n8n
curl -s http://localhost:5678 | head -3

# Test api_feriados
curl -s http://localhost:8000/health  # adjust endpoint as needed

# Test Caddy/SSL
curl -I https://n8n.igarreta.net

# Check logs for errors
docker logs n8n --tail 20
docker logs uptime-kuma --tail 20

# Verify fail2ban
fail2ban-client status sshd

# Verify crontab
crontab -l
```

---

## Key Configuration Details

### n8n compose.yaml (~/n8n/compose.yaml)
```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    env_file:
      - ~/etc/n8n.env
    volumes:
      - n8n_data:/home/node/.n8n
      - ./custom-nodes:/home/node/.n8n/custom
      - ./workflows:/home/node/.n8n/workflows
    networks:
      - n8n_network
volumes:
  n8n_data:
    driver: local
networks:
  n8n_network:
    driver: bridge
```

### Caddyfile (/etc/caddy/Caddyfile)
```
# n8n Webhook Server
n8n.igarreta.net {
    reverse_proxy localhost:5678
}
```

### NFS fstab entry for contabo2
```
100.89.202.69:/mnt/backup_usb1/contabo2 /mnt/backup nfs defaults,nofail,x-systemd.automount,x-systemd.device-timeout=10 0 0
```

### gr-srv03 NFS export to add
```
/mnt/backup_usb1/contabo2 CONTABO2_TAILSCALE_IP(rw,sync,no_subtree_check,no_root_squash,nohide)
```

### Pushover notifications
All scripts use `~/etc/pushover.env` with format:
```
PUSHOVER_TOKEN="<token>"
PUSHOVER_USER="<user>"
DEFAULT_DEVICE=iphoneRSI
```
All notifications include hostname and script name.

### Email (resend, not sendgrid)
Use `~/etc/resend.env`. The `sendgrid.env` should be renamed to `.deprecated`.
See resend configuration: `pip install resend`, use `RESEND_API_KEY` env var.

---

## Things to Watch Out For

1. **n8n encryption key**: `~/etc/n8n_encryption_key.json` MUST be present before n8n starts or credentials will be unreadable.

2. **NFS before backup cron**: The backup cron runs at 2:07am. Make sure NFS is mounted and working before that runs on contabo2.

3. **Caddy cert timing**: Start Caddy BEFORE updating DNS. Caddy needs to be listening on 80/443 when the first request hits after DNS propagation, or Let's Encrypt cert provisioning will fail.

4. **uptime-kuma data**: This volume has the most unique data (all monitor configurations). The volume export/import is the only way to preserve it. Verify it restored correctly before decommissioning contabo1.

5. **findata cron**: Runs weekdays at 6:15pm. Writes to `~/findata/var/`. Make sure the var directory exists and is writable.

6. **notion cron**: Runs every 2 hours. This is a Notion task rescheduler. Low risk if it misses a few runs during migration.

7. **sendgrid → resend**: Any service that used sendgrid.env needs to be updated to use resend.env. Check n8n workflows and any Python scripts for sendgrid references.

8. **Docker group**: rsi must be in the docker group (`usermod -aG docker rsi`) and must log out/in for it to take effect. Use `newgrp docker` or start a new session.