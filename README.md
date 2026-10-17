# Homelab

Self-hosted services running on an old desktop.

## Remote access

Tailscale (installed natively via their install script, not Docker).
Server address: 100.65.193.116, or `homelab` with MagicDNS enabled.
No ports are forwarded on the router â- nothing is exposed to the internet.

State lives in /var/lib/tailscale, outside the restic backup tree.
Losing it only means re-authenticating the machine.

## Hardware
- 512GB SSD (`sda`) â- Debian 13, Docker, service configs
- 1TB HDD (`sdb`) â- bulk storage, mounted at `/mnt/storage`
- Reserved IP via DHCP reservation on the router

## Layout
- `/srv/docker/<service>/` â- compose files and config (tracked here)
- `/mnt/storage/<service>/` â- bulk data (not tracked)

## Services
| Service | Port | Purpose |
|---|---|---|
| AdGuard Home | 8080 | Network-wide DNS ad blocking |
| Jellyfin | 8096 | Media Server |
| Minecraft Bedrock | 19132/tcp + 19140-19155/udp | Survival world for PS5 friends (LAN only for now) |

## Notes
- Docker installed from Docker's official repo, not Debian's
- Fstab uses UUIDs with `nofail` so a dead disk won't block boot
- AdGuard admin moved off port 80 to leave it free for a reverse proxy# Homelab


## Minecraft Bedrock (`minecraft/`)
- `itzg/minecraft-bedrock-server`, `VERSION=LATEST`, survival/normal, allow-list on.
- Uses NetherNet (BDS 1.26.50+): TCP 19132 for signaling plus one UDP port per
  player from `19140-19155`. It does **not** listen on UDP 19132.
- `network_mode: host` so LAN discovery (UDP 7551 broadcast) reaches the PS5.
- World data: `minecraft/data/` (gitignored, but covered by the restic backup of
  `/srv/docker`). `minecraft` is in the `backup.sh` stop-list for a consistent copy.
- Status: LAN only. Internet access (playit.gg tunnel) and friends-list
  broadcast (MCXboxBroadcast) are planned, in that order.
