# PocketBase-Served Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the separate Next.js dashboard with a Vite + React app served by PocketBase itself from `pocketbase/pb_public/`, then retire the `equine-frontend` submodule.

**Architecture:** New `dashboard/` directory (Vite + React + TypeScript + Tailwind, no router — `pb.authStore.isValid` picks Login vs Dashboard). The data layer (`assessments.ts`) and docx/zip generators port verbatim from the submodule; the protected page becomes `Dashboard.tsx` with a small import/prop/401 adaptation. `npm run build` emits into `pocketbase/pb_public/` (gitignored), which PocketBase auto-serves with SPA fallback. Spec: `docs/superpowers/specs/2026-08-02-pocketbase-served-dashboard-design.md`.

**Tech Stack:** Vite 6, React 19, TypeScript 5.7, Tailwind 3.4, `pocketbase` JS SDK, `docx`/`jszip`/`file-saver`/`lucide-react`.

## Global Constraints

- Branch `pocketbase-served-dashboard` (root repo only — the submodule is never modified in this plan, only removed at the end).
- `pocketbase/pb_public/` is a build artifact: **gitignored, never committed**. Source of truth is `dashboard/`.
- No Next.js, no Radix, no next-themes, no React Router. Auth persistence is the PocketBase SDK default (localStorage) — no cookies, no middleware.
- PocketBase client base URL: `import.meta.env.VITE_POCKETBASE_URL || "/"` — env var is dev-only; production is same-origin.
- Behavior parity contract (from the spec): realtime list + backend-unavailable banner, byte-identical export logic, cascade delete, email display + sign-out. New: signed-out state shows the Login screen; login lands on Dashboard without reload; request 401/403 clears the auth store (→ Login).
- Login screen is required: email/password only, "Accounts are created by the administrator." note, no sign-up/reset.
- Dependency versions (match the submodule where ported code came from): `docx ^9.3.0`, `jszip ^3.10.1`, `file-saver ^2.0.5`, `@types/file-saver ^2.0.7`, `lucide-react ^0.468.0`, `pocketbase ^0.27.1`, `react`/`react-dom ^19.0.0`, `tailwindcss ^3.4.17`, `typescript ^5.7.2`, `vite ^6.0.0`, `@vitejs/plugin-react ^4.3.4`.
- Every task ends with `cd dashboard && npm run build` passing (after Task 1 creates it). Run `nvm use node` first if the default Node is old.
- The PocketBase server restart (needed for it to start serving `pb_public/`) is done by the controller, not implementer subagents. Implementers never start/stop servers and never write to `.claude/` settings files.
- Verbatim ports come from the submodule checkout at `equine-frontend/` (branch `pocketbase-migration`, commit a76f672) — it is still present until Task 6.
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Scaffold the Vite app + build pipeline into pb_public

**Files:**
- Create: `dashboard/package.json`, `dashboard/vite.config.ts`, `dashboard/tsconfig.json`, `dashboard/index.html`, `dashboard/postcss.config.js`, `dashboard/tailwind.config.ts`, `dashboard/src/index.css`, `dashboard/src/vite-env.d.ts`, `dashboard/src/main.tsx`, `dashboard/src/App.tsx` (placeholder — real version in Task 4), `dashboard/.env.example`, `dashboard/.gitignore`
- Modify: `pocketbase/.gitignore` (add `pb_public/`)

**Interfaces:**
- Produces: a building Vite app whose `npm run build` emits to `pocketbase/pb_public/`; Tailwind theme tokens (`background`, `foreground`, `muted-foreground`, `input`, `primary`, etc.) that all later components' classNames rely on; `src/main.tsx` calling `initTheme()` (defined in Task 2 — main.tsx gets its final form there).

- [ ] **Step 1: Write `dashboard/package.json`**

```json
{
  "name": "equine-dashboard",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "docx": "^9.3.0",
    "file-saver": "^2.0.5",
    "jszip": "^3.10.1",
    "lucide-react": "^0.468.0",
    "pocketbase": "^0.27.1",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@types/file-saver": "^2.0.7",
    "@types/react": "^19.0.2",
    "@types/react-dom": "^19.0.2",
    "@vitejs/plugin-react": "^4.3.4",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "tailwindcss": "^3.4.17",
    "typescript": "^5.7.2",
    "vite": "^6.0.0"
  }
}
```

