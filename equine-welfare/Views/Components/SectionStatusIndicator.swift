import SwiftUI

struct SectionStatusIndicator: View {
    let status: SectionCompletionStatus
    var isSelected: Bool = false

    init(status: SectionCompletionStatus, isSelected: Bool = false) {
        self.status = status
        self.isSelected = isSelected
    }

    var body: some View {
        switch status {
        case .completed:
            // Filled circle with checkmark for completed
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(isSelected ? .white : status.color)
        case .inProgress:
            Image(systemName: "circle.lefthalf.filled")
                .foregroundColor(isSelected ? .white : status.color)
        case .notStarted:
            Image(systemName: "circle")
                .foregroundColor(isSelected ? .white : status.color)
        }
    }
}

struct SectionStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                SectionStatusIndicator(status: .notStarted)
                Text("Not Started")
            }

            HStack(spacing: 10) {
                SectionStatusIndicator(status: .inProgress)
                Text("In Progress")
            }

            HStack(spacing: 10) {
                SectionStatusIndicator(status: .completed)
                Text("Completed")
            }

            // Preview selected state
            HStack(spacing: 10) {
                SectionStatusIndicator(status: .completed, isSelected: true)
                Text("Selected State")
            }
            .padding()
            .background(Color.accentColor)
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
