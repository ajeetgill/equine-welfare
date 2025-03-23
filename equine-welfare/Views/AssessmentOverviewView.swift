import SwiftUI
import SwiftData

struct AssessmentOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    let assessment: Assessment
    var sectionViewModel: SectionSelectionViewModel
    @State private var isNonApplicableSectionsExpanded: Bool = true
    @State private var isApplicableSectionsExpanded: Bool = true
    
    init(assessment: Assessment, modelContext: ModelContext) {
        self.assessment = assessment
        self.sectionViewModel = SectionSelectionViewModel(modelContext: modelContext)
    }
    
    // Helper function to sort subsections
    private func sortedSubsections(_ subsections: [Subsection]) -> [Subsection] {
        return subsections.sorted { s1, s2 in
            let comps1 = s1.name.numericComponents()
            let comps2 = s2.name.numericComponents()
            
            // Compare components lexicographically
            for i in 0..<min(comps1.count, comps2.count) {
                if comps1[i] < comps2[i] { return true }
                if comps1[i] > comps2[i] { return false }
            }
            // If all common components match, shorter array comes first
            return comps1.count < comps2.count
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Non-Applicable Sections
                DisclosureGroup(
                    isExpanded: $isNonApplicableSectionsExpanded,
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(assessment.sections.filter { !$0.isApplicable }.sorted(by: { $0.id < $1.id }), id: \.id) { section in
                                HStack(spacing: 8) {
                                    Spacer()
                                        .frame(width: 12) // Add fixed padding to the left
                                    Image(systemName: "circle.slash")
                                        .foregroundColor(.blue)
                                    Text("  \(section.id). \(section.title)")
                                        .foregroundColor(.primary)
                                        .font(.title3)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(8)
                    },
                    label: {
                        Text("Non-Applicable Sections")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.vertical, 8)
                    }
                )
                .accentColor(.blue)
                
                // Applicable Sections
                DisclosureGroup(
                    isExpanded: $isApplicableSectionsExpanded,
                    content: {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(assessment.sections.filter { $0.isApplicable }.sorted(by: { $0.id < $1.id }), id: \.id) { section in
                                let completionStatus = sectionViewModel.getSectionStatus(section)
                                let progress = sectionViewModel.getSectionProgress(section)
                                
                                DisclosureGroup {
                                    // Subsections
                                    VStack(spacing: 12) {
                                        ForEach(sortedSubsections(section.subsections), id: \.name) { subsection in
                                            // Calculate if all requirements in this subsection are completed
                                            let isCompleted = !subsection.requirements.contains { $0.complianceStatus == nil }
                                            let isPartiallyCompleted = subsection.requirements.contains { $0.complianceStatus != nil } && !isCompleted
                                            
                                            // Convert subsection status to SectionCompletionStatus enum
                                            let subsectionStatus: SectionCompletionStatus = isCompleted ? .completed : 
                                                                                           isPartiallyCompleted ? .inProgress : .notStarted
                                            
                                            HStack {
                                                Spacer()
                                                    .frame(width: 36) // Add fixed padding to the left
                                                // Status indicator for subsection
                                                SectionStatusIndicator(status: subsectionStatus)
                                                    .foregroundColor(.blue)
                                                
                                                // Subsection name
                                                Text(subsection.name)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                // Details text with chevron
                                                HStack(spacing: 4) {
                                                    Text("Detail")
                                                        .font(.subheadline)
                                                        .foregroundColor(.gray)
                                                    Image(systemName: "chevron.right")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .padding(12)
                                            .background(Color.white)
                                            .cornerRadius(8)
                                        }
                                    }
                                    .padding(.top, 8)
                                } label: {
                                    HStack {
                                        // Section status indicator
                                        Spacer()
                                            .frame(width: 12) // Add fixed padding to the left

                                        SectionStatusIndicator(status: completionStatus)
                                            .foregroundColor(.blue)
                                        
                                        // Section title
                                        Text("\(section.id). \(section.title)")
                                            .font(.title3)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        // Requirements count with chevron
                                        HStack(spacing: 4) {
                                            Text("\(progress.0)/\(progress.1) Requirements")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                                
                                        }
                                    }
                                    .padding(.vertical, 12)
                                }
                                .accentColor(.blue)
                                .padding(.bottom, 4)
                                // .background(Color(.systemBackground))
                                .cornerRadius(8) // these are not needed
                            }
                        }
                        .padding(.vertical, 8)
                    },
                    label: {
                        Text("Applicable Sections")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    }
                )
                .accentColor(.blue)
            }
            .padding()
            .onAppear {
                sectionViewModel.loadAssessment(id: assessment.id)
            }
        }
        .navigationTitle("Overview")
        .background(Color(.systemGray6))
    }
}

// Preview
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Assessment.self, configurations: config)
    let context = ModelContext(container)
    
    let assessment = Assessment(vetName: "Dr. Smith", farmName: "Green Acres", visitDate: Date())
    
    return AssessmentOverviewView(assessment: assessment, modelContext: context)
        .modelContainer(container)
}