- [ ] **Step 2: Write `dashboard/vite.config.ts`**

```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: {
    // The built app is served by PocketBase itself (pb_public is auto-served
    // at / with SPA fallback). This directory is gitignored — build artifact.
    outDir: "../pocketbase/pb_public",
    emptyOutDir: true,
  },
});
```

- [ ] **Step 3: Write `dashboard/tsconfig.json`**

`noUnusedLocals` stays off: `src/actions/*` are verbatim ports from a Next.js build that doesn't enforce it.

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": false,
    "noFallthroughCasesInSwitch": true,
    "types": ["vite/client"]
  },
  "include": ["src"]
}
```

- [ ] **Step 4: Write `dashboard/index.html`**

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Horse C.O.P. Reports</title>
  </head>
  <body class="bg-background text-foreground">
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 5: Write `dashboard/postcss.config.js`**

```javascript
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

- [ ] **Step 6: Write `dashboard/tailwind.config.ts`**

Same token set as the old app (its `dark:`/token classNames port unchanged); container/accordion/Radix animation config dropped.

```typescript
import type { Config } from "tailwindcss";

const config = {
  darkMode: ["class"],
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
  plugins: [],
} satisfies Config;

export default config;
```

- [ ] **Step 7: Copy the theme CSS**

```bash
cp equine-frontend/app/globals.css dashboard/src/index.css
```

(Contents port unchanged: `@tailwind` directives, the `:root`/`.dark` HSL variable blocks, and the `@layer base` body styles.)

- [ ] **Step 8: Write `dashboard/src/vite-env.d.ts`**

```typescript
/// <reference types="vite/client" />
```

- [ ] **Step 9: Write placeholder `dashboard/src/main.tsx` and `dashboard/src/App.tsx`**

`main.tsx` (final form arrives in Task 2 when `initTheme` exists):

```tsx
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

`App.tsx` placeholder (replaced in Task 4):

```tsx
export default function App() {
  return (
    <main className="min-h-screen flex items-center justify-center">
      <p className="text-muted-foreground">Horse C.O.P. dashboard — scaffolding</p>
    </main>
  );
}
```

- [ ] **Step 10: Write `dashboard/.env.example` and `dashboard/.gitignore`; gitignore pb_public**

`dashboard/.env.example`:

```
# Dev only: where the Vite dev server finds PocketBase. The production build
# is served BY PocketBase, so it uses same-origin "/" and needs no env at all.
VITE_POCKETBASE_URL=http://localhost:8090
```

`dashboard/.gitignore`:

```gitignore
node_modules
.env
.env.local
```

Append to `pocketbase/.gitignore` (below the existing `pb_data/` line):

```gitignore
pb_public/
```

- [ ] **Step 11: Install and build**

```bash
cd dashboard && nvm use node && npm install && npm run build
ls ../pocketbase/pb_public/index.html && ls ../pocketbase/pb_public/assets | head -3
cd .. && git status --short pocketbase/ | grep pb_public && echo "NOT IGNORED — fix .gitignore" || echo "pb_public correctly ignored"
```

Expected: build succeeds, `index.html` + hashed assets exist, "pb_public correctly ignored".

- [ ] **Step 12: Commit**

```bash
git add dashboard pocketbase/.gitignore
git commit -m "feat(dashboard): scaffold Vite+React app building into pb_public

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Port the libraries (PB client, assessments, docx generators, BackendError, theme)

**Files:**
- Create: `dashboard/src/lib/pocketbase.ts`, `dashboard/src/lib/useTheme.ts`
- Copy: `equine-frontend/lib/assessments.ts` → `dashboard/src/lib/assessments.ts`; `equine-frontend/actions/docxReport.ts` and `equine-frontend/actions/docGeneration.ts` → `dashboard/src/actions/`; `equine-frontend/components/backend-error.tsx` → `dashboard/src/components/BackendError.tsx`
- Modify: `dashboard/src/main.tsx` (final form: call `initTheme()`)

