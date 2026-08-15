# Horse C.O.P. — Equine Welfare Assessment

Dual-platform tool for veterinary equine (horse/donkey) welfare assessments,
based on the Code of Practice for the Care and Handling of Equines:

- **iPad app** (`equine-welfare/`) — SwiftUI + SwiftData, fully offline-first.
  Assessors create assessments (horses, photos, compliance findings) in the
  field; a **Sync** button uploads to the cloud when signed in.
- **Web dashboard** (`dashboard/` → served at `/`) — sign in, watch synced
  assessments appear live, download a zip per assessment (docx report,
  horse table, photos), delete.
- **Backend** (`pocketbase/`) — one self-hosted [PocketBase](https://pocketbase.io)
  binary is the *entire* backend: SQLite database, auth, photo storage, the
  iOS sync endpoint, the admin UI (`/_/`), **and** it serves the built
  dashboard. One process, one port.

## Repo layout

```
equine-welfare/        iOS app (Xcode project at repo root)
dashboard/             Dashboard source (Vite + React + Tailwind)
pocketbase/            Backend: pb_migrations/ (schema), pb_hooks/ (sync
                       endpoint), scripts/ (user creation, e2e test).
                       Binary + pb_data/ + pb_public/ are NOT committed.
deploy/                Droplet deploy script + systemd unit
docs/superpowers/      Design specs + implementation plans for major work
CLAUDE.md              Working notes for AI-assisted development
```

## Run it locally

```bash
# 1. Backend — download the binary from github.com/pocketbase/pocketbase/releases
#    (v0.39.x for your platform) into pocketbase/, then:
cd pocketbase && ./pocketbase serve --http 0.0.0.0:8090
./pocketbase superuser upsert you@example.com <password>   # first time only
# schema self-applies from pb_migrations/; create app users in the admin UI
# (http://localhost:8090/_/) — there is deliberately NO self-registration

# 2. Dashboard — build into pocketbase/pb_public/ (PocketBase serves it at /)
cd dashboard && npm install && npm run build
# or hot-reload dev: cp .env.example .env && npm run dev  (localhost:5173)

# 3. iOS — copy equine-welfare/Config/Secrets.example.xcconfig to
#    Secrets.xcconfig (POCKETBASE_URL=http://localhost:8090 for Simulator,
#    your Mac's LAN IP for a physical iPad), open equine-welfare.xcodeproj
```

Sanity check the whole sync pipeline any time:
`./pocketbase/scripts/test_sync.sh <user-email> <password>` → `ALL PASS`.

## Deploy / release

`gh release create vX.Y.Z` triggers CI to build the dashboard and attach a
complete server bundle (linux binary + hooks + migrations + dashboard) to a
GitHub Release. On the server, `deploy/deploy.sh` bootstraps or updates in
place (systemd + automatic Let's Encrypt; never touches `pb_data/`).
Details in `pocketbase/README.md`.

## Data model & sync semantics (the parts that bite)

- iOS owns identity: every record carries an `externalId` (iOS UUID).
  Re-syncing an assessment **upserts** — children are wiped and re-inserted
  atomically; the cloud holds the latest snapshot only, no version history.
- Photos dedupe by `externalId` and deliberately **survive re-syncs**; they
  are only deleted when an assessment is deleted from the dashboard.
- All collection API rules require a signed-in user. `pb_data/` on the
  server is the only copy of production data — back it up accordingly.

## History

Backend lineage: Supabase → Convex + Clerk → **PocketBase** (Aug 2026).
The dashboard was a Next.js app in a separate `equine-frontend` submodule
(now retired, repo archived) before being rewritten in `dashboard/` and
served by PocketBase. Full rationale lives in `docs/superpowers/specs/`.
