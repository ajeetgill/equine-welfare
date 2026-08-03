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
