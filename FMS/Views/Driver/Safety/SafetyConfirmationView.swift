import SwiftUI

struct SafetyConfirmationView: View {
    @Bindable var safetyViewModel: SafetyViewModel
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                warningIcon
                titleSection
                timerSection
                actionButtons

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
    }

    // MARK: - Warning Icon

    private var warningIcon: some View {
        ZStack {
            Circle()
                .fill(FMSTheme.alertRed.opacity(0.15))
                .frame(width: 120, height: 120)
                .scaleEffect(pulseScale)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(FMSTheme.alertRed)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("Impact Detected")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            Text("Are you okay?")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        VStack(spacing: 6) {
            Text("\(secondsRemaining)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(FMSTheme.alertRed)
                .contentTransition(.numericText())

            Text("Auto-SOS if no response")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button {
                safetyViewModel.driverConfirmedOK()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                    Text("I'm OK")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(FMSTheme.obsidian)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(FMSTheme.alertGreen)
                .cornerRadius(16)
            }

            Button {
                safetyViewModel.driverNeedsHelp()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sos")
                        .font(.system(size: 20, weight: .bold))
                    Text("I Need Help")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(FMSTheme.alertRed)
                .cornerRadius(16)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Computed

    private var secondsRemaining: Int {
        if case .awaitingConfirmation(let s) = safetyViewModel.flowState { return s }
        return 30
    }
}
