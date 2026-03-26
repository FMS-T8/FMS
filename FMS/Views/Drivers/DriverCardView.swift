import SwiftUI

// MARK: - DriverCardView

/// Directory list card. iOS 26 design: system background, custom thicker
/// progress bar via ZStack+GeometryReader geometry, colored left rail.
/// Entire card is tappable (wrapped in NavigationLink by parent).
struct DriverCardView: View {

  let driver: DriverDisplayItem
  let onCall: (() -> Void)?

  var body: some View {
    HStack(spacing: 0) {
      statusRail
      cardContent
    }
    .background(FMSTheme.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: - Left Status Rail

  private var statusRail: some View {
    RoundedRectangle(cornerRadius: 3, style: .continuous)
      .fill(railColor)
      .frame(width: 4)
      .padding(.vertical, 10)
  }

  // MARK: - Card Content

  private var cardContent: some View {
    VStack(alignment: .leading, spacing: 10) {
      DriverNameRow(name: driver.name, status: driver.availabilityStatus)

      Text("ID: \(driver.employeeID)")
        .font(.footnote)
        .foregroundStyle(FMSTheme.textSecondary)

      if shouldShowAssignedVehicle,
        let vName = driver.vehicleDisplayName,
        let plate = driver.plateNumber
      {
        VehicleRow(vehicleName: vName, plate: plate)
      }

      if shouldShowShiftProgress {
        ShiftProgressRow(label: driver.shiftProgressLabel, progress: driver.shiftProgress)
      }

      CallButton(action: onCall, phoneNumber: driver.phone)
    }
    .padding(.leading, 14)
    .padding(.trailing, 16)
    .padding(.vertical, 16)
  }

  private var railColor: Color {
    switch driver.availabilityStatus {
    case .available: return FMSTheme.alertGreen
    case .onTrip: return FMSTheme.amber
    case .offDuty: return FMSTheme.textTertiary
    }
  }

  private var shouldShowShiftProgress: Bool {
    driver.availabilityStatus == .onTrip
  }

  private var shouldShowAssignedVehicle: Bool {
    driver.availabilityStatus == .onTrip
  }
}

// MARK: - DriverShiftCardView

/// Shifts list card. Same iOS 26 pattern as DriverCardView.
struct DriverShiftCardView: View {

  let shift: ShiftDisplayItem
  let onTrack: (() -> Void)?

  var body: some View {
    HStack(spacing: 0) {
      statusRail
      cardContent
    }
    .background(FMSTheme.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var statusRail: some View {
    RoundedRectangle(cornerRadius: 3, style: .continuous)
      .fill(railColor)
      .frame(width: 4)
      .padding(.vertical, 10)
  }

  private var cardContent: some View {
    VStack(alignment: .leading, spacing: 10) {
      ShiftNameRow(name: shift.driverName, status: shift.status, label: shift.statusLabel)

      if let vName = shift.vehicleDisplayName, let plate = shift.plateNumber {
        VehicleRow(vehicleName: vName, plate: plate)
      }

      ShiftTimingRow(start: shift.shiftStart, end: shift.shiftEnd)
      ShiftProgressRow(label: shift.progressLabel, progress: shift.progress)

      TrackButton(action: onTrack)
    }
    .padding(.leading, 14)
    .padding(.trailing, 16)
    .padding(.vertical, 16)
  }

  private var railColor: Color {
    switch shift.status {
    case "on_duty": return FMSTheme.alertGreen
    case "break": return FMSTheme.amber
    case "not_started": return FMSTheme.textTertiary
    default: return FMSTheme.borderLight
    }
  }
}

// MARK: - Extracted Card Row Subviews
// Extracted as separate structs so SwiftUI can diff them independently
// without re-computing the entire card body on every state tick.

struct DriverNameRow: View {
  let name: String
  let status: DriverAvailabilityStatus

  var body: some View {
    HStack {
      Text(name)
        .font(.headline)
        .foregroundStyle(FMSTheme.textPrimary)
      Spacer(minLength: 8)
      StatusBadge(status: status)
    }
  }
}

private struct ShiftNameRow: View {
  let name: String
  let status: String
  let label: String

  var body: some View {
    HStack {
      Text(name)
        .font(.headline)
        .foregroundStyle(FMSTheme.textPrimary)
      Spacer(minLength: 8)
      ShiftStatusChip(status: status, label: label)
    }
  }
}

struct VehicleRow: View {
  let vehicleName: String
  let plate: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "truck.box.fill")
        .font(.caption)
        .foregroundStyle(FMSTheme.textTertiary)
      Text(vehicleName)
        .font(.subheadline)
        .foregroundStyle(FMSTheme.textSecondary)
      Text("·")
        .font(.caption)
        .foregroundStyle(FMSTheme.textTertiary)
      Text(plate)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(FMSTheme.textSecondary)
    }
  }
}

private struct ShiftTimingRow: View {
  let start: Date?
  let end: Date?

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "clock")
        .font(.caption)
        .foregroundStyle(FMSTheme.textTertiary)
      Text(formatted(start))
        .font(.subheadline)
        .foregroundStyle(FMSTheme.textSecondary)
      Image(systemName: "arrow.right")
        .font(.caption2)
        .foregroundStyle(FMSTheme.textTertiary)
      Text(formatted(end))
        .font(.subheadline)
        .foregroundStyle(FMSTheme.textSecondary)
    }
  }

  private func formatted(_ date: Date?) -> String {
    guard let d = date else { return "--" }
    let f = DateFormatter()
    f.dateFormat = "hh:mm a"
    return f.string(from: d)
  }
}

