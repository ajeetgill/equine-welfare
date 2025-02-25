//
//  PreviousAssessments.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftUI

struct PreviousAssessments: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
                Text("Previous Assessments")
                    .font(.title2)
                    .fontWeight(.bold)
                
                LazyVStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { index in
                        PreviousAssessmentRow(
                            date: "2024-FEB-\(index)",
                            vetName: "Dr. Smith",
                            location: "Happy Horse Farm",
                            isComplete: index % 2 == 0
                        )
                    }
                }
            
        }
    }
}

#Preview {
    PreviousAssessments()
}
