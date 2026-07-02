import SwiftUI

/// The horses pane, laid out as two columns (list | detail). Combined with the
/// workspace sidebar this gives an overall `[ Panes | Horses list | Horse
/// detail ]` layout.
///
/// Navigation between list / info / add / edit is selection-based (a `@State`
/// mode drives the detail column) rather than push-based, because push
/// navigation inside a `NavigationSplitView` detail column does not fire
/// reliably. Each column has its own non-pushing `NavigationStack` purely to
/// host a title and toolbar.
struct HorsesPaneView: View {
    let assessmentId: UUID

    @State private var mode: Mode?

    enum Mode: Equatable {
        case info(UUID)
        case edit(UUID)
        case add
    }

    var body: some View {
        HStack(spacing: 0) {
            NavigationStack {
                HorsesView(
                    assessmentId: assessmentId,
                    onSelectHorse: { mode = .info($0) }
                )
                .navigationTitle("Horses")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            mode = .add
                        } label: {
                            Label("Add", systemImage: "plus")
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
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch mode {
        case .info(let id):
            HorseInfoView(
                horseId: id,
                onEdit: { id, _ in mode = .edit(id) }
            )
            .navigationTitle("Horse Details")
        case .edit(let id):
            HorseDetailView(
                horseId: id,
                assessmentId: assessmentId,
                onDismiss: { mode = .info(id) }
            )
            .navigationTitle("Edit Horse")
        case .add:
            HorseDetailView(
                horseId: nil,
                assessmentId: assessmentId,
                onDismiss: { mode = nil }
            )
            .navigationTitle("Add Horse")
        case nil:
            ContentUnavailableView(
                "No Horse Selected",
                systemImage: "pawprint",
                description: Text("Select a horse from the list, or add a new one.")
            )
        }
    }
}
