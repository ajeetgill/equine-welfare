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
                                    Text("  ")
                                    Image(systemName: "circle.slash")
                                        .foregroundColor(.blue)
                                    Text("\(section.id). \(section.title)")
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(8)
                    },
                    label: {
                        Text(" Non-Applicable Sections")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .bold()
                            .padding(.bottom, 16)
                    }
                )
                .accentColor(.blue)
                
                // Applicable Sections
                DisclosureGroup(
                    isExpanded: $isApplicableSectionsExpanded,
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(assessment.sections.filter { $0.isApplicable }.sorted(by: { $0.id < $1.id }), id: \.id) { section in
                                let completionStatus = sectionViewModel.getSectionStatus(section)
                                HStack(alignment: .center, spacing: 8) {
                                    Text("  ")
                                    SectionStatusIndicator(status: completionStatus)
                                        .foregroundColor(completionStatus == .completed ? .blue :
                                                       completionStatus == .inProgress ? .blue : .blue)
                                    Text("\(section.id). \(section.title)")
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if completionStatus == .inProgress {
                                        let progress = sectionViewModel.getSectionProgress(section)
                                        Text("\(progress.0)/\(progress.1) Requirements")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.trailing, 12)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(8)
                    },
                    label: {
                        Text(" Applicable Sections")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .bold()
                            .padding(.bottom, 16)
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
