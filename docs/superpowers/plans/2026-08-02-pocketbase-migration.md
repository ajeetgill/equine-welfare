# PocketBase Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Convex (database + file storage) and Clerk (auth) with one locally hosted PocketBase instance for both the iOS app and the Next.js web dashboard.

**Architecture:** PocketBase v0.39.10 runs as a single binary in a new `pocketbase/` directory with version-controlled JS migrations (schema) and one JS hook route that ports the Convex `syncAssessment` mutation (atomic upsert-by-externalId). iOS drops the ConvexMobile + ClerkKit SDKs for a small `URLSession` client; web drops `convex` + `@clerk/nextjs` for the official `pocketbase` npm SDK. Spec: `docs/superpowers/specs/2026-08-02-pocketbase-migration-design.md`.

**Tech Stack:** PocketBase 0.39.10 (SQLite, JS hooks/migrations), Swift 6.1 / SwiftUI / SwiftData, Next.js 15 / React 19 / TypeScript, official `pocketbase` JS SDK.

## Global Constraints

- Branch `pocketbase-migration` in the root repo AND in the `equine-frontend` submodule (create the submodule branch in Task 8).
- PocketBase binary source: `/Users/ajeetgill/Downloads/pocketbase_0.39.10_darwin_arm64/pocketbase`. Binary and `pb_data/` are NEVER committed; `pb_migrations/`, `pb_hooks/`, scripts, and README are committed.
- Local hosting only: `./pocketbase serve --http 0.0.0.0:8090`. Admin UI at `http://localhost:8090/_/`.
- Auth: email + password only. No in-app registration — users are created by the superuser (users collection `createRule = null`).
- All six data collections require auth for every operation: rule `@request.auth.id != ""`.
- IDs: iOS-owned UUIDs live in `externalId` fields (unique-indexed). PocketBase record ids never reach the iOS client except as opaque return values.
- Media semantics preserved from Convex: media records survive re-syncs; duplicate `externalId` on upload = "already uploaded" success; requirement media keep the composite `parentId` = `"<assessmentUUID>_<sectionId>_<subIdx>_<reqIdx>"`; every media record also carries `assessmentExternalId`.
- Sync payload contract (iOS → hook, real JSON, no JSON-string wrapping):
  ```json
  {
    "assessment": {"externalId": "…", "vetName": "…", "farmName": "…", "visitDate": 1722600000000, "isComplete": false, "sideNotes": "…"},
    "horses": [{"externalId": "…", "name": "…", "age": 5, "ageUnit": "…", "color": "…", "sex": "…", "breed": "…", "otherBreed": "…", "timeOnFarm": 2, "timeUnit": "…", "bcsScore": 5, "notes": "…", "isHorse": true}],
    "sections": [{"sectionNumber": 1, "title": "…", "isApplicable": true, "infoIconClicks": 0, "subsections": [{"name": "…", "requirements": [{"text": "…", "complianceStatus": "…", "nonComplianceReason": "…"}]}]}]
  }
  ```
  `visitDate` is ms-since-epoch (what iOS already sends); the hook converts to ISO for PocketBase date fields.
- `mediaType` values are `"image"` and `"video"` (existing `MediaAttachment.mediaType.rawValue`).
- iOS builds must pass at the end of every iOS task: `xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build` (run from repo root). Web builds must pass at the end of every web task: `npm run build` in `equine-frontend`.
- Neither app has an automated test suite; verification is `xcodebuild`/`npm run build` plus the curl scripts and manual end-to-end checks defined below. The PocketBase hook gets a committed curl-based test script — run it after any hook change.
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: PocketBase local instance scaffolding

**Files:**
- Create: `pocketbase/.gitignore`
- Create: `pocketbase/README.md`
- Copy (not committed): `pocketbase/pocketbase`

**Interfaces:**
- Consumes: the downloaded binary at `/Users/ajeetgill/Downloads/pocketbase_0.39.10_darwin_arm64/pocketbase`.
- Produces: a runnable PocketBase at `http://localhost:8090` with a superuser account; `pocketbase/` directory layout every later task relies on.

- [ ] **Step 1: Create the directory and copy the binary**

```bash
mkdir -p pocketbase
cp /Users/ajeetgill/Downloads/pocketbase_0.39.10_darwin_arm64/pocketbase pocketbase/pocketbase
chmod +x pocketbase/pocketbase
```

- [ ] **Step 2: Write `pocketbase/.gitignore`**

```gitignore
pocketbase
pb_data/
```

- [ ] **Step 3: Write `pocketbase/README.md`**

````markdown
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
````

- [ ] **Step 4: Start the server and verify health**

```bash
cd pocketbase && nohup ./pocketbase serve --http 0.0.0.0:8090 > /tmp/pocketbase.log 2>&1 &
sleep 2
curl -s http://localhost:8090/api/health
```

Expected: JSON containing `"code":200`.

- [ ] **Step 5: Create the superuser**

```bash
cd pocketbase && ./pocketbase superuser upsert admin@example.com admin-password-123
```

Expected: `Successfully saved superuser "admin@example.com"!`. (Local-dev credentials; tell the user to change them for anything beyond local use.)

- [ ] **Step 6: Commit**

```bash
git add pocketbase/.gitignore pocketbase/README.md
git commit -m "feat(pocketbase): scaffold local PocketBase instance

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Collections schema migration

**Files:**
- Create: `pocketbase/pb_migrations/1754100000_create_equine_collections.js`
- Create: `pocketbase/scripts/create_user.sh`

**Interfaces:**
- Consumes: running PocketBase from Task 1.
- Produces: collections `assessments`, `horses`, `sections`, `subsections`, `requirements`, `media_attachments` with the exact field names the hook (Task 3), iOS client (Task 4), and web lib (Task 9) use. Users collection locked to superuser-created accounts. Relation field names are `assessment`, `section`, `subsection`, `uploadedBy`.

- [ ] **Step 1: Write the migration**

`pocketbase/pb_migrations/1754100000_create_equine_collections.js`:

```javascript
/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const authRule = '@request.auth.id != ""';
  const usersId = app.findCollectionByNameOrId("users").id;

  // No self-registration: only superusers create accounts.
  const users = app.findCollectionByNameOrId("users");
  users.createRule = null;
  app.save(users);

  const assessments = new Collection({
    type: "base",
    name: "assessments",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "externalId", type: "text", required: true },
      { name: "vetName", type: "text" },
      { name: "farmName", type: "text" },
      { name: "visitDate", type: "date" },
      { name: "isComplete", type: "bool" },
      { name: "sideNotes", type: "text" },
      { name: "syncedAt", type: "date" },
      { name: "uploadedBy", type: "relation", collectionId: usersId, maxSelect: 1, cascadeDelete: false },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_assessments_externalId ON assessments (externalId)"],
  });
  app.save(assessments);

  const horses = new Collection({
    type: "base",
    name: "horses",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "externalId", type: "text", required: true },
      { name: "assessment", type: "relation", collectionId: assessments.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "name", type: "text" },
      { name: "age", type: "number" },
      { name: "ageUnit", type: "text" },
      { name: "color", type: "text" },
      { name: "sex", type: "text" },
      { name: "breed", type: "text" },
      { name: "otherBreed", type: "text" },
      { name: "timeOnFarm", type: "number" },
      { name: "timeUnit", type: "text" },
      { name: "bcsScore", type: "number" },
      { name: "notes", type: "text" },
      { name: "isHorse", type: "bool" },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_horses_externalId ON horses (externalId)"],
  });
  app.save(horses);

  const sections = new Collection({
    type: "base",
    name: "sections",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "assessment", type: "relation", collectionId: assessments.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "sectionNumber", type: "number" },
      { name: "title", type: "text" },
      { name: "isApplicable", type: "bool" },
      { name: "infoIconClicks", type: "number" },
    ],
  });
  app.save(sections);

  const subsections = new Collection({
    type: "base",
    name: "subsections",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "section", type: "relation", collectionId: sections.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "name", type: "text" },
    ],
  });
  app.save(subsections);

  const requirements = new Collection({
    type: "base",
    name: "requirements",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "subsection", type: "relation", collectionId: subsections.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "text", type: "text" },
      { name: "complianceStatus", type: "text" },
      { name: "nonComplianceReason", type: "text" },
    ],
  });
  app.save(requirements);

  const media = new Collection({
    type: "base",
    name: "media_attachments",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "externalId", type: "text", required: true },
      {
        name: "parentType", type: "select", maxSelect: 1, required: true,
        values: ["horse_photo", "horse_front", "horse_right", "horse_back", "horse_left", "horse_abnormal", "requirement"],
      },
      { name: "parentId", type: "text", required: true },
      { name: "assessmentExternalId", type: "text", required: true },
      {
        name: "file", type: "file", maxSelect: 1, required: true, protected: true,
        maxSize: 104857600,
        mimeTypes: ["image/jpeg", "image/png", "image/heic", "video/mp4"],
      },
      { name: "mediaType", type: "select", maxSelect: 1, values: ["image", "video"] },
      { name: "creationDate", type: "date" },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_media_externalId ON media_attachments (externalId)",
      "CREATE INDEX idx_media_assessmentExternalId ON media_attachments (assessmentExternalId)",
    ],
  });
  app.save(media);
}, (app) => {
  for (const name of ["media_attachments", "requirements", "subsections", "sections", "horses", "assessments"]) {
    try { app.delete(app.findCollectionByNameOrId(name)); } catch (_) { /* already gone */ }
  }
  const users = app.findCollectionByNameOrId("users");
  users.createRule = "";
  app.save(users);
});
```

- [ ] **Step 2: Write `pocketbase/scripts/create_user.sh`**

```bash
#!/usr/bin/env bash
# Create an app user (assessor) as the superuser. Usage:
#   ./scripts/create_user.sh <superuser-email> <superuser-password> <new-user-email> <new-user-password>
set -euo pipefail
PB_URL="${PB_URL:-http://localhost:8090}"

