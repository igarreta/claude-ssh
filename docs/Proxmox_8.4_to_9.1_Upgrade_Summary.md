# Proxmox 8.4.14 â†’ 9.1.1 Upgrade Summary
**Date:** November 29-30, 2024  
**System:** GMTec NucBox G5 (N97, 12GB RAM)  
**Result:** âœ… Successful

---

## Current System Status

### Software Versions
- **Proxmox VE:** 9.1.1 (upgraded from 8.4.14)
- **Kernel:** 6.17.2-2-pve (upgraded from 6.14.8-2-bpo12-pve)
- **Kernel Strategy:** Pinned to 6.17.2-2-pve with one-boot testing for future updates

### Repositories Configuration
- **Active:** Proxmox no-subscription repository (Trixie/Debian 13)
- **Disabled:** Enterprise repository (pve-enterprise.sources.disabled)
- **Status:** Clean, no errors, no pending updates

### Hardware Compatibility
- âœ… **USB Drive:** Kingston XS1000 working perfectly on kernel 6.17.2
- âœ… **RTL-433:** Connected and functional
- âœ… **Zigbee Hub:** Connected and functional
- âœ… **All Tailscale nodes:** Operational

### Services Status
- **Running VMs:**
  - 102: docker03 (6GB RAM, 64GB disk)
  - 104: HomeAssistant (4GB RAM, 32GB disk)
  
- **Running Containers:**
  - 101: Samba03 (Turnkey Linux)
  - 103: cloudflare

- **Core Services:** pveproxy, pvedaemon, pve-cluster all running correctly

### Kernel Configuration
- **Available Kernels:**
  - 6.17.2-2-pve (current, pinned)
  - 6.14.11-4-pve (fallback)
  - 6.14.8-2-bpo12-pve (old fallback from Proxmox 8)
  
- **Removed Kernels:** All 6.8.x series (had USB compatibility issues)

---

## Problems Encountered During Upgrade

### Problem 1: Frozen debconf Dialogs
**Symptom:**
- Package configuration dialogs (whiptail) displayed but became unresponsive
- Could not receive keyboard input despite appearing on screen
- Created deadlock: process waiting for input it couldn't receive

**Specific Instances:**
- `libc6` configuration asking about automatic service restarts
- `systemd` configuration asking about journald.conf changes

**Impact:**
- Upgrade process hung waiting for user response
- SSH and network services became unavailable during libc6 restart attempts
- System appeared frozen from remote access

**Root Cause:**
- Interactive debconf frontend spawned dialog on pseudo-terminal (pts/2)
- Dialog process (whiptail) displayed correctly but input handling broke
- Likely related to terminal I/O issues during library upgrades

**Solution Applied:**
1. Identified stuck whiptail process: `ps aux | grep whiptail`
2. Killed only the dialog process: `kill -9 <whiptail_pid>`
3. Apt process continued with default values
4. Alternative: Sent input directly to terminal: `echo "N" > /dev/pts/2`

### Problem 2: Service Disruption During Critical Library Updates
**Symptom:**
- SSH connection lost during upgrade
- Ping stopped responding
- Network became inaccessible

**Cause:**
- `libc6` (core C library) update required restarting system services
- Network services restarted during the upgrade process
- Normal behavior but created access issues

**Impact:**
- Lost primary SSH access during critical upgrade phase
- Could not monitor upgrade progress remotely
- Increased risk if issues occurred

**Mitigation Used:**
- tmux session kept upgrade running despite SSH disconnection
- Proxmox web console provided backup access
- Multiple access methods prevented complete lockout

### Problem 3: Dependency Chain Issues
**Symptom:**
- After main upgrade completed: `libpve-network-api-perl` and `pve-manager` failed to configure
- Error: "dependency problems prevent configuration"
- `pveproxy` service crashing with missing Perl module errors

**Specific Error:**
```
libpve-network-api-perl depends on libpve-network-perl (= 1.2.3); however:
  Version of libpve-network-perl on system is 0.11.2
```

**Cause:**
- Upgrade interrupted by dialog freezes didn't install all required packages
- Package dependency chain broken mid-upgrade
- Some packages unpacked but not configured

**Solution:**
1. Ran `dpkg --configure -a` to configure interrupted packages
2. Ran `apt install libpve-network-perl` to get missing dependency
3. Ran `apt dist-upgrade` again to complete package installations
4. Required 2-3 iterations to resolve all dependencies

### Problem 4: Kernel Boot Selection Issue
**Symptom:**
- Configured one-time boot to kernel 6.14.11-4-pve
- System booted into 6.17.2-2-pve instead

