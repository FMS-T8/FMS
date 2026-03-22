import SwiftUI
import UIKit

struct SOSFloatingButton: View {
    let onTrigger: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    private let haptic = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        Button {
            haptic.impactOccurred()
            onTrigger()
        } label: {
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(FMSTheme.alertRed.opacity(0.3), lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - Double(pulseScale))

                // Button background
                Circle()
                    .fill(FMSTheme.alertRed)
                    .frame(width: 60, height: 60)
                    .shadow(color: FMSTheme.alertRed.opacity(0.5), radius: 6)

                VStack(spacing: 1) {
                    Image(systemName: "sos")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)

                    Text("SOS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            haptic.prepare()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
}

#Preview {
    ZStack {
        FMSTheme.backgroundPrimary.ignoresSafeArea()
        SOSFloatingButton(onTrigger: {})
    }
}