**Interfaces:**
- Consumes: Task 1 scaffold.
- Produces (used by Tasks 3–4): `getPocketBase(): PocketBase` from `src/lib/pocketbase.ts`; everything `src/lib/assessments.ts` already exports (`AssessmentRecord`, `HorseRecord`, `fetchAssessmentDetails(id: string)`, `fetchAssessmentMedia(assessment, horses)`, `deleteAssessmentCascade(assessment)`); `BackendErrorMessage({ message }: { message: string })` from `src/components/BackendError.tsx`; `generateDocument` (default) from `src/actions/docxReport`; `generateHorseDoc` from `src/actions/docGeneration`; `useTheme(): { theme: Theme, setTheme(t: Theme): void }`, `initTheme()`, `type Theme = "light" | "dark" | "system"` from `src/lib/useTheme.ts`.

- [ ] **Step 1: Write `dashboard/src/lib/pocketbase.ts`**

```typescript
import PocketBase from "pocketbase";

let client: PocketBase | null = null;

// Same-origin in production (the app is served from PocketBase's pb_public);
// VITE_POCKETBASE_URL is only for the Vite dev server on its own port.
// Auth persists via the SDK's default localStorage store.
export function getPocketBase(): PocketBase {
  if (!client) {
    client = new PocketBase(import.meta.env.VITE_POCKETBASE_URL || "/");
  }
  return client;
}
```

- [ ] **Step 2: Copy the verbatim ports**

```bash
mkdir -p dashboard/src/actions dashboard/src/components
cp equine-frontend/lib/assessments.ts dashboard/src/lib/assessments.ts
cp equine-frontend/actions/docxReport.ts dashboard/src/actions/docxReport.ts
cp equine-frontend/actions/docGeneration.ts dashboard/src/actions/docGeneration.ts
cp equine-frontend/components/backend-error.tsx dashboard/src/components/BackendError.tsx
```

`assessments.ts` imports `./pocketbase` — the relative path still resolves. `BackendError.tsx` has no framework imports and keeps the `BackendErrorMessage` named export and its "./pocketbase serve" hint text.

- [ ] **Step 3: Check the copied actions for Next-isms**

```bash
grep -n "use server\|next/\|@/" dashboard/src/actions/*.ts dashboard/src/components/BackendError.tsx dashboard/src/lib/assessments.ts
```

Expected: no matches. If a `"use server"` directive line appears, delete that line (the generators run in the browser). If an `@/` alias import appears, rewrite it as the equivalent relative import.

- [ ] **Step 4: Write `dashboard/src/lib/useTheme.ts`**

```typescript
import { useEffect, useState } from "react";

export type Theme = "light" | "dark" | "system";

function systemPrefersDark(): boolean {
  return window.matchMedia("(prefers-color-scheme: dark)").matches;
}

function apply(theme: Theme) {
  const dark = theme === "dark" || (theme === "system" && systemPrefersDark());
  document.documentElement.classList.toggle("dark", dark);
}

function storedTheme(): Theme {
  const value = localStorage.getItem("theme");
  return value === "light" || value === "dark" ? value : "system";
}

// Called once before React renders (main.tsx) so a dark-theme user doesn't
// get a white flash while the app mounts.
export function initTheme() {
  apply(storedTheme());
}

export function useTheme() {
  const [theme, setThemeState] = useState<Theme>(storedTheme);

  useEffect(() => {
    apply(theme);
    if (theme !== "system") return;
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => apply("system");
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [theme]);

  const setTheme = (t: Theme) => {
    localStorage.setItem("theme", t);
    setThemeState(t);
  };

  return { theme, setTheme };
}
```

- [ ] **Step 5: Finalize `dashboard/src/main.tsx`**

```tsx
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { initTheme } from "./lib/useTheme";
import "./index.css";

initTheme();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

- [ ] **Step 6: Build**

Run: `cd dashboard && npm run build`
Expected: passes (the ported modules are not imported by App yet — that's fine, `tsc` still typechecks everything under `src/`).

- [ ] **Step 7: Commit**

```bash
git add dashboard/src
git commit -m "feat(dashboard): port PB client, assessments lib, docx generators, theme hook

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Dashboard component (port of the protected page)

**Files:**
- Copy then modify: `equine-frontend/app/protected/page.tsx` → `dashboard/src/components/Dashboard.tsx`

