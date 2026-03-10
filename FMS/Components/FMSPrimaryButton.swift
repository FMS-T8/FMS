import SwiftUI

public struct FMSPrimaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundColor(FMSTheme.obsidian)
            .padding()
            .frame(maxWidth: .infinity)
            .background(FMSTheme.amber)
            .cornerRadius(16)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == FMSPrimaryButtonStyle {
    static var fmsPrimary: FMSPrimaryButtonStyle { .init() }
}
