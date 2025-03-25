import SwiftUI

struct SectionSelectionView: View {
    @State var viewModel: SectionSelectionViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ScrollView {
                    ForEach(viewModel.sections.sorted(by: { $0.id < $1.id })) { section in
                        SectionToggleRow(
                            section: section,
                            toggleAction: {
                                viewModel.toggleSection(section.id)
                            },
                            isApplicable: Binding(
                                get: { viewModel.isSectionApplicable(section.id) },
                                set: { _ in viewModel.toggleSection(section.id) }
                            )
                        )
                    }
            }
        }
        .padding()
        .navigationTitle(LocalizedStringKey("Select Sections"))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
} 
