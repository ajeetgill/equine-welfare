# Fix Nested NavigationStack in HorsesNavigationView — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the nested `NavigationStack` from `HorsesNavigationView` that breaks navigation on iPhone and is unnecessary on iPad.

**Architecture:** `HorsesNavigationView` wraps its content in a `NavigationStack` that, on iPhone compact, nests inside `ContentView`'s `NavigationStack`, breaking `AppDestination` resolution. On iPad, the `NavigationSplitView` detail column already provides navigation context, so the inner `NavigationStack` is also redundant there. Remove it and move `.navigationTitle` / `.toolbar` onto the `VStack` content directly — they propagate to the nearest navigation container ancestor (the detail column on iPad, ContentView's stack on iPhone).

**Tech Stack:** Swift 6.1, SwiftUI

---

## Phase 1: iPad-First Patch (Remove Nested NavigationStack)

### Task 1: Remove NavigationStack from HorsesNavigationView

**Files:**
- Modify: `equine-welfare/Views/HorsesNavigationView.swift`

**Step 1: Restructure the body to remove NavigationStack**

Current code (`HorsesNavigationView.swift:12-99`):

```swift
var body: some View {
    NavigationStack {
        VStack {
            // ... view content based on currentView state
        }
        .navigationTitle(navTitle)
    }
    .toolbar {
        if currentView == .list {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { ... }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
```

Replace with (remove `NavigationStack`, move `.toolbar` inside onto the `VStack`):

```swift
var body: some View {
    VStack {
        // Base layer - horse list
        if currentView == .list {
            HorsesView(
                assessmentId: assessmentId,
                onSelectHorse: { horseId in
                    withAnimation {
                        selectedHorseId = horseId
                        currentView = .horseInfo
                    }
                }
            )
            .disabled(currentView != .list)
        }
        // Horse Detail view (Add)
        if currentView == .addHorse {
            HorseDetailView(
                horseId: nil,
                assessmentId: assessmentId,
                onDismiss: {
                    withAnimation {
                        currentView = .list
                    }
                }
            )
            .transition(.move(edge: .trailing))
        }
        // Horse Detail view (Edit)
        if currentView == .editHorse, let horseId = selectedHorseId {
            HorseDetailView(
                horseId: horseId,
                assessmentId: assessmentId,
                onDismiss: {
                    withAnimation {
                        currentView = .list
                    }
                }
            )
            .transition(.move(edge: .leading))
        }

        // Horse Info view
        if currentView == .horseInfo, let horseId = selectedHorseId {
            HorseInfoView(
                horseId: horseId,
                onEdit: { horseId, _ in
                    withAnimation {
                        selectedHorseId = horseId
                        currentView = .editHorse
                    }
                }
            )
            .transition(.move(edge: .trailing))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        withAnimation {
                            currentView = .list
                        }
                    }
                }
            }
        }
    }
    .navigationTitle(navTitle)
    .toolbar {
        if currentView == .list {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    withAnimation {
                        selectedHorseId = nil
                        currentView = .addHorse
                    }
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
```

Key changes:
- Removed `NavigationStack { ... }` wrapper
- Moved `.toolbar` from the `NavigationStack` to the `VStack`
- Moved `.navigationTitle` from inside NavigationStack to the `VStack`
- All view content is unchanged

**Step 2: Build for iPad simulator**

Run:
```bash
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,id=A726494E-BCEF-47E4-A187-7DFDB73E9D0E' build
```
Expected: **BUILD SUCCEEDED**

**Step 3: Manual test on iPad**

Open the app on iPad simulator:
1. Start a new assessment
2. Tap "Horses" in the sidebar
3. Verify the Horses list appears with "Add" button in toolbar
4. Add a horse, verify navigation works (add → list)
5. Tap a horse, verify info view appears with "Back" toolbar button
6. Tap "Edit", verify edit view appears
7. Dismiss, verify return to list

**Step 4: Commit**

```bash
git add equine-welfare/Views/HorsesNavigationView.swift
git commit -m "fix: remove nested NavigationStack from HorsesNavigationView

NavigationStack in HorsesNavigationView was nested inside ContentView's
NavigationStack on iPhone compact, breaking AppDestination resolution.
On iPad, the NavigationSplitView detail column already provides
navigation context, making the inner stack redundant.

Toolbar and navigationTitle now propagate to the nearest ancestor
navigation container."
```

---

## Phase 2: Verify iPhone Compact

### Task 2: Build and test on iPhone simulator

**Step 1: Build for iPhone simulator**

Run:
```bash
xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,id=7C6E9784-84A0-4373-9630-5A423851B58F' build
```
Expected: **BUILD SUCCEEDED**

**Step 2: Manual test on iPhone**

Open the app on iPhone simulator:
1. Start a new assessment
2. Tap "Horses" in the compact nav bar
3. Verify: NO console error about "NavigationLink presenting AppDestination"
4. Verify: Horses list appears (not blank/caution symbol)
5. Add a horse, verify navigation works
6. Tap a horse, verify info view
7. Also test: Resume a previous assessment → verify no caution symbol

**Step 3: Commit verification (only if changes needed)**

If everything works, no commit needed. If fixes are required, commit them.

---

## Summary

| Task | Description | Files | Priority |
|------|------------|-------|----------|
| 1 | Remove NavigationStack from HorsesNavigationView | HorsesNavigationView.swift | iPad-first |
| 2 | Verify iPhone compact works | (manual testing) | iPhone follow-up |
