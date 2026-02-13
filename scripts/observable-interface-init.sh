#!/bin/sh
set -eu

ENV_FILE="/etc/caddy/.env"
CADDYFILE_CUSTOM="/etc/caddy/Caddyfile.custom"

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
  # Append to .env; ensure we start on a new line
  [ -s "$ENV_FILE" ] && [ "$(tail -c 1 "$ENV_FILE")" != "" ] && echo >> "$ENV_FILE"
  echo "OS_PASSWORD=${OS_PASSWORD}" >> "$ENV_FILE"
fi

OS_PASSWORD_HASH="$(caddy hash-password --plaintext "$OS_PASSWORD")"

if ! grep -q "handle.*/opensearch" "$CADDYFILE_CUSTOM"; then
  cat >> "$CADDYFILE_CUSTOM" <<EOF

handle /opensearch/* {
    basicauth {
        ${OS_USER_VALUE} ${OS_PASSWORD_HASH}
    }
    reverse_proxy opensearch-dashboards:5601
}
EOF
  echo "OpenSearch Dashboards route added to Caddyfile.custom."
else
  echo "OpenSearch Dashboards route already exists in Caddyfile.custom, skipping."
fi

# ============================================================
# Phase 2: Create OpenSearch Dashboards index patterns
# ============================================================

DASHBOARDS_URL="http://opensearch-dashboards:5601/opensearch"
MAX_WAIT=120          # seconds to wait for Dashboards API
RETRY_INTERVAL=5      # seconds between retries
INDEX_WAIT=60         # seconds to wait for indices after Dashboards is up
INDEX_RETRY=10        # seconds between index checks

PATTERNS="mediawiki-logs-* caddy-logs-* mysql-logs-*"

# ---------- wait for OpenSearch Dashboards API ----------
echo "Waiting for OpenSearch Dashboards to become ready..."
elapsed=0
while [ "$elapsed" -lt "$MAX_WAIT" ]; do
  if wget -qO- "${DASHBOARDS_URL}/api/status" 2>/dev/null | grep -q '"state":"green"'; then
    echo "OpenSearch Dashboards is ready."
    break
  fi
  sleep "$RETRY_INTERVAL"
  elapsed=$((elapsed + RETRY_INTERVAL))
done

if [ "$elapsed" -ge "$MAX_WAIT" ]; then
  echo "WARNING: Dashboards did not report green within ${MAX_WAIT}s – proceeding anyway."
fi

# ---------- wait for at least one log index to appear ----------
echo "Waiting for log indices to be created by Logstash..."
elapsed=0
while [ "$elapsed" -lt "$INDEX_WAIT" ]; do
  indices="$(wget -qO- 'http://opensearch:9200/_cat/indices?h=index' 2>/dev/null || true)"
  for p in $PATTERNS; do
    prefix="${p%\*}"
    if echo "$indices" | grep -q "^${prefix}"; then
      echo "Found index matching ${p}"
    fi
  done
  if echo "$indices" | grep -qE "^(mediawiki-logs-|caddy-logs-|mysql-logs-)"; then
    echo "At least one log index exists – creating index patterns."
    break
  fi
  sleep "$INDEX_RETRY"
  elapsed=$((elapsed + INDEX_RETRY))
done

if [ "$elapsed" -ge "$INDEX_WAIT" ]; then
  echo "WARNING: No log indices found within ${INDEX_WAIT}s – creating patterns anyway."
fi

# ---------- create index patterns ----------
for pattern in $PATTERNS; do
  id="$pattern"
  echo "Creating index pattern: ${pattern}"

  response="$(wget -qO- \
    --header='Content-Type: application/json' \
    --header='osd-xsrf: true' \
    --post-data="{\"attributes\":{\"title\":\"${pattern}\",\"timeFieldName\":\"@timestamp\"}}" \
    "${DASHBOARDS_URL}/api/saved_objects/index-pattern/${id}" 2>&1 || true)"

  if echo "$response" | grep -q '"type":"index-pattern"'; then
    echo "  ✓ Created ${pattern}"
  elif echo "$response" | grep -qi 'already exists\|409 Conflict'; then
    echo "  - ${pattern} already exists, skipping."
  else
    echo "  ! Unexpected response for ${pattern}: ${response}"
  fi
done

# ---------- set default index pattern ----------
default_pattern="mediawiki-logs-*"
echo "Setting default index pattern to ${default_pattern}..."
wget -qO- \
  --header='Content-Type: application/json' \
  --header='osd-xsrf: true' \
  --post-data="{\"value\":\"${default_pattern}\"}" \
  "${DASHBOARDS_URL}/api/opensearch-dashboards/settings/defaultIndex" 2>&1 || true

# ---------- configure Dashboards settings ----------
echo "Configuring Dashboards settings..."

# Set Discover (logs view) as the homepage
echo "  Setting Discover as homepage..."
wget -qO- \
  --header='Content-Type: application/json' \
  --header='osd-xsrf: true' \
  --post-data='{"value":"/app/discover"}' \
  "${DASHBOARDS_URL}/api/opensearch-dashboards/settings/defaultRoute" 2>&1 || true

# Set default time range to last 24 hours
echo "  Setting default time range to last 24h..."
wget -qO- \
  --header='Content-Type: application/json' \
  --header='osd-xsrf: true' \
  --post-data='{"value":"{\"from\":\"now-24h\",\"to\":\"now\"}"}' \
  "${DASHBOARDS_URL}/api/opensearch-dashboards/settings/timepicker:timeDefaults" 2>&1 || true

# Set timezone to UTC (universally safe; users can change in Dashboards settings)
echo "  Setting timezone to UTC..."
wget -qO- \
  --header='Content-Type: application/json' \
  --header='osd-xsrf: true' \
  --post-data='{"value":"UTC"}' \
  "${DASHBOARDS_URL}/api/opensearch-dashboards/settings/dateFormat:tz" 2>&1 || true

echo "Dashboards configuration complete."
