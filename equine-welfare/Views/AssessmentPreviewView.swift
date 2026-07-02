import SwiftUI
import SwiftData

struct AssessmentPreviewView: View {
    let assessment: Assessment
    
    // MARK: - Helper Methods for Content Generation
    // Non-compliant filtering lives on the models (see NonComplianceFilters.swift)
    // so the preview and every export format share one definition.

    // Function to generate HTML content for sharing as a .doc file
    func generateDocContent() -> String {
        // Create HTML document with styling
        let html = """
        <html>
        <head>
        <meta charset="UTF-8">
        <title>Assessment Report - \(assessment.displayName)</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.5; }
            h1 { color: #2c3e50; border-bottom: 1px solid #eee; padding-bottom: 10px; }
            h2 { color: #3498db; margin-top: 30px; }
            h3 { color: #2c3e50; margin-top: 20px; }
            .header-info { margin-bottom: 30px; }
            .header-row { margin: 5px 0; }
            .label { font-weight: bold; display: inline-block; width: 120px; }
            .section { margin-top: 20px; margin-bottom: 30px; }
            .subsection { margin-left: 20px; margin-bottom: 20px; }
            .requirement { background-color: #f9f9f9; padding: 15px; margin-bottom: 15px; border-left: 4px solid #e74c3c; }
            .status { color: #e74c3c; font-weight: bold; }
            .reason { color: #7f8c8d; margin-top: 10px; }
            .divider { border-top: 1px solid #eee; margin: 30px 0; }
        </style>
        </head>
        <body>
        <h1>Assessment Report</h1>
        
        <div class="header-info">
            <div class="header-row"><span class="label">Vet Name:</span> \(assessment.vetName)</div>
            <div class="header-row"><span class="label">Farm Name:</span> \(assessment.farmName)</div>
            <div class="header-row"><span class="label">Date of Visit:</span> \(assessment.formattedDate)</div>
        </div>
        
        """
        
        let relevantSections = assessment.nonCompliantSections
        
        var htmlContent = html
        
        if relevantSections.isEmpty {
            htmlContent += "<p>No non-compliant requirements found.</p>"
        } else {
            for section in relevantSections {
                htmlContent += "<div class='section'>"
                htmlContent += "<h2>Section \(section.id): \(section.title)</h2>"
                
                let nonCompliantSubsections = section.nonCompliantSubsections
                
                for subsection in nonCompliantSubsections {
                    htmlContent += "<div class='subsection'>"
                    htmlContent += "<h3>\(subsection.name)</h3>"
                    
                    let nonCompliantRequirements = subsection.nonCompliantRequirements
                    
                    for requirement in nonCompliantRequirements {
                        htmlContent += "<div class='requirement'>"
                        htmlContent += "<p>\(requirement.text)</p>"
                        htmlContent += "<p><span class='status'>Status: \(requirement.complianceStatus?.rawValue ?? "Not Evaluated")</span></p>"
                        
                        if let reason = requirement.nonComplianceReason, !reason.isEmpty {
                            htmlContent += "<p class='reason'>Reason for non-compliance: \(reason)</p>"
                        }
                        
                        if !requirement.mediaAttachments.isEmpty {
                            htmlContent += "<p class='evidence'>Evidence: \(requirement.mediaAttachments.count) image(s) attached</p>"
                        }
                        
                        htmlContent += "</div>"
                    }
                    
                    htmlContent += "</div>"
                }
                
                htmlContent += "<div class='divider'></div>"
                htmlContent += "</div>"
            }
        }
        
        htmlContent += """
        </body>
        </html>
        """
        
        return htmlContent
    }
    
