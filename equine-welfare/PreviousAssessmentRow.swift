//
//  AssessmentRow.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//


import SwiftUI
import SwiftData

struct PreviousAssessmentRow: View {
    let assessment: Assessment
    @EnvironmentObject private var navigationState: NavigationState
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(assessment.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {
                    // Edit assessment
                    navigationState.editAssessment(assessmentId: assessment.id)
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                
                if !assessment.isComplete {
                    Button(action: {
                        // Resume assessment
                        navigationState.editAssessment(assessmentId: assessment.id)
                    }) {
                        Text("Resume")
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: {
                    // Export functionality would go here
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(assessment.isComplete ? .blue : .gray)
                }
                .disabled(!assessment.isComplete)
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .confirmationDialog(
                    "Delete Assessment",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        deleteAssessment()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure? You'll lose this assessment forever.")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func deleteAssessment() {
        // Delete the assessment from SwiftData
        modelContext.delete(assessment)
        try? modelContext.save()
    }
}
