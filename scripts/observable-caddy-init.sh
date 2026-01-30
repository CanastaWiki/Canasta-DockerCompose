#!/bin/sh
set -eu

ENV_FILE="/work/.env"
CADDYFILE="/work/config/Caddyfile"

if [ ! -f "$ENV_FILE" ]; then
  touch "$ENV_FILE"
fi

get_env() {
  grep -m 1 "^$1=" "$ENV_FILE" | cut -d= -f2-
}

OS_USER_VALUE="${OS_USER:-}"
if [ -z "$OS_USER_VALUE" ]; then
  OS_USER_VALUE="$(get_env OS_USER || true)"
fi

if [ -z "$OS_USER_VALUE" ]; then
  echo "OS_USER is required (set in .env or environment)." >&2
  exit 1
fi

if grep -q "^OS_PASSWORD=" "$ENV_FILE"; then
  OS_PASSWORD="$(get_env OS_PASSWORD)"
else
  OS_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '\n')"
  printf "\nOS_PASSWORD=%s\n" "$OS_PASSWORD" >> "$ENV_FILE"
fi

OS_PASSWORD_HASH="$(caddy hash-password --plaintext "$OS_PASSWORD")"

if ! grep -q "handle_path /opensearch" "$CADDYFILE"; then
  awk -v user="$OS_USER_VALUE" -v hash="$OS_PASSWORD_HASH" '
    BEGIN { inserted=0 }
    {
      print $0
      if (!inserted && $0 ~ /^reverse_proxy varnish:80/) {
        print ""
        print "handle_path /opensearch/* {"
        print "    basicauth {"
        print "        " user " " hash
        print "    }"
        print "    reverse_proxy opensearch-dashboards:5601"
        print "}"
        inserted=1
      }
    }
  ' "$CADDYFILE" > /tmp/Caddyfile
  mv /tmp/Caddyfile "$CADDYFILE"
fi
