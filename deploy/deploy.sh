#!/usr/bin/env bash
# Deploy (or update) the equine backend on a droplet from a GitHub Release.
#
# One droplet runs two separate copies, each with its own data:
#   prod -> /opt/equine       service equine-pocketbase       127.0.0.1:8090
#   test -> /opt/equine-test  service equine-pocketbase-test  127.0.0.1:8091
# Caddy sits in front, serves HTTPS for each domain (auto Let's Encrypt) and
# forwards to the right copy.
#
# First run of an environment bootstraps it: pocketbase user, Caddy, systemd
# service, Caddy site (you're prompted for the domain, or set DOMAIN=...).
# Later runs just swap in the new release and restart. pb_data/ is never touched.
#
# Usage (as root on the droplet):
#   ./deploy.sh prod              # latest release to production
#   ./deploy.sh test v1.2.0       # specific release to test
#   DOMAIN=test.example.com ./deploy.sh test   # no prompt
set -euo pipefail

ENVIRONMENT="${1:-}"
TAG="${2:-latest}"
case "$ENVIRONMENT" in
  prod) SERVICE="equine-pocketbase";      DEST="/opt/equine";      PORT=8090 ;;
  test) SERVICE="equine-pocketbase-test"; DEST="/opt/equine-test"; PORT=8091 ;;
  *) echo "usage: $0 <prod|test> [tag]" >&2; exit 1 ;;
esac

REPO="ajeetgill/equine-welfare"
ASSET="equine-backend-linux-amd64.zip"
if [ "$TAG" = "latest" ]; then
  URL="https://github.com/$REPO/releases/latest/download/$ASSET"
else
  URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"
fi

echo "== [$ENVIRONMENT] downloading $URL"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL -o "$TMP/$ASSET" "$URL"
unzip -q "$TMP/$ASSET" -d "$TMP/bundle"

# --- one-time bootstrap ---------------------------------------------------
if ! id pocketbase &>/dev/null; then
  echo "== creating pocketbase system user"
  useradd --system --home /opt/equine --shell /usr/sbin/nologin pocketbase
fi
mkdir -p "$DEST"

if ! command -v caddy &>/dev/null; then
  echo "== installing Caddy"
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq caddy >/dev/null
fi
mkdir -p /etc/caddy/sites
if ! grep -q 'import /etc/caddy/sites/\*.caddy' /etc/caddy/Caddyfile 2>/dev/null; then
  echo "import /etc/caddy/sites/*.caddy" > /etc/caddy/Caddyfile
fi
SITE="/etc/caddy/sites/$ENVIRONMENT.caddy"
if [ ! -f "$SITE" ]; then
  DOMAIN="${DOMAIN:-}"
  [ -n "$DOMAIN" ] || read -rp "Domain for $ENVIRONMENT (e.g. app.example.com): " DOMAIN
  [ -n "$DOMAIN" ] || { echo "a domain is required" >&2; exit 1; }
  printf '%s {\n\treverse_proxy 127.0.0.1:%s\n}\n' "$DOMAIN" "$PORT" > "$SITE"
fi

# Rewritten every run so the unit always matches this script.
cat > "/etc/systemd/system/$SERVICE.service" <<EOF
[Unit]
Description=Equine Welfare PocketBase backend ($ENVIRONMENT)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pocketbase
Group=pocketbase
WorkingDirectory=$DEST
ExecStart=$DEST/pocketbase serve --http=127.0.0.1:$PORT
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q "$SERVICE"

# --- swap in the new release (pb_data untouched) --------------------------
echo "== installing release into $DEST"
systemctl stop "$SERVICE" || true
rm -rf "$DEST/pb_hooks" "$DEST/pb_migrations" "$DEST/pb_public" "$DEST/deploy"
cp -r "$TMP/bundle/pb_hooks" "$TMP/bundle/pb_migrations" "$TMP/bundle/pb_public" "$TMP/bundle/deploy" "$DEST/"
install -m 755 "$TMP/bundle/pocketbase" "$DEST/pocketbase"
chown -R pocketbase:pocketbase "$DEST"

systemctl start "$SERVICE"
systemctl reload caddy || systemctl restart caddy
sleep 2
systemctl is-active "$SERVICE" && echo "== [$ENVIRONMENT] deploy OK ($TAG)"
curl -fsS "http://127.0.0.1:$PORT/api/health" && echo
echo "Site: https://$(head -1 "$SITE" | cut -d' ' -f1)"
