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
                VStack(alignment: .leading, spacing: 0) {
                    DisclosureGroup(
                        isExpanded: $isNonApplicableSectionsExpanded,
                        content: {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(assessment.sections.filter { !$0.isApplicable }.sorted(by: { $0.id < $1.id }), id: \.id) { section in
                                    HStack(spacing: 8) {
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(.gray)
                                        Text("\(section.id). \(section.title)")
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                        },
                        label: {
                            Text("Non-Applicable Sections")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .bold()
                        }
                    )
                    .accentColor(.primary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(8)
                
                // Applicable Sections
                VStack(alignment: .leading, spacing: 0) {
                    DisclosureGroup(
                        isExpanded: $isApplicableSectionsExpanded,
                        content: {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(assessment.sections.filter { $0.isApplicable }, id: \.id) { section in
                                    let completionStatus = sectionViewModel.getSectionStatus(section)
                                    HStack(spacing: 8) {
                                        SectionStatusIndicator(status: completionStatus)
                                            .foregroundColor(completionStatus == .completed ? .green :
                                                           completionStatus == .inProgress ? .orange : .gray)
                                        
                                        VStack(alignment: .leading) {
                                            Text("\(section.id). \(section.title)")
                                                .foregroundColor(.primary)
                                            
                                            if completionStatus == .inProgress {
                                                let progress = sectionViewModel.getSectionProgress(section)
                                                Text("\(progress.0)/\(progress.1) Requirements")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                        },
                        label: {
                            Text("Applicable Sections")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .bold()
                        }
                    )
                    .accentColor(.primary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(8)
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
