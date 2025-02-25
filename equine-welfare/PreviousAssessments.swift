//
//  PreviousAssessments.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftUI
import SwiftData

struct PreviousAssessments: View {
    @Query(sort: \Assessment.visitDate, order: .reverse) var assessments: [Assessment]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Previous Assessments")
                .font(.title2)
                .fontWeight(.bold)
            
            if assessments.isEmpty {
                Text("No previous assessments")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(assessments) { assessment in
                        PreviousAssessmentRow(assessment: assessment)
                    }
                }
            }
        }
    }
}

#Preview {
    PreviousAssessments()
        .modelContainer(for: Assessment.self, inMemory: true)
}
