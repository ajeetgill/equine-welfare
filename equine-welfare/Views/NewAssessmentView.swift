// import SwiftUI
// import SwiftData

// struct NewAssessmentView: View {
//     @Environment(\.modelContext) private var modelContext
//     @Query private var assessments: [Assessment]
//     @EnvironmentObject private var navigationState: NavigationState
    
//     @State private var vetName: String = ""
//     @State private var farmName: String = ""
//     @State private var visitDate: Date = Date()
    
//     @State private var assessmentHelper: AssessmentHelper?
//     @State private var sectionViewModel: SectionSelectionViewModel?
    
//     var body: some View {
//         VStack(alignment: .leading, spacing: 20) {
//             Text("New Assessment")
//                 .font(.largeTitle)
//                 .bold()
            
//             // New Assessment Form
//             VStack(alignment: .leading, spacing: 16) {
//                 TextField("Vet Name", text: $vetName)
//                     .textFieldStyle(.roundedBorder)
                
//                 TextField("Farm Name / Owner", text: $farmName)
//                     .textFieldStyle(.roundedBorder)
                
//                 DatePicker("Visit Date", selection: $visitDate, displayedComponents: .date)
//                     .datePickerStyle(.compact)
                
//                 Button(action: startNewAssessment) {
//                     HStack {
//                         Text("Start Assessment")
//                         Spacer()
//                         Image(systemName: "chevron.right")
//                     }
//                     .padding()
//                     .background(Color.gray.opacity(0.2))
//                     .cornerRadius(8)
//                 }
//                 .disabled(vetName.isEmpty || farmName.isEmpty)
//             }
//             .padding(.bottom, 30)
            
//             // Previous Assessments Section
//             Text("Previous Assessments")
//                 .font(.title)
//                 .bold()
            
//             List(assessments) { assessment in
//                 HStack {
//                     Text(assessment.displayName)
                    
//                     Spacer()
                    
//                     Button("Continue") {
//                         continueAssessment(assessment)
//                     }
//                     .buttonStyle(.borderless)
                    
//                     Button("Export") {
//                         // Handle export action
//                     }
//                     .buttonStyle(.borderless)
//                 }
//             }
//         }
//         .padding()
//         .onAppear {
//             assessmentHelper = AssessmentHelper(modelContext: modelContext)
//             sectionViewModel = SectionSelectionViewModel(modelContext: modelContext)
//         }
//     }
    
//     private func startNewAssessment() {
//         guard let helper = assessmentHelper,
//               let viewModel = sectionViewModel else { return }
        
//         // Create new assessment with default sections
//         let newAssessment = helper.createAssessment(
//             vetName: vetName,
//             farmName: farmName,
//             visitDate: visitDate,
//             sections: viewModel.sections,
//             horses: []
//         )
        
//         // Navigate to section selection
//         navigationState.currentAssessmentId = newAssessment.id
//         navigationState.showSectionSelection()
        
//         // Reset form
//         vetName = ""
//         farmName = ""
//         visitDate = Date()
//     }
    
//     private func continueAssessment(_ assessment: Assessment) {
//         navigationState.currentAssessmentId = assessment.id
//         navigationState.showSectionSelection()
//     }
    
//     private func exportAssessment(_ assessment: Assessment) {
//         // TODO: Implement export functionality
//     }
// }

// #Preview {
//     NewAssessmentView()
//         .modelContainer(for: Assessment.self, inMemory: true)
//         .environmentObject(NavigationState())
// } 