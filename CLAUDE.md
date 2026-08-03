# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dual-platform equine (horse/donkey) welfare assessment application:
- **iOS App** (`equine-welfare/`): Swift 6.1, SwiftUI, SwiftData (local-first)
- **Web App** (`equine-frontend/`): Next.js 15, React 19, TypeScript (git submodule)
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

### Web App
```bash
cd equine-frontend
nvm use node              # Switch to latest Node.js first
npm install
npm run dev               # Development server on localhost:3000
npm run build             # Production build
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
- `Services/` - Business logic (ConvexService cloud sync, COPService reference-data loading)
- `Utils/` - Helpers (BCS managers, assessment export/formatting)
- `Static-Data/` - JSON reference data (COP.json, BCS.json)

**Web (`equine-frontend/`):**
- `app/` - Next.js app directory with routes
- `components/` - React components (Radix UI + Tailwind)
- `actions/` - Server actions for Supabase queries

## Configuration

### iOS
Copy `equine-welfare/Config/Secrets.example.xcconfig` to `Secrets.xcconfig` and set:
- `POCKETBASE_URL` (typically `http://localhost:8090` for development)

### Web
Copy `equine-frontend/.env.example` to `.env.local` and configure:
- `NEXT_PUBLIC_POCKETBASE_URL` (typically `http://localhost:8090`)

## Current Migration Context

Branch `pocketbase-migration` is migrating from Convex + Clerk to PocketBase (self-hosted auth, database, and file storage). See `docs/superpowers/plans/2026-08-02-pocketbase-migration.md` for the full plan and `docs/superpowers/specs/2026-08-02-pocketbase-migration-design.md` for technical specification.

## Coding Guidelines

### iOS (from Cursor rules)
- **SwiftUI-first**: Only use UIKit if SwiftUI cannot accomplish the task
- **MVVM architecture** with SwiftData
- Use SF Symbols for icons
- Prefer value types (structs) over classes
- When teaching/explaining: explain WHY behind implementation choices

### Web
- TypeScript strict mode enabled
- Component-based with Radix UI primitives
- Tailwind CSS for styling
- Server actions for mutations
