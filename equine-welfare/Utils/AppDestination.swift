import Foundation

/// App-level navigation destinations pushed onto the root `NavigationStack`.
///
/// The top level only pushes one thing: an assessment workspace. Everything
/// inside an assessment (overview, sections, horses, gallery, notes, section
/// detail) is workspace-internal navigation — see `WorkspacePane` and
/// `HorseRoute` in Navigation/Routes.swift.
enum AppDestination: Hashable {
    case assessment(id: UUID)
}
