import SwiftUI
import Observation

@MainActor
@Observable
public class InspectionViewModel {
    private static let reportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, HH:mm"
        return formatter
    }()

    private static let exportTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return formatter
    }()

    private static let invalidFileNameCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")

    public var checklist: InspectionChecklist
    public var isCompleted: Bool = false
    public var showingCamera: Bool = false
    public var expandedItemId: String?
    public var showingExportSheet: Bool = false
    public var exportURL: URL?
    public var exportErrorMessage: String?

    public init(vehicleId: String = "VH-001", driverId: String = "DR-001", type: InspectionType = .preTrip) {
        self.checklist = InspectionChecklist(vehicleId: vehicleId, driverId: driverId, type: type)
    }

    // MARK: - Item Actions

    public func toggleItem(at index: Int) {
        guard checklist.items.indices.contains(index) else { return }
        checklist.items[index].passed.toggle()
    }

    public func updateNotes(at index: Int, notes: String) {
        guard checklist.items.indices.contains(index) else { return }
        checklist.items[index].notes = notes
    }

    public func setPhoto(at index: Int, data: Data?) {
        guard checklist.items.indices.contains(index) else { return }
        checklist.items[index].photoData = data
    }

    public func removePhoto(at index: Int) {
        guard checklist.items.indices.contains(index) else { return }
        checklist.items[index].photoData = nil
    }

    public func toggleExpanded(for itemId: String) {
        if expandedItemId == itemId {
            expandedItemId = nil
        } else {
            expandedItemId = itemId
        }
    }

    // MARK: - Completion

    public func completeInspection() {
        checklist.completedAt = Date()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isCompleted = true
        }
    }

    public var vehicleStatus: String {
        checklist.allPassed ? "Ready" : "Needs Attention"
    }

    // MARK: - Export

    public func prepareExport(includeTimestamp: Bool) {
        let data = generateReport()

        guard let url = saveReportToTemp(data: data, checklist: checklist, includeTimestamp: includeTimestamp) else {
            exportURL = nil
            showingExportSheet = false
            exportErrorMessage = "Unable to create an inspection report to share. Please try again."
            return
        }

        exportURL = url
        exportErrorMessage = nil
        showingExportSheet = true
    }

    public func clearExportState() {
        showingExportSheet = false
        exportURL = nil
    }

    public func clearExportError() {
        exportErrorMessage = nil
    }

    // MARK: - PDF Report Generation

    public func generateReport() -> Data {
        let checklist = self.checklist
        var report = """
        ══════════════════════════════════════════════
                    FMS VEHICLE INSPECTION REPORT
        ══════════════════════════════════════════════

        Type:           \(checklist.inspectionType.rawValue) Inspection
        Vehicle ID:     \(checklist.vehicleId)
        Driver ID:      \(checklist.driverId)
        Date:           \(formattedDate(checklist.createdAt))
        Completed:      \(checklist.completedAt.map { formattedDate($0) } ?? "In Progress")
        Status:         \(vehicleStatus)
        Progress:       \(checklist.completedCount) / \(checklist.totalCount) items passed

        ──────────────────────────────────────────────
        INSPECTION ITEMS
        ──────────────────────────────────────────────

        """

        for item in checklist.items {
            let status = item.passed ? "✅ PASS" : "❌ FAIL"
            report += """
            \(item.category.rawValue): \(status)
            """
            if !item.notes.isEmpty {
                report += """

                Notes: \(item.notes)
                """
            }
            if item.photoData != nil {
                report += """

                📷 Photo attached
                """
            }
            report += "\n\n"
        }

        if !checklist.overallNotes.isEmpty {
            report += """
            ──────────────────────────────────────────────
            OVERALL NOTES
            ──────────────────────────────────────────────
            \(checklist.overallNotes)

            """
        }

        let failedItems = checklist.failedItems
        if !failedItems.isEmpty {
            report += """
            ──────────────────────────────────────────────
            ⚠️  ITEMS REQUIRING ATTENTION
            ──────────────────────────────────────────────

            """
            for item in failedItems {
                report += "  • \(item.category.rawValue)"
                if !item.notes.isEmpty {
                    report += " — \(item.notes)"
                }
                report += "\n"
            }
        }

        report += """

        ══════════════════════════════════════════════
        Generated by FMS • \(formattedDate(Date()))
        ══════════════════════════════════════════════
        """

        return Data(report.utf8)
    }

    private func saveReportToTemp(data: Data, checklist: InspectionChecklist, includeTimestamp: Bool) -> URL? {
        var components = ["FMS_Inspection", checklist.inspectionType.rawValue, checklist.vehicleId]
        if includeTimestamp {
            components.append(formatFileDate())
        }

        let fileName = components
            .map(sanitizedFileComponent)
            .joined(separator: "_") + ".txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func formatFileDate() -> String {
        Self.exportTimestampFormatter.string(from: Date())
    }

    func formattedDate(_ date: Date) -> String {
        Self.reportDateFormatter.string(from: date)
    }

    private func sanitizedFileComponent(_ component: String) -> String {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacedInvalidCharacters = String(trimmed.unicodeScalars.map { scalar in
            Self.invalidFileNameCharacters.contains(scalar) ? "_" : Character(scalar)
        })
        let collapsedWhitespace = replacedInvalidCharacters.replacingOccurrences(
            of: "\\s+",
            with: "_",
            options: .regularExpression
        )
        let collapsedUnderscores = collapsedWhitespace.replacingOccurrences(
            of: "_+",
            with: "_",
            options: .regularExpression
        )
        let sanitized = collapsedUnderscores.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return sanitized.isEmpty ? "unknown" : sanitized
    }
}
