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

## 2026-09-12 â€” Jellyfin

Installed Jellyfin twice by accident. Read the docs, installed the apt
package without registering that I'd done it, then later tried the Docker
version and hit "address already in use" on 8096. `ss -tulnp` showed a
native `jellyfin` process holding the port â- that was the earlier install
running as a systemd service. Purged it and went with Docker for
consistency with everything else.

Second failure: config and cache directories were root-owned because
Docker creates missing bind-mount dirs as root. Jellyfin runs as 1000:1000
and couldn't write its logs, so it crash-looped with exit 139. chown fixed
it â- but `up -d` reused the broken container, so it kept restarting until
I ran `down` first. Second time today that `restart`/`up -d` on an existing
container didn't do what I expected.

Also: `-- Media:` instead of `- Media:` in services.yaml. Two hyphens is
not a list item. `python3 -c "import yaml; yaml.safe_load(open(...))"`
catches this in a second.

### Notes
- AdGuard admin moved off port 80 to leave it free for a reverse proxy
- Removed AdGuard's 3000 mapping once setup was done; it was blocking Homepage
