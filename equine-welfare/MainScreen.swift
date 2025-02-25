//
//  MainOpening.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftUI

struct MainScreen: View {
    @Binding var vetName: String
    @Binding var farmName: String
    @Binding var visitDate: Date
    var navigationState: NavigationState
    
    var isFormValid: Bool {
        !vetName.isEmpty && !farmName.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Assessment")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                TextField("Name", text: $vetName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Location Name", text: $farmName)
                    .textFieldStyle(.roundedBorder)
                
                DatePicker(
                    "Visit Date",
                    selection: $visitDate,
                    displayedComponents: [.date]
                )
                
                Button(action: {
                    // Use navigationState to transition to the section selection screen
                    navigationState.startNewAssessment(
                        vetName: vetName,
                        farmName: farmName,
                        visitDate: visitDate
                    )
                }) {
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
}
