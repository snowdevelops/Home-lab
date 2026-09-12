# Homelab

Self-hosted services running on an old desktop.

## Hardware
- 512GB SSD (`sda`) — Debian 13, Docker, service configs
- 1TB HDD (`sdb`) — bulk storage, mounted at `/mnt/storage`
- Reserved IP via DHCP reservation on the router

## Layout
- `/srv/docker/<service>/` — compose files and config (tracked here)
- `/mnt/storage/<service>/` — bulk data (not tracked)

## Services
| Service | Port | Purpose |
|---|---|---|
| AdGuard Home | 8080 | Network-wide DNS ad blocking |
| Jellyfin | 8096 | Media Server |

## Notes
- Docker installed from Docker's official repo, not Debian's
- Fstab uses UUIDs with `nofail` so a dead disk won't block boot
- AdGuard admin moved off port 80 to leave it free for a reverse proxy# Homelab
