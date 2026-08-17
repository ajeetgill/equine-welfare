import UIKit

extension UIFont {
    func bold() -> UIFont {
        return UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitBold)!, size: pointSize)
    }
}

/// Builds the shareable RTF report for an assessment. Extracted from
/// PreviousAssessmentRow so report content is testable and reusable; the
/// non-compliant selection comes from NonComplianceFilters, keeping the
/// report consistent with the on-screen preview.
enum AssessmentRTFReport {

    /// The report body, matching what AssessmentPreviewView shows.
    static func content(for assessment: Assessment) -> NSAttributedString {
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

                for subsection in section.nonCompliantSubsections {
                    // Subsection name
                    let subsectionAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.preferredFont(forTextStyle: .title3).bold(),
                        .foregroundColor: UIColor.black
                    ]
                    attributedString.append(NSAttributedString(string: "\(subsection.name)\n\n", attributes: subsectionAttributes))

                    for requirement in subsection.nonCompliantRequirements {
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

    /// Writes the report to a temp file named after the assessment for
    /// ShareLink; returns nil if RTF conversion or the write fails.
    static func temporaryFileURL(for assessment: Assessment) -> URL? {
        let attributedString = content(for: assessment)
        let sanitizedName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitizedName).rtf")

        guard let rtfData = try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else { return nil }

        do {
            try rtfData.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
}