SUTOKEN=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$1\",\"password\":\"$2\"}" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin)["token"])')

curl -s -X POST "$PB_URL/api/collections/users/records" \
  -H "Content-Type: application/json" \
  -H "Authorization: $SUTOKEN" \
  -d "{\"email\":\"$3\",\"password\":\"$4\",\"passwordConfirm\":\"$4\",\"verified\":true}"
echo
```

Then: `chmod +x pocketbase/scripts/create_user.sh`

- [ ] **Step 3: Restart PocketBase to apply the migration**

```bash
pkill -f "pocketbase serve" || true
cd pocketbase && nohup ./pocketbase serve --http 0.0.0.0:8090 > /tmp/pocketbase.log 2>&1 &
sleep 2
grep -i "migrat" /tmp/pocketbase.log; curl -s http://localhost:8090/api/health
```

Expected: log line about applying `1754100000_create_equine_collections.js`; health returns 200. If the migration has a syntax error, serve fails — read `/tmp/pocketbase.log`, fix, restart.

- [ ] **Step 4: Verify rules with curl**

```bash
# a) create a test app user
./pocketbase/scripts/create_user.sh admin@example.com admin-password-123 tester@example.com test-password-123

# b) unauthenticated write must fail
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8090/api/collections/assessments/records \
  -H "Content-Type: application/json" -d '{"externalId":"guest-attempt"}'
# Expected: 400 (rule failure)

# c) authenticated write must succeed, then clean up
TOKEN=$(curl -s -X POST http://localhost:8090/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"tester@example.com","password":"test-password-123"}' \
  | python3 -c 'import sys, json; print(json.load(sys.stdin)["token"])')
REC=$(curl -s -X POST http://localhost:8090/api/collections/assessments/records \
  -H "Content-Type: application/json" -H "Authorization: $TOKEN" \
  -d '{"externalId":"rule-check"}' | python3 -c 'import sys, json; print(json.load(sys.stdin)["id"])')
curl -s -o /dev/null -w "%{http_code}\n" -X DELETE \
  "http://localhost:8090/api/collections/assessments/records/$REC" -H "Authorization: $TOKEN"
# Expected: record id printed, then 204
```

- [ ] **Step 5: Commit**

```bash
git add pocketbase/pb_migrations pocketbase/scripts/create_user.sh
git commit -m "feat(pocketbase): equine collections schema + auth rules

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Sync hook endpoint

**Files:**
- Create: `pocketbase/pb_hooks/main.pb.js`
- Create: `pocketbase/scripts/test_sync.sh`

**Interfaces:**
- Consumes: collections from Task 2; sync payload contract from Global Constraints.
- Produces: `POST /api/equine/sync-assessment` (Authorization: user token; body = payload contract; 200 → `{"assessmentId": "<pb-record-id>"}`; 400 with `{"message": …}` on bad payload; 401 without token). iOS Task 4 calls exactly this.

- [ ] **Step 1: Write the hook**

`pocketbase/pb_hooks/main.pb.js`:

```javascript
/// <reference path="../pb_data/types.d.ts" />

// Atomic port of the Convex assessments:syncAssessment mutation.
// Upserts an assessment by externalId; on re-sync, child horses/sections are
// wiped and re-inserted (subsections/requirements cascade via their relation
// fields). Media records are intentionally untouched — their externalIds are
// stable across syncs and uploads dedupe on them.
routerAdd("POST", "/api/equine/sync-assessment", (e) => {
  const body = e.requestInfo().body;
  const assessment = body.assessment;
  const horses = Array.isArray(body.horses) ? body.horses : [];
  const sections = Array.isArray(body.sections) ? body.sections : [];

  if (!assessment || typeof assessment.externalId !== "string" || assessment.externalId === "") {
    throw new BadRequestError("assessment.externalId is required");
  }

  let assessmentId = "";

  $app.runInTransaction((txApp) => {
    const assessmentsCol = txApp.findCollectionByNameOrId("assessments");

    let record = null;
    try {
      record = txApp.findFirstRecordByData("assessments", "externalId", assessment.externalId);
    } catch (_) {
      record = null; // first sync of this assessment
    }

    if (record) {
      const oldHorses = txApp.findRecordsByFilter("horses", "assessment = {:id}", "", 0, 0, { id: record.id });
      for (const h of oldHorses) txApp.delete(h);
      const oldSections = txApp.findRecordsByFilter("sections", "assessment = {:id}", "", 0, 0, { id: record.id });
      for (const s of oldSections) txApp.delete(s);
    } else {
      record = new Record(assessmentsCol);
      record.set("externalId", assessment.externalId);
    }

    record.set("vetName", assessment.vetName || "");
    record.set("farmName", assessment.farmName || "");
    record.set("visitDate", new Date(assessment.visitDate).toISOString());
    record.set("isComplete", !!assessment.isComplete);
    record.set("sideNotes", assessment.sideNotes || "");
    record.set("syncedAt", new Date().toISOString());
    record.set("uploadedBy", e.auth.id);
    txApp.save(record);
    assessmentId = record.id;

    const horsesCol = txApp.findCollectionByNameOrId("horses");
    for (const horse of horses) {
      const h = new Record(horsesCol);
      h.set("externalId", horse.externalId);
      h.set("assessment", assessmentId);
      h.set("name", horse.name || "");
      h.set("age", horse.age || 0);
      h.set("ageUnit", horse.ageUnit || "");
      h.set("color", horse.color || "");
      h.set("sex", horse.sex || "");
      h.set("breed", horse.breed || "");
      h.set("otherBreed", horse.otherBreed || "");
      h.set("timeOnFarm", horse.timeOnFarm || 0);
      h.set("timeUnit", horse.timeUnit || "");
      h.set("bcsScore", horse.bcsScore || 0);
      h.set("notes", horse.notes || "");
      h.set("isHorse", !!horse.isHorse);
      txApp.save(h);
    }

    const sectionsCol = txApp.findCollectionByNameOrId("sections");
    const subsectionsCol = txApp.findCollectionByNameOrId("subsections");
    const requirementsCol = txApp.findCollectionByNameOrId("requirements");
    for (const section of sections) {
      const s = new Record(sectionsCol);
      s.set("assessment", assessmentId);
      s.set("sectionNumber", section.sectionNumber || 0);
      s.set("title", section.title || "");
      s.set("isApplicable", !!section.isApplicable);
      s.set("infoIconClicks", section.infoIconClicks || 0);
      txApp.save(s);

      const subsections = Array.isArray(section.subsections) ? section.subsections : [];
      for (const subsection of subsections) {
        const sub = new Record(subsectionsCol);
        sub.set("section", s.id);
        sub.set("name", subsection.name || "");
        txApp.save(sub);

        const requirements = Array.isArray(subsection.requirements) ? subsection.requirements : [];
        for (const requirement of requirements) {
          const r = new Record(requirementsCol);
          r.set("subsection", sub.id);
          r.set("text", requirement.text || "");
          r.set("complianceStatus", requirement.complianceStatus || "");
          r.set("nonComplianceReason", requirement.nonComplianceReason || "");
          txApp.save(r);
        }
      }
    }
  });

  return e.json(200, { assessmentId: assessmentId });
}, $apis.requireAuth());
```

- [ ] **Step 2: Write the test script**

`pocketbase/scripts/test_sync.sh`:

