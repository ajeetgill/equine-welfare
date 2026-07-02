//
//  PreviousAssessments.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftData
import SwiftUI

struct PreviousAssessments: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Assessment.visitDate, order: .reverse) var assessments:
        [Assessment]
    
    /// Called with the tapped assessment's id to open its workspace.
    var onOpen: (UUID) -> Void

    init(onOpen: @escaping (UUID) -> Void) {
        self.onOpen = onOpen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Previous Assessments")
                .font(.title2)
                .fontWeight(.bold)

            assessmentsList
        }
        .padding()
    }

    // MARK: - Private Views

    @ViewBuilder
    private var assessmentsList: some View {
        if assessments.isEmpty {
            emptyStateView
        } else {
            assessmentsListView
        }
    }

    private var emptyStateView: some View {
        Text("No previous assessments")
            .foregroundColor(.secondary)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var assessmentsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(assessments) { assessment in
                    PreviousAssessmentRow(
                        assessment: assessment, 
                        modelContext: modelContext,
                        onSelectAssessment: { assessmentId in
                            onOpen(assessmentId)
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    PreviousAssessments(onOpen: { _ in })
        .modelContainer(for: Assessment.self, inMemory: true)
}
