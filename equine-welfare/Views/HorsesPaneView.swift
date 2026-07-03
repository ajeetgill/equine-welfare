import SwiftUI

/// The horses pane: a two-column master/detail (list | selected-horse info).
/// Combined with the workspace sidebar this reads as `[ Panes | Horses list |
/// Horse info ]`.
///
/// Adding and editing a horse are modal *tasks* (discrete, cancelable,
/// committed), so they present as a sheet with Cancel / Save rather than taking
/// over the detail column. Viewing a horse stays inline in the detail column.
struct HorsesPaneView: View {
    let assessmentId: UUID

    /// The horse shown in the detail column.
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
        HStack(spacing: 0) {
            NavigationStack {
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
            .frame(width: 340)

            Divider()

            NavigationStack {
                detailColumn
            }
            .frame(maxWidth: .infinity)
        }
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

    @ViewBuilder
    private var detailColumn: some View {
        if let selectedHorseId {
            HorseInfoView(
                horseId: selectedHorseId,
                onEdit: { id, _ in editing = .edit(id) }
            )
            .navigationTitle("Horse Details")
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
}
