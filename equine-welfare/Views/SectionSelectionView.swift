import SwiftUI

struct SectionSelectionView: View {
    @State var viewModel: SectionSelectionViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Include Sections")
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)
            
            ScrollView {
                LazyVStack(spacing: 12) {
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
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGray6))
    }
} 
