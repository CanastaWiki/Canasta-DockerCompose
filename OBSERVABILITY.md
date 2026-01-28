# Observability (OpenSearch + Logstash + Dashboards)

## Enable the observability profile

1. Ensure your `.env` contains values for OpenSearch Dashboards access:
   - `OS_PORT`
   - `OS_USER`
   - `OS_PASSWORD_HASH`
  
Note: Default username is set to **admin** and password is set to **password**. 

2. Start the stack with the observability profile:

   ```bash
   docker compose --profile observable up -d
   ```

   Tip: to make the profile the default for future runs, set:

   ```bash
   export COMPOSE_PROFILES=observable
   docker compose up -d
   ```

## Expose OpenSearch Dashboards via Caddy

Edit [config/Caddyfile](config/Caddyfile) to proxy `/opensearch` to the Dashboards container and protect it with basic auth. Use the following structure (matches the reference configuration):

```caddyfile
{$MW_SITE_FQDN}:{$HTTPS_PORT}

reverse_proxy varnish:80

handle_path /opensearch/* {
    basicauth {
        {$OS_USER} {$OS_PASSWORD_HASH}
    }
    reverse_proxy opensearch-dashboards:5601
}

log {
    output file /var/log/caddy/access.log
}
```

Apply the change:

```bash
docker compose restart caddy
```

## Open OpenSearch Dashboards

- URL: `https://<MW_SITE_FQDN>/opensearch`
- Login: use the `OS_USER` and the plain text password that matches `OS_PASSWORD_HASH`.

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
