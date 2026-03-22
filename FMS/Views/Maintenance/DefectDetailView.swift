import SwiftUI

@MainActor
struct DefectDetailView: View {
    @State private var defect: DefectItem
    let store: DefectStore
    let woStore: WorkOrderStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    init(defect: DefectItem, store: DefectStore, woStore: WorkOrderStore) {
        self._defect = State(initialValue: defect)
        self.store = store
        self.woStore = woStore
    }

    @State private var showingEdit        = false
    @State private var showingDeleteAlert = false
    @State private var showingCreateWO    = false
    @State private var deleteErrorMessage: String? = nil
    @State private var showingDeleteError = false

    private var cardBg: Color {
        colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary).ignoresSafeArea()

            VStack(spacing: 0) {

                // Custom nav bar
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(defect.title)
                            .font(.headline.weight(.bold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            .lineLimit(1)
                        Text(defect.vehicleDisplay)
                            .font(.caption)
                            .foregroundColor(FMSTheme.textSecondary)
                    }
                    Spacer()
                    Text(defect.priority.displayLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(defect.priority.color)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(defect.priority.color.opacity(0.12))
                        .clipShape(Capsule())
                    Button { showingEdit = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.cardBackground)

                Divider().opacity(0.4)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Photo gallery or hero icon
                        if let urls = defect.imageUrls, !urls.isEmpty {
                            DefectPhotoGallery(imageUrls: urls)
                                .padding(.horizontal, 16)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(defect.priority.color.opacity(0.08))
                                    .frame(height: 140)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(defect.priority.color.opacity(0.2), lineWidth: 1))
                                Image(systemName: defect.imageName)
                                    .font(.system(size: 56))
                                    .foregroundColor(defect.priority.color)
                            }
                            .padding(.horizontal, 16)
                        }

                        // Stat row
                        HStack(spacing: 12) {
                            DDStatCard(title: "Category", value: defect.category,
                                       icon: "tag.fill", color: FMSTheme.amberDark)
                            DDStatCard(title: "Reported", value: defect.reportedAgo,
                                       icon: "clock.fill", color: FMSTheme.textSecondary)
                            DDStatCard(title: "Status",
                                       value: defect.linkedWorkOrderId == nil ? "Open" : "W/O Raised",
                                       icon: "checkmark.shield.fill",
                                       color: defect.linkedWorkOrderId == nil ? FMSTheme.alertOrange : FMSTheme.alertGreen)
                        }
                        .padding(.horizontal, 16)

                        // Reported by
                        if let reporter = defect.reportedBy, !reporter.isEmpty {
                            DDCard {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(FMSTheme.amber)
                                        .frame(width: 36, height: 36)
                                        .background(FMSTheme.amber.opacity(0.12))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("REPORTED BY")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(FMSTheme.textTertiary)
                                            .tracking(0.6)
                                        Text(reporter)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Description card
                        DDCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DESCRIPTION")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                Text(defect.description.isEmpty ? "No description provided." : defect.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : FMSTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Linked Work Order badge (if any)
                        if let woId = defect.linkedWorkOrderId {
                            DDCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("LINKED WORK ORDER")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(FMSTheme.amber.opacity(0.12))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(FMSTheme.amberDark)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(woId)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                            Text("Work Order")
                                                .font(.caption)
                                                .foregroundColor(FMSTheme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(FMSTheme.alertGreen)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer().frame(height: 8)
                    }
                    .padding(.top, 16).padding(.bottom, 28)
                }

                // Bottom actions
                VStack(spacing: 0) {
                    Divider().opacity(0.4)
                    HStack(spacing: 12) {
                        Button { showingDeleteAlert = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(FMSTheme.alertRed)
                                .frame(width: 50, height: 50)
                                .background(FMSTheme.alertRed.opacity(0.08))
                                .cornerRadius(12)
                        }
                        if defect.linkedWorkOrderId == nil {
                            Button { showingCreateWO = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil.and.list.clipboard").font(.system(size: 16))
                                    Text("Create Work Order").font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FMSTheme.amber)
                                .cornerRadius(12)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 16))
                                Text("Work Order Raised").font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(FMSTheme.alertGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(FMSTheme.alertGreen.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEdit) {
            EditDefectView(defect: $defect, store: store)
        }
        .sheet(isPresented: $showingCreateWO) {

            CreateWorkOrderView(prefillVehicle: defect.vehicleId) { newWO in
                let insertedWO = try await woStore.addItem(WOItem(from: newWO))
                do {
                    try await store.linkWorkOrder(defectId: defect.id, workOrderId: insertedWO.id)
                    await MainActor.run {
                        defect.linkedWorkOrderId = insertedWO.id
                        defect.status = "in_progress"
                    }
                } catch {
                    print("Error linking WO \(insertedWO.id) to defect \(defect.id). Rolling back...")
                    do {
                        try await woStore.delete(id: insertedWO.id)
                    } catch let deleteError {
                        print("CRITICAL: Failed to rollback orphaned WO \(insertedWO.id). Error: \(deleteError)")
                    }
                    throw error
                }
            }
        }
        .alert("Delete Defect", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await store.deleteDefect(id: defect.id)
                        await MainActor.run { dismiss() }
                    } catch {
                        await MainActor.run {
                            deleteErrorMessage = error.localizedDescription
                            showingDeleteError = true
                        }
                    }
                }
            }
        } message: {
            Text("Remove \"\(defect.title)\"? This cannot be undone.")
        }
        .alert("Error Deleting", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "An unknown error occurred.")
        }
    }
}

// MARK: - Helpers
private struct DDCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Photo Gallery

private struct DefectPhotoGallery: View {
    let imageUrls: [String]
    @State private var selectedIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FMSTheme.textTertiary)
                Text("\(imageUrls.count) Photo\(imageUrls.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FMSTheme.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlStr in
                        if let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 140, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .onTapGesture { selectedIndex = index }
                                case .failure:
                                    photoPlaceholder(icon: "exclamationmark.triangle")
                                case .empty:
                                    photoPlaceholder(icon: "photo")
                                        .overlay(ProgressView().tint(.white))
                                @unknown default:
                                    photoPlaceholder(icon: "photo")
                                }
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: Binding(
            get: { selectedIndex.map { SelectedPhoto(index: $0) } },
            set: { selectedIndex = $0?.index }
        )) { selected in
            DefectPhotoFullScreen(imageUrls: imageUrls, initialIndex: selected.index)
        }
    }

    private func photoPlaceholder(icon: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.15))
            .frame(width: 140, height: 140)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(FMSTheme.textTertiary)
            )
    }
}

private struct SelectedPhoto: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Full Screen Photo Viewer

private struct DefectPhotoFullScreen: View {
    let imageUrls: [String]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlStr in
                    if let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure:
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white.opacity(0.5))
                            case .empty:
                                ProgressView().tint(.white)
                            @unknown default:
                                ProgressView().tint(.white)
                            }
                        }
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .padding(20)
                }
                Spacer()

                // Counter
                Text("\(currentIndex + 1) / \(imageUrls.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
        }
        .onAppear { currentIndex = initialIndex }
    }
}

private struct DDStatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(value).font(.system(size: 13, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary).lineLimit(1)
            Text(title).font(.system(size: 10, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground)
        .cornerRadius(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
    }
}