```bash
#!/usr/bin/env bash
# End-to-end test of the sync endpoint. Usage:
#   ./scripts/test_sync.sh <user-email> <user-password>
set -euo pipefail
PB_URL="${PB_URL:-http://localhost:8090}"

TOKEN=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$1\",\"password\":\"$2\"}" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin)["token"])')

PAYLOAD='{
  "assessment": {"externalId": "11111111-2222-3333-4444-555555555555", "vetName": "Dr. Test", "farmName": "Test Farm", "visitDate": 1754100000000, "isComplete": true, "sideNotes": "test note"},
  "horses": [{"externalId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "name": "Testy", "age": 5, "ageUnit": "years", "color": "bay", "sex": "mare", "breed": "Arabian", "otherBreed": "", "timeOnFarm": 2, "timeUnit": "years", "bcsScore": 5, "notes": "", "isHorse": true}],
  "sections": [{"sectionNumber": 1, "title": "Nutrition", "isApplicable": true, "infoIconClicks": 3, "subsections": [{"name": "Feed", "requirements": [{"text": "Adequate feed", "complianceStatus": "Compliant", "nonComplianceReason": ""}]}]}]
}'

echo "-- guest request (expect 401):"
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$PB_URL/api/equine/sync-assessment" \
  -H "Content-Type: application/json" -d "$PAYLOAD"

echo "-- first sync:"
ID1=$(curl -s -X POST "$PB_URL/api/equine/sync-assessment" \
  -H "Content-Type: application/json" -H "Authorization: $TOKEN" -d "$PAYLOAD" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin)["assessmentId"])')
echo "assessmentId: $ID1"

echo "-- re-sync (expect SAME id — upsert, not duplicate):"
ID2=$(curl -s -X POST "$PB_URL/api/equine/sync-assessment" \
  -H "Content-Type: application/json" -H "Authorization: $TOKEN" -d "$PAYLOAD" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin)["assessmentId"])')
echo "assessmentId: $ID2"
[ "$ID1" = "$ID2" ] && echo "PASS: upsert kept the same record" || { echo "FAIL: duplicate assessment"; exit 1; }

echo "-- horse count after re-sync (expect 1):"
curl -s "$PB_URL/api/collections/horses/records?filter=(assessment='$ID1')" -H "Authorization: $TOKEN" \
  | python3 -c 'import sys, json; d = json.load(sys.stdin); print(d["totalItems"]); sys.exit(0 if d["totalItems"] == 1 else 1)'

echo "-- bad payload (expect 400):"
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$PB_URL/api/equine/sync-assessment" \
  -H "Content-Type: application/json" -H "Authorization: $TOKEN" -d '{"horses": []}'

echo "-- cleanup:"
curl -s -o /dev/null -w "%{http_code}\n" -X DELETE \
  "$PB_URL/api/collections/assessments/records/$ID1" -H "Authorization: $TOKEN"
echo "ALL PASS"
```

Then: `chmod +x pocketbase/scripts/test_sync.sh`

- [ ] **Step 3: Restart PocketBase (hooks load at startup) and run the test — expect failures first if the hook file has errors**

```bash
pkill -f "pocketbase serve" || true
cd pocketbase && nohup ./pocketbase serve --http 0.0.0.0:8090 > /tmp/pocketbase.log 2>&1 &
sleep 2
./scripts/test_sync.sh tester@example.com test-password-123
```

Expected output, in order: `401`, an assessmentId, the same assessmentId + `PASS`, `1`, `400`, `204`, `ALL PASS`. If any step fails, read `/tmp/pocketbase.log`, fix the hook, restart, re-run.

- [ ] **Step 4: Commit**

```bash
git add pocketbase/pb_hooks pocketbase/scripts/test_sync.sh
git commit -m "feat(pocketbase): atomic sync-assessment hook endpoint + test script

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: iOS PocketBase client (additive — no Convex/Clerk removal yet)

**Files:**
- Create: `equine-welfare/Config/PocketBaseConfig.swift`
- Create: `equine-welfare/Services/KeychainStore.swift`
- Create: `equine-welfare/Services/PocketBaseService.swift`
- Modify: `equine-welfare/Info.plist` (add `POCKETBASE_URL` key + ATS; keep old keys until Task 6)
- Modify: `equine-welfare/Config/Secrets.example.xcconfig` (add `POCKETBASE_URL`; keep old keys until Task 6)

**Interfaces:**
- Consumes: hook endpoint from Task 3; `Assessment`/`Horse`/`MediaAttachment` SwiftData models (existing).
- Produces (used by Task 5):
  - `PocketBaseService.shared` — `@Observable`, `private(set) var isSignedIn: Bool`, `private(set) var userEmail: String?`
  - `func signIn(email: String, password: String) async throws`
  - `func signOut()`
  - `func syncAssessment(_ assessment: Assessment, progressHandler: ((String, Double) -> Void)?) async throws`
  - `enum PocketBaseError: LocalizedError` — cases `.notSignedIn`, `.server(String)`, `.uploadFailed`, `.invalidResponse`

- [ ] **Step 1: Check how the Xcode project picks up new files**

```bash
grep -c "fileSystemSynchronized" equine-welfare.xcodeproj/project.pbxproj || true
```

If the count is ≥ 1, the target uses synchronized folders and new `.swift` files under `equine-welfare/` compile automatically. If 0, each created file must also be registered in `project.pbxproj` — in that case, after creating the files, STOP and ask the user to add the three new files to the target in Xcode (drag into the project navigator), then continue.

- [ ] **Step 2: Write `equine-welfare/Config/PocketBaseConfig.swift`**

```swift
import Foundation

enum PocketBaseConfig {
    static var baseURL: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "POCKETBASE_URL") as? String,
              !raw.isEmpty,
              let url = URL(string: raw) else {
            fatalError("POCKETBASE_URL not found in Info.plist. Add it to your Secrets.xcconfig file.")
        }
        return url
    }
}
```

- [ ] **Step 3: Write `equine-welfare/Services/KeychainStore.swift`**

```swift
import Foundation
import Security

/// Minimal Keychain wrapper for the PocketBase auth token and account email.
enum KeychainStore {
    private static let service = "com.equine-welfare.pocketbase"

    static var token: String? {
        get { read("authToken") }
        set { write("authToken", newValue) }
    }

    static var email: String? {
        get { read("userEmail") }
        set { write("userEmail", newValue) }
    }

    private static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ account: String, _ value: String?) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }
}
```

- [ ] **Step 4: Write `equine-welfare/Services/PocketBaseService.swift`**

The sync serialization is copied from `ConvexService.syncAssessment` (same dictionaries, same progress fractions) — only the transport changes: one JSON POST to the hook, then one multipart POST per media file.

```swift
import Foundation

enum PocketBaseError: LocalizedError {
    case notSignedIn
    case server(String)
    case uploadFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in required to sync. Please sign in and try again."
        case .server(let message):
            return message
        case .uploadFailed:
            return "Failed to upload media file"
        case .invalidResponse:
            return "Unexpected response from the server"
        }
    }
}

@Observable
final class PocketBaseService {
    static let shared = PocketBaseService()

    private(set) var isSignedIn: Bool
    private(set) var userEmail: String?

