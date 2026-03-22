import SwiftUI

struct SOSCountdownView: View {
    @Bindable var viewModel: SOSViewModel
    let onSOSSent: () -> Void
    let onCancelled: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                countdownCircle
                statusText

                if viewModel.sendFailed {
                    offlineWarning
                }

                // iPhone SOS prompt — shown after alert is sent
                if case .active = viewModel.state {
                    iPhoneSOSPrompt

                    // Acknowledgment status from fleet manager
                    if viewModel.isAcknowledged {
                        acknowledgedBanner
                    }

                    if viewModel.isResolved {
                        resolvedBanner
                    }
                }

                actionButtons

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            viewModel.startCountdown()
        }
        .onChange(of: viewModel.state) { _, newState in
            if case .active = newState {
                onSOSSent()
            }
        }
    }

    // MARK: - Countdown Circle

    private var countdownCircle: some View {
        ZStack {
            Circle()
                .stroke(FMSTheme.alertRed.opacity(0.2), lineWidth: 6)
                .frame(width: 180, height: 180)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(FMSTheme.alertRed, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            VStack(spacing: 4) {
                if case .sending = viewModel.state {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else {
                    Text("\(secondsRemaining)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(FMSTheme.alertRed)
                        .contentTransition(.numericText())

                    Text("seconds")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Status Text

    private var statusText: some View {
        VStack(spacing: 8) {
            Text(statusTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text(statusSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Offline Warning

    private var offlineWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMSTheme.alertOrange)
            Text("No connection — alert queued for delivery")
                .font(.system(size: 13))
                .foregroundStyle(FMSTheme.alertOrange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(FMSTheme.alertOrange.opacity(0.15))
        .cornerRadius(10)
    }

    // MARK: - iPhone SOS Prompt

    private var iPhoneSOSPrompt: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "phone.badge.waveform.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FMSTheme.amber)

                Text("Need emergency services?")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Hold the **side button + volume button** for 2 seconds to activate iPhone Emergency SOS")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Acknowledgment Banners

    private var acknowledgedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMSTheme.alertGreen)
            Text("Fleet manager is aware of your emergency")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FMSTheme.alertGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(FMSTheme.alertGreen.opacity(0.12))
        .cornerRadius(10)
    }

    private var resolvedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMSTheme.alertGreen)
            Text("SOS resolved by fleet manager")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FMSTheme.alertGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(FMSTheme.alertGreen.opacity(0.12))
        .cornerRadius(10)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if case .active = viewModel.state {
                // Cancel SOS (driver-initiated)
                Button {
                    viewModel.cancelSOS()
                    onCancelled()
                } label: {
                    Text("Cancel SOS")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FMSTheme.alertRed)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 12)
                        .background(FMSTheme.alertRed.opacity(0.15))
                        .cornerRadius(14)
                }

                // Done / dismiss
                Button {
                    viewModel.deactivateSOS()
                    onCancelled()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.15))
                        .cornerRadius(14)
                }
            } else {
                // During countdown — cancel
                Button {
                    viewModel.cancelCountdown()
                    onCancelled()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.15))
                        .cornerRadius(14)
                }
            }
        }
    }

    // MARK: - Computed

    private var secondsRemaining: Int {
        if case .countdown(let s) = viewModel.state { return s }
        return 0
    }

    private var progress: CGFloat {
        CGFloat(secondsRemaining) / CGFloat(10)
    }

    private var statusTitle: String {
        switch viewModel.state {
        case .sending: return "Sending SOS..."
        case .active: return viewModel.sendFailed ? "SOS Queued" : "SOS Alert Sent"
        default: return "SOS Alert Sending"
        }
    }

    private var statusSubtitle: String {
        switch viewModel.state {
        case .sending: return "Contacting fleet manager..."
        case .active where viewModel.sendFailed:
            return "Alert will be delivered when connection is restored"
        case .active:
            return "Your fleet manager has been notified"
        default:
            return "Emergency alert will be sent to your fleet manager"
        }
    }

}
