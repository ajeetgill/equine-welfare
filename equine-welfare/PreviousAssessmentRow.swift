//
//  AssessmentRow.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit
import AVFoundation

// MARK: - UIFont Extension
extension UIFont {
    func bold() -> UIFont {
        return UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitBold)!, size: pointSize)
    }
}

struct PreviousAssessmentRow: View {
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State Properties
    @State private var showingDeleteConfirmation = false
    @State private var showingPreview = false
    @State private var shareURL: URL?
    @State private var isShareReady = false
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showUploadAlert = false
    @State private var showUploadSuccess = false
    @State private var uploadSuccessMessage: String?
    @State private var uploadProgress: Double = 0.0
    @State private var isUploadingMedia: Bool = false
    @State private var sectionViewModel: SectionSelectionViewModel
    @StateObject private var permissionsManager = PermissionsManager()
    @State private var showPermissionsAlert = false
    @AppStorage("isPermissionsGranted") private var isPermissionsGranted = false
    
    // MARK: - Properties
    let assessment: Assessment
    var onSelectAssessment: ((UUID) -> Void)?
    private let assessmentHelper: AssessmentHelper

    // MARK: - Initialization
    init(assessment: Assessment, modelContext: ModelContext, onSelectAssessment: ((UUID) -> Void)? = nil) {
        self.assessment = assessment
        self.assessmentHelper = AssessmentHelper(modelContext: modelContext)
        self.sectionViewModel = SectionSelectionViewModel(
            modelContext: modelContext)
        self.onSelectAssessment = onSelectAssessment
    }
    