    private init() {
        isSignedIn = KeychainStore.token != nil
        userEmail = KeychainStore.email
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        var request = URLRequest(url: PocketBaseConfig.baseURL.appending(path: "api/collections/users/auth-with-password"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["identity": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.invalidResponse }
        guard http.statusCode == 200 else {
            throw PocketBaseError.server(Self.serverMessage(from: data) ?? "Sign-in failed. Check your email and password.")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              let record = json["record"] as? [String: Any] else {
            throw PocketBaseError.invalidResponse
        }
        KeychainStore.token = token
        KeychainStore.email = record["email"] as? String ?? email
        isSignedIn = true
        userEmail = KeychainStore.email
    }

    func signOut() {
        // PocketBase tokens are stateless — signing out is purely local.
        KeychainStore.token = nil
        KeychainStore.email = nil
        isSignedIn = false
        userEmail = nil
    }

    /// Validates the stored token and rotates it. A 401/403 means the token
    /// expired or the user was deleted — clear local auth so the sign-in
    /// sheet is shown again.
    private func refreshAuth() async throws {
        guard let token = KeychainStore.token else { throw PocketBaseError.notSignedIn }
        var request = URLRequest(url: PocketBaseConfig.baseURL.appending(path: "api/collections/users/auth-refresh"))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 {
            signOut()
            throw PocketBaseError.notSignedIn
        }
        guard http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["token"] as? String else {
            throw PocketBaseError.invalidResponse
        }
        KeychainStore.token = newToken
    }

    // MARK: - Sync Assessment

    func syncAssessment(_ assessment: Assessment, progressHandler: ((String, Double) -> Void)? = nil) async throws {
        try await refreshAuth()

        progressHandler?("Preparing assessment data...", 0.1)

        let assessmentDict: [String: Any] = [
            "externalId": assessment.id.uuidString,
            "vetName": assessment.vetName,
            "farmName": assessment.farmName,
            "visitDate": assessment.visitDate.timeIntervalSince1970 * 1000,
            "isComplete": assessment.isComplete,
            "sideNotes": assessment.sideNotes ?? ""
        ]

        progressHandler?("Preparing horse data...", 0.2)

        var horsesArray: [[String: Any]] = []
        for horse in assessment.horses {
            horsesArray.append([
                "externalId": horse.uuid.uuidString,
                "name": horse.name,
                "age": horse.age,
                "color": horse.color,
                "sex": horse.sex,
                "breed": horse.breed,
                "otherBreed": horse.otherBreed ?? "",
                "timeOnFarm": horse.timeOnFarm,
                "bcsScore": horse.bcsScore,
                "notes": horse.notes ?? "",
                "ageUnit": horse.ageUnit.rawValue,
                "timeUnit": horse.timeUnit.rawValue,
                "isHorse": horse.isHorse
            ])
        }

        progressHandler?("Preparing section data...", 0.3)

        var sectionsArray: [[String: Any]] = []
        for section in assessment.sections where section.isApplicable {
            var subsectionsArray: [[String: Any]] = []
            for subsection in section.subsections {
                var requirementsArray: [[String: Any]] = []
                for req in subsection.requirements {
                    requirementsArray.append([
                        "text": req.text,
                        "complianceStatus": req.complianceStatus?.rawValue ?? "",
                        "nonComplianceReason": req.nonComplianceReason ?? ""
                    ])
                }
                subsectionsArray.append([
                    "name": subsection.name,
                    "requirements": requirementsArray
                ])
            }
            sectionsArray.append([
                "sectionNumber": section.id,
                "title": section.title,
                "isApplicable": section.isApplicable,
                "infoIconClicks": section.infoIconClicks,
                "subsections": subsectionsArray
            ])
        }

        progressHandler?("Syncing to server...", 0.5)

        var request = URLRequest(url: PocketBaseConfig.baseURL.appending(path: "api/equine/sync-assessment"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(KeychainStore.token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "assessment": assessmentDict,
            "horses": horsesArray,
            "sections": sectionsArray
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 {
            signOut()
            throw PocketBaseError.notSignedIn
        }
        guard http.statusCode == 200 else {
            throw PocketBaseError.server(Self.serverMessage(from: data) ?? "Sync failed. Please try again later.")
        }

        // MARK: Upload horse photos (progress 0.6 to 0.9)

        let assessmentExternalId = assessment.id.uuidString
        let horses = assessment.horses
        let totalHorses = horses.count

        for (horseIndex, horse) in horses.enumerated() {
            let horseId = horse.uuid.uuidString
            let horseProgress = 0.6 + (0.3 * Double(horseIndex) / Double(max(totalHorses, 1)))
            progressHandler?("Uploading photos for \(horse.name)...", horseProgress)

            var photoUploads: [(MediaAttachment, String)] = []
            if let photo = horse.photoData { photoUploads.append((photo, "horse_photo")) }
            if let front = horse.frontPhotoData { photoUploads.append((front, "horse_front")) }
            if let right = horse.rightPhotoData { photoUploads.append((right, "horse_right")) }
            if let back = horse.backPhotoData { photoUploads.append((back, "horse_back")) }
            if let left = horse.leftPhotoData { photoUploads.append((left, "horse_left")) }
            for abnormal in horse.abnormalPhotosData { photoUploads.append((abnormal, "horse_abnormal")) }

            for (attachment, parentType) in photoUploads {
                try await uploadMedia(
                    data: attachment.data,
                    externalId: attachment.id.uuidString,
                    parentType: parentType,
                    parentId: horseId,
                    assessmentExternalId: assessmentExternalId,
                    mediaType: attachment.mediaType.rawValue
                )
            }
        }

        // MARK: Upload requirement media (progress 0.9 to 0.95)

        progressHandler?("Uploading requirement media...", 0.9)

        for section in assessment.sections where section.isApplicable {
            for (subIdx, subsection) in section.subsections.enumerated() {
                for (reqIdx, requirement) in subsection.requirements.enumerated() {
                    guard !requirement.mediaAttachments.isEmpty else { continue }
                    let parentId = "\(assessment.id.uuidString)_\(section.id)_\(subIdx)_\(reqIdx)"
                    for attachment in requirement.mediaAttachments {
                        try await uploadMedia(
                            data: attachment.data,
                            externalId: attachment.id.uuidString,
                            parentType: "requirement",
                            parentId: parentId,
                            assessmentExternalId: assessmentExternalId,
                            mediaType: attachment.mediaType.rawValue
                        )
                    }
                }
            }
        }

        progressHandler?("Sync complete!", 1.0)
    }

    // MARK: - Upload Media

    /// One multipart record-create per file. A duplicate externalId means the
    /// file already landed in a previous (partial) sync — treated as success
    /// so retries stay idempotent, matching the old Convex saveFile dedupe.
    func uploadMedia(data: Data, externalId: String, parentType: String, parentId: String,
                     assessmentExternalId: String, mediaType: String) async throws {
        guard let token = KeychainStore.token else { throw PocketBaseError.notSignedIn }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: PocketBaseConfig.baseURL.appending(path: "api/collections/media_attachments/records"))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        addField("externalId", externalId)
        addField("parentType", parentType)
        addField("parentId", parentId)
        addField("assessmentExternalId", assessmentExternalId)
        addField("mediaType", mediaType)
        addField("creationDate", ISO8601DateFormatter().string(from: Date()))

        let isImage = mediaType == "image"
        let filename = "\(externalId).\(isImage ? "jpg" : "mp4")"
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(isImage ? "image/jpeg" : "video/mp4")\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.invalidResponse }
        switch http.statusCode {
        case 200:
            return
        case 400 where Self.isDuplicateExternalId(responseData):
            return
        case 401, 403:
            signOut()
            throw PocketBaseError.notSignedIn
        default:
            throw PocketBaseError.uploadFailed
        }
    }

    // MARK: - Response parsing

    private static func serverMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String, !message.isEmpty else { return nil }
        return message
    }

    private static func isDuplicateExternalId(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fieldErrors = json["data"] as? [String: Any],
              let externalIdError = fieldErrors["externalId"] as? [String: Any],
              let code = externalIdError["code"] as? String else { return false }
        return code == "validation_not_unique"
    }
}
```

- [ ] **Step 5: Add `POCKETBASE_URL` + ATS to `equine-welfare/Info.plist`**

Add inside the top-level `<dict>` (keep the existing CONVEX/CLERK keys for now — they go in Task 6):

```xml
	<key>POCKETBASE_URL</key>
	<string>$(POCKETBASE_URL)</string>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
```

(`NSAllowsLocalNetworking` permits plain-HTTP to localhost/LAN hosts. If a physical-device test is still blocked by ATS, the dev-only fallback is `NSAllowsArbitraryLoads` — flag it to the user rather than committing it silently.)

- [ ] **Step 6: Add `POCKETBASE_URL` to `equine-welfare/Config/Secrets.example.xcconfig`** (append; old keys removed in Task 6)

```
// PocketBase server URL (local dev; use your Mac's LAN IP for a physical iPad)
// Note: Use $() to escape // in URLs — xcconfig treats // as a comment delimiter
POCKETBASE_URL = http:/$()/localhost:8090
```

Also append the same line to the user's untracked `equine-welfare/Config/Secrets.xcconfig` (it exists locally; do not commit it).

- [ ] **Step 7: Build**

```bash
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```

Expected: BUILD SUCCEEDED (new files are additive; Convex/Clerk code untouched).

- [ ] **Step 8: Commit**

```bash
git add equine-welfare/Config/PocketBaseConfig.swift equine-welfare/Services/KeychainStore.swift \
  equine-welfare/Services/PocketBaseService.swift equine-welfare/Info.plist \
  equine-welfare/Config/Secrets.example.xcconfig
git commit -m "feat(ios): PocketBase client service, keychain store, config

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: iOS sign-in UI + swap call sites to PocketBase

**Files:**
- Create: `equine-welfare/Views/SignInSheet.swift`
- Modify: `equine-welfare/Views/PreviousAssessmentRow.swift`
- Modify: `equine-welfare/Views/AccountMenu.swift`
- Modify: `equine-welfare/equine_welfareApp.swift`

**Interfaces:**
- Consumes: `PocketBaseService.shared` (`isSignedIn`, `userEmail`, `signIn`, `signOut`, `syncAssessment`) and `PocketBaseError` from Task 4.
- Produces: app no longer references `Clerk`/`AuthView` anywhere; `ConvexService`/`ClerkAuth` become dead code (deleted in Task 6).

- [ ] **Step 1: Write `equine-welfare/Views/SignInSheet.swift`**

```swift
import SwiftUI

/// Email + password sign-in against PocketBase. Replaces Clerk's AuthView.
/// Accounts are created by the administrator — there is no sign-up here.
struct SignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSigningIn = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button {
                        signIn()
                    } label: {
                        if isSigningIn {
                            ProgressView()
                        } else {
                            Text("Sign In")
                        }
                    }
                    .disabled(isSigningIn || email.isEmpty || password.isEmpty)
                } footer: {
                    Text("Accounts are created by your administrator.")
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func signIn() {
        isSigningIn = true
        errorMessage = nil
        Task {
            do {
                try await PocketBaseService.shared.signIn(email: email, password: password)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}

#Preview {
    SignInSheet()
}
```

- [ ] **Step 2: Update `equine-welfare/Views/PreviousAssessmentRow.swift`**

Four changes:

a) Delete the Clerk imports (lines `import ClerkKit` and `import ClerkKitUI`).

b) Replace the whole `syncToConvex()` function (lines 83–130) with:

```swift
    // Sync assessment to PocketBase
    private func syncToCloud() async {
        isUploading = true
        uploadProgress = 0.1

        do {
            try await PocketBaseService.shared.syncAssessment(assessment) { message, progress in
                self.uploadProgress = progress
                self.isUploadingMedia = message.contains("media")
            }

            uploadSuccessMessage = "Assessment synced successfully!"
            showUploadSuccess = true
            uploadError = nil
            isUploadingMedia = false
            uploadProgress = 1.0

        } catch let error as PocketBaseError {
            // PocketBase errors are structured — no string matching needed.
            uploadError = error.localizedDescription
            showUploadAlert = true
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost:
                uploadError = "Could not reach the sync server. Check that you're on the same network and PocketBase is running."
            default:
                uploadError = "Sync failed. Please try again later."
            }
            showUploadAlert = true
        } catch {
            uploadError = "Sync failed. Please try again later."
            showUploadAlert = true
        }

        isUploading = false
        uploadProgress = 0.0
    }
```

c) In `uploadButton`, replace the sign-in gate:

