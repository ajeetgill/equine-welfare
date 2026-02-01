# Fix iPhone Blank Screen After "Start Assessment" - Diagnostic & Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the blank screen that appears on iPhone when tapping "Start Assessment" — the same flow works correctly on iPad showing the sidebar + detail content.

**Architecture:** The root cause is `NavigationSplitView` behavior differences between iPad (regular horizontal size class) and iPhone (compact horizontal size class). On iPad, `NavigationSplitView` shows sidebar + detail side-by-side. On iPhone in compact mode, it collapses into a stack-like navigation — but only the sidebar column is shown initially. The detail column content is invisible because there's no mechanism (like `NavigationLink` or column visibility binding) to push the user into the detail view. The fix is to use `@Environment(\.horizontalSizeClass)` to conditionally render either a `NavigationSplitView` (iPad) or a single-column `TabView`/`ScrollView` layout (iPhone).

**Tech Stack:** Swift 6.1, SwiftUI, NavigationSplitView, Environment horizontalSizeClass

---

## Root Cause Analysis

### The Problem

`AssessmentSidebarView.swift:64-101` uses a bare `NavigationSplitView` with two columns: sidebar and detail.

```swift
NavigationSplitView {
    ScrollView { /* sidebar buttons */ }
} detail: {
    switch currentDetailView { /* content views */ }
}
```

### Why iPad Works

On iPad (regular horizontal size class), `NavigationSplitView` renders both columns side-by-side. The sidebar is visible on the left, detail content on the right. The user sees "Section Selection" content immediately.

### Why iPhone Breaks

On iPhone (compact horizontal size class), `NavigationSplitView` collapses to show **only the sidebar column** as a full-screen view — but the sidebar content is just navigation buttons (Overview, Section Selection, Horses, etc.) rendered via custom `SidebarButton` views. These are plain `Button` views that update `@State private var currentDetailView` — they do NOT use `NavigationLink`, so there's no push navigation to the detail column.

Result: the user sees the sidebar buttons but the detail content is unreachable. Even worse — the `NavigationSplitView` is nested inside a `NavigationStack` from `ContentView.swift:34`, which means the "Back" button is from the outer `NavigationStack`, and the sidebar content may not even render properly due to the nested navigation containers.

The screenshot shows just "Back" and a blank screen — this is likely the detail column being shown (empty because the sidebar was never visible to navigate from), or the sidebar rendered with no visible content due to navigation container conflicts.

---

## Fix Strategy

**Approach: Use `horizontalSizeClass` to provide different layouts for compact vs regular.**

- **Regular (iPad):** Keep the current `NavigationSplitView` sidebar + detail layout. It works.
- **Compact (iPhone):** Replace with a single-column layout where the sidebar buttons and detail content are in a single scrollable view, or use a `TabView` for top-level navigation.

The simplest and most robust fix: on compact, skip `NavigationSplitView` entirely and show the detail content directly (defaulting to Section Selection), with a toolbar menu or segmented picker to switch between views.

---

## Tasks

### Task 1: Verify the Problem in Simulator

**Step 1: Build and run on iPhone simulator**

Run:
```bash
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Step 2: Confirm blank screen behavior**

Open the app in iPhone 16 simulator, fill in vet name and farm name, tap "Start Assessment". Confirm you see a blank screen with just "Back".

**Step 3: Confirm iPad works**

Run on iPad simulator to confirm the sidebar + detail layout works correctly:
```bash
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```

---

### Task 2: Add horizontalSizeClass Environment Variable

**Files:**
- Modify: `equine-welfare/Views/AssessmentSidebarView.swift`

**Step 1: Add the environment variable**

At the top of `AssessmentSidebarView` struct (after line 6), add:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
```

**Step 2: Commit**

```bash
git add equine-welfare/Views/AssessmentSidebarView.swift
git commit -m "feat: add horizontalSizeClass environment to AssessmentSidebarView"
```

---

### Task 3: Extract Shared Detail Content View

**Files:**
- Modify: `equine-welfare/Views/AssessmentSidebarView.swift`

Extract the detail view switch statement into a computed property so both layouts can reuse it.

**Step 1: Create the computed property**

Add this computed property to `AssessmentSidebarView` (before the `body` property, after the `DetailView` enum):

```swift
@ViewBuilder
private var detailContent: some View {
    switch currentDetailView {
    case .overview:
        if let assessment = viewModel.assessment {
            AssessmentOverviewView(
                assessment: assessment,
                modelContext: modelContext
            )
        }
    case .sectionSelection:
        SectionSelectionView(viewModel: viewModel)
    case .horses:
        HorsesNavigationView(
            assessmentId: assessmentId
        )
    case .gallery:
        GalleryView(viewModel: galleryViewModel)
    case .sideNotes:
        if let assessment = viewModel.currentAssessment {
            SideNotesView(assessment: assessment)
        }
    case .sectionDetail(let section):
        SectionDetailView(section: section)
    }
}
```

