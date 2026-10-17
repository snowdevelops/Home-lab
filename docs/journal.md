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

## 2026-10-17 — Minecraft Bedrock, stage 1 (server only)

- Plan was BDS + playit (UDP 19132) + MCXboxBroadcast. Upstream docs showed it
  would not work as written: BDS 1.26.50+ defaults to NetherNet (WebRTC). TCP 19132
  signaling, then one UDP port per player from `server-udp-ports`. Nothing listens
  on UDP 19132. RakNet (`transport=raknet`) is being removed.
- playit's combined TCP+UDP tunnel needs Premium; one forum report says a single
  TCP tunnel to 19132 is enough. Plan: try that free (stage 2), pay if it fails.
  MCXboxBroadcast has NetherNet support but open issues (#402, #384) (stage 3).
- Stage 1 built: `minecraft/compose.yaml`, bedrock only. `.gitignore` rules added
  before anything else; `minecraft` added to `backup.sh` SERVICES.
- `network_mode: host` because LAN discovery is a UDP 7551 broadcast and Docker's
  bridge doesn't forward broadcasts. Pre-created `data/` as snow and set UID/GID
  1000, so no root-owned bind mount this time.
- python3-yaml isn't installed here; `docker compose config -q` validated instead.
- Verified: `curl http://192.168.1.6:19132/v1/join` returns server JSON, container healthy.

### 2026-10-17 — Stage 1 LAN test: result
- First PS5 join failed ("Boat", InitialConnection-145, NetherNet:2193) with plain
  `SERVER_UDP_PORTS=19140-19155` in host mode. Server log had no connection line at all.
  Hypothesis was that BDS advertises every host address (docker bridges, tailscale).
- Tried `192.168.1.6:19140-19155:19140-19155` (documented ip:ext:int form). On BDS
  1.26.52.3 that made the TCP 19132 listener silently disappear (no "Accepting clients",
  `ss` showed only UDP 7551) while the container still reported healthy. I had only
  checked server.properties, not `ss`. Lesson: verify listeners with `ss -tulnp` after
  any port change. Healthy + "Server started" proves nothing about the TCP listener.
- Reverted to plain range, `down` + `up -d`. PS5 then joined fine (LAN Games).
  Root cause of the first failure NOT established: same config as the failed attempt,
  and `allowlist add DaSnowV5` was run in between. Don't assume the address theory.
- Host firewall ruled out: ufw/nftables/firewalld inactive, no iptables/nft installed.
- allowlist.json entries added via console have a name but no XUID; joining works anyway.
- Next: stage 2 (playit single TCP tunnel to 127.0.0.1:19132), then stage 3 (MCXboxBroadcast).

### 2026-10-17 — Correction: TCP 19132 listener is flaky, not caused by ip:ext:int
- Changed DIFFICULTY to hard and added OPS (DaSnowV5, by XUID so no mcprofile.io lookup
  at startup). Both verified: log "Difficulty: 3 HARD", permissions.json has the operator.
- After that `down`/`up -d`, TCP 19132 was missing again with the PLAIN `19140-19155`
  range. Repeated identical recreates: sometimes "Accepting clients" appears and TCP
  19132 listens, sometimes it silently doesn't (no error in the log, container still
  "healthy", "Server started." still printed). So my earlier conclusion that the
  `ip:ext:int` form removed the listener was wrong (or at least not the only cause).
- Not found in itzg's issue tracker. Root cause unknown (BDS 1.26.52.3).
- Workaround for now: after any recreate, check `ss -tln | grep 19132` and recreate
  again if missing. Risk: with `restart: unless-stopped` a reboot can leave the server
  up but unjoinable. Consider a healthcheck on TCP 19132 and/or a post-start check.

### 2026-10-17 — TCP-aware healthcheck on the Bedrock container
- The image's default healthcheck (mc-monitor, UDP RakNet ping) passed while TCP 19132 was
  missing. Overrode it with `curl -fs http://127.0.0.1:19132/v1/join` (30s interval,
  3 retries, 60s start period). Curl exit 7 = connection refused = listener missing.
- Verified both ways: a start without the listener went `unhealthy`; a good start `healthy`.
- Docker only marks the container unhealthy, it does not restart it. Next: have Uptime
  Kuma watch the Docker health status or the join URL.

### 2026-10-17 — RakNet is not viable on BDS 1.26.52.3 (correction)
- Tried `TRANSPORT=raknet` because playit's free Bedrock tunnel is UDP-only. Server wrote
  "TRANSPORT TYPE ERROR ... NetherNet is the only supported transport type. Players will
  not be able to connect", and UDP 7551 LAN discovery disappeared. Reverted.
- Deleting the TRANSPORT env var did NOT revert it: the itzg image only rewrites
  server.properties keys that have an env var, so `transport=raknet` stayed in ./data and
  every restart lacked the TCP listener. Fix: set `TRANSPORT: "nethernet"` explicitly.
  Lesson: removing an env var does not undo its effect on persisted config.
- Verified after revert: server.properties transport=nethernet, TCP 19132 + UDP 7551
  listening (`ss -tulnp`), "Accepting clients on [::]:19132", /v1/join OK, healthy.
- Stage 2: playit agent added to compose (secret in gitignored minecraft/playit/playit.env,
  mode 600). Agent connects; account_status=email_not_verified, tunnel_count=0.
  The official image has no claim-link flow: it needs SECRET_KEY from playit's Docker
  setup wizard. Remaining: verify email, create TCP tunnel (1 port) -> 127.0.0.1:19132.
