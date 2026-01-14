# Troubleshooting LXC Mount Permissions

## Problem Summary

When binding a mount from the Proxmox host into an LXC container, the mounted directory showed as `nobody:nogroup` with permission denied errors on write operations, despite the mount appearing as read-write (`rw,noatime`).

### Specific Error

```
mkdir /mnt/backup_a/restic-repo: permission denied
```

The directory was mounted at `/mnt/backup_a` inside the container and appeared writable in the mount options, but any attempt to create files or directories resulted in permission denied errors.

---

## Root Cause Analysis

### Container Configuration
- **Container**: Ceres (ID 203)
- **Type**: Unprivileged LXC container (`unprivileged: 1`)
- **User in container**: `rsi` (UID 1000)

### The Core Issue: UID/GID Mapping

Unprivileged LXC containers use UID/GID mapping through `/etc/subuid` and `/etc/subgid` files on the host. This is a fundamental security feature:

- Container UID 1000 (rsi) **does not map directly** to host UID 1000
- Instead, it maps to a different UID on the host, typically starting from 100000 + container_uid
- The mounted directory (`/mnt/backup_a`) was owned by `root:root` (0:0) on the host
- Container's mapped UID couldn't access a root-owned directory, resulting in permission denied

### Why Standard Ownership Changes Didn't Work

1. **`chown 1000:1000 /mnt/backup_a` on host** - Failed because host UID 1000 is not the same as the container's mapped UID
2. **`mkdir` with sudo in container** - Failed because sudo access doesn't resolve the underlying UID mapping issue
3. **`chown -R 1000:1000 /mnt/backup_a/restic-repo` on host** - Failed for the same reason as attempt #1

---

## Failed Attempts

### Attempt 1: Direct Ownership Change

```bash
# On Proxmox host
chown 1000:1000 /mnt/backup_a
```

**Result**: Permission denied when writing from container. Container's mapped UID still couldn't access.

### Attempt 2: Sudo in Container

```bash
# Inside container
sudo mkdir /mnt/backup_a/restic-repo
```

**Result**: Permission denied. Sudo doesn't bypass the UID mapping restriction on the mounted filesystem.

### Attempt 3: Recursive Ownership Change

```bash
# On Proxmox host
chown -R 1000:1000 /mnt/backup_a/restic-repo
```

**Result**: The subdirectory still remained inaccessible due to the same UID mapping issue.

---

## The Solution

### Implementation

On the Proxmox host, make the mount point world-writable:

```bash
chmod 777 /mnt/backup_a
```

This changes the permissions from the original state to:

```
drwxrwxrwx
```

### Why This Works

1. **World-writable permissions (777)** allow any user/UID to read, write, and execute
2. The unprivileged container's mapped UIDs can now write to the directory
3. Despite appearing as `nobody:nogroup` from the container's perspective, files are actually owned by the mapped UID on the host
4. The UID mapping is transparently handled by the kernel

---

## Security Considerations

### When This Solution Is Acceptable

This solution is **appropriate** for `/mnt/backup_a` because:

- It's a **dedicated backup drive** for a single, specific purpose
- The drive is not shared with other containers or services
- It contains only backup-related data
- Access is limited to the Ceres container

### When This Solution Is NOT Recommended

Do **not** use `chmod 777` for:

- Shared directories with sensitive data
- Directories with mixed-purpose usage
- Multi-tenant systems
- Directories that require strict access control

### Recommended Best Practices

For future similar scenarios, consider these alternatives:

1. **Explicit UID Mapping in LXC Config** - Map container UIDs to specific host UIDs
   - More complex but more secure
   - Requires editing LXC container configuration

2. **ACLs (Access Control Lists)** - Use POSIX ACLs for fine-grained permissions
   - More flexible than standard permissions
   - More complex to manage

3. **Container with Different Privileges** - Use a privileged container (not recommended)
   - Security risk
   - Should only be considered for development/testing

---

## Verification

### Test Write Access

After applying `chmod 777`, verify write access from the container:

```bash
# In container
touch /mnt/backup_a/test-write && rm /mnt/backup_a/test-write
```

**Result**: SUCCESS ✓

### Functional Test

The actual use case (restic initialization) now works:

```bash
# In container
restic init -r /mnt/backup_a/restic-repo
```

**Result**: SUCCESS ✓

### All Backup Operations

After the fix, all backup operations function correctly without permission errors.

---

## File Ownership Behavior

It's important to understand what happens after the fix:

### From Container Perspective
- Files created appear as owned by `nobody:nogroup`
- This is the container's view of the mapped UID

### From Host Perspective
- Files are actually owned by the mapped UID (typically `100000+`)
- The mapping is handled transparently by the kernel
- This doesn't pose a security issue for single-purpose backup storage

---

## Summary

| Aspect | Details |
|--------|---------|
| **Problem** | Permission denied on LXC bind mount from unprivileged container |
| **Root Cause** | UID/GID mapping in unprivileged containers prevented access to root-owned directory |
| **Solution** | `chmod 777 /mnt/backup_a` on host |
| **Why It Works** | World-writable permissions allow mapped UIDs to access the mount |
| **Security Impact** | Acceptable for dedicated backup drive; not recommended for shared/sensitive directories |
| **Verification** | Write operations now succeed; restic and backup operations fully functional |

---

## Related Resources

- [LXC Documentation - Unprivileged Containers](https://linuxcontainers.org/lxc/)
- [Linux UID/GID Mapping](https://man7.org/linux/man-pages/man7/user_namespaces.7.html)
- [Proxmox LXC Configuration](https://pve.proxmox.com/wiki/LXC)