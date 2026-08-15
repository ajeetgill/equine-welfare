import SwiftUI

/// The horses pane.
///
/// - On **regular** width (iPad) it's a two-column master/detail (list |
///   selected-horse info). Combined with the workspace sidebar this reads as
///   `[ Panes | Horses list | Horse info ]`.
/// - On **compact** width (iPhone) two side-by-side columns would be crushed to
///   ~50pt each and wrap character-by-character, so it collapses to a single
///   full-width list and *pushes* the selected horse's info onto the stack
///   (list → detail, Contacts-style).
///
/// Adding and editing a horse are modal *tasks* (discrete, cancelable,
/// committed), so they always present as a sheet with Cancel / Save regardless
/// of width. Details must NOT be a sheet on compact: a sheet-within-a-sheet
/// blocks the edit sheet's presentation until the first one dismisses, which
/// made Edit appear to do nothing until Done was tapped.
struct HorsesPaneView: View {
    let assessmentId: UUID

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The horse shown in the detail column (iPad) or info sheet (iPhone).
    @State private var selectedHorseId: UUID?
    /// Non-nil while the add/edit sheet is presented.
    @State private var editing: EditTarget?

    enum EditTarget: Identifiable {
        case add
        case edit(UUID)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let uuid): return uuid.uuidString
            }
        }

        /// The horse being edited, or nil when adding.
        var horseId: UUID? {
            if case .edit(let id) = self { return id }
            return nil
        }
    }

    var body: some View {
        layout
            .sheet(item: $editing) { target in
                NavigationStack {
                    HorseDetailView(
                        horseId: target.horseId,
                        assessmentId: assessmentId,
                        onSaved: { savedId in
                            selectedHorseId = savedId
                            editing = nil
                        }
                    )
                    .navigationTitle(target.horseId == nil ? "Add Horse" : "Edit Horse")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { editing = nil }
                        }
                    }
                }
                // A large "page" sheet gives the BCS slider + reference room to
                // coexist; disabling interactive dismissal prevents an accidental
                // tap-outside (or swipe-down) from discarding an in-progress edit.
                .presentationSizing(.page)
                .interactiveDismissDisabled()
            }
    }

    // MARK: - Layout

    @ViewBuilder
    private var layout: some View {
        if horizontalSizeClass == .compact {
            NavigationStack {
                listContent
                    .navigationDestination(item: $selectedHorseId) { id in
                        horseInfoView(id: id)
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        } else {
            HStack(spacing: 0) {
                NavigationStack {
                    listContent
                }
                .frame(width: 340)

                Divider()

                NavigationStack {
                    detailColumn
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// The horses list with its title and Add button, shared by both layouts.
    private var listContent: some View {
        HorsesView(
            assessmentId: assessmentId,
            selectedHorseId: selectedHorseId,
            onSelectHorse: { selectedHorseId = $0 }
        )
        .navigationTitle("Horses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = .add
                } label: {
                    Label("Add Horse", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailColumn: some View {
        if let selectedHorseId {
            horseInfoView(id: selectedHorseId)
        } else {
            ContentUnavailableView {
                Label("No Horse Selected", systemImage: "pawprint")
            } description: {
                Text("Select a horse from the list, or add a new one.")
            } actions: {
                Button {
                    editing = .add
                } label: {
                    Label("Add Horse", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func horseInfoView(id: UUID) -> some View {
        HorseInfoView(
            horseId: id,
            onEdit: { editId, _ in editing = .edit(editId) }
        )
        .navigationTitle("Horse Details")
    }
}
