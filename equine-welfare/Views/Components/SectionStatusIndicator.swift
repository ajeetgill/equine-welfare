import SwiftUI

struct SectionStatusIndicator: View {
    let status: SectionCompletionStatus

    init(status: SectionCompletionStatus) {
        self.status = status
    }

    var body: some View {
        switch status {
        case .completed:
            // Filled circle with checkmark for completed
            Image(systemName: "checkmark.circle.fill")
        case .inProgress:
            Image(systemName: "circle.lefthalf.filled")
        case .notStarted:
            Image(systemName: "circle")
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
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
