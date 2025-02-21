import SwiftUI
import SwiftData

struct NewAssessmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assessments: [Assessment]
    
    @State private var vetName: String = ""
    @State private var farmName: String = ""
    @State private var visitDate: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Assessment")
                .font(.largeTitle)
                .bold()
            
            // New Assessment Form
            VStack(alignment: .leading, spacing: 16) {
                TextField("Vet Name", text: $vetName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Farm Name / Owner", text: $farmName)
                    .textFieldStyle(.roundedBorder)
                
                DatePicker("Visit Date", selection: $visitDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                
                Button(action: startNewAssessment) {
                    HStack {
                        Text("Start Assessment")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.bottom, 30)
            
            // Previous Assessments Section
            Text("Previous Assessments")
                .font(.title)
                .bold()
            
            List(assessments) { assessment in
                HStack {
                    Text("\(formatDate(assessment.visitDate))-\(assessment.vetName)-\(assessment.farmName)")
                    
                    Spacer()
                    
                    Button("Edit") {
                        // Handle edit action
                    }
                    .buttonStyle(.borderless)
                    
                    Button("Export") {
                        // Handle export action
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
    }
    
    private func startNewAssessment() {
        let newAssessment = Assessment(
            vetName: vetName,
            farmName: farmName,
            visitDate: visitDate
        )
        modelContext.insert(newAssessment)
        
        // Navigate to assessment flow
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MMM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    NewAssessmentView()
        .modelContainer(for: Assessment.self, inMemory: true)
} 