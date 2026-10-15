#!/bin/bash
# Checks Vaultwarden through tailscale serve (HTTPS on the tailnet) and reports to Uptime Kuma.
PUSH_URL="$(cat /home/snow/.config/kuma-push-url)"

if curl -fsS --max-time 10 -o /dev/null https://homelab.tail89496e.ts.net/alive; then
  curl -fsS --max-time 10 -o /dev/null "${PUSH_URL}?status=up&msg=OK"
else
  curl -fsS --max-time 10 -o /dev/null "${PUSH_URL}?status=down&msg=tailscale-path-failed"
fi
