# Cloud Sync & Auth — How It Works

*Written 2026-07-13, after making sync idempotent and gating uploads behind Clerk sign-in.*

## The design in one paragraph

The iOS app is **local-first**: assessments are created, edited, and exported entirely in SwiftData with no network and no account. The **only** feature that touches the cloud is the Sync button on a previous assessment, which uploads to Convex (deployment `little-sparrow-828`, dev). Sync requires a Clerk sign-in — prompted just-in-time when the button is tapped, persisted afterwards. Sync is **idempotent**: if it dies mid-upload (flaky barn wifi), tapping Sync again resumes cleanly.

## User journey

1. Vet installs the app. No sign-in, no network needed.
2. Creates/edits assessments in the field — fully offline.
3. Back on wifi, taps **Sync** on an assessment:
   - Signed out → Clerk `AuthView` sheet appears; after sign-in the sync continues automatically.
   - Signed in → syncs immediately (session persists across launches).
4. If sync fails partway → tap Sync again; already-uploaded data is deduped, the rest uploads.
5. Office staff view synced assessments in the Next.js dashboard (`/protected`, Clerk-gated).

## Sync pipeline (iOS → Convex)

`PreviousAssessmentRow.uploadButton` → `ConvexService.shared.syncAssessment(assessment)`:

1. **Auth refresh** — `refreshAuth()` mints a Convex-template JWT from the Clerk session via `ClerkAuthProvider` and hands it to `ConvexClientWithAuth`.
2. **Metadata** — assessment + horses + applicable sections serialized as JSON strings (Swift SDK compatibility) → `assessments:syncAssessment` mutation.
3. **Horse photos** — per horse: profile/front/right/back/left/abnormal → `files:generateUploadUrl` → HTTP POST bytes → `files:saveFile`. Auth is refreshed between horses (Clerk template JWTs are short-lived; a long photo sync must not outlive one).
4. **Requirement media** — same upload flow, `parentId = "<assessmentExternalId>_<sectionNum>_<subIdx>_<reqIdx>"`.

Progress callbacks drive the inline progress bar (0.1 → 1.0).

## Idempotency (fixed 2026-07-13)

Previously a re-sync threw *"Assessment already synced. Duplicate uploads not allowed"* — so a sync that died mid-photo could **never** be completed. Now:

- `assessments:syncAssessment` **upserts**: if the `externalId` exists, it wipes child rows (horses, sections, subsections, requirements), patches the assessment, and re-inserts. Media rows are kept — they're keyed by stable `externalId`s.
- `files:saveFile` **dedupes** by `externalId` (new index `by_external_id` on `mediaAttachments`): a re-uploaded attachment keeps the original row and deletes the redundant new storage blob.

Caveat: a retry still re-uploads photo *bytes* that already made it (backend discards them). Correct but wasteful; a pre-upload "which of these externalIds exist?" query would skip them. Not built yet.

## Auth (added 2026-07-13)

### Backend

`requireUser(ctx)` in `convex/assessments.ts` throws unless `ctx.auth.getUserIdentity()` returns an identity. Applied to all writes:

| Function | Auth |
|---|---|
| `assessments:syncAssessment` | required; stamps `uploadedBy` (Clerk user ID) |
| `assessments:remove` | required |
| `files:generateUploadUrl` | required |
| `files:saveFile` | required |
| all queries (`list`, `getWithDetails`, `getAssessmentMedia`, …) | **open** — tighten before production |

Convex validates JWTs against `CLERK_JWT_ISSUER_DOMAIN` (set in the Convex deployment env, see `convex/auth.config.ts`).

### iOS

- `equine_welfareApp.init()` calls `Clerk.configure(publishableKey:)` — key comes from `Secrets.xcconfig` → `Info.plist` → `ConvexConfig.clerkPublishableKey` (same pattern as `CONVEX_URL`).
- `Services/ClerkAuth.swift` — `ClerkAuthProvider` conforms to ConvexMobile's `AuthProvider`. It never presents UI; it just mints `session.getToken(.init(template: "convex"))`. Clerk caches the token and only hits the network near expiry.
- `ConvexService` uses `ConvexClientWithAuth<String>` and calls `refreshAuth()` at sync start, per horse, and before requirement media.
- Sign-in UI is Clerk's prebuilt `AuthView`, presented as a sheet from the Sync button only when `Clerk.shared.user == nil`; `onDismiss` continues the sync if sign-in succeeded.

### Web

Already authed end-to-end: `clerkMiddleware` protects `/protected(.*)`, and `ConvexProviderWithClerk` attaches the JWT to every Convex call. Backend gating required no web changes.

## Configuration

| Where | Key | Notes |
|---|---|---|
| `equine-welfare/Config/Secrets.xcconfig` | `CONVEX_URL` | `https:/$()/little-sparrow-828.convex.cloud` — the `$()` escapes `//` (xcconfig comment) |
| | `CLERK_PUBLISHABLE_KEY` | `pk_test_…` — client-safe, same key as web |
| `equine-frontend/.env.local` | `CONVEX_DEPLOYMENT`, `NEXT_PUBLIC_CONVEX_URL`, Clerk keys | |
| Convex deployment env | `CLERK_JWT_ISSUER_DOMAIN` | `https://awake-krill-5.clerk.accounts.dev` |
| Clerk dashboard | JWT template named **`convex`** | **Required** — sync fails with a token error without it. Configure → JWT Templates → New template → Convex. |

Deploy backend changes: `cd equine-frontend && npx convex dev --once`.

## Verifying it works

```bash
# Reads are open (should succeed):
curl -s -X POST https://little-sparrow-828.convex.cloud/api/query \
  -H "Content-Type: application/json" \
  -d '{"path":"assessments:list","args":{},"format":"json"}'

# Writes are gated (should error with "Sign in required to upload"):
curl -s -X POST https://little-sparrow-828.convex.cloud/api/mutation \
  -H "Content-Type: application/json" \
  -d '{"path":"files:generateUploadUrl","args":{},"format":"json"}'
```

Both verified live on 2026-07-13, along with a double-sync test confirming the upsert returns the same document ID with no duplicated children.

## Key commits

| Commit | Repo | What |
|---|---|---|
| `573579e` | equine-frontend | idempotent sync (upsert + media dedupe) |
| `86b23aa` | equine-frontend | auth required on write mutations, `uploadedBy` stamp |
| `5cde2e9` | equine-welfare | drop dead "already synced" alert path |
| `e40f27f` | equine-welfare | Clerk SDK, `ClerkAuthProvider`, sign-in-gated Sync button |

## Not done yet / future work

- [ ] **Auth queries too** — `assessments:list` etc. are world-readable; gate before production data goes in.
- [ ] **Skip re-uploading photo bytes on retry** — pre-check which `externalId`s already exist.
- [ ] **Per-user data scoping** — every signed-in user sees every assessment; filter by `uploadedBy` or an org model if needed.
- [ ] **Sign-out UI** — there's no way to sign out in the iOS app yet (`ClerkAuthProvider.logout()` exists but nothing calls it).
- [ ] **Production Clerk instance** — currently on `pk_test_…` / dev deployment.
- [ ] Anti-patterns deferred from the July sweep: rename SwiftData `Section` → `AssessmentSection`; `ConvexConfig` `fatalError` on missing key (now two of them — CONVEX_URL and CLERK_PUBLISHABLE_KEY).