**Interfaces:**
- Consumes: everything Task 2 produced (`getPocketBase`, assessments lib, `BackendErrorMessage`, docx generators).
- Produces: `export default function Dashboard({ email }: { email: string | null })` — rendered by Task 4's App. Reads no auth state itself except the 401 hook below.

- [ ] **Step 1: Copy the source file**

```bash
cp equine-frontend/app/protected/page.tsx dashboard/src/components/Dashboard.tsx
```

- [ ] **Step 2: Apply exactly these edits to `Dashboard.tsx`**

a) Delete the first line `"use client";`.

b) Replace the entire import block (everything down to the first `function`/`const` after imports) with:

```tsx
import { useCallback, useEffect, useState } from "react";
import { Download, Loader2, Trash2 } from "lucide-react";
import { Packer } from "docx";
import { saveAs } from "file-saver";
import JSZip from "jszip";
import generateDocument from "../actions/docxReport";
import { generateHorseDoc } from "../actions/docGeneration";
import { BackendErrorMessage } from "./BackendError";
import { getPocketBase } from "../lib/pocketbase";
import {
  AssessmentRecord,
  deleteAssessmentCascade,
  fetchAssessmentDetails,
  fetchAssessmentMedia,
} from "../lib/assessments";
```

c) Change the component signature from
`export default function ProtectedPage() {` to
`export default function Dashboard({ email }: { email: string | null }) {`

d) Delete the line `const [email, setEmail] = useState<string | null>(null);` (email is now the prop).

e) In the `useEffect`, delete the line `setEmail((pb.authStore.record?.email as string | undefined) ?? null);`.

f) Replace the `reload` callback's catch block so a dead session flips the app back to Login instead of showing the banner:

```tsx
  const reload = useCallback(async () => {
    try {
      const records = await getPocketBase()
        .collection("assessments")
        .getFullList<AssessmentRecord>({ sort: "-created" });
      setAssessments(records);
      setLoadError(null);
    } catch (err) {
      const status = (err as { status?: number }).status;
      if (status === 401 || status === 403) {
        // Token expired or user removed — clear auth; App's onChange
        // listener switches to the Login screen.
        getPocketBase().authStore.clear();
        return;
      }
      setLoadError("Could not connect to the PocketBase backend.");
    }
  }, []);
```

Everything else — the realtime `subscribe`/`unsubscribe` effect, `sanitizeName`, `handleDelete`, the entire `handleDownload` docx/zip assembly, and all JSX (including `<h2>Hey, {email ?? "there"}!</h2>`) — stays byte-identical to the copied file.

- [ ] **Step 3: Build**

Run: `cd dashboard && npm run build`
Expected: passes. (Dashboard is not yet rendered by App — `tsc` still checks it.)

- [ ] **Step 4: Commit**

```bash
git add dashboard/src/components/Dashboard.tsx
git commit -m "feat(dashboard): port assessments dashboard from Next protected page

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Login screen + App shell (auth switching, header, theme toggle)

**Files:**
- Create: `dashboard/src/components/Login.tsx`
- Copy: `equine-frontend/assets/logo-small.png` → `dashboard/src/assets/logo-small.png`
- Replace: `dashboard/src/App.tsx` (placeholder → final)

**Interfaces:**
- Consumes: `getPocketBase`, `useTheme`/`Theme`, `Login`, `Dashboard` (with its `email` prop) from earlier tasks.
- Produces: the complete app. Login performs `authWithPassword`; success needs no navigation — App's `authStore.onChange` listener re-renders into Dashboard.

- [ ] **Step 1: Copy the logo**

```bash
mkdir -p dashboard/src/assets
cp equine-frontend/assets/logo-small.png dashboard/src/assets/logo-small.png
```

- [ ] **Step 2: Write `dashboard/src/components/Login.tsx`**

```tsx
import { useState } from "react";
import { getPocketBase } from "../lib/pocketbase";

