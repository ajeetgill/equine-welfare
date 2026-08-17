# Handover: ship Horse C.O.P. to production

Doc for the Claude session that takes this project from "code complete" to
"delivered". Written 2026-08-16. Client details are deliberately NOT in this
public repo — they're in the session memory (`MEMORY.md` loads automatically;
see `client-and-billing.md`). "The client" below = the veterinarian customer.

## Where things stand

- **main**: PocketBase backend + Vite dashboard + iOS app, all migrated and
  e2e-tested. Release `v0.2.0` was verified end-to-end (CI bundle → Docker
  boot on ubuntu/amd64 → `test_sync.sh` ALL PASS).
- **PR #19 (`split-god-file`)**: NOT yet merged. Contains the
  PreviousAssessmentRow refactor, 33 unit tests + visual UI test, and COP
  edition stamping (iOS + server + dashboard + docx). The `copVersion`
  migration/hook/dashboard changes are ONLY on this branch — production must
  ship a release cut *after* this merges.
- Payment: quote Q-001 sent (valid until Sep 30, 2026); this session starts
  once it's accepted and paid.

## Ask Ajeet for these at session start (blockers)

1. Confirmation the payment landed.
2. **DigitalOcean account** access (created under the client's name) —
   login or team invite.
3. **Apple Developer account** access (client's; Program enrollment $99/yr
   must be completed — enrollment itself can take a day or two, prompt early).
   Ajeet will be publishing from this account.
4. **Domain name**: which one, and where it was bought (~$15/yr; registrar
   DNS must be pointable to the droplet). If none yet, help pick/buy one.
5. Email addresses for app accounts: the client + any team members.
6. A password manager location for the production superuser credential.

## Step-by-step to done

### 1. Merge PR #19
- Manual simulator pass first (5 min): sync an assessment, preview + share
  RTF, stop PocketBase mid-sync to see the error alert, delete a row.
- Test suite must be green:
  `xcodebuild test -scheme equine-welfare -destination 'id=<sim>' -only-testing:equine-welfareTests`
- Merge to main, delete the branch.

### 2. Cut the production release
- `gh release create v0.3.0 --target main --generate-notes` → CI attaches
  `equine-backend-linux-amd64.zip` (binary + hooks + migrations + dashboard).
- Verify: workflow success, asset present at
  `releases/latest/download/equine-backend-linux-amd64.zip`.

### 3. Server (DigitalOcean)
- Droplet: **Basic 1 GB / $6-mo**, Ubuntu 24.04 LTS, region Toronto (tor1),
  SSH key auth. No automated backups (decided; `pb_data/` is the only
  production data — document a manual `scp` backup line for Ajeet).
- DNS: A record `<domain>` → droplet IP.
- On the droplet, follow `pocketbase/README.md`: fetch `deploy/deploy.sh`
  from raw.githubusercontent, run it (bootstraps `pocketbase` user, systemd
  unit, prompts for the domain; PocketBase auto-provisions Let's Encrypt).
- Create the superuser (`/opt/equine/pocketbase superuser upsert …` as the
  service user) → store credential in the password manager.
- Create app users with `pocketbase/scripts/create_user.sh` (no
  self-registration by design).
- Verify: `PB_URL=https://<domain> ./pocketbase/scripts/test_sync.sh <user> <pw>`
  → ALL PASS, and the dashboard loads + signs in at `https://<domain>`.

### 4. iOS release build
- `equine-welfare/Config/Secrets.xcconfig`: `POCKETBASE_URL=https://<domain>`.
- **Before the first upload, consider renaming the bundle id** — it is
  currently `horse-thingy-v3.equine-welfare`, which will be visible in App
  Store Connect forever once used. Something like `com.ajeetgill.horsecop`.
  Rename BEFORE the first App Store Connect upload or never. (If renamed:
  the simulator camera/mic grant in AssessmentRowUITests' docs changes too.)
- Set the signing team to the client's Apple Developer team in Xcode.

### 5. TestFlight → App Store
- App Store Connect: create the app record (name "Horse C.O.P." or similar,
  primary language, bundle id).
- Archive in Xcode → upload → TestFlight internal testing → add the client
  as tester (internal testing needs no review).
- App Store submission needs: iPad + iPhone screenshots, description
  (plain language — the client is non-technical), a privacy policy URL
  (a simple GitHub Pages page is fine: data collected = email for sign-in,
  assessment data + photos stored on the client's own server), and a demo
  account for Apple's reviewer (create a `demo@` app user).

### 6. Client documentation (deliverable)
One-page, very plain language (client is non-technical), covering:
- Installing the app from TestFlight/App Store, signing in.
- Working offline in the field; the Sync button.
- The dashboard: sign in, watch assessments appear, download the report
  zip (Word report, horse table, photos), delete.
- How new team accounts get created (admin asks Ajeet / admin UI at
  `https://<domain>/_/` — superuser only).
- Who pays what: Apple $99/yr, droplet $6/mo, domain ~$15/yr.

### 7. Wrap up
- Update memory: invoice paid, deployed (domain, droplet region), TestFlight
  shipped, remaining future billables (new COP edition transcription,
  Android, push notifications, maintenance).
- Leave Ajeet a one-line "how to update the server later":
  `gh release create vX.Y.Z` then `sudo ./deploy.sh` on the droplet.

## Gotchas previous sessions already hit (don't re-learn these)

- **PocketBase 0.23+**: collections created via migrations with explicit
  field lists do NOT get `created`/`updated` autodate fields automatically
  (migration `1755200000` fixed this). Same applies to any new field: add
  via migration, restart to apply.
- PocketBase **rate-limits rapid auth requests** — back-to-back
  `test_sync.sh`/auth calls can 429 and look like flakes. Rerun.
- Rule-filtered list requests return **200 + empty** (not 401) for
  invalid/expired tokens.
- UI tests: `-parallel-testing-enabled NO` (the runner won't launch on
  simulator clones), and the simulator needs
  `xcrun simctl privacy <sim> grant camera|microphone <bundle-id>` once —
  otherwise the app's own permissions alert blocks assessment creation.
- `CLAUDE.md` is ignored by Ajeet's global gitignore — `git add -f` it.
- Local dev has leftover test users (`tester@example.com`,
  `e2e-admin@test.local`, `e2e-tester@test.local`) — local only, not
  production.
- The dashboard build output `pocketbase/pb_public/` is gitignored; CI
  builds it fresh for every release, so never commit it.
- iOS test simulator previously used: iPad Pro 13-inch (M4),
  id `F44FF2C4-2A1B-41C8-B31C-4625DA6B63D4` (this Mac).

## Future work already scoped (bill separately, do NOT do now)

- New Code of Practice edition (~4–5 months): transcribe into
  `Static-Data/COP.json`, bump `COPEdition.current`, ship app update.
  Architecture verified ready: assessments snapshot the COP at creation
  (`COPSnapshotTests` pins this), and every assessment/report carries its
  edition.
- `.externalStorage` on `MediaAttachment.data` (perf); requirement stable
  IDs (only if requirements ever become editable/reorderable).
