# How to setup multiple wiki instances on the same server

The easiest way to setup multiple Canasta stacks on a single server is to replace
default bundled Caddy web server with a separately running Traefik stack acting as an SSL terminator 
and automatic certificates provisioner (via LetsEncrypt).

# 1. Start Traefik instance

Use `docker-compose.traefik.yml` bundled template to start pre-configured
Traefik instance:

```bash
# Create public network for Traefik served wikis
docker network create --driver overlay --attachable traefik-public-compose
# Set email for LetsEncrypt
export EMAIL=myemailforletsencrypt@somehost.com
# Start the Traefik instance
docker-compose -p compose_traefik -f docker-compose.traefik.yml up -d
```

The command above will spin up a [Traefik](https://doc.traefik.io/) instance
listening port 443 and 80. You may copy the `docker-compose.traefik.yml` out
to some directory or just have it cloned as a separate repo directory, eg: `~/traefik`
for easier updates.

# 2. Start Canasta instances

Use `docker-compose.for.traefik.yml` to start Canasta stack instance:

```bash
docker-compose -f docker-compose.for.traefik.yml up -d
```

If your `.env` files does contain proper `MW_SITE_FQDN` your wiki should be up
running with a certificate issued by Traefik in a minute!

Repeat for the rest of stacks needed, routing and certificates provisioning will
be handled automatically by Traefik.

# Links

Find more about Traefik at https://doc.traefik.io/
