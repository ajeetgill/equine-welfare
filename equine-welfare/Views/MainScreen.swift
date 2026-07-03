//
//  MainOpening.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftUI
import SwiftData
import AVFoundation

struct MainScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Binding var vetName: String
    @Binding var farmName: String
    @Binding var visitDate: Date
    @AppStorage("isPermissionsGranted") private var isPermissionsGranted = false
    var onStartNewAssessment: (UUID) -> Void
    
    @State private var assessmentHelper: AssessmentHelper?
    @State private var sectionViewModel: SectionSelectionViewModel?
    @StateObject private var permissionsManager = PermissionsManager()
    @State private var showPermissionsAlert = false
    
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
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isFormValid)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 16) {
                Link("The contents of this application is based on the Code of Practice for the Care and Handling of Equines and for more information go to Equine Code of Practice (PDF)", 
                     destination: URL(string: "https://www.nfacc.ca/pdfs/codes/equine_code_of_practice.pdf")!)
                    .font(.caption)
            }
        }
        .padding()
        .onAppear {
            assessmentHelper = AssessmentHelper(modelContext: modelContext)
            sectionViewModel = SectionSelectionViewModel(modelContext: modelContext)
            // Only check and request permissions if they haven't been granted yet
            if !isPermissionsGranted {
                Task {
                    await permissionsManager.checkAndRequestPermissions()
                }
            } else {
                // If permissions were previously granted, just verify their current status
                permissionsManager.checkCurrentPermissionStatus()
            }
        }
        .onChange(of: permissionsManager.isCameraAuthorized) { _, newValue in
            updatePermissionsGranted()
        }
        .onChange(of: permissionsManager.isMicrophoneAuthorized) { _, newValue in
            updatePermissionsGranted()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                permissionsManager.checkCurrentPermissionStatus()
                updatePermissionsGranted()
            }
        }
        .alert("Permissions Required", isPresented: $showPermissionsAlert) {
            Button("Open Settings") {
                permissionsManager.openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable camera and microphone access in Settings to use Horse COP.")
        }
    }
    
    private func updatePermissionsGranted() {
        let wasGranted = isPermissionsGranted
        isPermissionsGranted = permissionsManager.isCameraAuthorized && permissionsManager.isMicrophoneAuthorized
        
        // Only show the alert if permissions were previously granted and have been revoked
        if wasGranted && !isPermissionsGranted {
            showPermissionsAlert = true
        }
    }
    
    var isFormValid: Bool {
        !vetName.isEmpty && !farmName.isEmpty
    }
    
    private func startNewAssessment() {
        guard isFormValid else { return }
        
        // Check permissions again before proceeding
        permissionsManager.checkCurrentPermissionStatus()
        if !permissionsManager.isCameraAuthorized || !permissionsManager.isMicrophoneAuthorized {
            isPermissionsGranted = false
            showPermissionsAlert = true
            return
        }
        
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