export default function Login() {
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
      // authStore.onChange in App switches to the Dashboard — nothing else to do.
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
          <label htmlFor="email" className="text-sm font-medium">
            Email
          </label>
          <input
            id="email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            className="border border-input rounded-md px-3 py-2 bg-background text-sm"
          />
        </div>
        <div className="flex flex-col gap-2">
          <label htmlFor="password" className="text-sm font-medium">
            Password
          </label>
          <input
            id="password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            className="border border-input rounded-md px-3 py-2 bg-background text-sm"
          />
        </div>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <button
          type="submit"
          disabled={submitting}
          className="bg-primary text-primary-foreground rounded-md py-2 text-sm font-medium hover:opacity-90 disabled:opacity-50"
        >
          {submitting ? "Signing in..." : "Sign in"}
        </button>
        <p className="text-xs text-muted-foreground">
          Accounts are created by the administrator.
        </p>
      </form>
    </div>
  );
}
```

- [ ] **Step 3: Write the final `dashboard/src/App.tsx`**

```tsx
import { useEffect, useState } from "react";
import { Monitor, Moon, Sun } from "lucide-react";
import { getPocketBase } from "./lib/pocketbase";
import { Theme, useTheme } from "./lib/useTheme";
import Dashboard from "./components/Dashboard";
import Login from "./components/Login";
import logo from "./assets/logo-small.png";

const THEME_ORDER: Theme[] = ["light", "dark", "system"];

function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const next = THEME_ORDER[(THEME_ORDER.indexOf(theme) + 1) % THEME_ORDER.length];
  const Icon = theme === "light" ? Sun : theme === "dark" ? Moon : Monitor;
  return (
    <button
      onClick={() => setTheme(next)}
      title={`Theme: ${theme} (click for ${next})`}
      className="p-2 rounded-md hover:bg-muted"
    >
      <Icon className="w-4 h-4" />
    </button>
  );
}

export default function App() {
  const pb = getPocketBase();
  const [signedIn, setSignedIn] = useState(pb.authStore.isValid);
  const [email, setEmail] = useState<string | null>(
    (pb.authStore.record?.email as string | undefined) ?? null
  );

  useEffect(() => {
    return pb.authStore.onChange(() => {
      setSignedIn(pb.authStore.isValid);
      setEmail((pb.authStore.record?.email as string | undefined) ?? null);
    });
  }, [pb]);

  return (
    <main className="min-h-screen flex flex-col items-center">
      <div className="flex-1 w-full flex flex-col gap-20 items-center">
        <nav className="w-full flex justify-center border-b border-b-foreground/10 h-16">
          <div className="w-full max-w-5xl flex justify-between items-center p-3 px-5 text-sm">
            <span className="flex items-center text-lg font-black">
              <img
                src={logo}
                className="w-auto max-w-[35px]"
                alt="Horse C.O.P logo"
              />
              C.O.P
            </span>
            <div className="flex items-center gap-3">
              {signedIn && (
                <>
                  <span className="text-xs text-muted-foreground">{email}</span>
                  <button
                    onClick={() => pb.authStore.clear()}
                    className="border rounded-md py-1.5 px-3 text-xs hover:bg-muted"
                  >
                    Sign out
                  </button>
                </>
              )}
              <ThemeToggle />
            </div>
          </div>
        </nav>
        {signedIn ? <Dashboard email={email} /> : <Login />}
      </div>
    </main>
  );
}
```

- [ ] **Step 4: Build**

Run: `cd dashboard && npm run build`
Expected: passes; `pocketbase/pb_public/` now contains the real app (logo appears under `assets/`).

- [ ] **Step 5: Commit**

```bash
git add dashboard/src
git commit -m "feat(dashboard): login screen and auth-switching app shell

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Serve-from-PocketBase verification + run docs

**Files:**
- Modify: `pocketbase/README.md` (add Dashboard section)

**Interfaces:**
- Consumes: built `pb_public/` from Task 4; running PocketBase (controller restarts it after the build so the `pb_public` route registers).

- [ ] **Step 1: Rebuild and hand off for restart**

```bash
cd dashboard && npm run build
```

Then the CONTROLLER restarts PocketBase. Implementer: verify with the curl checks below only after the controller confirms the restart.

- [ ] **Step 2: Curl verification (server on :8090)**

```bash
curl -s http://localhost:8090/ | grep -o '<div id="root"></div>' && echo "index served"
curl -s http://localhost:8090/some/deep/link | grep -o '<div id="root"></div>' && echo "SPA fallback works"
curl -s -o /dev/null -w "admin UI: %{http_code}\n" http://localhost:8090/_/
curl -s http://localhost:8090/api/health | grep -o '"code":200' && echo "API intact"
```