```swift
            // Sync is the only feature that needs an account — everything
            // else works offline. Prompt for sign-in just-in-time.
            if !PocketBaseService.shared.isSignedIn {
                showSignIn = true
            } else {
                Task {
                    await syncToCloud()
                }
            }
```

d) Replace the sheet (the `.sheet(isPresented: $showSignIn, ...)` modifier):

```swift
        .sheet(isPresented: $showSignIn, onDismiss: {
            // Continue the sync the user asked for once they're signed in.
            if PocketBaseService.shared.isSignedIn {
                Task {
                    await syncToCloud()
                }
            }
        }) {
            SignInSheet()
        }
```

- [ ] **Step 3: Rewrite `equine-welfare/Views/AccountMenu.swift`**

```swift
import SwiftUI

/// Toolbar account control. Cloud sync is the only feature that needs an
/// account, so this only appears once the user has signed in (via the sync
/// flow). It shows who's signed in and lets them sign out.
///
/// Sign-out only clears the locally stored PocketBase token. Local data is
/// untouched — signing out just revokes the ability to sync until someone
/// signs in again.
struct AccountMenu: View {
    // PocketBaseService is @Observable — reading isSignedIn here re-renders
    // on sign in / sign out, so the button appears and disappears.
    private var service = PocketBaseService.shared

    var body: some View {
        if service.isSignedIn {
            Menu {
                if let email = service.userEmail {
                    Text(email)
                }
                Button(role: .destructive) {
                    service.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "person.crop.circle")
                    .accessibilityLabel("Account")
            }
        }
    }
}
```

- [ ] **Step 4: Update `equine-welfare/equine_welfareApp.swift`**

Delete `import ClerkKit` and the whole `init()` block (Clerk.configure was its only content). PocketBase needs no app-launch configuration.

- [ ] **Step 5: Build**

```bash
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```

Expected: BUILD SUCCEEDED. `ConvexService.swift`/`ClerkAuth.swift` still compile (they still reference the installed SDKs) but nothing calls them anymore.

- [ ] **Step 6: Commit**

```bash
git add equine-welfare/Views/SignInSheet.swift equine-welfare/Views/PreviousAssessmentRow.swift \
  equine-welfare/Views/AccountMenu.swift equine-welfare/equine_welfareApp.swift
git commit -m "feat(ios): PocketBase sign-in sheet, swap sync + account UI off Clerk

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: iOS — remove Convex + Clerk packages, files, and config

**Files:**
- Delete: `equine-welfare/Services/ConvexService.swift`, `equine-welfare/Services/ClerkAuth.swift`, `equine-welfare/Config/ConvexConfig.swift`
- Modify: `equine-welfare.xcodeproj/project.pbxproj` (remove SPM package references)
- Modify: `equine-welfare/Info.plist` (remove CONVEX/CLERK keys)
- Modify: `equine-welfare/Config/Secrets.example.xcconfig` (remove CONVEX/CLERK keys)

**Interfaces:**
- Consumes: Task 5 (nothing references Convex/Clerk symbols anymore).
- Produces: dependency-free iOS build — `ConvexMobile`, `ClerkKit`, `ClerkKitUI` gone from `project.pbxproj` and `Package.resolved`.

- [ ] **Step 1: Delete the dead source files**

```bash
git rm equine-welfare/Services/ConvexService.swift equine-welfare/Services/ClerkAuth.swift \
  equine-welfare/Config/ConvexConfig.swift
```

- [ ] **Step 2: Remove the SPM packages from `project.pbxproj`**

Find every reference first:

```bash
grep -n "clerk-ios\|convex-swift\|ClerkKit\|ConvexMobile" equine-welfare.xcodeproj/project.pbxproj
```

Remove, for BOTH packages (`clerk-ios`, `convex-swift`) and all THREE products (`ClerkKit`, `ClerkKitUI`, `ConvexMobile`):
1. The `XCRemoteSwiftPackageReference` blocks (in `/* Begin XCRemoteSwiftPackageReference section */`) and the lines referencing them in the project's `packageReferences = (...)` list.
2. The `XCSwiftPackageProductDependency` blocks and the lines referencing them in the target's `packageProductDependencies = (...)` list.
3. The `PBXBuildFile` lines for those products and their entries in the Frameworks build phase's `files = (...)` list.

Do not touch the `MijickCamera` package entries. Preserve the pbxproj format exactly (tabs, trailing commas, comment annotations).

- [ ] **Step 3: Clean Info.plist and xcconfig**

- `equine-welfare/Info.plist`: delete the `CONVEX_URL` and `CLERK_PUBLISHABLE_KEY` key/string pairs (keep `POCKETBASE_URL` and `NSAppTransportSecurity`).
- `equine-welfare/Config/Secrets.example.xcconfig`: delete the `CONVEX_URL` and `CLERK_PUBLISHABLE_KEY` lines and their comments (keep `POCKETBASE_URL`).
- Tell the user their local `Secrets.xcconfig` can drop the same two keys.

- [ ] **Step 4: Build (forces package re-resolution)**

```bash
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
grep -i "clerk\|convex" equine-welfare.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved || echo "packages fully removed"
```

Expected: BUILD SUCCEEDED and "packages fully removed" (Clerk's transitive deps — Nuke, PhoneNumberKit etc. — drop out of `Package.resolved` too). If the build fails on pbxproj parsing, restore with `git checkout -- equine-welfare.xcodeproj/project.pbxproj` and redo Step 2 more carefully.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(ios): remove Convex and Clerk SDKs, dead services, stale config

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: iOS end-to-end verification (Simulator ↔ local PocketBase)

**Files:** none (verification checkpoint).

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: verified iOS sync path; go/no-go for the web tasks.

- [ ] **Step 1: Ensure PocketBase is running** (`curl -s http://localhost:8090/api/health`; restart per Task 1 Step 4 if not).

- [ ] **Step 2: Confirm the user's `Secrets.xcconfig` has `POCKETBASE_URL = http:/$()/localhost:8090`** (Simulator shares the Mac's localhost).

- [ ] **Step 3: Run the app in the Simulator**

