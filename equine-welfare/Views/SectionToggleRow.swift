import SwiftUI

struct SectionToggleRow: View {
    let section: AssessmentSection
    let toggleAction: () -> Void
    @Binding var isApplicable: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                // Show info
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .padding(.trailing, 4)
            
            Text("\(section.id). \(section.title)")
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            Toggle("", isOn: $isApplicable)
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .onChange(of: isApplicable) { _, _ in
                    toggleAction()
                }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }
} 