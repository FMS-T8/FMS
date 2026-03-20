//
//  View+GlassEffect.swift
//  FMS
//
//  Created by Anish on 12/03/26.
//

import Foundation
import SwiftUI

public extension View {
    @ViewBuilder
    func fmsGlassEffect(
        cornerRadius: CGFloat = 32,
        fallbackMaterial: Material = .ultraThinMaterial
    ) -> some View {
        self.background(fallbackMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}
