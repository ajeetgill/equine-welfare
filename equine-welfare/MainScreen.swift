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
    var navigationState: NavigationState
    
    @State private var assessmentHelper: AssessmentHelper?
    @State private var sectionViewModel: SectionSelectionViewModel?
    
    init(vetName: Binding<String>, farmName: Binding<String>, 
         visitDate: Binding<Date>, navigationState: NavigationState) {
        self._vetName = vetName
        self._farmName = farmName
        self._visitDate = visitDate
        self.navigationState = navigationState
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Assessment")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                TextField("Vet Name", text: $vetName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Farm Name", text: $farmName)
                    .textFieldStyle(.roundedBorder)
                
                DatePicker(
                    "Visit Date",
                    selection: $visitDate,
                    displayedComponents: [.date]
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
        let newAssessment = viewModel.createNewAssessment(
            vetName: vetName,
            farmName: farmName,
            visitDate: visitDate
        )
        
        // Store the assessment ID in navigation state before resetting form
        navigationState.currentAssessmentId = newAssessment
        
        // Handle navigation
        navigationState.startNewAssessment(
            vetName: vetName,
            farmName: farmName,
            visitDate: visitDate
        )
        
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
        navigationState: NavigationState()
    )
    .modelContainer(for: Assessment.self, inMemory: true)
}
