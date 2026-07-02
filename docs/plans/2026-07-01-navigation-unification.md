# Navigation Unification — Implementation Plan

**Goal:** Replace the three incompatible, ad-hoc navigation systems with one
coherent, data-driven structure built on the current SwiftUI-preferred APIs
(`NavigationStack` + typed destinations, `NavigationSplitView` with a
selection binding). Eliminate manual `@State`-enum view swapping, duplicated
navigation state, and the hand-rolled back buttons.

**Tech stack:** Swift 6.1, SwiftUI, iOS 18.2 deployment target, **iPad-primary**.

---

## Hard constraint (read first)

A previous fix (`docs/plans/2026-02-01-fix-nested-navigationstack.md`) removed a
`NavigationStack` from `HorsesNavigationView` because **nesting a
`NavigationStack` inside another `NavigationStack`** broke iPhone compact
(blank screens + "NavigationLink presenting value of type AppDestination…"
runtime warnings). The current manual `@State`-enum swapping is the workaround
that replaced it.

**This plan must not re-introduce a `NavigationStack` directly inside another
`NavigationStack`.** The safe structure is: one root `NavigationStack`, and a
`NavigationSplitView` for the workspace (a split view *may* be pushed as a
destination of a stack, and its detail column *may* own its own stack — those
are supported; stack-in-stack is not).

Because the iOS platform can't currently be built in the working environment,
**every phase below ends with a real Xcode build + device test** before moving
on. Do not batch phases.

---

## Current state (what we're replacing)

| # | System | Where | Problem |
|---|--------|-------|---------|
| 1 | `NavigationStack(path:)` + `AppDestination` | `ContentView` | Correct foundation, but only used for the top level; `.sectionDetail` is resolved here *and* inside the sidebar (redundant); enum has commented-out horse cases |
| 2 | `@State DetailView` enum + `if/switch` swap | `AssessmentSidebarView` | Receives `navigationPath` but ignores it; hand-built button bar; a separate `compactLayout` duplicates the whole pane list; a `NavigationSplitView` is nested *inside* ContentView's stack with its detail also driven by the enum |
| 3 | `@State HorseViewState` enum + `if` swap | `HorsesNavigationView` | Fully isolated; manual "Back" toolbar button; `onSelectHorse`/`onEdit`/`onDismiss` callbacks instead of navigation |

Duplicated/derived state to collapse: `ContentView.currentAssessmentId`
duplicates what the pushed `AppDestination` already carries;
`selectedSectionId` is unused by the target design.

---

## Target architecture

Three **legitimately separate** navigation containers, each with a **single
source of truth**. Having more than one container is correct — the bug was
never "multiple containers," it was "ad-hoc `@State` instead of real
bindings, and stack-in-stack."

```
NavigationStack(path: [AppDestination])          ← ContentView (root, app-level flow)
│   root = Home (MainScreen + PreviousAssessments)
│
└── .assessment(id:) ──> AssessmentWorkspaceView
        │
        NavigationSplitView(sidebar: detail:)     ← workspace (pane selection)
        │   sidebar = List(selection: $pane)  [Overview·Sections·Horses·Gallery·Notes + applicable sections]
        │
        └── detail: switch(pane)
              ├── .overview   → AssessmentOverviewView
              ├── .sections   → SectionSelectionView
              ├── .section(id)→ SectionDetailView
              ├── .gallery    → GalleryView
              ├── .notes      → SideNotesView
              └── .horses     → NavigationStack(path: [HorseRoute])   ← horses sub-flow
                                  root = HorsesView (list)
                                  ├── .info(id) → HorseInfoView
                                  ├── .add      → HorseDetailView(nil)
                                  └── .edit(id) → HorseDetailView(id)
```

Why this shape:
- **Top level is a push flow** (Home → one assessment) → `NavigationStack`.
- **Panes are a selection, not a push** → `NavigationSplitView` + `List(selection:)`.
  This also gives iPad the correct sidebar highlight for free, and
  **auto-collapses to a single stack on compact — so the entire hand-written
  `compactLayout` (the horizontal button scroller) is deleted.**
- **Horse list → info → edit is a genuine push flow** → its own
  `NavigationStack` living in the detail column (a stack inside a split-view
  detail column is supported; it is *not* a stack-in-stack).

### New route types

Replace the three enums with two `Hashable` route types plus a pane enum.

