# PocketBase-Served Dashboard Design (Vite + React)

**Date:** 2026-08-02
**Branch:** `pocketbase-served-dashboard` (off `pocketbase-migration`)
**Status:** Approved
**Depends on:** `2026-08-02-pocketbase-migration-design.md` (implemented on the parent branch)

## Goal

Serve the web dashboard from PocketBase itself instead of a separate Next.js
deployment. End state: the entire product is one PocketBase binary plus its
folders — no Node server in production, no CORS configuration, one process to
run. The `equine-frontend` submodule is retired from the root repo.

## Verified platform facts this design rests on

- PocketBase auto-serves a `pb_public/` directory (next to the binary) as the
  root website, with SPA index.html fallback.
- The `/_/` admin UI and `/api/*` routes are reserved; a static site at `/`
  does not conflict with them.
- PocketBase's default CORS is permissive, so the Vite dev server (different
  origin) can call `http://localhost:8090` during development without config.
- The admin dashboard is NOT extensible (compiled in); this design serves our
  own UI, it does not modify the admin UI.

## Decisions

| Question | Decision |
|---|---|
| App location | New `dashboard/` directory in the root repo. |
| Framework | Vite + React + TypeScript + Tailwind. No Next.js. |
| Router | None. Two states only: `pb.authStore.isValid` → `Dashboard`, else → `Login`. |
| Login | Required (user requirement): email/password screen calling `authWithPassword`, "accounts are created by your administrator" note. No sign-up/reset. |
| Auth persistence | PocketBase SDK default (localStorage). The `pb_auth` cookie + Next middleware machinery is not ported — client-side gating is UX only; PocketBase API rules remain the enforcement. |
| Radix / next-themes | Dropped. Plain Tailwind-styled inputs/buttons; a ~20-line `useTheme` hook (class strategy, localStorage, system default) keeps the existing `dark:` styles and a header toggle. |
| Build output | `dashboard/npm run build` → `pocketbase/pb_public/` (Vite `outDir`, `emptyOutDir: true`). `pb_public/` is **gitignored** — build artifact, not source. |
| Submodule | `equine-frontend` submodule entry removed from the root repo as the final task of this branch, after the served dashboard is verified. The GitHub repo and its open PR are left untouched. |

## Architecture

```
dashboard/
├── index.html
├── vite.config.ts          # outDir: ../pocketbase/pb_public, emptyOutDir
├── tailwind.config.ts / postcss.config.js
├── src/
│   ├── main.tsx            # mounts <App/>
│   ├── App.tsx             # authStore.onChange → Login | Dashboard shell (header: email, sign-out, theme toggle)
│   ├── lib/pocketbase.ts   # new PocketBase(import.meta.env.VITE_POCKETBASE_URL || "/")
│   ├── lib/assessments.ts  # ported unchanged from equine-frontend
│   ├── lib/useTheme.ts     # class-strategy dark mode hook
│   ├── components/Login.tsx
│   ├── components/Dashboard.tsx     # ported from app/protected/page.tsx (realtime subscribe, zip/docx export, delete)
│   ├── components/BackendError.tsx  # ported from components/backend-error.tsx
│   └── actions/docxReport.ts, actions/docGeneration.ts  # ported unchanged
└── .env.example            # VITE_POCKETBASE_URL=http://localhost:8090 (dev only)
```

Dependencies carried over: `pocketbase`, `docx`, `jszip`, `file-saver`,
`lucide-react`, Tailwind. Dropped: `next`, `@radix-ui/*`, `next-themes`,
`class-variance-authority`, everything Next-specific.

**Dev flow:** `cd dashboard && npm run dev` (Vite on :5173, talks to
PocketBase on :8090 cross-origin). **Prod flow:** `npm run build`, then
PocketBase serves the result same-origin — the SDK base URL `"/"` needs no
configuration.

## Behavior parity contract

The dashboard must preserve, unchanged from the Next.js version:
- Realtime assessment list (`subscribe('*')` → reload) with the
  backend-unavailable banner on load failure.
- Zip/docx export byte-identical logic (report assembly, `sanitizeName`,
  folder dedupe, failed-file collection, protected-file tokens).
- Cascade delete (media by `assessmentExternalId` query, then assessment).
- Signed-in email display and sign-out.

New behavior: reloading while signed out (or after token expiry) shows the
Login screen; successful login lands on the Dashboard without a reload.

## Error handling

- Login failure → inline "Sign-in failed. Check your email and password."
- 401 on any data call → clear authStore (SDK does this on auth-refresh
  failure paths; additionally treat request 401s by `authStore.clear()`),
  which flips the app to the Login screen via `onChange`.
- Backend down → existing BackendError banner (message updated to the
  single-binary world: "Make sure PocketBase is running").

## Testing

1. `npm run build` populates `pocketbase/pb_public/`; `curl -s localhost:8090/`
   returns the app's index.html; deep-link path returns index.html (SPA
   fallback).
2. Browser at `localhost:8090`: login (bad credentials rejected inline),
   realtime update when `test_sync.sh` inserts, zip export with media,
   delete cascade, sign-out returns to Login, reload while signed out shows
   Login.
3. Vite dev server flow works against :8090 (CORS default).
4. After submodule removal: fresh `git clone` + `git submodule status` shows
   no submodule; CLAUDE.md describes the new layout; iOS build unaffected.

## Out of scope

Production TLS/hosting, dashboard feature changes, deleting the
`equine-frontend` GitHub repository or closing its PR (the repo simply stops
being referenced), admin-UI customization.
