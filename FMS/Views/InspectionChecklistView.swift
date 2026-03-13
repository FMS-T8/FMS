import SwiftUI
import PhotosUI

// MARK: - Main Inspection View

public struct InspectionChecklistView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: InspectionViewModel
    private let onCompletion: (() -> Void)?

    public init(
        type: InspectionType = .preTrip,
        vehicleId: String = "VH-001",
        driverId: String = "DR-001",
        onCompletion: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: InspectionViewModel(vehicleId: vehicleId, driverId: driverId, type: type))
        self.onCompletion = onCompletion
    }

    public var body: some View {
        Group {
            if viewModel.isCompleted {
                InspectionCompleteView(viewModel: viewModel)
            } else {
                checklistContent
            }
        }
    }

    // MARK: - Checklist Content

    private var checklistContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    progressHeader
                    itemsList
                    continueButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(FMSTheme.backgroundPrimary)
            .navigationTitle("Vehicle Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FMSTheme.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Inspection Progress")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)
                Spacer()
                Text("\(viewModel.checklist.completedCount) / \(viewModel.checklist.totalCount) steps")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FMSTheme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(FMSTheme.borderLight)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(FMSTheme.amber)
                        .frame(width: geo.size.width * viewModel.checklist.progress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.checklist.progress)
                }
            }
            .frame(height: 8)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Items List

    private var itemsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(viewModel.checklist.items.enumerated()), id: \.element.id) { index, item in
                InspectionItemCard(
                    item: item,
                    isExpanded: viewModel.expandedItemId == item.id,
                    onToggle: { viewModel.toggleItem(at: index) },
                    onToggleExpand: { viewModel.toggleExpanded(for: item.id) },
                    onNotesChanged: { viewModel.updateNotes(at: index, notes: $0) },
                    onPhotoSelected: { viewModel.setPhoto(at: index, data: $0) },
                    onRemovePhoto: { viewModel.removePhoto(at: index) }
                )
            }
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            viewModel.completeInspection()
            onCompletion?()
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.headline.weight(.bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .buttonStyle(.fmsPrimary)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
}

// MARK: - Inspection Item Card

struct InspectionItemCard: View {
    let item: InspectionItem
    let isExpanded: Bool
    let onToggle: () -> Void
    let onToggleExpand: () -> Void
    let onNotesChanged: (String) -> Void
    let onPhotoSelected: (Data) -> Void
    let onRemovePhoto: () -> Void

    @State private var localNotes: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @FocusState private var notesFieldFocused: Bool

    private var hasCriticalIssue: Bool {
        !item.passed && (!item.notes.isEmpty || item.photoData != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if isExpanded {
                expandedContent
            } else if !hasCriticalIssue {
                collapsedActions
            }

            if hasCriticalIssue && !isExpanded {
                criticalBanner
            }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(hasCriticalIssue ? FMSTheme.alertRed.opacity(0.5) : FMSTheme.borderLight, lineWidth: hasCriticalIssue ? 1.5 : 1)
        )
        .onAppear {
            localNotes = item.notes
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    onPhotoSelected(data)
                }
                pickerItem = nil
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Button(action: onToggleExpand) {
                HStack(spacing: 8) {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(hasCriticalIssue ? FMSTheme.alertRed : FMSTheme.amber)

                    Text(item.category.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Toggle("", isOn: Binding(
                get: { item.passed },
                set: { _ in onToggle() }
            ))
            .tint(FMSTheme.amber)
            .labelsHidden()
        }
    }

    // MARK: - Collapsed Actions

    private var collapsedActions: some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Add Photo", systemImage: "camera")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(8)
            }

            Button {
                onToggleExpand()
            } label: {
                Label("Add Note", systemImage: "text.justify.leading")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasCriticalIssue {
                criticalBanner
            }

            // Photo section
            if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button(action: onRemovePhoto) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
            }

            // Notes
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FMSTheme.textSecondary)

                TextField("Add inspection notes...", text: $localNotes, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(3...6)
                    .padding(12)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(10)
                    .focused($notesFieldFocused)
                    .onChange(of: localNotes) { _, newValue in
                        onNotesChanged(newValue)
                    }
            }

            // Photo picker button
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(item.photoData != nil ? "Update Photo" : "Add Photo", systemImage: "camera")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FMSTheme.obsidian)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(FMSTheme.amber.opacity(0.15))
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Critical Banner

    private var criticalBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMSTheme.alertRed)

            Text("Critical: \(item.category.criticalMessage)")
                .font(.system(size: 13))
                .foregroundStyle(FMSTheme.alertRed)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMSTheme.alertRed.opacity(0.08))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("Pre-trip Inspection") {
    InspectionChecklistView(type: .preTrip)
}

#Preview("Post-trip Inspection") {
    InspectionChecklistView(type: .postTrip)
}
