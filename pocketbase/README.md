# PocketBase backend (local)

Single self-hosted backend replacing Convex (data + files) and Clerk (auth).
The binary is NOT committed — download it from
https://github.com/pocketbase/pocketbase/releases (v0.39.x, darwin_arm64),
place it in this directory as `pocketbase`, and `chmod +x pocketbase`.

## Run

```bash
cd pocketbase
./pocketbase serve --http 0.0.0.0:8090
```

- `0.0.0.0` exposes the server on the LAN so a physical iPad can reach it at
  `http://<your-Mac-LAN-IP>:8090` (same Wi-Fi).
- Admin dashboard: http://localhost:8090/_/
- Schema lives in `pb_migrations/` (applied automatically on serve).
- The iOS sync endpoint lives in `pb_hooks/main.pb.js`.

## Dashboard (web UI)

The web dashboard is a Vite + React app in `../dashboard/`, served by
PocketBase itself from `pb_public/` (gitignored build artifact).

```bash
# build (emits into pocketbase/pb_public/)
cd ../dashboard && nvm use node && npm install && npm run build

# then (re)start PocketBase and open http://localhost:8090/
```

For dashboard development with hot reload:

```bash
cd ../dashboard && npm run dev   # Vite on :5173, talks to PocketBase on :8090
```

## First-time setup

```bash
# create the superuser (admin dashboard login)
./pocketbase superuser upsert admin@example.com <choose-a-password>
```

App users (assessors) are created by the superuser in the admin dashboard
(users collection → New record) or via `scripts/create_user.sh`. There is no
self-registration.

## Test the sync endpoint

```bash
./scripts/test_sync.sh tester@example.com <password>
```

## Releases & server deployment

Tagging a version packages everything (PocketBase linux binary + `pb_hooks/`
+ `pb_migrations/` + freshly built dashboard) into a GitHub Release via
`.github/workflows/release.yml`:

```bash
gh release create v1.0.0        # or: git tag v1.0.0 && git push --tags
```

One droplet runs two separate copies, each with its own data, behind Caddy
(automatic HTTPS):

| env  | folder            | service                  | local port |
|------|-------------------|--------------------------|------------|
| prod | `/opt/equine`      | `equine-pocketbase`      | 8090 |
| test | `/opt/equine-test` | `equine-pocketbase-test` | 8091 |

On the droplet (first run of an env installs Caddy, the service and the
Caddy site, and asks for the domain; later runs update in place; `pb_data/`
is never touched):

```bash
curl -fsSL https://raw.githubusercontent.com/ajeetgill/equine-welfare/main/deploy/deploy.sh -o deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh test            # latest release to test first
sudo ./deploy.sh prod            # then to production
sudo ./deploy.sh prod v1.0.0     # pin a version / roll back
```

After the first run of an env:

```bash
# superuser (store the password in the password manager)
sudo -u pocketbase /opt/equine/pocketbase superuser upsert EMAIL PASSWORD --dir /opt/equine/pb_data
# PocketBase sits behind Caddy, so trust its X-Forwarded-For header
# (otherwise every client looks like 127.0.0.1 in logs and rate limits):
# Dashboard -> Settings -> Application -> "User IP proxy headers" = X-Forwarded-For
```

Backup (DigitalOcean weekly droplet backups are on; for a manual copy):

```bash
ssh root@DROPLET 'systemctl stop equine-pocketbase && tar czf /root/pb_data.tgz -C /opt/equine pb_data; systemctl start equine-pocketbase'
scp root@DROPLET:/root/pb_data.tgz .
```

See `deploy/deploy.sh`.
