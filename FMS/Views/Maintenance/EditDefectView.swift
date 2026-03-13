import SwiftUI

struct EditDefectView: View {
    @Binding var defect: DefectItem
    let store: DefectStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var title       = ""
    @State private var vehicle     = ""
    @State private var description = ""
    @State private var priority    = DefectItem.Priority.medium

    let categories = ["mechanical", "electrical", "tyres", "brakes", "body", "other"]
    @State private var category = "mechanical"

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.bg(colorScheme).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        EDCard {
                            VStack(alignment: .leading, spacing: 16) {
                                EDField(label: "TITLE", placeholder: "e.g. Tyre Puncture", text: $title, icon: "exclamationmark.triangle.fill")
                                Divider().opacity(0.4)
                                EDField(label: "VEHICLE", placeholder: "e.g. Truck #402", text: $vehicle, icon: "box.truck")
                            }
                        }

                        EDCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("CATEGORY").font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(categories, id: \.self) { cat in
                                            Button { withAnimation { category = cat } } label: {
                                                Text(cat).font(.system(size: 13, weight: .semibold))
                                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                                    .background(category == cat ? FMSTheme.amber : Color.gray.opacity(0.1))
                                                    .foregroundColor(category == cat ? .black : FMSTheme.textSecondary)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        EDCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("PRIORITY").font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                HStack(spacing: 8) {
                                    ForEach(DefectItem.Priority.allCases, id: \.self) { p in
                                        Button { withAnimation { priority = p } } label: {
                                            Text(p.displayLabel).font(.system(size: 11, weight: .semibold))
                                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                                .background(priority == p ? p.color : Color.gray.opacity(0.1))
                                                .foregroundColor(priority == p ? .white : FMSTheme.textSecondary)
                                                .cornerRadius(9)
                                        }
                                    }
                                }
                                Divider().opacity(0.4)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DESCRIPTION").font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    ZStack(alignment: .topLeading) {
                                        TextEditor(text: $description)
                                            .frame(minHeight: 80).padding(10)
                                            .background(Color.gray.opacity(0.08)).cornerRadius(10)
                                        if description.isEmpty {
                                            Text("Add details…").font(.system(size: 14))
                                                .foregroundColor(FMSTheme.textTertiary)
                                                .padding(.horizontal, 14).padding(.vertical, 18)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            guard !title.isEmpty, !vehicle.isEmpty else { return }
                            defect.title       = title
                            defect.vehicle     = vehicle
                            defect.category    = category
                            defect.priority    = priority
                            defect.description = description
                            Task {
                                try? await store.updateDefect(defect)
                                await MainActor.run { dismiss() }
                            }
                        } label: {
                            Text("Save Changes").font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(FMSTheme.amber).cornerRadius(14)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Edit Defect").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(FMSTheme.textSecondary)
                }
            }
            .onAppear {
                title = defect.title; vehicle = defect.vehicle
                description = defect.description; priority = defect.priority; category = defect.category
            }
        }
    }
}

private struct EDCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(FMSTheme.card(colorScheme)).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
    }
}

private struct EDField: View {
    let label: String; let placeholder: String; @Binding var text: String; let icon: String
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundColor(FMSTheme.amberDark).font(.system(size: 15))
                TextField(placeholder, text: $text).font(.system(size: 15))
                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
            }
            .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
        }
    }
}
