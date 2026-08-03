# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dual-platform equine (horse/donkey) welfare assessment application:
- **iOS App** (`equine-welfare/`): Swift 6.1, SwiftUI, SwiftData (local-first)
- **Web Dashboard** (`dashboard/`): Vite + React 19, TypeScript — built into `pocketbase/pb_public/` and served by PocketBase
- **Current Backend**: PocketBase (self-hosted — auth, database, file storage) in pocketbase/

## Build & Run Commands

### iOS App
```bash
# Build (from repo root)
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build

# Or open in Xcode and run (⌘R)
open equine-welfare.xcodeproj
```
- Requires Xcode 16.2+, Swift 6.1
- Primary target: iPad

### Web Dashboard
```bash
cd dashboard
nvm use node              # Switch to latest Node.js first
npm install
npm run dev               # Vite dev server on localhost:5173 (PocketBase must run on :8090)
npm run build             # Builds into pocketbase/pb_public/ (served by PocketBase at :8090)
```

### PocketBase
```bash
cd pocketbase
./pocketbase serve --http 0.0.0.0:8090
```

## Architecture

### iOS: Local-First with Cloud Sync
- **SwiftData** is the source of truth for all data
- MVVM pattern: Views → ViewModels (Observable) → Models (@Model)
- Manual sync button uploads to cloud on demand
- Supports full offline usage

### Data Model Hierarchy
```
Assessment
├── Sections → Subsections → Requirements (compliance tracking)
├── Horses → MediaAttachments (photos: front/right/back/left/abnormal)
└── Side notes
```

### Key Directories

**iOS (`equine-welfare/`):**
- `Models/` - SwiftData models (Assessment, Horse, Section, Subsection, Requirement, MediaAttachment)
- `ViewModels/` - Observable view models
- `Views/` - SwiftUI views
- `Services/` - Business logic (PocketBaseService cloud sync, COPService reference-data loading)
- `Utils/` - Helpers (BCS managers, assessment export/formatting)
- `Static-Data/` - JSON reference data (COP.json, BCS.json)

**Web (`dashboard/`):**
- `src/components/` - Login, Dashboard, BackendError
- `src/lib/` - PocketBase client, assessments data layer, theme hook
- `src/actions/` - Client-side docx/report generators (no backend calls)

## Configuration

### iOS
Copy `equine-welfare/Config/Secrets.example.xcconfig` to `Secrets.xcconfig` and set:
- `POCKETBASE_URL` (typically `http://localhost:8090` for development)

### Web
No configuration needed for production (served same-origin by PocketBase).
For the Vite dev server, copy `dashboard/.env.example` to `dashboard/.env`:
- `VITE_POCKETBASE_URL` (typically `http://localhost:8090`)

## Current Migration Context

Branch `pocketbase-migration` migrated from Convex + Clerk to PocketBase (self-hosted auth, database, and file storage). See `docs/superpowers/plans/2026-08-02-pocketbase-migration.md` for the full plan and `docs/superpowers/specs/2026-08-02-pocketbase-migration-design.md` for technical specification.

Branch `pocketbase-served-dashboard` moved the dashboard into `dashboard/` (built into `pocketbase/pb_public/` and served by PocketBase) and retired the `equine-frontend` submodule. See `docs/superpowers/specs/2026-08-02-pocketbase-served-dashboard-design.md` for the technical specification and `docs/superpowers/plans/2026-08-02-pocketbase-served-dashboard.md` for the full plan.

## Coding Guidelines

### iOS (from Cursor rules)
- **SwiftUI-first**: Only use UIKit if SwiftUI cannot accomplish the task
- **MVVM architecture** with SwiftData
- Use SF Symbols for icons
- Prefer value types (structs) over classes
- When teaching/explaining: explain WHY behind implementation choices

### Web
- TypeScript strict mode enabled
- Plain React function components styled with Tailwind CSS (no Radix, no server actions)
- All backend access goes through the PocketBase JS SDK via `src/lib/pocketbase.ts`
