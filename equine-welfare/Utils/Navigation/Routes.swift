import Foundation

// Central navigation route types.
//
// The app has three distinct navigation containers, each with a single
// source of truth:
//   1. Root NavigationStack        -> [AppDestination]   (app-level flow)
//   2. Workspace NavigationSplitView -> WorkspacePane    (pane selection)
//   3. Horses NavigationStack      -> [HorseRoute]       (horse sub-flow)
//
// See docs/plans/2026-07-01-navigation-unification.md.

/// Which pane of an assessment workspace is currently showing. Bound to the
/// `NavigationSplitView` sidebar `List` selection.
///
/// Sections are selected by their `Int` id (not the SwiftData model) so the
/// value stays cheaply `Hashable` and survives model reloads.
enum WorkspacePane: Hashable {
    case overview
    case sections
    case section(id: Int)
    case gallery
    case notes
    case horses
}

/// A screen in the horses sub-flow, pushed onto the horses `NavigationStack`.
enum HorseRoute: Hashable {
    case info(horseId: UUID)
    case add
    case edit(horseId: UUID)
}