**Step 2: Update the body to use it in the existing NavigationSplitView**

Replace the detail closure content in `body` (lines 78-100) with:

```swift
} detail: {
    detailContent
}
```

**Step 3: Build to verify no regressions**

Run:
```bash
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```
Expected: Build succeeds.

**Step 4: Commit**

```bash
git add equine-welfare/Views/AssessmentSidebarView.swift
git commit -m "refactor: extract detail content into reusable computed property"
```

---

### Task 4: Implement Compact Layout for iPhone

**Files:**
- Modify: `equine-welfare/Views/AssessmentSidebarView.swift`

**Step 1: Create compact layout view**

Add this computed property to `AssessmentSidebarView`:

```swift
private var compactLayout: some View {
    VStack(spacing: 0) {
        // Navigation picker at the top
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CompactNavButton(title: "Overview", icon: "doc.text.magnifyingglass",
                                 isActive: currentDetailView == .overview) {
                    selectedSection = nil
                    currentDetailView = .overview
                }
                CompactNavButton(title: "Sections", icon: "checklist",
                                 isActive: currentDetailView == .sectionSelection) {
                    selectedSection = nil
                    currentDetailView = .sectionSelection
                }
                CompactNavButton(title: "Horses", icon: "pawprint.fill",
                                 isActive: currentDetailView == .horses) {
                    selectedSection = nil
                    currentDetailView = .horses
                }
                CompactNavButton(title: "Gallery", icon: "photo.on.rectangle",
                                 isActive: currentDetailView == .gallery) {
                    selectedSection = nil
                    currentDetailView = .gallery
                }
                CompactNavButton(title: "Notes", icon: "note.text",
                                 isActive: currentDetailView == .sideNotes) {
                    selectedSection = nil
                    currentDetailView = .sideNotes
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))

        Divider()

        // Detail content
        detailContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onDisappear {
        viewModel.saveAssessment()
    }
}
```

**Step 2: Create CompactNavButton helper**

Add this struct after `SidebarButton` (around line 269):

```swift
struct CompactNavButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isActive ? .white : .accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.accentColor : Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}
```

**Step 3: Update body to branch on size class**

Replace the entire `body` computed property with:

```swift
var body: some View {
    if horizontalSizeClass == .compact {
        compactLayout
    } else {
        NavigationSplitView {
            ScrollView {
                navigationButtonsView
                sectionsList
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .onDisappear {
                viewModel.saveAssessment()
            }
        } detail: {
            detailContent
        }
    }
}
```

**Step 4: Build to verify**

Run:
```bash
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPhone 16' build
```
Expected: Build succeeds.

**Step 5: Commit**

```bash
git add equine-welfare/Views/AssessmentSidebarView.swift
git commit -m "feat: add compact layout for iPhone using horizontalSizeClass"
```

---

### Task 5: Test on Both Simulators

**Step 1: Run on iPhone simulator**

Build and run on iPhone 16 simulator. Tap "Start Assessment". Verify:
- You see a horizontal nav bar at the top with Overview, Sections, Horses, Gallery, Notes
- Section Selection content is shown by default
- Tapping each nav button switches the content below

**Step 2: Run on iPad simulator**

Build and run on iPad Pro simulator. Tap "Start Assessment". Verify:
- Sidebar appears on the left with all navigation options
- Detail content appears on the right
- Existing behavior is preserved

**Step 3: Commit if all good**

```bash
git add -A
git commit -m "test: verified iPhone and iPad layouts work correctly"
```

---

### Task 6: Clean Up Debug Print Statement

**Files:**
- Modify: `equine-welfare/Views/AssessmentSidebarView.swift`

**Step 1: Remove the debug print**

Remove lines 36-38 from `AssessmentSidebarView.init`:

```swift
print(
    "DEBUG: AssessmentSidebarView initialized with assessmentId: \(assessmentId)"
)
```

**Step 2: Commit**

```bash
git add equine-welfare/Views/AssessmentSidebarView.swift
git commit -m "chore: remove debug print from AssessmentSidebarView"
```

---

## Summary

| Task | Description | Files |
|------|------------|-------|
| 1 | Verify the problem | (simulator testing) |
| 2 | Add horizontalSizeClass env | AssessmentSidebarView.swift |
| 3 | Extract shared detail content | AssessmentSidebarView.swift |
| 4 | Implement compact iPhone layout | AssessmentSidebarView.swift |
| 5 | Test on both simulators | (verification) |
| 6 | Clean up debug print | AssessmentSidebarView.swift |
