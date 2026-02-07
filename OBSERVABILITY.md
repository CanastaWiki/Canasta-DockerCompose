# Observability (OpenSearch + Logstash + Dashboards)

## Enable the observability profile

1. Ensure your `.env` contains a value for `OS_USER` (the username for OpenSearch Dashboards access). `OS_PASSWORD` will be auto-generated on first run if not already set.

2. Start the stack with the observability profile:

   ```bash
   docker compose --profile observable up -d
   ```

   Tip: to make the profile the default for future runs, set:

   ```bash
   export COMPOSE_PROFILES=observable
   docker compose up -d
   ```

3. After the first run, restart Caddy so it picks up the generated OpenSearch Dashboards route:

   ```bash
   docker compose restart caddy
   ```

## Open OpenSearch Dashboards

- URL: `https://<MW_SITE_FQDN>/opensearch`
- Login: use the `OS_USER` and the plain-text `OS_PASSWORD` from your `.env` file.

## Enable MediaWiki logging

By default, MediaWiki does not write log files. Add the following to `config/LocalSettings.php`:

```php
# Logging configuration for observability
$wgDebugLogFile = "/var/log/mediawiki/debug.log";
$wgDBerrorLog = "/var/log/mediawiki/dberror.log";
$wgDebugLogGroups = [
    'exception' => "/var/log/mediawiki/exception.log",
    'error' => "/var/log/mediawiki/error.log",
];
```

Then restart the web container:

```bash
docker compose restart web
```

## Create index patterns (Dashboards)

Index patterns are created automatically by the `observable-interface-init` container
when the observability profile starts. It waits for OpenSearch Dashboards and at
least one log index to exist, then creates:

- `mediawiki-logs-*`
- `caddy-logs-*`
- `mysql-logs-*`

The default index pattern is set to `mediawiki-logs-*`.

If automatic creation fails (check `docker compose logs observable-interface-init`),
you can create them manually:

1. Open **OpenSearch Dashboards** → **Dashboards Management** → **Index Patterns**.
2. Create the following patterns (one at a time):
   - `mediawiki-logs-*`
   - `caddy-logs-*`
   - `mysql-logs-*`
3. When prompted for a time field, pick `@timestamp` if available; otherwise use the suggested timestamp field or skip if none exists.

## View logs in Discover

1. Go to **Discover**.
2. Select the index pattern you created (top-left selector).
3. Adjust the time range (top-right) to include recent activity.

## Verify logs are flowing

If you do not see logs:
- Generate activity (browse the wiki, log in, etc.).
- Ensure the observability profile is running: `docker compose ps`.
- Check Logstash and OpenSearch containers for errors: `docker compose logs logstash opensearch`.
