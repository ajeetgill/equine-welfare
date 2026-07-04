import SwiftUI
import SwiftData

struct SideNotesView: View {
    let assessment: Assessment
    @Environment(\.modelContext) private var modelContext
    @State private var notes: String
    
    init(assessment: Assessment) {
        self.assessment = assessment
        self._notes = State(initialValue: assessment.sideNotes ?? "")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Notes content with placeholder
                TextEditor(text: $notes)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(minHeight: 200)
                    .overlay(
                        Group {
                            if notes.isEmpty {
                                Text("Tap to add notes...")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 4)
                                    .padding(.top, 8)
                            }
                        },
                        alignment: .topLeading
                    )
                    .onChange(of: notes) { _, newValue in
                        // Save notes as user types
                        assessment.sideNotes = newValue.isEmpty ? nil : newValue
                        modelContext.saveOrLog("side notes")
                    }
            }
            .padding()
        }
        .navigationTitle("Side Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