**Cause:**
- Grub selected first available kernel when multiple options present
- One-time boot flag may have been overridden by grub default behavior

**Impact:**
- Minor - system booted into newer kernel than intended
- Actually beneficial as 6.17.2 worked perfectly

**Resolution:**
- Verified 6.17.2-2-pve works with USB drives and all hardware
- Pinned 6.17.2-2-pve as permanent kernel
- Strategy still valid for future kernel testing

### Problem 5: Repository Configuration Issues
**Symptom:**
- Post-upgrade `apt update` showing 401 Unauthorized errors
- Enterprise repository trying to authenticate

**Cause:**
- Enterprise repository file remained active in new DEB822 format
- File: `/etc/apt/sources.list.d/pve-enterprise.sources`
- Old `.list` format was commented but `.sources` was not

**Solution:**
- Renamed file to `.disabled`: `mv pve-enterprise.sources pve-enterprise.sources.disabled`
- Confirmed only no-subscription repository active

---

## Lessons Learned & Best Practices

### Pre-Upgrade Preparation (CRITICAL)

#### 1. Configure Non-Interactive Mode
Prevents frozen dialog issues entirely:
```bash
export DEBIAN_FRONTEND=noninteractive
echo 'libc6 libraries/restart-without-asking boolean true' | debconf-set-selections
```

#### 2. Set Configuration File Handling
Automatically keep current configurations:
```bash
apt-get -o Dpkg::Options::="--force-confold" dist-upgrade
```

#### 3. Multiple Access Methods (ESSENTIAL)
Never rely on single access point:
- âœ… **Primary:** SSH in tmux/screen session
- âœ… **Backup 1:** Proxmox web console (different service)
- âœ… **Backup 2:** Physical console access (even if inconvenient)

**Why this matters:**
- SSH can fail during library updates
- Network services may restart
- Web console runs independently and survived when SSH failed

#### 4. Backup Verification
- Verify backups exist and are current
- Test restore process beforehand if possible
- Document backup locations

#### 5. Pre-flight Checks
```bash
# Check current state
pveversion -v > ~/pre-upgrade-state.txt
dpkg -l | grep proxmox-kernel >> ~/pre-upgrade-state.txt
df -h >> ~/pre-upgrade-state.txt

# Verify no broken packages
dpkg --audit

# Check available disk space (need ~2-3GB for upgrade)
df -h /
```

### During Upgrade Best Practices

#### 1. Use Terminal Multiplexer
**Always use tmux or screen:**
```bash
tmux new -s upgrade
# Then run upgrade commands
apt update
apt dist-upgrade
```

**Why:** Session persists even if SSH connection drops

#### 2. Monitor from Multiple Terminals
```bash
# Terminal 1 (tmux): Run upgrade
apt dist-upgrade

# Terminal 2: Monitor progress
tail -f /var/log/apt/term.log

# Terminal 3: Watch for stuck processes
watch 'ps aux | grep -E "apt|dpkg|debconf|whiptail"'
```

#### 3. Don't Stop VMs/Containers
- VMs and containers run independently
- Stopping them doesn't help the upgrade
- Keep them running unless specific reason to stop
- They'll automatically stop during reboot anyway

#### 4. Handling Frozen Dialogs
**If a dialog freezes:**

1. **Don't panic** - upgrade can recover
2. **Identify the stuck process:**
   ```bash
   ps aux | grep -E "whiptail|dialog"
   ```
3. **Kill ONLY the dialog process:**
   ```bash
   kill -9 <whiptail_pid>
   ```
   **Do NOT kill apt or dpkg!**

4. **Alternative - send input directly:**
   ```bash
   # Find which terminal (pts) the dialog is on
   lsof -p <dpkg_pid> | grep pts
   
   # Send input to that terminal
   echo "N" > /dev/pts/X
   ```

#### 5. Configuration File Prompts
When asked about configuration files:

**Keep your version (N) for:**
- `/etc/network/interfaces` (network config)
- `/etc/systemd/journald.conf` (logging settings you customized)
- `/etc/lvm/lvm.conf` (storage settings)
- Any `/etc/pve/*` files (Proxmox-specific configs)

**Accept new version (Y) for:**
- `/etc/issue` (login banner)
- `/etc/issue.net` (network banner)
- `/etc/motd` (message of the day)
- System files you haven't customized

**When in doubt:** Choose 'N' (keep current) - you can always update later

### Post-Upgrade Steps (REQUIRED)

