import SwiftUI

struct SectionStatusIndicator: View {
    let status: SectionCompletionStatus
    let size: CGFloat
    
    init(status: SectionCompletionStatus, size: CGFloat = 16) {
        self.status = status
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Base circle outline
            Circle()
                .stroke(status.color, lineWidth: 1.5)
                .frame(width: size, height: size)
            
            // Fill based on completion status
            Group {
                switch status {
                case .completed:
                    // Filled circle with checkmark for completed
                    Circle()
                        .fill(status.color)
                        .frame(width: size - 3, height: size - 3)
                    
                    // Add checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.6))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                
                case .inProgress:
                    // Half-filled circle for in progress
                    HalfCircle()
                        .fill(status.color)
                        .frame(width: size - 3, height: size - 3)
                
                case .notStarted:
                    // Empty for not started
                    EmptyView()
                }
            }
        }
        .padding(.leading, 4) // Add extra padding on left to prevent clipping
    }
}

// Custom shape for half-circle
struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                   radius: rect.width / 2,
                   startAngle: Angle(degrees: -90),
                   endAngle: Angle(degrees: 90),
                   clockwise: false)
        path.closeSubpath()
        
        return path
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