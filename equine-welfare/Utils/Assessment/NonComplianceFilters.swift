import Foundation

// Centralised definition of "non-compliant" used by the on-screen preview
// (AssessmentPreviewView) and every exported report format (HTML / plain
// text / RTF). Keeping the filter predicates in one place means the meaning
// of "non-compliant" can't drift between what's shown and what's exported.
//
// These are computed (non-stored) properties, so they have no effect on the
// SwiftData schema.

extension Assessment {
    /// Applicable sections that contain at least one non-compliant
    /// requirement, sorted by section id.
    var nonCompliantSections: [Section] {
        sections
            .filter { section in
                section.isApplicable && section.subsections.contains { subsection in
                    subsection.requirements.contains { $0.complianceStatus == .notCompliant }
                }
            }
            .sorted { $0.id < $1.id }
    }
}

extension Section {
    /// Subsections that contain at least one non-compliant requirement.
    var nonCompliantSubsections: [Subsection] {
        subsections.filter { subsection in
            subsection.requirements.contains { $0.complianceStatus == .notCompliant }
        }
    }
}

extension Subsection {
    /// Requirements marked as non-compliant.
    var nonCompliantRequirements: [Requirement] {
        requirements.filter { $0.complianceStatus == .notCompliant }
    }
}
