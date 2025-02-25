//
//  AssessmentRow.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//


import SwiftUI
import SwiftData

struct PreviousAssessmentRow: View {
    let date: String
    let vetName: String
    let location: String
    let isComplete: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(date)-\(vetName)-\(location)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {}) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                
                if !isComplete {
                    Button(action: {}) {
                        Text("Resume")
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(isComplete ? .blue : .gray)
                }
                .disabled(!isComplete)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
