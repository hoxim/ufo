//
//  UfoBackground.swift
//  ufo
//
//  Created by Marcin Ryzko on 26/02/2026.
//

import SwiftUI

struct UfoGradientBackground<Content: View>: View {
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.backgroundTopGradient,
                    Color.backgroundMiddleGradient,
                    Color.backgroundBottomGradient
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            content
        }
    }
}
