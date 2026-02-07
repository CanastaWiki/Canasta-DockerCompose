#!/bin/sh
# Caddy entrypoint wrapper.
# Detects the observable profile by checking if opensearch-dashboards resolves
# (Docker Compose only registers DNS for running containers), and runs the
# observability init script in the background before starting Caddy.

INIT_SCRIPT="/etc/caddy/scripts/observable-interface-init.sh"

(
  # Give Docker DNS a moment to register service names
  sleep 10

  # Check if opensearch-dashboards is reachable (observable profile active)
  attempts=0
  while [ "$attempts" -lt 3 ]; do
    if nslookup opensearch-dashboards >/dev/null 2>&1; then
      echo "[observable-init] Observable profile detected."
      sh "$INIT_SCRIPT"

      # Reload Caddy to pick up Caddyfile.custom changes
      caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile 2>/dev/null || true
      echo "[observable-init] Caddy reloaded."
      exit 0
    fi
    sleep 5
    attempts=$((attempts + 1))
  done

  echo "[observable-init] Observable profile not detected, skipping."
) &

# Start Caddy as PID 1
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
