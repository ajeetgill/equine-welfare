//
//  CheckmarkToggleStyle.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 24/03/25.
//

import SwiftUI

struct CheckmarkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Rectangle()
                .foregroundColor(configuration.isOn ? .green : .gray.opacity(0.8))
                .frame(width: 51, height: 31, alignment: .center)
                .overlay(
                    Circle()
                        .foregroundColor(.white)
                        .padding(.all, 3)
                        .overlay(
                            Image(systemName: configuration.isOn ? "checkmark" : "xmark")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .font(Font.title.weight(.black))
                                .frame(width: 8, height: 8, alignment: .center)
                                .foregroundColor(configuration.isOn ? .green : .gray)
                        )
                        .offset(x: configuration.isOn ? 11 : -11, y: 0)
                        .animation(.linear(duration: 0.1), value: configuration.isOn)
                        
                ).cornerRadius(20)
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
    
}

#Preview("Custom Toggle",traits: .fixedLayout(width: 350, height: 300)) {
    @Previewable @State var isSelected: Bool = false
    VStack(spacing: 20) {
        Toggle("First Toggle", isOn: $isSelected)
            .toggleStyle(CheckmarkToggleStyle())
            .padding()
            .frame(width: 250)
        
        Toggle("Second Toggle (Inverse)", isOn: .init(
            get: { !isSelected },
            set: { isSelected = !$0 }
        ))
        .toggleStyle(CheckmarkToggleStyle())
        .padding()
        .frame(width: 250)
    }
    .padding()
}