Launch via Xcode (⌘R) or `xcodebuild ... build` + `xcrun simctl launch`. Then walk this checklist (ask the user to drive if Simulator interaction isn't available to the executor):

1. Create a small assessment (1 horse with a photo, 1 applicable section, a requirement answered).
2. Tap Sync while signed out → SignInSheet appears.
3. Sign in as `tester@example.com` / `test-password-123` → sheet dismisses → sync runs to completion with progress.
4. Admin UI (`http://localhost:8090/_/`): `assessments` has 1 record, `horses` 1, `sections`/`subsections`/`requirements` populated, `media_attachments` has the photo with a stored file, `uploadedBy` set.
5. Tap Sync again → success; record counts unchanged (upsert + media dedupe).
6. Account menu shows the email; Sign Out; Sync → sign-in sheet reappears.
7. Wrong password in the sheet → readable error, sheet stays up.
8. Stop PocketBase (`pkill -f "pocketbase serve"`), tap Sync → "Could not reach the sync server..." alert. Restart PocketBase afterwards.

- [ ] **Step 4: Report results** — any failure here goes back to the task that owns the broken piece before continuing to web.

---

### Task 8: Web — PocketBase client + auth swap (Clerk removal)

All file paths in Tasks 8–9 are relative to `equine-frontend/` (the git submodule — commits happen inside it).

**Files:**
- Create branch: `pocketbase-migration` in the submodule
- Create: `lib/pocketbase.ts`, `components/backend-error.tsx`, `app/(auth-pages)/sign-in/page.tsx`
- Modify: `package.json` (drop `@clerk/nextjs`, add `pocketbase`), `middleware.ts`, `components/header-auth.tsx`, `app/layout.tsx`, `app/page.tsx`, `.env.example`, minimal edits to `app/protected/page.tsx`
- Delete: `components/providers.tsx`, `app/(auth-pages)/sign-in/[[...sign-in]]/`, `app/(auth-pages)/sign-up/`, `app/(auth-pages)/forgot-password/`, `app/protected/reset-password/`

**Interfaces:**
- Consumes: PocketBase server (Tasks 1–3).
- Produces (used by Task 9): `getPocketBase(): PocketBase` from `lib/pocketbase.ts` (browser singleton, cookie-persisted auth); `BackendErrorMessage({ message }: { message: string })` from `components/backend-error.tsx`. Auth cookie name: `pb_auth`.

- [ ] **Step 1: Branch + dependencies**

```bash
cd equine-frontend
git checkout -b pocketbase-migration
npm uninstall @clerk/nextjs
npm install pocketbase
```

- [ ] **Step 2: Write `lib/pocketbase.ts`**

```typescript
import PocketBase from "pocketbase";

export const POCKETBASE_URL =
  process.env.NEXT_PUBLIC_POCKETBASE_URL ?? "http://localhost:8090";

let client: PocketBase | null = null;

// Browser-side singleton. Auth state round-trips through the `pb_auth` cookie
// so middleware.ts can gate /protected without a server call.
export function getPocketBase(): PocketBase {
  if (!client) {
    client = new PocketBase(POCKETBASE_URL);
    if (typeof document !== "undefined") {
      client.authStore.loadFromCookie(document.cookie);
      client.authStore.onChange(() => {
        document.cookie = client!.authStore.exportToCookie({
          httpOnly: false,
          secure: false, // local-dev HTTP; revisit for production TLS
        });
      });
    }
  }
  return client;
}
```

- [ ] **Step 3: Write `components/backend-error.tsx`** (replaces `providers.tsx`'s `ConvexErrorMessage`)

```tsx
export function BackendErrorMessage({ message }: { message: string }) {
  return (
    <div className="flex items-center justify-center min-h-[50vh]">
      <div className="max-w-md p-6 rounded-lg border border-red-300 bg-red-50 dark:border-red-800 dark:bg-red-950">
        <h2 className="text-lg font-semibold text-red-800 dark:text-red-200 mb-2">
          Backend Unavailable
        </h2>
        <p className="text-sm text-red-700 dark:text-red-300 mb-4">{message}</p>
        <p className="text-xs text-red-600 dark:text-red-400">
          Make sure PocketBase is running:{" "}
          <code className="bg-red-100 dark:bg-red-900 px-1.5 py-0.5 rounded">
            ./pocketbase serve --http 0.0.0.0:8090
          </code>
        </p>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Replace the sign-in page**

```bash
rm -rf "app/(auth-pages)/sign-in/[[...sign-in]]" "app/(auth-pages)/sign-up" "app/(auth-pages)/forgot-password" app/protected/reset-password
```

Write `app/(auth-pages)/sign-in/page.tsx`:

```tsx
"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { getPocketBase } from "@/lib/pocketbase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export default function SignInPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      await getPocketBase().collection("users").authWithPassword(email, password);
      router.push("/protected");
    } catch {
      setError("Sign-in failed. Check your email and password.");
      setSubmitting(false);
    }
  };

  return (
    <div className="flex min-h-[60vh] items-center justify-center">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4 w-80">
        <h1 className="text-2xl font-medium">Sign in</h1>
        <div className="flex flex-col gap-2">
          <Label htmlFor="email">Email</Label>
          <Input id="email" type="email" value={email}
            onChange={(e) => setEmail(e.target.value)} required />
        </div>
        <div className="flex flex-col gap-2">
          <Label htmlFor="password">Password</Label>
          <Input id="password" type="password" value={password}
            onChange={(e) => setPassword(e.target.value)} required />
        </div>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <Button type="submit" disabled={submitting}>
          {submitting ? "Signing in..." : "Sign in"}
        </Button>
        <p className="text-xs text-muted-foreground">
          Accounts are created by the administrator.
        </p>
      </form>
    </div>
  );
}
```

- [ ] **Step 5: Rewrite `middleware.ts`** (no SDK import — decodes the cookie's JWT `exp` directly, safe for the edge runtime)

```typescript
import { NextRequest, NextResponse } from "next/server";

// The pb_auth cookie holds {"token": "<jwt>", "record": {...}} written by
// lib/pocketbase.ts. Validity here = well-formed token that hasn't expired;
// PocketBase itself re-checks the token on every API call.
function hasValidAuthCookie(value: string | undefined): boolean {
  if (!value) return false;
  try {
    const { token } = JSON.parse(value);
    if (typeof token !== "string") return false;
    const payload = JSON.parse(
      atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/"))
    );
    return typeof payload.exp === "number" && payload.exp * 1000 > Date.now();
  } catch {
    return false;
  }
}

