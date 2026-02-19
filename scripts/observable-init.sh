#!/bin/sh
# One-shot init container: creates OpenSearch Dashboards index patterns
# and configures default settings. Runs only when the observable profile
# is active. Credential generation and Caddyfile configuration are
# handled by the Canasta CLI.
set -eu

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
  if echo "$indices" | grep -qE "^(mediawiki-logs-|caddy-logs-|mysql-logs-)"; then
    echo "At least one log index exists."
    break
  fi
  sleep "$INDEX_RETRY"
  elapsed=$((elapsed + INDEX_RETRY))
done

if [ "$elapsed" -ge "$INDEX_WAIT" ]; then
  echo "WARNING: No log indices found within ${INDEX_WAIT}s."
fi

# ---------- create index patterns only for existing indices ----------
# Re-fetch current indices
indices="$(wget -qO- 'http://opensearch:9200/_cat/indices?h=index' 2>/dev/null || true)"
default_pattern=""

for pattern in $PATTERNS; do
  prefix="${pattern%\*}"
  if ! echo "$indices" | grep -q "^${prefix}"; then
    echo "Skipping index pattern ${pattern} (no matching index yet)"
    continue
  fi

  echo "Creating index pattern: ${pattern}"
  response="$(wget -qO- \
    --header='Content-Type: application/json' \
    --header='osd-xsrf: true' \
    --post-data="{\"attributes\":{\"title\":\"${pattern}\",\"timeFieldName\":\"@timestamp\"}}" \
    "${DASHBOARDS_URL}/api/saved_objects/index-pattern/${pattern}" 2>&1 || true)"

  if echo "$response" | grep -q '"type":"index-pattern"'; then
    echo "  Created ${pattern}"
  elif echo "$response" | grep -qi 'already exists\|409 Conflict'; then
    echo "  ${pattern} already exists, skipping."
  else
    echo "  Unexpected response for ${pattern}: ${response}"
  fi

  # Use the first successfully created/existing pattern as default
  if [ -z "$default_pattern" ]; then
    default_pattern="$pattern"
  fi
done

# ---------- set default index pattern ----------
if [ -n "$default_pattern" ]; then
  echo "Setting default index pattern to ${default_pattern}..."
  wget -qO- \
    --header='Content-Type: application/json' \
    --header='osd-xsrf: true' \
    --post-data="{\"value\":\"${default_pattern}\"}" \
    "${DASHBOARDS_URL}/api/opensearch-dashboards/settings/defaultIndex" > /dev/null 2>&1 || true
else
  echo "No index patterns created, skipping default index pattern."
fi

# ---------- configure Dashboards settings ----------
echo "Configuring Dashboards settings..."

echo "  Setting Discover as homepage..."
wget -qO- \
  --header='Content-Type: application/json' \
  --header='osd-xsrf: true' \
  --post-data='{"value":"/app/discover"}' \
  "${DASHBOARDS_URL}/api/opensearch-dashboards/settings/defaultRoute" > /dev/null 2>&1 || true

echo "  Setting default time range to last 24h..."
wget -qO- \
  --header='Content-Type: application/json' \
  --header='osd-xsrf: true' \
  --post-data='{"value":"{\"from\":\"now-24h\",\"to\":\"now\"}"}' \
  "${DASHBOARDS_URL}/api/opensearch-dashboards/settings/timepicker:timeDefaults" > /dev/null 2>&1 || true

echo "  Setting timezone to UTC..."
wget -qO- \
  --header='Content-Type: application/json' \
  --header='osd-xsrf: true' \
  --post-data='{"value":"UTC"}' \
  "${DASHBOARDS_URL}/api/opensearch-dashboards/settings/dateFormat:tz" > /dev/null 2>&1 || true

echo "Dashboards configuration complete."
