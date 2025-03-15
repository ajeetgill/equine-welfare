//
//  MainOpening.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftUI
import SwiftData

struct MainScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var vetName: String
    @Binding var farmName: String
    @Binding var visitDate: Date
    // Replace NavigationState with callback function
    var onStartNewAssessment: (UUID) -> Void
    
    @State private var assessmentHelper: AssessmentHelper?
    @State private var sectionViewModel: SectionSelectionViewModel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Assessment")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                TextField("Veterinarian Name", text: $vetName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Farm Name", text: $farmName)
                    .textFieldStyle(.roundedBorder)
                
                DatePicker(
                    "Visit Date",
                    selection: $visitDate,
                    displayedComponents: .date
                )
                
                Button(action: startNewAssessment) {
                    Text("Start Assessment")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!isFormValid)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .onAppear {
            assessmentHelper = AssessmentHelper(modelContext: modelContext)
            sectionViewModel = SectionSelectionViewModel(modelContext: modelContext)
        }
    }
    
    var isFormValid: Bool {
        !vetName.isEmpty && !farmName.isEmpty
    }
    
    private func startNewAssessment() {
        guard let viewModel = sectionViewModel else { return }
        
        // Create new assessment
        let newAssessmentId = viewModel.createNewAssessment(
            vetName: vetName,
            farmName: farmName,
            visitDate: visitDate
        )
        onStartNewAssessment(newAssessmentId)

        // Reset form fields
        vetName = ""
        farmName = ""
        visitDate = Date()
    }
}

#Preview {
    @Previewable @State var vetName = ""
    @Previewable @State var farmName = ""
    @Previewable @State var visitDate = Date()
    
    MainScreen(
        vetName: $vetName,
        farmName: $farmName,
        visitDate: $visitDate,
        onStartNewAssessment: { _ in }
    )
    .modelContainer(for: Assessment.self, inMemory: true)
}
