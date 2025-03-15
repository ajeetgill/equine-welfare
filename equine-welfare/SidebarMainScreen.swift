//
//  SideBarMainScreen.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftUI

struct SidebarMainScreen: View {
    @EnvironmentObject private var navigationState: NavigationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Report")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            
            // Home button (disabled since we're already on home screen)
            SidebarButton(
                title: "Home",
                icon: "house.fill",
                isActive: false
            )
            .padding(.horizontal)
            .padding(.top, 16)
            .disabled(true)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    SidebarMainScreen()
        .environmentObject(NavigationState())
}
