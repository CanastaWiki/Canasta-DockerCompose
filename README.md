# Canasta: Docker Compose stack repo template
This is the official template for a Docker Compose-based Canasta stack.

Download the contents of this repo and follow instructions below to start using Canasta.

# 1. Create `.env` file

Create a copy of the `.env.example` file and put necessary settings there

```ssh
cp .env.example .env
vi .env
```

# 2. Start Traefik instance

Use `docker-compose.traefik.yml` bundled template to start pre-configured
Traefik instance:

```bash
# Create public network for Traefik
docker network create --driver overlay --attachable traefik-public-compose
# Start the Traefik instance
docker-compose -p compose_traefik -f docker-compose.traefik.yml up -d
```

The command above will spin up a [Traefik](https://doc.traefik.io/) instance
listening port 443 and 80. You may copy the `docker-compose.traefik.yml` out
to some directory or just have it cloned as a separate repo directory, eg: `~/traefik`
for easier updates.

# 3. Start Canasta instances

Use `docker-compose.yml` to start Canasta stack instance:

```bash
docker-compose -f docker-compose.yml up -d
```

If your `.env` files does contain proper `MW_SITE_FQDN` and `EMAIL` variables your wiki 
should be up running with a certificate issued by Traefik.

Repeat steps 1 and 3 for the rest of stacks if needed, routing and certificates provisioning will
be handled automatically by Traefik.

For more detailed information on setting this up, please see the [documentation](https://canasta.wiki/documentation).
