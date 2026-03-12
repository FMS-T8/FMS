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
    .background(Color(.secondarySystemGroupedBackground))
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
        .foregroundStyle(Color(.secondaryLabel))

      if let vName = driver.vehicleDisplayName, let plate = driver.plateNumber {
        VehicleRow(vehicleName: vName, plate: plate)
      }

      if driver.shiftStart != nil {
        ShiftProgressRow(label: driver.shiftProgressLabel, progress: driver.shiftProgress)
      }

      CallButton(action: onCall)
    }
    .padding(.leading, 14)
    .padding(.trailing, 16)
    .padding(.vertical, 16)
  }

  private var railColor: Color {
    switch driver.availabilityStatus {
    case .available: return FMSTheme.alertGreen
    case .onTrip: return FMSTheme.amber
    case .offDuty: return Color(.tertiaryLabel)
    }
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
    .background(Color(.secondarySystemGroupedBackground))
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
    case "not_started": return Color(.tertiaryLabel)
    default: return Color(.separator)
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
        .foregroundStyle(Color(.label))
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
        .foregroundStyle(Color(.label))
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
        .foregroundStyle(Color(.tertiaryLabel))
      Text(vehicleName)
        .font(.subheadline)
        .foregroundStyle(Color(.secondaryLabel))
      Text("·")
        .font(.caption)
        .foregroundStyle(Color(.tertiaryLabel))
      Text(plate)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Color(.secondaryLabel))
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
        .foregroundStyle(Color(.tertiaryLabel))
      Text(formatted(start))
        .font(.subheadline)
        .foregroundStyle(Color(.secondaryLabel))
      Image(systemName: "arrow.right")
        .font(.caption2)
        .foregroundStyle(Color(.tertiaryLabel))
      Text(formatted(end))
        .font(.subheadline)
        .foregroundStyle(Color(.secondaryLabel))
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
          .foregroundStyle(Color(.tertiaryLabel))
        Spacer()
        Text(label)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color(.label))
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
          .fill(Color(.systemFill))
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

  var body: some View {
    Button {
      action?()
    } label: {
      Label("Call", systemImage: "phone.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color(.systemBackground))
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(FMSTheme.amber, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .disabled(action == nil)
    .opacity(action == nil ? 0.5 : 1.0)
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
        .foregroundStyle(Color(.systemBackground))
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
    case .offDuty: return Color(.tertiaryLabel)
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
    case "not_started": return Color(.tertiaryLabel)
    default: return Color(.secondaryLabel)
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
