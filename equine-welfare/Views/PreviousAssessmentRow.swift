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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
    @State private var showSignIn = false
    @State private var sectionViewModel: SectionSelectionViewModel
    @Environment(PermissionsManager.self) private var permissionsManager
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
        // Generate RTF content that matches what's shown in the preview
        let attributedString = generateRTFContent()
        
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
    
    // Sync assessment to PocketBase
    private func syncToCloud() async {
        isUploading = true
        uploadProgress = 0.1

        do {
            try await PocketBaseService.shared.syncAssessment(assessment) { message, progress in
                self.uploadProgress = progress
                self.isUploadingMedia = message.contains("media")
            }

            uploadSuccessMessage = "Assessment synced successfully!"
            showUploadSuccess = true
            uploadError = nil
            isUploadingMedia = false
            uploadProgress = 1.0

        } catch let error as PocketBaseError {
            // PocketBase errors are structured — no string matching needed.
            uploadError = error.localizedDescription
            showUploadAlert = true
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost:
                uploadError = "Could not reach the sync server. Check that you're on the same network and PocketBase is running."
            default:
                uploadError = "Sync failed. Please try again later."
            }
            showUploadAlert = true
        } catch {
            uploadError = "Sync failed. Please try again later."
            showUploadAlert = true
        }

        isUploading = false
        uploadProgress = 0.0
    }
    
    // Generate RTF content that matches the preview
    private func generateRTFContent() -> NSAttributedString {
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
        
        // Non-compliant filtering is shared with the preview (see NonComplianceFilters.swift)
        let nonCompliantSections = assessment.nonCompliantSections

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
                
                let nonCompliantSubsections = section.nonCompliantSubsections

                for subsection in nonCompliantSubsections {
                    // Subsection name
                    let subsectionAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.preferredFont(forTextStyle: .title3).bold(),
                        .foregroundColor: UIColor.black
                    ]
                    attributedString.append(NSAttributedString(string: "\(subsection.name)\n\n", attributes: subsectionAttributes))
                    
                    let nonCompliantRequirements = subsection.nonCompliantRequirements

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
        Group {
            if horizontalSizeClass == .compact {
                VStack(alignment: .leading, spacing: 10) {
                    assessmentInfo
                        .frame(maxWidth: .infinity, alignment: .leading)
                    actionButtons
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack {
                    assessmentInfo
                    Spacer()
                    actionButtons
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .sheet(isPresented: $showingPreview) {
            previewSheet
        }
        .onAppear {
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
        let isCompact = horizontalSizeClass == .compact
        return HStack(spacing: isCompact ? 16 : 12) {
            // Sync button
            uploadButton

            Button(action: {
                // Check permissions before allowing resume/edit
                if !permissionsManager.isCameraAuthorized || !permissionsManager.isMicrophoneAuthorized {
                    Task {
                        await permissionsManager.checkAndRequestPermissions()
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
                if isCompact {
                    Image(systemName: "pencil")
                } else {
                    Label(assessment.isComplete ? "Edit" : "Resume", systemImage: "pencil")
                }
            }
            .help(assessment.isComplete ? "Edit Assessment" : "Resume Assessment")

            // Preview button
            Button(action: { showingPreview.toggle() }) {
                if isCompact {
                    Image(systemName: "doc.text.magnifyingglass")
                } else {
                    Label("Preview", systemImage: "doc.text.magnifyingglass")
                }
            }
            .help("Preview Assessment")

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
            // Sync is the only feature that needs an account — everything
            // else works offline. Prompt for sign-in just-in-time.
            if !PocketBaseService.shared.isSignedIn {
                showSignIn = true
            } else {
                Task {
                    await syncToCloud()
                }
            }
        } label: {
            if isUploading {
                VStack(spacing: 4) {
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView(value: uploadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: horizontalSizeClass == .compact ? 60 : 100)
                }
                .padding(.horizontal, 4)
            } else {
                if horizontalSizeClass == .compact {
                    Image(systemName: "arrow.trianglehead.clockwise.icloud.fill")
                } else {
                    Label("Sync", systemImage: "arrow.trianglehead.clockwise.icloud.fill")
                }
            }
        }
        .disabled(isUploading)
        .tint(.blue)
        .help("Sync assessment to cloud")
        .sheet(isPresented: $showSignIn, onDismiss: {
            // Continue the sync the user asked for once they're signed in.
            if PocketBaseService.shared.isSignedIn {
                Task {
                    await syncToCloud()
                }
            }
        }) {
            SignInSheet()
        }
        .alert("Sync Error", isPresented: $showUploadAlert) {
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
        .frame(minWidth: horizontalSizeClass == .compact ? nil : 600,
               minHeight: horizontalSizeClass == .compact ? nil : 800)
    }
}

// MARK: - Preview
#Preview {
    let modelContext = ModelContext(try! ModelContainer(for: Assessment.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    
    let assessment = Assessment(vetName: "Dr. Smith", farmName: "Green Acres", visitDate: Date())
    
    PreviousAssessmentRow(assessment: assessment, modelContext: modelContext)
        .environment(PermissionsManager())
        .modelContainer(for: Assessment.self)
}
