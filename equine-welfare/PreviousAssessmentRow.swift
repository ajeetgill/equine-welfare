//
//  AssessmentRow.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PreviousAssessmentRow: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationState: NavigationState
    
    // MARK: - State Properties
    @State private var showingDeleteConfirmation = false
    @State private var showingPreview = false
    @State private var shareURL: URL?
    @State private var isShareReady = false
    
    // MARK: - Properties
    let assessment: Assessment
    private let assessmentHelper: AssessmentHelper
    
    // MARK: - Initialization
    init(assessment: Assessment, modelContext: ModelContext) {
        self.assessment = assessment
        self.assessmentHelper = AssessmentHelper(modelContext: modelContext)
    }
    
    // MARK: - Helper Methods
    private func prepareShareContent() {
        // Create a preview view to generate content that matches what's shown in preview
        let previewView = AssessmentPreviewView(assessment: assessment)
        let htmlContent = previewView.generateDocContent()
        
        // Create a temporary file with a sanitized filename
        let tempDir = FileManager.default.temporaryDirectory
        let sanitizedName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
        let fileName = "\(sanitizedName).doc"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            // Write the HTML content to the file with .doc extension
            try htmlContent.write(to: fileURL, atomically: true, encoding: .utf8)
            shareURL = fileURL
            isShareReady = true
        } catch {
            print("Error creating share file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - View Body
    var body: some View {
        HStack {
            // Assessment information
            assessmentInfo
            
            Spacer()
            
            // Action buttons
            actionButtons
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .sheet(isPresented: $showingPreview) {
            previewSheet
        }
        .onAppear {
            // Prepare share content when the view appears
            prepareShareContent()
        }
    }
    
    // MARK: - View Components
    
    private var assessmentInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(assessment.displayName)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Preview button
            Button(action: { showingPreview.toggle() }) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.blue)
            }
            .help("Preview Assessment")
            
            // Edit button
            Button(action: { navigationState.editAssessment(assessmentId: assessment.id) }) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .help("Edit Assessment")
            
            // Resume button (only for incomplete assessments)
            if !assessment.isComplete {
                Button(action: { navigationState.editAssessment(assessmentId: assessment.id) }) {
                    Text("Resume")
                        .foregroundColor(.blue)
                }
            }
            
            // Share button
            shareButton
            
            // Delete button
            deleteButton
        }
    }
    
    private var shareButton: some View {
        Group {
            if let url = shareURL, isShareReady {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .help("Share Assessment as Word Document")
            } else {
                Button(action: { prepareShareContent() }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .help("Share Assessment as Word Document")
            }
        }
    }
    
    private var deleteButton: some View {
        Button(action: { showingDeleteConfirmation = true }) {
            Image(systemName: "trash")
                .foregroundColor(.red)
        }
        .help("Delete Assessment")
        .confirmationDialog(
            "Delete Assessment",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                assessmentHelper.deleteAssessment(assessment: assessment)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure? You'll lose this assessment forever.")
        }
    }
    
    private var previewSheet: some View {
        NavigationView {
            AssessmentPreviewView(assessment: assessment)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingPreview = false
                        }
                    }
                }
        }
        .frame(minWidth: 600, minHeight: 800)
    }
}

// MARK: - Preview
#Preview {
    let modelContext = ModelContext(try! ModelContainer(for: Assessment.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    
    let assessment = Assessment(vetName: "Dr. Smith", farmName: "Green Acres", visitDate: Date())
    
    return PreviousAssessmentRow(assessment: assessment, modelContext: modelContext)
        .environmentObject(NavigationState())
}
