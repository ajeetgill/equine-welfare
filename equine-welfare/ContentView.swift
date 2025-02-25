//
//  ContentView.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 19/02/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var vetName = ""
    @State private var farmName = ""
    @State private var visitDate = Date()
    
    
    var body: some View {
        NavigationSplitView {
            SidebarMainScreen()
        } detail: {
            VStack(alignment: .leading, spacing: 24) {

            MainScreen(vetName: $vetName, farmName: $farmName, visitDate: $visitDate)
                
            
                ScrollView {
                    PreviousAssessments()
                }
                
            }.padding()
        }
    }
}



#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