#### 1. Complete Package Configuration
Always run these after main upgrade completes:
```bash
# Configure any interrupted packages
dpkg --configure -a

# Fix dependency issues
apt --fix-broken install

# Catch remaining updates (may need to run 2-3 times)
apt dist-upgrade

# Clean up old packages
apt autoremove
apt autoclean
```

#### 2. Pre-Reboot Verification
```bash
# Verify version upgraded
pveversion -v

# Check critical services
systemctl status pveproxy pvedaemon pve-cluster

# Check for errors
journalctl -xe | tail -50

# Verify no broken packages
dpkg --audit
```

#### 3. Kernel Management Strategy
**For conservative, safe kernel updates:**

```bash
# After new kernel is installed via apt update
# List available kernels
proxmox-boot-tool kernel list

# Test new kernel with ONE boot only
proxmox-boot-tool kernel pin <new-kernel-version> --next-boot

# Reboot and test
reboot

# After reboot, if everything works:
proxmox-boot-tool kernel pin <new-kernel-version>

# If new kernel fails:
# Just reboot again - automatically falls back to pinned kernel
```

**Current configuration:**
- Pinned: 6.17.2-2-pve (known working)
- Fallback: 6.14.11-4-pve (also tested)
- Old fallback: 6.14.8-2-bpo12-pve (from Proxmox 8)

#### 4. Post-Reboot Verification Checklist
```bash
# Verify kernel version
uname -r

# Check hardware (especially USB drives on N97)
ls -la /dev/disk/by-id/ | grep usb

# Verify VMs and containers
pct list
qm list

# Start stopped services if needed
pct start <VMID>
qm start <VMID>

# Check services
systemctl status pveproxy pvedaemon pve-cluster

# Verify web interface accessible
# Access https://<server-ip>:8006

# Check logs for errors
journalctl -xe | grep -i error
```

#### 5. Repository Cleanup
```bash
# Verify repository configuration
cat /etc/apt/sources.list
ls -la /etc/apt/sources.list.d/

# Disable enterprise repo if not subscribed
mv /etc/apt/sources.list.d/pve-enterprise.sources \
   /etc/apt/sources.list.d/pve-enterprise.sources.disabled

# Test repositories
apt update
# Should complete without 401 errors
```

---

## Hardware-Specific Notes

### N97 Processor (Intel)
- **USB Drive Issues:** Kernels before 6.14 had compatibility problems
- **Working Kernels:** 6.14.8+, 6.14.11, 6.17.2
- **Problematic:** 6.8.12-11 caused USB drive detection failures
- **Solution:** Always test new kernels before permanent pinning

### USB Drive (Kingston XS1000)
- Requires kernel 6.14+ for proper detection
- Failed with kernel 6.8.12-11
- Working perfectly on 6.17.2-2-pve
- Device ID: `usb-Kingston_XS1000_50026B7283888C6D-0:0`

### Network Configuration
- 300 Mbps connection
- Tailscale integration across VMs/containers
- Multiple CIFS mounts from various servers:
  - 192.168.1.7
  - 100.77.7.42
  - 192.168.1.54

---

## Time Expectations

### Upgrade Duration
- **Download phase:** 5-10 minutes (300 Mbps connection)
- **Unpacking/installing:** 10-15 minutes
- **Configuration:** 5-10 minutes
- **Total expected:** 20-35 minutes
- **Actual (with issues):** ~45 minutes due to frozen dialogs

### Factors Affecting Duration
- Internet speed (package downloads)
- Disk I/O speed (SSD vs HDD)
- Number of configuration prompts
- Processor speed (N97 is capable but not high-end)
- Number of packages to upgrade (~600 packages in this upgrade)

---

## Emergency Recovery Procedures

### If SSH Connection Lost During Upgrade

1. **Don't panic** - if you used tmux, upgrade is still running
2. **Access via Proxmox web console:**
   - Navigate to node â†’ Shell
   - Reconnect to tmux: `tmux attach`
3. **Check upgrade status:**
   ```bash
   ps aux | grep apt
   tail -f /var/log/apt/term.log
   ```

### If Upgrade Appears Completely Stuck

1. **Verify processes:**
   ```bash
   ps aux | grep -E "apt|dpkg|debconf"
   ```

2. **Check for frozen dialogs:**
   ```bash
   ps aux | grep -E "whiptail|dialog"
   ```

3. **If found, kill dialog only:**
   ```bash
   kill -9 <whiptail_pid>
   ```

4. **Monitor if upgrade continues:**
   ```bash
   tail -f /var/log/apt/term.log
   ```

### If System Won't Boot After Upgrade

1. **Access grub menu** during boot (hold Shift or press Esc)
2. **Select previous working kernel:**
   - 6.14.8-2-bpo12-pve (known working from Proxmox 8)
   - 6.14.11-4-pve (tested during this upgrade)
