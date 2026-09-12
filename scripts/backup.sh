#!/usr/bin/env bash
set -euo pipefail

export RESTIC_REPOSITORY="/mnt/storage/backups/restic"
export RESTIC_PASSWORD_FILE="/root/.restic-password"

SERVICES=(adguard homepage jellyfin)

echo "=== Backup started $(date) ==="

for svc in "${SERVICES[@]}"; do
  echo "Stopping $svc"
  docker compose -f "/srv/docker/$svc/compose.yaml" stop
done

restic backup /srv/docker --tag auto

for svc in "${SERVICES[@]}"; do
  echo "Starting $svc"
  docker compose -f "/srv/docker/$svc/compose.yaml" start
done

echo "Pruning old snapshots"
restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune

echo "=== Backup finished $(date) ==="

echo "Verifying repository"
if restic check --read-data-subset=5%; then
  echo "Repository check passed"
else
  echo "REPOSITORY CHECK FAILED" >&2
  exit 1
fi