export function middleware(req: NextRequest) {
  if (!hasValidAuthCookie(req.cookies.get("pb_auth")?.value)) {
    return NextResponse.redirect(new URL("/sign-in", req.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/protected/:path*"],
};
```

- [ ] **Step 6: Rewrite `components/header-auth.tsx`**

```tsx
"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getPocketBase } from "@/lib/pocketbase";
import { Button } from "./ui/button";

export default function HeaderAuth() {
  const router = useRouter();
  const [email, setEmail] = useState<string | null>(null);

  useEffect(() => {
    const pb = getPocketBase();
    setEmail((pb.authStore.record?.email as string | undefined) ?? null);
    return pb.authStore.onChange(() => {
      setEmail((pb.authStore.record?.email as string | undefined) ?? null);
    });
  }, []);

  if (!email) {
    return (
      <Button asChild size="sm" variant="outline">
        <Link href="/sign-in">Sign in</Link>
      </Button>
    );
  }

  return (
    <div className="flex items-center gap-3">
      <span className="text-xs text-muted-foreground">{email}</span>
      <Button
        size="sm"
        variant="outline"
        onClick={() => {
          getPocketBase().authStore.clear();
          router.push("/");
        }}
      >
        Sign out
      </Button>
    </div>
  );
}
```

- [ ] **Step 7: Update `app/layout.tsx`, `app/page.tsx`, and `app/protected/page.tsx` minimally**

- `app/layout.tsx`: delete `import { Providers } from "@/components/providers";` and remove the `<Providers>` / `</Providers>` wrapper (keep `ThemeProvider` and everything inside).
- `app/page.tsx`: replace the sign-up instructions paragraph with:
  ```tsx
        <p>
          <b>"Sign in"</b> with the account your administrator created for you.
        </p>
  ```
- `app/protected/page.tsx` (full rewrite comes in Task 9; these edits keep it compiling):
  - delete `import { useUser } from "@clerk/nextjs";` and the `const { user } = useUser();` line;
  - replace `import { ConvexErrorMessage } from "@/components/providers";` with `import { BackendErrorMessage as ConvexErrorMessage } from "@/components/backend-error";`
  - replace the greeting line `<h2>Hey, {user?.emailAddresses[0]?.emailAddress}!</h2>` with `<h2>Welcome!</h2>`
- Delete `components/providers.tsx`:
  ```bash
  rm components/providers.tsx
  ```

- [ ] **Step 8: Update `.env.example`** (full replacement)

```
NEXT_PUBLIC_POCKETBASE_URL=http://localhost:8090
```

Also update the user's untracked `.env.local` to contain the same line (keep a commented-out copy of the old Clerk/Convex values in case of rollback; do not commit `.env.local`).

- [ ] **Step 9: Build**

```bash
npm run build
```

Expected: build succeeds — `convex` is still installed and `convex/` still exists, so the remaining Convex imports in `app/protected/page.tsx` compile; nothing imports Clerk anymore. If Clerk imports remain, `grep -rn "@clerk" app components middleware.ts` and fix.

- [ ] **Step 10: Commit (inside the submodule)**

```bash
git add -A
git commit -m "feat(auth): replace Clerk with PocketBase email/password auth

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Web — data layer swap (Convex removal)

**Files (in `equine-frontend/`):**
- Create: `lib/assessments.ts`
- Modify: `app/protected/page.tsx` (full rewrite), `package.json` (drop `convex`)
- Delete: `convex/` directory

**Interfaces:**
- Consumes: `getPocketBase()` and `BackendErrorMessage` from Task 8; collections/hook from Tasks 2–3.
- Produces: `lib/assessments.ts` exports `AssessmentRecord`, `HorseRecord`, `AssessmentDetails`, `MediaFiles`, `fetchAssessmentDetails(id: string): Promise<AssessmentDetails>`, `fetchAssessmentMedia(assessment: AssessmentRecord, horses: HorseRecord[]): Promise<MediaFiles>`, `deleteAssessmentCascade(assessment: AssessmentRecord): Promise<void>`.

- [ ] **Step 1: Write `lib/assessments.ts`**

```typescript
import { RecordModel } from "pocketbase";
import { getPocketBase } from "./pocketbase";

export interface AssessmentRecord extends RecordModel {
  externalId: string;
  vetName: string;
  farmName: string;
  visitDate: string; // ISO date string from PocketBase
  isComplete: boolean;
  sideNotes: string;
  syncedAt: string;
}

export interface HorseRecord extends RecordModel {
  externalId: string;
  assessment: string;
  name: string;
  age: number;
  ageUnit: string;
  color: string;
  sex: string;
  breed: string;
  otherBreed: string;
  timeOnFarm: number;
  timeUnit: string;
  bcsScore: number;
  notes: string;
  isHorse: boolean;
}

export interface SectionRecord extends RecordModel {
  assessment: string;
  sectionNumber: number;
  title: string;
  isApplicable: boolean;
  infoIconClicks: number;
}

export interface SubsectionRecord extends RecordModel {
  section: string;
  name: string;
}

export interface RequirementRecord extends RecordModel {
  subsection: string;
  text: string;
  complianceStatus: string;
  nonComplianceReason: string;
}

export interface MediaRecord extends RecordModel {
  externalId: string;
  parentType: string;
  parentId: string;
  assessmentExternalId: string;
  file: string;
  mediaType: string;
  creationDate: string;
}

export interface AssessmentDetails extends AssessmentRecord {
  horses: HorseRecord[];
  sections: (SectionRecord & {
    subsections: (SubsectionRecord & { requirements: RequirementRecord[] })[];
  })[];
}

// Port of the Convex getWithDetails fan-out: one query per collection using
// relation-traversal filters, then stitched together in memory.
export async function fetchAssessmentDetails(id: string): Promise<AssessmentDetails> {
  const pb = getPocketBase();
  const [assessment, horses, sections, subsections, requirements] = await Promise.all([
    pb.collection("assessments").getOne<AssessmentRecord>(id),
    pb.collection("horses").getFullList<HorseRecord>({
      filter: pb.filter("assessment = {:id}", { id }),
    }),
    pb.collection("sections").getFullList<SectionRecord>({
      filter: pb.filter("assessment = {:id}", { id }),
      sort: "sectionNumber",
    }),
    pb.collection("subsections").getFullList<SubsectionRecord>({
      filter: pb.filter("section.assessment = {:id}", { id }),
    }),
    pb.collection("requirements").getFullList<RequirementRecord>({
      filter: pb.filter("subsection.section.assessment = {:id}", { id }),
    }),
  ]);

  const reqsBySubsection = new Map<string, RequirementRecord[]>();
  for (const req of requirements) {
    const list = reqsBySubsection.get(req.subsection) ?? [];
    list.push(req);
    reqsBySubsection.set(req.subsection, list);
  }

  const subsBySection = new Map<string, (SubsectionRecord & { requirements: RequirementRecord[] })[]>();
  for (const sub of subsections) {
    const withReqs = { ...sub, requirements: reqsBySubsection.get(sub.id) ?? [] };
    const list = subsBySection.get(sub.section) ?? [];
    list.push(withReqs);
    subsBySection.set(sub.section, list);
  }

  return {
    ...assessment,
    horses,
    sections: sections.map((s) => ({ ...s, subsections: subsBySection.get(s.id) ?? [] })),
  };
}

export interface MediaFiles {
  horseMedia: { horseName: string; files: { name: string; url: string }[] }[];
  requirementMedia: { name: string; url: string }[];
}

// Port of the Convex getAssessmentMedia query. One indexed query on
// assessmentExternalId (the old version full-scanned the table), then file
// URLs with a short-lived file token (the file field is protected).
export async function fetchAssessmentMedia(
  assessment: AssessmentRecord,
  horses: HorseRecord[]
): Promise<MediaFiles> {
  const pb = getPocketBase();
  const media = await pb.collection("media_attachments").getFullList<MediaRecord>({
    filter: pb.filter("assessmentExternalId = {:ext}", { ext: assessment.externalId }),
    sort: "creationDate",
  });
  const fileToken = await pb.files.getToken();

  const horsesByExternalId = new Map(horses.map((h) => [h.externalId, h]));
  const horseFiles = new Map<string, { name: string; url: string }[]>();
  const requirementMedia: { name: string; url: string }[] = [];
  const abnormalCounts = new Map<string, number>();

  for (const att of media) {
    const url = pb.files.getURL(att, att.file, { token: fileToken });
    const ext = att.mediaType === "video" ? "mp4" : "jpg";

    if (att.parentType === "requirement") {
      requirementMedia.push({
        name: `requirement_${requirementMedia.length + 1}.${ext}`,
        url,
      });
      continue;
    }
    if (!att.parentType.startsWith("horse_")) continue;
    if (!horsesByExternalId.has(att.parentId)) continue;

    const photoType = att.parentType.replace("horse_", "");
    let name: string;
    if (photoType === "abnormal") {
      const n = (abnormalCounts.get(att.parentId) ?? 0) + 1;
      abnormalCounts.set(att.parentId, n);
      name = `abnormal_${n}.${ext}`;
    } else {
      name = `${photoType}.${ext}`;
    }
    const list = horseFiles.get(att.parentId) ?? [];
    list.push({ name, url });
    horseFiles.set(att.parentId, list);
  }

  const horseMedia = [...horseFiles.entries()].map(([parentId, files]) => ({
    horseName: horsesByExternalId.get(parentId)?.name || "unnamed-horse",
    files,
  }));

  return { horseMedia, requirementMedia };
}

// Port of the Convex remove mutation. Media records have no relation to
// assessments (they survive re-syncs by design), so they're deleted by the
// indexed assessmentExternalId query; PocketBase deletes their stored files
// with the records. Everything else cascades off the assessment via
// relation cascadeDelete.
export async function deleteAssessmentCascade(assessment: AssessmentRecord): Promise<void> {
  const pb = getPocketBase();
  const media = await pb.collection("media_attachments").getFullList<MediaRecord>({
    filter: pb.filter("assessmentExternalId = {:ext}", { ext: assessment.externalId }),
  });
  for (const m of media) {
    await pb.collection("media_attachments").delete(m.id);
  }
  await pb.collection("assessments").delete(assessment.id);
}
```

- [ ] **Step 2: Rewrite `app/protected/page.tsx`**

Keep `sanitizeName`, the zip/docx assembly, and all JSX styling identical to the current file — only the data source changes. Full replacement:

```tsx
"use client";

import { useCallback, useEffect, useState } from "react";
import { Download, Loader2, Trash2 } from "lucide-react";
import { Packer } from "docx";
import { saveAs } from "file-saver";
import JSZip from "jszip";
import generateDocument from "@/actions/docxReport";
import { generateHorseDoc } from "@/actions/docGeneration";
import { BackendErrorMessage } from "@/components/backend-error";
import { getPocketBase } from "@/lib/pocketbase";
import {
  AssessmentRecord,
  deleteAssessmentCascade,
  fetchAssessmentDetails,
  fetchAssessmentMedia,
} from "@/lib/assessments";

// Strip characters that are illegal in file/zip paths so a horse or farm name
// can't break the folder structure or overwrite a sibling entry.
function sanitizeName(name: string): string {
  return name.replace(/[/\\:*?"<>|\x00-\x1f]/g, "_").trim();
}

export default function ProtectedPage() {
  const [email, setEmail] = useState<string | null>(null);
  const [assessments, setAssessments] = useState<AssessmentRecord[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [downloadingId, setDownloadingId] = useState<string | null>(null);

  const reload = useCallback(async () => {
    try {
      const records = await getPocketBase()
        .collection("assessments")
        .getFullList<AssessmentRecord>({ sort: "-created" });
      setAssessments(records);
      setLoadError(null);
    } catch {
      setLoadError("Could not connect to the PocketBase backend.");
    }
  }, []);

  useEffect(() => {
    const pb = getPocketBase();
    setEmail((pb.authStore.record?.email as string | undefined) ?? null);
    reload();
    // Realtime: re-fetch the list on any assessments change (replaces the
    // Convex useQuery live subscription).
    pb.collection("assessments").subscribe("*", () => reload());
    return () => {
      pb.collection("assessments").unsubscribe("*");
    };
  }, [reload]);

  if (loadError) {
    return <BackendErrorMessage message={loadError} />;
  }

  if (!assessments) {
    return (
      <div className="flex flex-col gap-6 w-11/12 max-w-3xl">
        <h2>Loading...</h2>
      </div>
    );
  }

  const handleDelete = async (assessment: AssessmentRecord) => {
    if (confirm("Are you sure you want to delete this assessment?")) {
      try {
        await deleteAssessmentCascade(assessment);
        await reload();
      } catch (error) {
        alert(
          `Delete failed: ${error instanceof Error ? error.message : "Unknown error"}`
        );
      }
    }
  };

  const handleDownload = async (assessment: AssessmentRecord) => {
    setDownloadingId(assessment.id);
    try {
      const details = await fetchAssessmentDetails(assessment.id);
      const media = await fetchAssessmentMedia(details, details.horses);

      const zip = new JSZip();

      // 1. Generate assessment report .docx
      const horses = details.horses.filter((h) => h.isHorse);
      const donkeys = details.horses.filter((h) => !h.isHorse);
      const avgHorseBCS =
        horses.length > 0
          ? (
              horses.reduce((sum, h) => sum + h.bcsScore, 0) / horses.length
            ).toFixed(1)
          : "";
      const avgDonkeyBCS =
        donkeys.length > 0
          ? (
              donkeys.reduce((sum, h) => sum + h.bcsScore, 0) / donkeys.length
            ).toFixed(1)
          : "";

      const nonCompliantSections = details.sections
        .map((section) => ({
          id: section.sectionNumber,
          title: section.title,
          subsections: section.subsections
            .map((sub) => ({
              name: sub.name,
              requirements: sub.requirements
                .filter((req) => req.complianceStatus === "Not Compliant")
                .map((req) => ({
                  text: req.text,
                  complianceStatus: req.complianceStatus || "",
                  findings: req.nonComplianceReason || undefined,
                })),
            }))
            .filter((sub) => sub.requirements.length > 0),
        }))
        .filter((section) => section.subsections.length > 0);

      const reportData = {
        metadata: {
          displayName: details.vetName,
          farmName: details.farmName,
          id: details.externalId,
          vetName: details.vetName,
          visitDate: new Date(details.visitDate).toLocaleDateString(),
          averageHorseBCS: avgHorseBCS,
          averageDonkeyBCS: avgDonkeyBCS,
        },
        nonCompliantFindings: {
          sections: nonCompliantSections,
        },
        sideNotes: details.sideNotes || "",
      };

      const reportDoc = generateDocument(reportData);
      const reportBlob = await Packer.toBlob(reportDoc);
      zip.file("assessment-report.docx", reportBlob);

      // 2. Generate horse table .docx
      const horseTableBlob = await generateHorseDoc(details.horses);
      zip.file("horse-table.docx", horseTableBlob);

      // A single failed media fetch shouldn't abort the whole export: collect
      // failures and still produce the zip with the report + everything that
      // did download. Never rejects.
      const failedFiles: string[] = [];
      const addRemoteFile = async (
        folder: JSZip,
        name: string,
        url: string
      ) => {
        try {
          const response = await fetch(url);
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          folder.file(name, await response.blob());
        } catch (err) {
          console.error(`Failed to fetch media "${name}":`, err);
          failedFiles.push(name);
        }
      };

      // 3. Add horse media folders. Sanitize and de-duplicate folder names so
      // same-named (or unnamed) horses don't overwrite each other's photos.
      const usedFolderNames = new Set<string>();
      for (const horse of media.horseMedia) {
        const base = sanitizeName(horse.horseName) || "unnamed-horse";
        let folderName = base;
        for (let n = 2; usedFolderNames.has(folderName); n++) {
          folderName = `${base}-${n}`;
        }
        usedFolderNames.add(folderName);

        const folder = zip.folder(folderName);
        if (!folder) continue;
        await Promise.all(
          horse.files.map((file) => addRemoteFile(folder, file.name, file.url))
        );
      }

      // 4. Add requirement media folder
      if (media.requirementMedia.length > 0) {
        const reqFolder = zip.folder("requirement-media");
        if (reqFolder) {
          await Promise.all(
            media.requirementMedia.map((file) =>
              addRemoteFile(reqFolder, file.name, file.url)
            )
          );
        }
      }

      // 5. Generate and download zip
      const zipBlob = await zip.generateAsync({ type: "blob" });
      saveAs(
        zipBlob,
        `${sanitizeName(assessment.farmName) || "assessment"}-assessment.zip`
      );

      if (failedFiles.length > 0) {
        alert(
          `Download complete, but ${failedFiles.length} media file(s) could not be retrieved and were skipped:\n${failedFiles.join("\n")}`
        );
      }
    } catch (error) {
      alert(
        `Download failed: ${error instanceof Error ? error.message : "Unknown error"}`
      );
    } finally {
      setDownloadingId(null);
    }
  };

  return (
    <div className="flex flex-col gap-6 w-11/12 max-w-3xl">
      <h2>Hey, {email ?? "there"}!</h2>
      <h2 className="font-medium text-xl mb-4">Your Assessments</h2>

      {assessments.length === 0 ? (
        <p className="text-gray-500">
          No assessments yet. Sync from the iOS app to see them here.
        </p>
      ) : (
        <div className="flex flex-wrap gap-3 justify-between">
          {assessments.map((assessment) => (
            <div
              key={assessment.id}
              className="flex justify-between shrink-1 basis-full md:basis-[47%] gap-2 hover:bg-slate-200 dark:hover:bg-slate-800 p-4 rounded-md border"
            >
              <div>
                <p className="font-medium">
                  {assessment.vetName} - {assessment.farmName}
                </p>
                <p className="text-sm text-gray-500">
                  {new Date(assessment.visitDate).toLocaleDateString()}
                </p>
                <p className="text-xs text-gray-400">
                  {assessment.isComplete ? "Complete" : "In Progress"}
                </p>
              </div>
              <div className="flex gap-2 items-start">
                <button
                  onClick={() => handleDownload(assessment)}
                  disabled={downloadingId === assessment.id}
                  className="border rounded-md py-2 px-4 h-min bg-none hover:bg-green-400 hover:text-green-800 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                  title="Download report"
                >
                  {downloadingId === assessment.id ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <Download className="w-4 h-4" />
                  )}
                </button>
                <button
                  onClick={() => handleDelete(assessment)}
                  className="border rounded-md py-2 px-4 h-min bg-none hover:bg-red-400 hover:text-red-800 transition-all"
                  title="Delete assessment"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 3: Remove Convex**

```bash
rm -rf convex
npm uninstall convex
grep -rn "convex" --include="*.ts" --include="*.tsx" app components lib actions middleware.ts || echo "convex fully removed"
```

Expected: "convex fully removed".

- [ ] **Step 4: Build**

```bash
npm run build
```

Expected: build succeeds with no missing-module errors.

- [ ] **Step 5: Commit (inside the submodule)**

```bash
git add -A
git commit -m "feat(data): replace Convex with PocketBase records + realtime

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Web end-to-end verification + root-repo integration

**Files:**
- Modify (root repo): `CLAUDE.md`, `equine-frontend` submodule pointer, `equine-welfare.xcodeproj/xcshareddata/xcschemes/equine-welfare.xcscheme`

**Interfaces:**
- Consumes: everything above.
- Produces: verified full-stack flow; root branch carries the updated submodule pointer and accurate docs.

- [ ] **Step 1: Web end-to-end checklist**

With PocketBase running and `.env.local` set (`NEXT_PUBLIC_POCKETBASE_URL=http://localhost:8090`):

```bash
cd equine-frontend && npm run dev
```

1. Visit `http://localhost:3000/protected` signed out → redirected to `/sign-in`.
2. Sign in as `tester@example.com` / `test-password-123` → lands on `/protected`, header shows the email.
3. Run `./pocketbase/scripts/test_sync.sh tester@example.com test-password-123` **with the cleanup step temporarily skipped** (comment out the DELETE) → the new assessment appears in the dashboard **without a manual refresh** (realtime subscription).
4. If an iOS-synced assessment with photos exists (Task 7), Download it → zip contains `assessment-report.docx`, `horse-table.docx`, and per-horse photo folders with `front.jpg`-style names.
5. Delete the test assessment from the dashboard → it disappears; in the admin UI, its horses/sections/subsections/requirements and media are gone.
6. Sign out → header shows "Sign in"; `/protected` redirects again.
7. Stop PocketBase, reload `/protected` → "Backend Unavailable" message renders. Restart PocketBase.

- [ ] **Step 2: Update root-repo docs and stale config**

- `CLAUDE.md`: update the backend line in Project Overview to `**Current Backend**: PocketBase (self-hosted — auth, database, file storage) in pocketbase/`; replace the "Current Migration Context" section to point at branch `pocketbase-migration`, this plan, and the spec; update the web Configuration section to `NEXT_PUBLIC_POCKETBASE_URL`; update the iOS Configuration mention of Secrets keys; add a "Run PocketBase" snippet to Build & Run Commands.
- `equine-welfare.xcodeproj/xcshareddata/xcschemes/equine-welfare.xcscheme`: delete the two dead `SUPABASE_URL` / `SUPABASE_KEY` environment-variable entries.

- [ ] **Step 3: Commit the submodule pointer + root changes**

```bash
git add equine-frontend CLAUDE.md equine-welfare.xcodeproj/xcshareddata/xcschemes/equine-welfare.xcscheme
git commit -m "chore: point submodule at PocketBase web migration, update docs

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Final sweep**

```bash
grep -rn "convex\|clerk\|Clerk\|Convex" --include="*.swift" equine-welfare/ || echo "iOS clean"
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```

Expected: "iOS clean" (docs/plans may still mention Convex historically — that's fine) and BUILD SUCCEEDED. Report any leftovers to the user with where they live.