3. **After boot, check what went wrong:**
   ```bash
   journalctl -xb
   dmesg | tail -100
   ```
4. **Pin working kernel:**
   ```bash
   proxmox-boot-tool kernel pin <working-kernel>
   ```

### If Packages Are Broken

```bash
# Try to configure interrupted packages
dpkg --configure -a

# Fix broken dependencies
apt --fix-broken install

# Force reconfigure of specific package
dpkg-reconfigure <package-name>

# As last resort, reinstall problematic package
apt install --reinstall <package-name>
```

---

## What Worked Well

âœ… **tmux session:** Kept upgrade running when SSH disconnected  
âœ… **Web console access:** Essential backup when SSH failed  
âœ… **Multiple terminals:** Monitored different aspects simultaneously  
âœ… **Not stopping VMs/containers:** Correct decision, they run independently  
âœ… **Methodical troubleshooting:** Systematic diagnosis before action  
âœ… **Conservative kernel testing:** One-boot strategy prevents boot failures  
âœ… **Documentation:** Taking notes during process helped recovery  

---

## Recommendations Summary

### Must-Do Before Every Major Upgrade
1. âœ… Set `DEBIAN_FRONTEND=noninteractive`
2. âœ… Configure `--force-confold` for apt
3. âœ… Use tmux/screen for upgrade session
4. âœ… Verify multiple access methods available
5. âœ… Confirm current backups exist
6. âœ… Check available disk space

### During Upgrade
1. âœ… Monitor from multiple terminals
2. âœ… Don't stop VMs/containers unnecessarily
3. âœ… Be prepared to kill frozen dialogs
4. âœ… Keep notes of any issues encountered

### After Upgrade
1. âœ… Run `dpkg --configure -a`
2. âœ… Run `apt dist-upgrade` multiple times until clean
3. âœ… Test kernel with one-boot before pinning
4. âœ… Verify all hardware before making kernel permanent
5. âœ… Clean up old kernels after confirming new one works

---

## Future Upgrade Checklist

**Copy this checklist for next upgrade:**

### Pre-Upgrade
- [ ] Verify current backups
- [ ] Check disk space (need 2-3GB free)
- [ ] Document current state (`pveversion -v`)
- [ ] Set non-interactive mode
- [ ] Configure force-confold
- [ ] Start tmux session
- [ ] Verify web console access works
- [ ] Note physical console access method

### During Upgrade
- [ ] Run upgrade in tmux
- [ ] Monitor from second terminal
- [ ] Watch for stuck processes
- [ ] Answer config prompts appropriately
- [ ] Note any errors or unusual behavior

### Post-Upgrade
- [ ] Run `dpkg --configure -a`
- [ ] Run `apt --fix-broken install`
- [ ] Run `apt dist-upgrade` until clean
- [ ] Run `apt autoremove`
- [ ] Verify `pveversion` shows new version
- [ ] Check critical services status
- [ ] Test new kernel with one-boot
- [ ] Verify hardware compatibility
- [ ] Make kernel permanent if working
- [ ] Clean up old kernels
- [ ] Disable enterprise repo if needed
- [ ] Update documentation

---

## Conclusion

The upgrade from Proxmox 8.4.14 to 9.1.1 was ultimately successful despite encountering several common upgrade issues. The key factors in success were:

1. **Preparation:** Multiple access methods prevented complete lockout
2. **Protection:** tmux session survived SSH disconnection
3. **Patience:** Methodical troubleshooting rather than forcing solutions
4. **Persistence:** Running cleanup commands multiple times until resolved
5. **Testing:** Conservative kernel update strategy prevented boot issues

The documented issues and solutions will make future upgrades significantly smoother by implementing preventive measures (non-interactive mode, force-confold) and knowing exactly how to handle frozen dialogs if they occur.

**Current system status:** Fully operational, stable, and ready for production use.

---

## Quick Reference Commands

```bash
# Pre-upgrade setup
export DEBIAN_FRONTEND=noninteractive
echo 'libc6 libraries/restart-without-asking boolean true' | debconf-set-selections
tmux new -s upgrade

# Run upgrade
apt update
apt-get -o Dpkg::Options::="--force-confold" dist-upgrade

# Post-upgrade cleanup
dpkg --configure -a
apt --fix-broken install
apt dist-upgrade
apt autoremove

# Kernel management
proxmox-boot-tool kernel list
proxmox-boot-tool kernel pin <version> --next-boot
proxmox-boot-tool kernel pin <version>  # permanent
proxmox-boot-tool kernel unpin

# Emergency recovery
kill -9 <whiptail_pid>  # Only if dialog frozen
echo "N" > /dev/pts/X   # Send input to stuck terminal
tmux attach             # Reconnect to upgrade session

# Verification
pveversion -v
uname -r
systemctl status pveproxy pvedaemon pve-cluster
apt update && apt list --upgradable
```

