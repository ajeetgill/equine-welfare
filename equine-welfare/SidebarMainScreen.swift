//
//  SideBarMainScreen.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/02/25.
//

import SwiftUI

struct SidebarMainScreen: View {
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Report")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    SidebarMainScreen()
}
