# nginx-gateway2

RWAT / Wittgens production Nginx + Certbot gateway.

Current production routes:

- `rwagate.net` and `www.rwagate.net`: frontend static site
- `api.rwagate.net`: reverse proxy to `rwat-go-server:8000`
- `admin.rwagate.net`: reverse proxy to `rwat-admin-ui:80`
- Frontend host root: `/var/www/wittgens`
- Frontend production root in container: `/var/www/wittgens/prod`
- Docker network: `rwat-edge`
- Certificate directory: `certbot/conf/live/rwagate.net/`

The gateway is prod-only. It keeps HTTP routes for ACME challenges before a certificate is available, then renders HTTPS routes after the `rwagate.net` certificate set is present.

## Files

- `docker-compose.yml`: runs only Nginx, mounting Wittgens static files and Certbot directories.
- `environments/prod/gateway.env`: production domains, upstreams, static root, network, and certificate group.
- `environments/prod/routes/http-only/rwat.conf`: HTTP-only ACME fallback.
- `environments/prod/routes/https/rwat.conf`: HTTPS frontend and reverse proxy routes.
- `nginx/templates/preamble.conf`: shared Nginx preamble.
- `nginx/default.conf`: active generated Nginx config.
- `scripts/render-nginx-conf.sh`: renders HTTP-only or HTTPS config based on certificate readiness.
- `scripts/request-cert.sh`: requests certificates.
- `scripts/renew-cert.sh`: renews certificates.
- `scripts/compose.sh`: runs Docker Compose with the prod environment.

## GitHub Environment

Configure the `prod` GitHub Environment.

Variables:

- `DEPLOY_HOST`
- `DEPLOY_PORT`
- `DEPLOY_USER`
- `DEPLOY_PATH`, default: `/opt/projects/nginx-gateway2`

Secrets:

- `SSH_PRIVATE_KEY`
- `LETSENCRYPT_EMAIL`

## Usage

Deploy/bootstrap on the server:

```bash
APP_ENV=prod ./scripts/bootstrap.sh
```

Request certificates:

```bash
APP_ENV=prod LETSENCRYPT_EMAIL=ops@example.com ./scripts/request-cert.sh
```

Renew certificates:

```bash
APP_ENV=prod LETSENCRYPT_EMAIL=ops@example.com ./scripts/renew-cert.sh
```

## Verification

```bash
sh scripts/tests/source-layout-test.sh
sh scripts/tests/compose-command-test.sh
sh scripts/tests/render-environments-test.sh
sh scripts/tests/rwagate-prod-test.sh
sh scripts/tests/compose-environments-test.sh
sh -n scripts/*.sh scripts/tests/*.sh
APP_ENV=prod ./scripts/compose.sh config
```