```swift
// App-level flow (root stack). Simplify AppDestination down to what actually
// pushes at the top level — everything else moves into the workspace.
enum AppDestination: Hashable {
    case assessment(id: UUID)
}

// Which pane of the workspace is showing (NavigationSplitView selection).
// Select sections by Int id, not by the SwiftData model, so it stays Hashable
// and survives model reloads.
enum WorkspacePane: Hashable {
    case overview
    case sections
    case section(id: Int)
    case gallery
    case notes
    case horses
}

// Horse sub-flow (detail-column stack).
enum HorseRoute: Hashable {
    case info(horseId: UUID)
    case add
    case edit(horseId: UUID)
}
```

Navigation becomes value-based throughout:
- `path.append(AppDestination.assessment(id: id))` instead of setting `currentAssessmentId` + append.
- Sidebar rows: `List(selection: $pane) { NavigationLink(value: WorkspacePane.horses) { … } }` (or a plain selectable list).
- Horse rows: `NavigationLink(value: HorseRoute.info(horseId: horse.uuid))`.
- "Add": `hPath.append(HorseRoute.add)`; "Back"/dismiss: `@Environment(\.dismiss)` or `hPath.removeLast()` — **the system draws the back button**, so the manual one is deleted.

---

## Phase 0 — Define routes (no behavior change)

**Files:** new `equine-welfare/Utils/Navigation/Routes.swift`

- Add `WorkspacePane` and `HorseRoute`. Leave the existing `AppDestination`
  untouched for now (changed in Phase 1).
- Build. Nothing uses them yet — this just lands the types cleanly.

**Verify:** BUILD SUCCEEDED.

---

## Phase 1 — Top-level stack cleanup

**Files:** `AppDestination.swift`, `ContentView.swift`, `PreviousAssessments.swift`, `MainScreen.swift`

1. Reduce `AppDestination` to `case assessment(id: UUID)` (delete the
   commented horse cases and the now-workspace-internal `.overview` /
   `.sectionDetail`; drop the hand-written `Hashable`/`==` — the simple enum
   synthesizes both).
2. In `ContentView`:
   - Change `@State private var navigationPath = NavigationPath()` to
     `@State private var path: [AppDestination] = []` (typed array is easier to
     inspect/deep-link than `NavigationPath`).
   - Delete `currentAssessmentId` and `selectedSectionId` — the pushed
     `.assessment(id:)` is the source of truth.
   - `.navigationDestination(for: AppDestination.self)` resolves
     `.assessment(id:)` → `AssessmentWorkspaceView(assessmentId: id)` (the
     renamed/rehomed `AssessmentSidebarView`; see Phase 2). Remove the
     `.overview` / `.sectionDetail` arms.
   - Simplify `startNewAssessment` / `editAssessment` to a single append;
     `returnToMain` becomes `path.removeAll()` + form reset;
     delete `showSectionSelection` / `loadAssessment` id-diff bookkeeping
     (the workspace owns its own load — see Phase 2).
3. Update `PreviousAssessments` / `MainScreen` callbacks to append
   `.assessment(id:)`.

**Verify:** Build; from Home, start a new assessment and open a previous one —
both land in the workspace; back returns Home. (Workspace internals unchanged
this phase.)

---

## Phase 2 — Workspace as a real `NavigationSplitView`

**Files:** `AssessmentSidebarView.swift` → rename to `AssessmentWorkspaceView.swift`

1. Replace `@State private var currentDetailView: DetailView` and the private
   `DetailView` enum with `@State private var pane: WorkspacePane = .sections`.
2. Body becomes a single `NavigationSplitView` for **all** size classes:
   - `sidebar:` a `List(selection: $pane)` — one row per fixed pane, then a
     `Section("Applicable Sections")` with `WorkspacePane.section(id:)` rows
     from `viewModel.applicableSections`. This replaces `navigationButtonsView`,
     `sectionsList`, the `SidebarButton`/`CompactNavButton` helpers, **and the
     entire `compactLayout`** (NavigationSplitView adapts to compact itself).
   - `detail:` `switch pane { … }` — same `detailContent` mapping you have now,
     with `.section(id:)` looking the section up by id via the view model.
3. Keep the `.onDisappear { viewModel.saveAssessment() }` save hook (move it to
   the split view). Keep `viewModel.loadAssessment(id:)` in an `.onAppear`/`task`
   on the workspace so the workspace is self-loading (removes ContentView's
   cross-assessment bookkeeping from Phase 1).
4. **Naming caveat:** the model type `Section` collides with SwiftUI's `Section`
   used in the sidebar `List`. Disambiguate the SwiftData one as
   `EquineWelfare.Section` (module name) or the SwiftUI one as `SwiftUI.Section`
   at the call sites — or (recommended, larger) rename the model to
   `AssessmentSection` in a separate change.

