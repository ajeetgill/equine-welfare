//
//  AssessmentRow.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftUI
import SwiftData

// Row for one saved assessment: info + actions (sync / edit / preview /
// delete / share). Sync state lives in AssessmentSyncViewModel; the RTF
// report is built by AssessmentRTFReport — this file is UI only.
struct PreviousAssessmentRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - State Properties
    @State private var showingDeleteConfirmation = false
    @State private var showingPreview = false
    @State private var shareURL: URL?
    @State private var isShareReady = false
    @State private var showSignIn = false
    @State private var syncModel = AssessmentSyncViewModel()
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

    // MARK: - View Body
    var body: some View {
        @Bindable var syncModel = syncModel
        return Group {
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
            shareURL = AssessmentRTFReport.temporaryFileURL(for: assessment)
            isShareReady = shareURL != nil
        }
        .alert("Upload Successful", isPresented: $syncModel.showUploadSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncModel.uploadSuccessMessage ?? "Assessment document has been uploaded.")
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
        @Bindable var syncModel = syncModel
        return Button {
            // Sync is the only feature that needs an account — everything
            // else works offline. Prompt for sign-in just-in-time.
            if !PocketBaseService.shared.isSignedIn {
                showSignIn = true
            } else {
                Task {
                    await syncModel.sync(assessment)
                }
            }
        } label: {
            if syncModel.isUploading {
                VStack(spacing: 4) {
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView(value: syncModel.uploadProgress, total: 1.0)
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
        .disabled(syncModel.isUploading)
        .tint(.blue)
        .help("Sync assessment to cloud")
        .sheet(isPresented: $showSignIn, onDismiss: {
            // Continue the sync the user asked for once they're signed in.
            if PocketBaseService.shared.isSignedIn {
                Task {
                    await syncModel.sync(assessment)
                }
            }
        }) {
            SignInSheet()
        }
        .alert("Sync Error", isPresented: $syncModel.showUploadAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncModel.uploadError ?? "An unknown error occurred")
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
