import SwiftUI

struct AssessmentSidebarView: View {
    @ObservedObject var viewModel: SectionSelectionViewModel
    @State private var isApplicableSectionsExpanded: Bool = true
    @EnvironmentObject private var navigationState: NavigationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Header
            headerView
            
            // MARK: - Navigation Actions
            navigationButtonsView
            
            // MARK: - Applicable Sections
            sectionsList
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .onDisappear {
            viewModel.saveAssessment()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            Text("Assessment")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
        }
    }
    
    private var navigationButtonsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Back to Home Button
            SidebarButton(
                title: "Back to Home",
                icon: "chevron.left",
                isActive: false,
                action: {
                    viewModel.saveAssessment()
                    navigationState.returnToMain()
                }
            )
            
            // Section Selection Button
            SidebarButton(
                title: "Section Selection",
                icon: "checklist",
                isActive: navigationState.selectedSectionId == nil,
                action: {
                    navigationState.showSectionSelection()
                }
            )
        }
    }
    
    private var sectionsList: some View {
        DisclosureGroup(
            isExpanded: $isApplicableSectionsExpanded,
            content: {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.applicableSections) { section in
                        SidebarButton(
                            title: "\(section.id). \(section.title)",
                            isActive: navigationState.selectedSectionId == section.id,
                            isPrimary: false,
                            action: {
                                navigationState.selectedSectionId = section.id
                            }
                        )
                    }
                }
                .padding(.top, 4)
            },
            label: {
                Text("Applicable Sections")
                    .fontWeight(.medium)
            }
        )
    }
}

// MARK: - Helper Views

/// Reusable sidebar button component
struct SidebarButton: View {
    let title: String
    var icon: String? = nil
    var isActive: Bool = false
    var isPrimary: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let iconName = icon {
                    Image(systemName: iconName)
                }
                
                Text(title)
                    .fontWeight(isPrimary ? .medium : .regular)
                
                Spacer()
            }
            .padding(isPrimary ? 12 : 8)
            .padding(.leading, isPrimary ? 0 : 16)
            .background(isActive ? Color.blue : (isPrimary ? Color.blue.opacity(0.1) : Color.clear))
            .foregroundColor(isActive ? .white : (isPrimary ? .blue : .primary))
            .cornerRadius(8)
        }
    }
}

// MARK: - Section Detail View

struct SectionDetailView: View {
    let section: AssessmentSection
    @EnvironmentObject private var navigationState: NavigationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            Text(section.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            // Section content
            Group {
                Text("Section \(section.id) Details")
                    .font(.title2)
                    .padding(.bottom, 10)
                
                Text("This is where the specific content for the '\(section.title)' section would appear.")
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGray6))
    }
}
