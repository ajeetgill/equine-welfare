# PocketBase Migration Design

**Date:** 2026-08-02
**Branch:** `pocketbase-migration` (root repo and `equine-frontend` submodule)
**Status:** Approved

## Goal

Replace Convex (database + file storage) and Clerk (auth) with a single self-hosted
PocketBase instance (v0.39.10, the darwin_arm64 binary) for both the iOS app and the
Next.js web dashboard. The app remains local-first: SwiftData stays the source of
truth, the cloud is a write-only mirror consumed by the web dashboard.

## Decisions

| Question | Decision |
|---|---|
| Hosting | Local/LAN only for now — PocketBase runs on the developer's Mac, served on `0.0.0.0:8090` so iPads can reach it over LAN. Production hosting deferred. |
| Auth methods | Email + password only. No OAuth, no OTP. |
| User registration | None in-app. Users are created by the superuser in the PocketBase admin dashboard. Apps only sign in. |
| Existing Convex data | Start fresh. iOS devices hold the source of truth; re-syncing repopulates the cloud. No migration script. |
| Integration approach | **A: JS hook endpoint.** A custom route in `pb_hooks` performs the atomic sync upsert server-side; iOS uses a thin raw-`URLSession` client; web uses the official `pocketbase` npm SDK. Rejected: B (client-orchestrated batch API — chattier, more client logic for the same atomicity) and C (community Swift SDK — unofficial pre-1.0 dependency for a ~3-call surface). |

## Current state (what is being replaced)

- **iOS:** `Services/ConvexService.swift` (official `ConvexMobile` SDK) calls three
  Convex functions: `assessments:syncAssessment` (one upsert mutation carrying
  assessment/horses/sections as JSON strings — a Swift SDK arg-type workaround),
  `files:generateUploadUrl`, and `files:saveFile` (3-step signed-URL upload).
  `Services/ClerkAuth.swift` bridges Clerk → Convex via a JWT template named
  `convex`; short-lived tokens force `refreshAuth()` mid-sync per horse. Sign-in UI
  is Clerk's prebuilt `AuthView`, presented from `Views/PreviousAssessmentRow.swift`;
  sign-out lives in `Views/AccountMenu.swift`. Error handling string-matches Convex
  error text. Upload-only: iOS never reads from the cloud.
- **Web (`equine-frontend`):** `convex` + `@clerk/nextjs`. One live subscription
  (`useQuery(api.assessments.list)`), one mutation (`remove`), two imperative queries
  (`getWithDetails`, `getAssessmentMedia`) powering a client-side docx/zip export.
  Clerk components for all auth pages; `clerkMiddleware` protects `/protected`.
- **Convex backend:** `equine-frontend/convex/` — 6 tables keyed by iOS-owned
  `externalId` UUIDs, upsert-by-externalId with child wipe-and-reinsert, media rows
  preserved across re-syncs. Reads are currently **unauthenticated**; writes require
  auth. Two full-table scans filter `mediaAttachments` by `parentId.startsWith(...)`.

## New architecture

### Repo layout

```
pocketbase/
├── pocketbase           # binary (gitignored)
├── pb_data/             # SQLite DB + uploaded files (gitignored)
├── pb_migrations/       # JS migrations defining collections (committed)
├── pb_hooks/
│   └── main.pb.js       # custom sync endpoint (committed)
├── .gitignore
└── README.md            # setup + run instructions
```

Run: `./pocketbase serve --http 0.0.0.0:8090`. Admin dashboard at
`http://localhost:8090/_/`. Schema is version-controlled via `pb_migrations` so a
fresh checkout + binary reproduces the backend.

### Collections

Built-in `users` auth collection (email/password, created via admin dashboard), plus
six base collections mirroring the Convex schema:

| Collection | Fields (beyond `id`/timestamps) | Notes |
|---|---|---|
| `assessments` | `externalId` (text, **unique index**), `vetName`, `farmName`, `visitDate` (date), `isComplete` (bool), `sideNotes`, `syncedAt` (date), `uploadedBy` (relation → users) | Upsert key is `externalId` (iOS UUID) |
| `horses` | `externalId` (unique), `assessment` (relation → assessments, cascade delete), `name`, `age`, `ageUnit`, `color`, `sex`, `breed`, `otherBreed`, `timeOnFarm`, `timeUnit`, `bcsScore`, `notes`, `isHorse` (bool) | |
| `sections` | `assessment` (relation, cascade delete), `sectionNumber` (number), `title`, `isApplicable` (bool), `infoIconClicks` (number) | Only `isApplicable` sections are synced (unchanged) |
| `subsections` | `section` (relation, cascade delete), `name` | |
| `requirements` | `subsection` (relation, cascade delete), `text`, `complianceStatus`, `nonComplianceReason` | |
| `media_attachments` | `externalId` (unique), `parentType` (select: horse_photo/horse_front/horse_right/horse_back/horse_left/horse_abnormal/requirement), `parentId` (text), `assessmentExternalId` (text, **indexed**), `file` (file field, single, images + mp4), `mediaType` (select: photo/video), `creationDate` (date) | `assessmentExternalId` replaces the two `startsWith` full-table scans. Media survive re-syncs (no relation to `assessments`; cleanup handled by the delete flow). |

**API rules (all six collections):** list/view/create/update/delete all require
`@request.auth.id != ""`. This is stricter than today (Convex reads were
unauthenticated). All signed-in users see all assessments — the existing
team-shared model, unchanged. `media_attachments` create rule additionally used for
direct multipart uploads from iOS.

### Server hook: `POST /api/equine/sync-assessment`

`pb_hooks/main.pb.js`, using `routerAdd` + `$app.runInTransaction`:

- **Auth:** requires a valid user token (route bound to auth middleware); stamps
  `uploadedBy` from the authenticated user.
- **Payload:** real JSON — `{ assessment: {...}, horses: [...], sections: [...] }`
  with the same shape `ConvexService` builds today. The JSON-string workaround is
  dropped along with the Convex Swift SDK.
- **Behavior (port of `convex/assessments.ts:syncAssessment`):** find assessment by
  `externalId`; if present, delete child horses/sections (subsections/requirements
  cascade via relation delete rules) and update the parent; else create it. Insert
  horses and the section→subsection→requirement tree. Media records are untouched.
  All inside one transaction. Returns `{ assessmentId }`.

### File upload (replaces generateUploadUrl / saveFile)