/// Thicker progress bar using a custom fill shape — avoids the
/// unreliable `scaleEffect` hack on ProgressView.
struct ShiftProgressRow: View {
  let label: String
  let progress: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("SHIFT PROGRESS")
          .font(.caption2.weight(.bold))
          .foregroundStyle(FMSTheme.textTertiary)
        Spacer()
        Text(label)
          .font(.caption.weight(.semibold))
          .foregroundStyle(FMSTheme.textPrimary)
      }
      ThickProgressBar(progress: progress, tint: FMSTheme.amber)
    }
  }
}

/// Custom 8pt tall progress bar drawn via GeometryReader.
private struct ThickProgressBar: View {
  let progress: Double
  let tint: Color

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(FMSTheme.pillBackground)
          .frame(height: 8)
        Capsule()
          .fill(tint)
          .frame(width: geo.size.width * max(0, min(1, progress)), height: 8)
          .animation(.easeInOut(duration: 0.3), value: progress)
      }
    }
    .frame(height: 8)
  }
}

private struct CallButton: View {
  let action: (() -> Void)?
  let phoneNumber: String?
  @Environment(\.openURL) var openURL

  private var validatedPhoneNumber: String? {
    guard let raw = phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty
    else {
      return nil
    }

    let lower = raw.lowercased()
    let placeholders = ["n/a", "na", "none", "null", "not available", "unknown", "-", "—"]
    guard !placeholders.contains(lower) else { return nil }

    let digitsCount = raw.filter(\.isNumber).count
    guard digitsCount >= 7 else { return nil }

    let allowed = CharacterSet(charactersIn: "+-(). 0123456789")
    guard raw.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }

    return raw
  }

  private var dialablePhoneNumber: String? {
    guard let validatedPhoneNumber else { return nil }
    let trimmed = validatedPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasLeadingPlus = trimmed.hasPrefix("+")
    let digitsOnly = trimmed.filter(\.isNumber)
    guard !digitsOnly.isEmpty else { return nil }
    return hasLeadingPlus ? "+\(digitsOnly)" : digitsOnly
  }

  private var hasPhone: Bool {
    validatedPhoneNumber != nil
  }

  private var canTrigger: Bool {
    hasPhone || action != nil
  }

  var body: some View {
    Button {
      if let dialablePhoneNumber, let url = URL(string: "tel:\(dialablePhoneNumber)") {
        openURL(url)
        return
      }
      action?()
    } label: {
      Label("Call", systemImage: "phone.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(FMSTheme.obsidian)
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(FMSTheme.amber, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .disabled(!canTrigger)
    .opacity(canTrigger ? 1.0 : 0.5)
  }
}

private struct TrackButton: View {
  let action: (() -> Void)?

  var body: some View {
    Button {
      action?()
    } label: {
      Label("Track", systemImage: "location.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(FMSTheme.obsidian)
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(FMSTheme.amber, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .disabled(action == nil)
    .opacity(action == nil ? 0.5 : 1.0)
  }
}

// MARK: - Shared Status Components

/// Pill badge for driver availability status.
struct StatusBadge: View {
  let status: DriverAvailabilityStatus

  var body: some View {
    Label(status.displayLabel.uppercased(), systemImage: "circle.fill")
      .font(.caption2.weight(.bold))
      .labelStyle(DotLabelStyle())
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .foregroundStyle(color)
      .background(color.opacity(0.12))
      .clipShape(Capsule())
  }

  private var color: Color {
    switch status {
    case .available: return FMSTheme.alertGreen
    case .onTrip: return FMSTheme.amber
    case .offDuty: return FMSTheme.textTertiary
    }
  }
}

/// Pill badge for shift status.
private struct ShiftStatusChip: View {
  let status: String
  let label: String

  var body: some View {
    Label(label.uppercased(), systemImage: "circle.fill")
      .font(.caption2.weight(.bold))
      .labelStyle(DotLabelStyle())
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .foregroundStyle(color)
      .background(color.opacity(0.12))
      .clipShape(Capsule())
  }

  private var color: Color {
    switch status {
    case "on_duty": return FMSTheme.alertGreen
    case "break": return FMSTheme.amber
    case "not_started": return FMSTheme.textTertiary
    default: return FMSTheme.textSecondary
    }
  }
}

/// Inline dot before label text.
private struct DotLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 4) {
      configuration.icon
        .font(.system(size: 5))
      configuration.title
    }
  }
}

/// Plain circle with initials — kept for DriverDetailView.
struct AvatarCircle: View {
  let initials: String
  let color: Color
  var size: CGFloat = 48

  var body: some View {
    ZStack {
      Circle().fill(color).frame(width: size, height: size)
      Text(initials)
        .font(.system(size: size * 0.33, weight: .semibold))
        .foregroundStyle(.white)
    }
  }
}
