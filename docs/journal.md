# Homelab Journal

## 2026-09-10 - Initial build

Installed Debian 13 headless on the 512GB SSD, wiped the old Mint install
off the 1TB HDD and mounted it at /mnt/storage. Docker from the official
repo. First two services: AdGuard Home and Homepage.

### Things that went wrong

**Accidentally installed a desktop environment.** Hit Enter instead of
space on the software selection screen, which confirmed the defaults
instead of toggling them. Purging it tried to take `sudo` with it -
Debian refused because no root password was set, which saved me from
being locked out. Lesson: space toggles, Enter confirms. And check the
removal list before saying yes.

**mkfs ran before the partition existed.** Ran the partition and format
commands as one paste; the kernel hadn't re-read the partition table yet
so /dev/sdb1 didn't exist. blkid then showed a stale vfat signature from
the old EFI partition, which I nearly put in fstab. `partprobe` forces
the re-read. Short 8-char UUIDs mean FAT; ext4 UUIDs are long.

**Homepage config directory owned by root.** The container created it, so
my user couldn't write to it - that's why the config files never
appeared. chown fixed it. Containers and the host share the filesystem
but not the user database.

**Port never published despite being in the compose file.** Container was
healthy and listening internally, but the PORTS column was empty.
`docker compose restart` reuses the existing container, so it never
picked up the mapping. `down` then `up -d` recreated it properly.
Rule: edit the compose file, use `up -d`. Edit a config file the app
reads at runtime, `restart` is enough.

## 2026-09-12 — Jellyfin

Installed Jellyfin twice by accident. Read the docs, installed the apt
package without registering that I'd done it, then later tried the Docker
version and hit "address already in use" on 8096. `ss -tulnp` showed a
native `jellyfin` process holding the port �- that was the earlier install
running as a systemd service. Purged it and went with Docker for
consistency with everything else.

Second failure: config and cache directories were root-owned because
Docker creates missing bind-mount dirs as root. Jellyfin runs as 1000:1000
and couldn't write its logs, so it crash-looped with exit 139. chown fixed
it �- but `up -d` reused the broken container, so it kept restarting until
I ran `down` first. Second time today that `restart`/`up -d` on an existing
container didn't do what I expected.

Also: `-- Media:` instead of `- Media:` in services.yaml. Two hyphens is
not a list item. `python3 -c "import yaml; yaml.safe_load(open(...))"`
catches this in a second.

## 2026-10-15 — Vaultwarden monitor false alarms

- Uptime Kuma showed Vaultwarden down repeatedly (EAI_AGAIN, ENOTFOUND, ECONNREFUSED).
- Root cause of the long outage: the Oct 12 `apt upgrade` (Tailscale 1.102.5 → 1.104.1,
  Docker 29.8 → 29.9) changed behavior so containers can no longer connect to the host's
  tailnet IP on 443. The `tailscale serve` listener is bound to tailscale0
  (`100.65.193.116%tailscale0:443`), and container traffic arrives on the Docker bridge instead.
- Vaultwarden itself was never down: `curl` from the host returned 200.
- Fix: split monitoring.
  - "Vaultwarden" → HTTP check of `http://192.168.1.6:8081/alive` (service only)
  - "Vaultwarden via Tailscale" → Push monitor fed by `scripts/tailscale-check.sh`,
    run every minute by `tailscale-check.timer` as user snow
- Lesson: one monitor checking the whole chain can't tell you which layer broke.
  Read error codes as steps: DNS (EAI_AGAIN/ENOTFOUND) → TCP (ECONNREFUSED) → HTTP.

- Follow-up: the Push monitor showed "pending" because systemd timers have up to 1 min
  of default slack (runs came every ~70s against a 60s heartbeat). Fixed with
  `AccuracySec=1s` in the timer and a 90s heartbeat interval in Kuma.

### Notes
- AdGuard admin moved off port 80 to leave it free for a reverse proxy
- Removed AdGuard's 3000 mapping once setup was done; it was blocking Homepage
