FROM caddy:2.9.1-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/hslatman/caddy-crowdsec-bouncer/http

FROM caddy:2.9.1-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