**Verify:** Build on **iPad** (regular width) first: sidebar selection switches
panes, section rows work, selection highlights. Then build on **iPhone**
(compact): confirm the split view collapses to a working list→detail stack and
there is **no** nested-stack warning.

---

## Phase 3 — Horses sub-flow as a `NavigationStack`

**Files:** `HorsesNavigationView.swift`, `HorsesView.swift`, `HorseInfoView.swift`, `HorseDetailView.swift`

1. Rewrite `HorsesNavigationView` body as
   `NavigationStack(path: $hPath) { HorsesView(...) .navigationDestination(for: HorseRoute.self) { … } }`
   where `@State private var hPath: [HorseRoute] = []`.
   - `.info(id)` → `HorseInfoView(horseId: id)`
   - `.add` → `HorseDetailView(horseId: nil, assessmentId:)`
   - `.edit(id)` → `HorseDetailView(horseId: id, assessmentId:)`
2. Delete the `HorseViewState` enum, the `if currentView == …` swapping, the
   `.transition(...)` moves, **and the manual "Back" toolbar button** (the stack
   supplies it). Keep the `+ Add` toolbar item but have it `hPath.append(.add)`.
3. Convert callbacks to value-based navigation / dismissal:
   - `HorsesView.onSelectHorse` → rows use
     `NavigationLink(value: HorseRoute.info(horseId: horse.uuid))`.
   - `HorseInfoView.onEdit` → replace with `hPath.append(.edit(horseId:))`
     (pass the path binding or an `@Observable` horses router down, or use a
     `NavigationLink(value:)` on the Edit button).
   - `HorseDetailView.onDismiss` → `@Environment(\.dismiss)`; on save, `dismiss()`
     (or `hPath.removeLast()`).
4. **Compact-mode risk:** this stack lives in the split view's detail column.
   On iPad regular width that's clean. On iPhone compact the split view
   collapses, so verify the horses stack pushes correctly and does **not**
   reproduce the old nested-stack warning. If it does, fall back to promoting
   horse list/detail into split-view columns (3-column) instead of a
   detail-column stack — note this as the contingency.

**Verify:** iPad + iPhone: list → tap horse → info → Edit → save/back → list;
Add → save → list. System back button present throughout; no console warnings.

---

## Phase 4 — (Stretch) Extract a router for deep-linking

Only if full deep-linking / state restoration is wanted. Introduce
`@Observable final class AppRouter { var path: [AppDestination] = [] }` injected
via `.environment`, so any view can drive top-level navigation without binding
threading, and the path can be encoded for restoration. The per-container child
paths (`pane`, `hPath`) can stay local, or move onto the router if cross-cutting
deep links (e.g. "open horse X in assessment Y") are required.

Defer unless there's a concrete deep-link requirement — Phases 1–3 already
remove the inconsistency.

---

## Risks & verification checklist

- **No stack-in-stack.** After each phase, watch the console for
  "NavigationLink presenting a value of type … NavigationStack" warnings and
  test iPhone compact explicitly (that's where the prior bug surfaced).
- **`Section` name collision** with `SwiftUI.Section` in the sidebar `List`
  (Phase 2) — disambiguate or rename the model.
- **Cannot build in this environment** (iOS 18/26 platform SDK not installed) —
  all builds/tests happen in Xcode by the implementer.
- **Behavior parity:** save-on-disappear, assessment loading, and the
  overview/sections/gallery/notes panes must behave exactly as before; this is a
  navigation refactor, not a feature change.

## Summary

| Phase | Change | Key files | Removes |
|-------|--------|-----------|---------|
| 0 | Add `WorkspacePane`, `HorseRoute` | Routes.swift (new) | — |
| 1 | Root stack: typed `[AppDestination]`, slim enum | ContentView, AppDestination, PreviousAssessments | `currentAssessmentId`, `selectedSectionId`, redundant top-level `.sectionDetail` |
| 2 | Workspace → `NavigationSplitView` + `List(selection:)` | AssessmentWorkspaceView (renamed) | `DetailView` enum, `compactLayout`, button-bar helpers |
| 3 | Horses → `NavigationStack` + `navigationDestination` | HorsesNavigationView, HorsesView, HorseInfoView, HorseDetailView | `HorseViewState`, manual Back button, `onSelectHorse`/`onEdit`/`onDismiss` callbacks |
| 4 | (Stretch) `@Observable AppRouter` for deep-linking | new router | binding threading |
