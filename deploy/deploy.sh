#!/usr/bin/env bash
# Deploy (or update) the equine backend on a droplet from a GitHub Release.
#
# First run bootstraps everything: creates the pocketbase user, /opt/equine,
# and the systemd service (you'll be prompted for the domain). Later runs
# just swap in the new release and restart. pb_data/ is never touched.
#
# Usage (as root on the droplet):
#   ./deploy.sh              # latest release
#   ./deploy.sh v1.2.0       # specific release
set -euo pipefail

REPO="ajeetgill/equine-welfare"
ASSET="equine-backend-linux-amd64.zip"
DEST="/opt/equine"
TAG="${1:-latest}"

if [ "$TAG" = "latest" ]; then
  URL="https://github.com/$REPO/releases/latest/download/$ASSET"
else
  URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"
fi

echo "== downloading $URL"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL -o "$TMP/$ASSET" "$URL"
unzip -q "$TMP/$ASSET" -d "$TMP/bundle"

# --- one-time bootstrap ---------------------------------------------------
if ! id pocketbase &>/dev/null; then
  echo "== creating pocketbase system user"
  useradd --system --home "$DEST" --shell /usr/sbin/nologin pocketbase
fi
mkdir -p "$DEST"

if [ ! -f /etc/systemd/system/equine-pocketbase.service ]; then
  echo "== installing systemd service"
  read -rp "Domain for HTTPS (blank = plain HTTP on :8090): " DOMAIN
  if [ -n "$DOMAIN" ]; then
    sed "s/YOUR_DOMAIN/$DOMAIN/" "$TMP/bundle/deploy/equine-pocketbase.service" \
      > /etc/systemd/system/equine-pocketbase.service
  else
    sed "s|ExecStart=.*|ExecStart=$DEST/pocketbase serve --http=0.0.0.0:8090|" \
      "$TMP/bundle/deploy/equine-pocketbase.service" \
      > /etc/systemd/system/equine-pocketbase.service
  fi
  systemctl daemon-reload
  systemctl enable equine-pocketbase
fi

# --- swap in the new release (pb_data untouched) --------------------------
echo "== installing release into $DEST"
systemctl stop equine-pocketbase || true
rm -rf "$DEST/pb_hooks" "$DEST/pb_migrations" "$DEST/pb_public" "$DEST/deploy"
cp -r "$TMP/bundle/pb_hooks" "$TMP/bundle/pb_migrations" "$TMP/bundle/pb_public" "$TMP/bundle/deploy" "$DEST/"
install -m 755 "$TMP/bundle/pocketbase" "$DEST/pocketbase"
chown -R pocketbase:pocketbase "$DEST"

systemctl start equine-pocketbase
sleep 2
systemctl is-active equine-pocketbase && echo "== deploy OK ($TAG)"
echo "Health: curl -s localhost:8090/api/health (or https://your-domain/api/health)"
