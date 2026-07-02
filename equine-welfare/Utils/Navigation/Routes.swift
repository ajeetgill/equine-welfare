import Foundation

// Central navigation route types.
//
// The app's navigation:
//   - Home (NavigationStack) presents the assessment workspace as a
//     full-screen cover (a NavigationSplitView must be a navigation root).
//   - Workspace NavigationSplitView -> WorkspacePane (sidebar selection).
//   - The horses pane is a selection-based master-detail (see HorsesPaneView);
//     push navigation inside a NavigationSplitView detail column does not fire
//     reliably, so horse info/add/edit are driven by selection, not a stack.
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
