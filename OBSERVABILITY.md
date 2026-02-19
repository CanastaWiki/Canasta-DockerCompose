# Observability (OpenSearch + Logstash + Dashboards)

## Enable the observability profile

Add `COMPOSE_PROFILES=observable` to your `.env` file (or append `,observable`
to an existing `COMPOSE_PROFILES` value), then run:

```bash
canasta create ...          # for new installations
canasta upgrade -i <id>     # for existing installations
```

The CLI automatically:
- Generates `OS_USER`, `OS_PASSWORD`, and `OS_PASSWORD_HASH` in `.env`
- Adds the OpenSearch Dashboards reverse proxy block to the Caddyfile

## Open OpenSearch Dashboards

- URL: `https://<your-domain>/opensearch`
- Login: use `OS_USER` and the plain-text `OS_PASSWORD` from your `.env` file.

## Enable MediaWiki logging

By default, MediaWiki does not write log files. Add the following to
`config/settings/global/Logging.php` (or your per-wiki settings):

```php
<?php
$wgDebugLogFile = "/var/log/mediawiki/debug.log";
$wgDBerrorLog = "/var/log/mediawiki/dberror.log";
$wgDebugLogGroups = [
    'exception' => "/var/log/mediawiki/exception.log",
    'error' => "/var/log/mediawiki/error.log",
];
```

Then restart the web container:

```bash
canasta restart -i <id>
```

Without this configuration, only Caddy access logs and MySQL logs will appear
in Dashboards. The `mediawiki-logs-*` index pattern will be created
automatically once MediaWiki log files exist.

## Index patterns

Index patterns are created automatically by the `observable-init` container
when the observability profile starts. It waits for OpenSearch Dashboards and
at least one log index to exist, then creates patterns for each available
index. A second pass runs 60 seconds later to catch late-arriving indices.

If automatic creation fails (check `docker logs <id>-observable-init-1`),
you can create patterns manually:

1. Open **OpenSearch Dashboards** > **Stack Management** > **Index Patterns**.
2. Create patterns for the indices that exist:
   - `caddy-logs-*`
   - `mysql-logs-*`
   - `mediawiki-logs-*` (only if MediaWiki logging is enabled)
3. Select `@timestamp` as the time field.

## View logs in Discover

1. Go to **Discover**.
2. Select the index pattern (top-left dropdown).
3. Adjust the time range (top-right) to include recent activity.

## Verify logs are flowing

If you do not see logs:
- Generate activity (browse the wiki, log in, etc.).
- Ensure the observability profile is running: `canasta list` or `docker ps`.
- Check container logs: `docker logs <id>-logstash-1` and `docker logs <id>-opensearch-1`.

## Security notes

- OpenSearch has security disabled (`plugins.security.disabled=true`). Access
  to the Dashboards UI is protected by Caddy's basicauth. OpenSearch itself is
  only accessible within the Docker network (no ports exposed to the host).
- OpenSearch Dashboards port 5601 is not exposed to the host; access is
  exclusively through the Caddy reverse proxy.
