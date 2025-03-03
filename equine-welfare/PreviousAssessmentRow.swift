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

// MARK: - UIFont Extension
extension UIFont {
    func bold() -> UIFont {
        return UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitBold)!, size: pointSize)
    }
}

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
            } else {
                print("Error converting to RTF format")
            }
        } catch {
            print("Error creating share file: \(error.localizedDescription)")
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
            // Edit button
            Button(action: { navigationState.editAssessment(assessmentId: assessment.id) }) {
                Image(systemName: "pencil")
                if assessment.isComplete {
                    Text("Edit")
                } else {
                    Text("Resume")
                }
                
            }
            .help("Edit Assessment")
            
            // Preview button
            Button(action: { showingPreview.toggle() }) {
                
                Image(systemName: "doc.text.magnifyingglass")
                Text("Preview")
                    
            }
            .help("Preview Assessment")
            
            // Share button
            shareButton
            
            // Delete button
            deleteButton
        }.foregroundColor(.blue)
    }
    
    private var shareButton: some View {
        Group {
            if let url = shareURL, isShareReady {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Share")
                }
                .help("Share Assessment as RTF Document")
            } else {
                Button(action: { prepareShareContent() }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .help("Share Assessment as RTF Document")
            }
        }
    }
    
    private var deleteButton: some View {
        Button(action: { showingDeleteConfirmation = true }) {
            Image(systemName: "trash")
            Text("Delete")
        }
        .help("Delete Assessment")
        .foregroundColor(.red)
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