Expected: all four checks print their success lines (admin UI 200).

- [ ] **Step 3: Add a Dashboard section to `pocketbase/README.md`** (after the "Run" section)

````markdown
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
````

- [ ] **Step 4: Commit**

```bash
git add pocketbase/README.md
git commit -m "docs(pocketbase): dashboard build + serve instructions

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Browser checklist (controller/user — record results, not a subagent step)**

At `http://localhost:8090/`: bad login rejected inline → good login lands on Dashboard without reload → `./scripts/test_sync.sh tester@example.com test-password-123` (cleanup DELETE commented out) makes the new assessment appear without refresh → zip export downloads with report + media → delete cascades → sign out returns to Login → reload while signed out still shows Login → theme toggle cycles and persists across reload.

---

### Task 6: Retire the equine-frontend submodule + docs

**Files:**
- Delete: `equine-frontend` submodule (gitlink + `.gitmodules` entry)
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: verified dashboard (Task 5) — do not start this task before Task 5's curl checks pass.
- Produces: single-repo layout. The `ajeetgill/equine-frontend` GitHub repo and its PR are NOT touched — the root repo just stops referencing them.

- [ ] **Step 1: Remove the submodule**

```bash
git submodule deinit -f equine-frontend
git rm -f equine-frontend
# git rm updates .gitmodules; if the file has no sections left, remove it too:
grep -q '\[submodule' .gitmodules 2>/dev/null || git rm -f .gitmodules 2>/dev/null || true
rm -rf .git/modules/equine-frontend
git submodule status; echo "exit: $?"
```

Expected: `git submodule status` prints nothing.

- [ ] **Step 2: Update `CLAUDE.md`**

- Project Overview: replace the Web App line with
  `- **Web Dashboard** (\`dashboard/\`): Vite + React 19, TypeScript — built into \`pocketbase/pb_public/\` and served by PocketBase`
  and remove "(git submodule)" phrasing anywhere.
- Build & Run Commands → replace the "Web App" subsection with:
  ````markdown
  ### Web Dashboard
  ```bash
  cd dashboard
  nvm use node              # Switch to latest Node.js first
  npm install
  npm run dev               # Vite dev server on localhost:5173 (PocketBase must run on :8090)
  npm run build             # Builds into pocketbase/pb_public/ (served by PocketBase at :8090)
  ```
  ````
- Key Directories → replace the "Web (`equine-frontend/`)" block with:
  ````markdown
  **Web (`dashboard/`):**
  - `src/components/` - Login, Dashboard, BackendError
  - `src/lib/` - PocketBase client, assessments data layer, theme hook
  - `src/actions/` - Client-side docx/report generators (no backend calls)
  ````
- Configuration → replace the Web subsection with:
  ````markdown
  ### Web
  No configuration needed for production (served same-origin by PocketBase).
  For the Vite dev server, copy `dashboard/.env.example` to `dashboard/.env`:
  - `VITE_POCKETBASE_URL` (typically `http://localhost:8090`)
  ````
- Current Migration Context: replace the paragraph to say branch `pocketbase-served-dashboard` moved the dashboard into `dashboard/` (served by PocketBase) and retired the `equine-frontend` submodule; keep the references to both spec/plan docs and add this plan's paths (`docs/superpowers/specs/2026-08-02-pocketbase-served-dashboard-design.md`, `docs/superpowers/plans/2026-08-02-pocketbase-served-dashboard.md`).

- [ ] **Step 3: Verify nothing referenced the submodule**

```bash
grep -rn "equine-frontend" CLAUDE.md docs/superpowers/specs/2026-08-02-pocketbase-served-dashboard-design.md dashboard/src 2>/dev/null | grep -v "retired\|submodule entry removed\|GitHub" || echo "no live references"
cd dashboard && npm run build && cd ..
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -1
```

Expected: "no live references" (historical mentions in older specs/plans are fine and excluded from this check's scope), dashboard build passes, iOS `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: retire equine-frontend submodule, dashboard now served by PocketBase

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