    // Function to generate text content for sharing - matching exactly what's shown in the preview
    func generateShareContent() -> String {
        var content = """
        Assessment Report
        
        """
        
        // Add assessment details
        content += "Vet Name: \(assessment.vetName)\n"
        content += "Farm Name: \(assessment.farmName)\n"
        content += "Date of Visit: \(assessment.formattedDate)\n\n"
        
        let relevantSections = assessment.nonCompliantSections
        
        if relevantSections.isEmpty {
            content += "No non-compliant requirements found.\n"
        } else {
            for section in relevantSections {
                content += "Section \(section.id): \(section.title)\n"
                
                let nonCompliantSubsections = section.nonCompliantSubsections
                
                for subsection in nonCompliantSubsections {
                    content += "\n\(subsection.name)\n"
                    
                    let nonCompliantRequirements = subsection.nonCompliantRequirements
                    
                    for requirement in nonCompliantRequirements {
                        content += "\n\(requirement.text)\n"
                        content += "Status: \(requirement.complianceStatus?.rawValue ?? "Not Evaluated")\n"
                        
                        if let reason = requirement.nonComplianceReason, !reason.isEmpty {
                            content += "Reason for non-compliance: \(reason)\n"
                        }
                        
                        if !requirement.mediaAttachments.isEmpty {
                            content += "Evidence: \(requirement.mediaAttachments.count) image(s) attached\n"
                        }
                    }
                }
                
                content += "\n--------------------------------------------------\n"
            }
        }
        
        return content
    }
    
    // MARK: - View Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Section
                AssessmentHeaderView(assessment: assessment)
                
                // Sections - only show sections that have non-compliant requirements
                ForEach(assessment.nonCompliantSections) { section in
                    SectionPreviewView(section: section)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Helper Views

// Header view component
struct AssessmentHeaderView: View {
    let assessment: Assessment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assessment Report")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Divider()
            
            // Assessment Details
            Group {
                DetailRow(label: "Vet Name", value: assessment.vetName)
                DetailRow(label: "Farm Name", value: assessment.farmName)
                DetailRow(label: "Date of Visit", value: assessment.formattedDate)
            }
            
            Divider()
        }
        .padding(.bottom)
    }
}

// Helper view for detail rows in the header
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

// Helper view for section preview
struct SectionPreviewView: View {
    let section: Section

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Section \(section.id): \(section.title)")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(section.nonCompliantSubsections, id: \.name) { subsection in
                SubsectionPreviewView(subsection: subsection)
            }
            
            Divider()
        }
    }
}

// Helper view for subsection preview
struct SubsectionPreviewView: View {
    let subsection: Subsection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(subsection.name)
                .font(.title3)
                .fontWeight(.semibold)

            ForEach(subsection.nonCompliantRequirements, id: \.text) { requirement in
                RequirementPreviewView(requirement: requirement)
            }
        }
        .padding(.leading)
    }
}

// Helper view for requirement preview
struct RequirementPreviewView: View {
    let requirement: Requirement
    @State private var showingMediaPreview: MediaAttachment?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(requirement.text)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Text("Status:")
                    .fontWeight(.medium)
                
                Text(requirement.complianceStatus?.rawValue ?? "Not Evaluated")
                    .foregroundColor(.red) // Always red since we only show non-compliant items
            }
            
            if let reason = requirement.nonComplianceReason, !reason.isEmpty {
                Text("Reason for non-compliance:")
                    .fontWeight(.medium)
                Text(reason)
                    .foregroundColor(.secondary)
            }
            
            if !requirement.mediaAttachments.isEmpty {
                Text("Evidence:")
                    .fontWeight(.medium)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(requirement.mediaAttachments, id: \.id) { attachment in
                            MediaThumbnail(attachment: attachment, size: 60)
                                .onTapGesture {
                                    showingMediaPreview = attachment
                                }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
        .sheet(item: $showingMediaPreview) { attachment in
            MediaPreviewView(attachment: attachment)
        }
    }
}

#Preview {
    let assessment = Assessment(vetName: "Dr. Smith", farmName: "Green Acres", visitDate: Date())
    let section = Section(id: 1, title: "Housing", isApplicable: true)
    let subsection = Subsection(name: "1.1 Shelter")
    
    // Add a non-compliant requirement
    let requirement1 = Requirement(text: "Adequate shelter must be provided")
    requirement1.complianceStatus = .notCompliant
    requirement1.nonComplianceReason = "Insufficient shelter space"
    
    // Add a compliant requirement (won't be shown)
    let requirement2 = Requirement(text: "Proper ventilation must be maintained")
    requirement2.complianceStatus = .compliant
    
    subsection.requirements.append(requirement1)
    subsection.requirements.append(requirement2)
    section.subsections.append(subsection)
    assessment.sections.append(section)
    
    return AssessmentPreviewView(assessment: assessment)
} 