---

**Document Version:** 1.0  
**Last Updated:** November 30, 2024  
**Next Upgrade:** Use this document as reference and update with any new findings



 Proxmox 8.4 → 9.1 Upgrade Summary

## What Happened

**Successful upgrade** from Proxmox 8.4.14 to 9.1.1, but encountered interactive dialog freezes during package configuration.

## Problems Encountered

1. **Frozen debconf dialogs**: 
   - `libc6` configuration dialog asking about automatic service restarts became unresponsive
   - Whiptail dialog displayed but stopped reading keyboard input
   - Created a deadlock: process waiting for input it couldn't receive

2. **Service disruption during upgrade**:
   - SSH and ping became unavailable when libc6 tried to restart services
   - System partially hung during critical library updates

3. **Dependency issues after main upgrade**:
   - `libpve-network-api-perl` and `pve-manager` had missing dependencies
   - Required running `apt dist-upgrade` multiple times to resolve

## Solutions Applied

1. **Killed frozen whiptail processes** (`kill -9`) to unblock the upgrade
2. **Used Proxmox web console** as backup when SSH failed
3. **Sent input directly to terminals** using `echo "N" > /dev/pts/2`
4. **Ran `dpkg --configure -a`** to complete interrupted package configurations
5. **Multiple `apt dist-upgrade` runs** to resolve dependency chains

## Recommendations for Next Upgrade

### Pre-Upgrade Preparation

1. **Set non-interactive mode** to avoid dialog prompts:
   ```bash
   export DEBIAN_FRONTEND=noninteractive
   echo 'libc6 libraries/restart-without-asking boolean true' | debconf-set-selections
   ```

2. **Pre-answer common configuration questions**:
   ```bash
   # Keep current config files by default
   apt-get -o Dpkg::Options::="--force-confold" dist-upgrade
   ```

3. **Ensure multiple access methods**:
   - ✅ tmux session (keeps running if SSH drops)
   - ✅ Proxmox web console access
   - ✅ Physical/console access available (even if cumbersome)

4. **Current, tested backups** of all VMs and containers

### During Upgrade

1. **Use tmux or screen** - Your session survived SSH disconnection because of this

2. **Monitor from multiple terminals**:
   ```bash
   # Terminal 1: Run upgrade
   apt dist-upgrade
   
   # Terminal 2: Monitor progress
   tail -f /var/log/apt/term.log
   
   # Terminal 3: Watch for stuck processes
   watch 'ps aux | grep -E "apt|dpkg|debconf"'
   ```

3. **Don't stop VMs/containers** unless necessary - they run independently and stopping doesn't help the upgrade

4. **If dialogs freeze**:
   - Don't panic - the upgrade can recover
   - Find whiptail/dialog processes: `ps aux | grep -E "whiptail|dialog"`
   - Kill only the dialog, not apt/dpkg: `kill -9 <whiptail_pid>`
   - The upgrade will continue with default values

### Post-Upgrade

1. **Always run these commands** after upgrade completes:
   ```bash
   dpkg --configure -a          # Configure any interrupted packages
   apt --fix-broken install     # Fix dependency issues
   apt dist-upgrade             # Catch any remaining updates
   apt autoremove               # Clean up old packages
   ```

2. **Verify before rebooting**:
   ```bash
   pveversion                   # Confirm version upgraded
   systemctl status pveproxy    # Check critical services
   ```

3. **After reboot verification**:
   ```bash
   uname -r                     # Verify new kernel loaded
   ls -la /dev/disk/by-id/      # Check USB drive accessible
   pct list && qm list          # Verify VMs/containers
   ```

## Key Takeaways

✅ **What worked well**:
- Using tmux protected the session when SSH failed
- Having web console access as backup was essential
- Not stopping VMs/containers was the right call
- Your troubleshooting approach was methodical

⚠️ **What would improve next time**:
- Pre-configure non-interactive mode to avoid dialog prompts
- Use `--force-confold` to automatically keep current configs
- Expect the upgrade to take 20-30 minutes with potential interruptions

## Hardware Compatibility Note

Your N97 system required kernel 6.14+ for USB drive compatibility. Proxmox 9.1 has kernel 6.14.11 and 6.17 available, so hardware support is confirmed for future upgrades.