    // MARK: - Helper Methods
    private func prepareShareContent() {
        // Create a preview view to generate content that matches what's shown in preview
        let previewView = AssessmentPreviewView(assessment: assessment)
        
        // Generate RTF content instead of HTML
        let attributedString = generateRTFContent(from: previewView)
        
        // Create a temporary file with a sanitized filename
        let tempDir = FileManager.default.temporaryDirectory
        let sanitizedName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
        let fileName = "\(sanitizedName).rtf"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            // Convert NSAttributedString to RTF data and write to file
            if let rtfData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length), 
                                                       documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                try rtfData.write(to: fileURL)
                shareURL = fileURL
                isShareReady = true
            }
        } catch {
            // Error creating share file - silently fail
        }
    }
    
    // Upload the RTF file to Supabase
    private func uploadRTFToSupabase() async {
        // Always prepare/refresh the content first to ensure we have the latest version
        prepareShareContent()
        
        guard let fileURL = shareURL, isShareReady else {
            uploadError = "Failed to prepare the document for upload"
            showUploadAlert = true
            return
        }
        
        // Small delay to ensure file is fully written
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify file exists before attempting upload
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            uploadError = "RTF file not found at expected location"
            showUploadAlert = true
            return
        }
        
        // Start uploading - show progress
        isUploading = true
        uploadProgress = 0.1 // Initial progress
        
        // Use the comprehensive upload method which handles all upload steps
        let result = await SupabaseService.shared.uploadAssessmentComplete(
            assessment: assessment,
            modelContext: modelContext
        ) { message, progress in
            // Update UI with detailed progress message and value
            self.uploadProgress = progress
            
            // Update the UI with detailed status messages
            if message.contains("horse data") || message.contains("document") {
                self.isUploadingMedia = false
            } else if message.contains("media") {
                self.isUploadingMedia = true
            }
        }
        
        // Handle the result
        switch result {
        case .success(let uploadResult):
            // Create a success message based on upload result
            uploadSuccessMessage = "Assessment uploaded successfully to cloud storage."
            showUploadSuccess = true
            uploadError = nil
            isUploadingMedia = false
            
            // Complete the upload process
            uploadProgress = 1.0
            
            // Reset state
            isUploading = false
            uploadProgress = 0.0
            
        case .failure(let error):
            uploadError = error.localizedDescription
            showUploadAlert = true
            
            // Reset state
            isUploading = false
            uploadProgress = 0.0
        }
    }
    
    // Generate RTF content that matches the preview
    private func generateRTFContent(from previewView: AssessmentPreviewView) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .title1).bold(),
            .foregroundColor: UIColor.black
        ]
        attributedString.append(NSAttributedString(string: "Assessment Report\n\n", attributes: titleAttributes))
        
        // Header info
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.black
        ]
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body).bold(),
            .foregroundColor: UIColor.black
        ]
        
        attributedString.append(NSAttributedString(string: "Vet Name: ", attributes: boldAttributes))
        attributedString.append(NSAttributedString(string: "\(assessment.vetName)\n", attributes: headerAttributes))
        
        attributedString.append(NSAttributedString(string: "Farm Name: ", attributes: boldAttributes))
        attributedString.append(NSAttributedString(string: "\(assessment.farmName)\n", attributes: headerAttributes))
        
        attributedString.append(NSAttributedString(string: "Date of Visit: ", attributes: boldAttributes))
        attributedString.append(NSAttributedString(string: "\(assessment.formattedDate)\n\n", attributes: headerAttributes))
        
        // Get non-compliant sections (reusing the same logic from AssessmentPreviewView)
        let nonCompliantSections = assessment.sections
            .filter { section in
                section.isApplicable && section.subsections.contains { subsection in
                    subsection.requirements.contains { requirement in
                        requirement.complianceStatus == .notCompliant
                    }
                }
            }
            .sorted(by: { $0.id < $1.id })
        
        if nonCompliantSections.isEmpty {
            attributedString.append(NSAttributedString(string: "No non-compliant requirements found.\n", attributes: headerAttributes))
        } else {
            for section in nonCompliantSections {
                // Section title
                let sectionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.preferredFont(forTextStyle: .title2).bold(),
                    .foregroundColor: UIColor.black
                ]
                attributedString.append(NSAttributedString(string: "Section \(section.id): \(section.title)\n\n", attributes: sectionAttributes))
                
                // Get non-compliant subsections
                let nonCompliantSubsections = section.subsections.filter { subsection in
                    subsection.requirements.contains { requirement in
                        requirement.complianceStatus == .notCompliant
                    }
                }
                
                for subsection in nonCompliantSubsections {
                    // Subsection name
                    let subsectionAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.preferredFont(forTextStyle: .title3).bold(),
                        .foregroundColor: UIColor.black
                    ]
                    attributedString.append(NSAttributedString(string: "\(subsection.name)\n\n", attributes: subsectionAttributes))
                    
                    // Get non-compliant requirements
                    let nonCompliantRequirements = subsection.requirements.filter { requirement in
                        requirement.complianceStatus == .notCompliant
                    }
                    
                    for requirement in nonCompliantRequirements {
                        // Requirement text
                        attributedString.append(NSAttributedString(string: "\(requirement.text)\n", attributes: headerAttributes))
                        
                        // Status
                        attributedString.append(NSAttributedString(string: "Status: ", attributes: boldAttributes))
                        
                        let statusAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.preferredFont(forTextStyle: .body),
                            .foregroundColor: UIColor.red
                        ]
                        attributedString.append(NSAttributedString(string: "\(requirement.complianceStatus?.rawValue ?? "Not Evaluated")\n", attributes: statusAttributes))
                        
                        // Reason for non-compliance (if any)
                        if let reason = requirement.nonComplianceReason, !reason.isEmpty {
                            attributedString.append(NSAttributedString(string: "Reason for non-compliance: ", attributes: boldAttributes))
                            attributedString.append(NSAttributedString(string: "\(reason)\n", attributes: headerAttributes))
                        }
                        
                        attributedString.append(NSAttributedString(string: "\n", attributes: headerAttributes))
                    }
                }
                
                // Divider
                attributedString.append(NSAttributedString(string: "--------------------------------------------------\n\n", attributes: headerAttributes))
            }
        }
        
        return attributedString
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
        .alert("Upload Successful", isPresented: $showUploadSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(uploadSuccessMessage ?? "Assessment document has been uploaded.")
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
        HStack(spacing: 12) {
            // Only show upload button if credentials are available
            if SupabaseService.areCredentialsAvailable() {
                uploadButton
            }
            
            Button(action: {
                // Check permissions before allowing resume/edit
                if !permissionsManager.isCameraAuthorized || !permissionsManager.isMicrophoneAuthorized {
                    // Request permissions instead of just showing alert
                    Task {
                        await permissionsManager.checkAndRequestPermissions()
                        // After requesting, check if they were granted
                        if permissionsManager.isCameraAuthorized && permissionsManager.isMicrophoneAuthorized {
                            isPermissionsGranted = true
                            sectionViewModel.loadAssessment(id: assessment.id)
                            onSelectAssessment?(assessment.id)
                        } else {
                            isPermissionsGranted = false
                            showPermissionsAlert = true
                        }
                    }
                    return
                }
                
                sectionViewModel.loadAssessment(id: assessment.id)
                onSelectAssessment?(assessment.id)
            }) {
                Label(assessment.isComplete ? "Edit" : "Resume", systemImage: "pencil")
            }
            .help("Edit Assessment")
            
            // Preview button
            Button(action: { showingPreview.toggle() }) {
                Label("Preview", systemImage: "doc.text.magnifyingglass")
            }
            .help("Preview Assessment")
            
            // Share button - it is disabled by choice, we don't want to use it now since we have the upload button
            // shareButton
            
            // Delete button
            deleteButton
        }
        .foregroundColor(.blue)
        .alert("Permissions Required", isPresented: $showPermissionsAlert) {
            Button("Open Settings") {
                permissionsManager.openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable camera and microphone access in Settings to use Horse COP.")
        }
    }
    
    private var uploadButton: some View {
        Button {
            Task {
                await uploadRTFToSupabase()
            }
        } label: {
            if isUploading {
                VStack(spacing: 4) {
                    if isUploadingMedia {
                        Text("Uploading media...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Uploading document...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Custom progress bar
                    ProgressView(value: uploadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 100)
                }
                .padding(.horizontal, 4)
            } else {
                Label("Upload", systemImage: "arrow.trianglehead.clockwise.icloud.fill")
            }
        }
        .disabled(isUploading || !SupabaseService.areCredentialsAvailable())
        .tint(.blue)
        .help(SupabaseService.areCredentialsAvailable() ? 
              "Upload assessment to cloud storage" : 
              "Upload disabled - Supabase credentials not configured")
        .alert(uploadError?.contains("already been uploaded") ?? false ? "Assessment Already Exists" : "Upload Error", isPresented: $showUploadAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(uploadError ?? "An unknown error occurred")
        }
    }
    
    private var shareButton: some View {
        Group {
            if let url = shareURL, isShareReady {
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .help("Share Assessment as RTF Document")
            }
        }
    }
    
    private var deleteButton: some View {
        Button(action: { showingDeleteConfirmation = true }) {
            Label("", systemImage: "trash")
        }
        .help("Delete Assessment")
        .foregroundColor(.red)
        .confirmationDialog(
            "Delete Assessment",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                withAnimation(){
                    assessmentHelper.deleteAssessment(assessment: assessment)
                }
            }
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
    
    PreviousAssessmentRow(assessment: assessment, modelContext: modelContext)
        .modelContainer(for: Assessment.self)
}