One multipart `POST /api/collections/media_attachments/records` per photo/video with
the binary in the `file` field plus `externalId`, `parentType`, `parentId`,
`assessmentExternalId`, `mediaType`, `creationDate`. Idempotency: the unique index on
`externalId` makes a retry fail with a validation error, which the client treats as
"already uploaded" (same semantics as Convex `saveFile`'s dedupe). Requirement media
keep the synthetic composite `parentId`
(`"<assessmentUUID>_<sectionId>_<subIdx>_<reqIdx>"`) but now also carry
`assessmentExternalId` for indexed lookup.

### iOS changes

- **Remove packages:** `get-convex/convex-swift`, `clerk/clerk-ios` (and their
  products from the target). Delete `Services/ClerkAuth.swift`; the Clerk `convex`
  JWT template is no longer needed.
- **New `Services/PocketBaseService.swift`** (singleton, plain `URLSession`):
  - `signIn(email:password:)` → `POST /api/collections/users/auth-with-password`;
    token stored in Keychain, current user email exposed for `AccountMenu`.
  - `refreshIfNeeded()` → `POST /api/collections/users/auth-refresh`; on 401 the
    stored token is cleared and the sign-in sheet is re-presented. The per-horse
    mid-sync refresh calls are removed (PB tokens are long-lived).
  - `syncAssessment(_:progressHandler:)` — same public surface as today: serialize
    (reusing the existing dictionary-building logic, minus JSON-string wrapping),
    one POST to the hook endpoint, then per-media multipart uploads with the same
    progress fractions.
  - `signOut()` — clears the Keychain token (PB is stateless; nothing server-side).
- **New sign-in UI:** a simple SwiftUI email/password sheet replacing Clerk's
  `AuthView`, presented from the same trigger in `PreviousAssessmentRow` with the
  same resume-sync-on-success behavior. No sign-up, no password reset in-app.
  `AccountMenu` keeps sign-out, showing the signed-in email.
- **Config:** `Secrets.xcconfig` gains `POCKETBASE_URL` (e.g.
  `http:/$()/192.168.x.x:8090`), drops `CONVEX_URL` and `CLERK_PUBLISHABLE_KEY`;
  `Config/ConvexConfig.swift` becomes `PocketBaseConfig.swift`. Info.plist adds
  `NSAppTransportSecurity > NSAllowsLocalNetworking` so plain-HTTP LAN calls work.
- **Error handling:** replace the Convex error-string matching in
  `PreviousAssessmentRow.swift` with decoding of PocketBase's structured JSON errors
  (`{ code, message, data }`), mapping 401 → sign-in prompt, network errors →
  "check that PocketBase is running / same Wi-Fi", other → message passthrough.

### Web changes (`equine-frontend`, own branch in submodule)

- **Remove:** `convex`, `@clerk/nextjs`. Delete `convex/` directory. **Add:**
  `pocketbase` npm SDK.
- **Auth:** one email/password sign-in page replacing the Clerk component pages
  (sign-up/user-profile pages removed). PB auth store persisted in a cookie;
  `middleware.ts` checks the cookie's validity for `/protected(.*)` and redirects to
  sign-in. Header shows email + sign-out instead of Clerk's `UserButton`.
- **Data:** `app/protected/page.tsx` swaps `useQuery(api.assessments.list)` for
  `getFullList` on mount + `pb.collection('assessments').subscribe('*', ...)` for
  realtime updates (wrapped in a small custom hook with loading/error state,
  replacing the `ConvexProviderWithClerk` + 10s-timeout machinery in
  `providers.tsx`). Delete uses the records API (children cascade;
  `media_attachments` cleaned up by `assessmentExternalId` query). The
  `getWithDetails` fan-out becomes a few `getFullList` calls with filters/`expand`;
  media URLs come from PB's file URL API (`pb.files.getURL`). The docx/zip export
  code (`actions/docxReport.ts`, `actions/docGeneration.ts`) is untouched.

## Error handling summary

- iOS 401 → clear token, present sign-in sheet, resume sync on success (existing
  pattern, new trigger).
- iOS duplicate `externalId` on media upload → treat as success (idempotent retry).
- Hook endpoint validates payload shape and returns 400 with a message on bad input;
  transaction rollback on any mid-sync failure means no half-synced assessments.
- Web: subscribe errors surface a "backend unavailable — is PocketBase running?"
  banner (replacing the Convex-specific fallback).

## Testing

1. `pocketbase serve` locally; apply migrations automatically on first run; create a
   test user in the admin dashboard.
2. iOS Simulator: sync an assessment against `http://localhost:8090` (Simulator
   shares the Mac's localhost); verify records + files in the admin UI; re-sync and
   verify upsert (no duplicates, media preserved); sync while signed out and verify
   the sign-in sheet + resume.
3. Physical iPad: point `POCKETBASE_URL` at the Mac's LAN IP, same Wi-Fi.
4. Web: sign in, verify list realtime-updates when an iOS sync lands, download the
   docx/zip export, delete an assessment and verify cascades.
5. Hook endpoint unit-testable via `curl` with an impersonation or user token
   (documented in `pocketbase/README.md`).

## Out of scope

Production hosting/TLS, OAuth providers, in-app registration/password reset,
per-user data scoping, Convex data migration, iOS pull/download sync. PocketBase is
pre-1.0; version upgrades may need manual migration steps — acceptable at this
stage.
