import SwiftUI

struct SectionToggleRow: View {
    let section: Section
    let toggleAction: () -> Void
    @Binding var isApplicable: Bool
    @State private var showingInfo: Bool = false
    
    var body: some View {
        HStack {
            Button(action: {
                showingInfo.toggle()
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .sheet(isPresented: $showingInfo) {
                SectionInfoView(section: section)
            }
            
            Text("\(section.id). \(section.title)")
                .font(.body)
                .fontWeight(.medium)
            
            Toggle("", isOn: $isApplicable)
                .toggleStyle(CheckmarkToggleStyle())
                
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

// MARK: - Section Info View
struct SectionInfoView: View {
    let section: Section
    @Environment(\.dismiss) private var dismiss

    private var sortedSubsections: [Subsection] {
        section.subsections.sorted { s1, s2 in
            let comps1 = s1.name.numericComponents()
            let comps2 = s2.name.numericComponents()
            
            // Compare components lexicographically
            for i in 0..<min(comps1.count, comps2.count) {
                if comps1[i] < comps2[i] { return true }
                if comps1[i] > comps2[i] { return false }
            }
            // If all common components match, shorter array comes first
            return comps1.count < comps2.count
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("About this section")
                    .font(.title)
                    .bold()
                
                Text("Section \(section.id): \(section.title)")
                    .font(.headline)
                
                if !section.subsections.isEmpty {
                    Text("Subsections:")
                        .font(.headline)
                        .padding(.top)
                    
                    ForEach(sortedSubsections, id: \.name) { subsection in
                        Text("• \(subsection.name)")
                            .padding(.leading)
                    }
                }
                
                Spacer()
            }
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
        
}
