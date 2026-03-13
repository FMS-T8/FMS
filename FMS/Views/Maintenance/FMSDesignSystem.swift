import SwiftUI

// ─────────────────────────────────────────────
// MARK: - FMSTheme helpers
// ─────────────────────────────────────────────

extension FMSTheme {
    /// Adaptive background
    static func bg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary
    }

    /// Adaptive card surface
    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 28/255, green: 28/255, blue: 30/255)
            : FMSTheme.cardBackground
    }
}

// ─────────────────────────────────────────────
// MARK: - Shared Filter Bar
// ─────────────────────────────────────────────

struct FMSFilterBar: View {
    let tabs: [String]
    @Binding var selected: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            selected = tab
                        }
                    } label: {
                        Text(tab)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selected == tab ? .black : FMSTheme.textSecondary)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(
                                Capsule().fill(selected == tab
                                               ? FMSTheme.amber
                                               : Color.gray.opacity(0.12))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(FMSTheme.card(colorScheme))
    }
}

// ─────────────────────────────────────────────
// MARK: - Title Row  (title + search + amber +)
// ─────────────────────────────────────────────

/// Inline content-level header: large bold title on the left,
/// search icon + amber plus capsule on the right.
/// Profile lives in the system nav bar (FMSDashboardToolbar).
struct FMSTitleRow: View {
    let title: String
    var onSearch: (() -> Void)? = nil
    var onAdd: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)

            Spacer()

            if let onSearch {
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                }
            }

            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(FMSTheme.amber)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
}


// ─────────────────────────────────────────────
// MARK: - Shared Toolbars
// ─────────────────────────────────────────────

/// Reusable amber profile button
struct FMSProfileButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(FMSTheme.amber.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(FMSTheme.amberDark)
            }
        }
    }
}

/// Dashboard toolbar: profile icon only (trailing)
struct FMSDashboardToolbar: ToolbarContent {
    @Binding var showingProfile: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            FMSProfileButton { showingProfile = true }
        }
    }
}

/// Secondary pages toolbar: profile + search + plus, all in one trailing group
struct FMSNavToolbar: ToolbarContent {
    @Binding var showingCreate: Bool
    @Binding var showingProfile: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 10) {
                FMSProfileButton { showingProfile = true }

                Button { } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                }
                .tint(.primary)

                Button { showingCreate = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(FMSTheme.amber)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

/// Legacy toolbar kept for backward compat
struct FMSToolbar: ToolbarContent {
    @Binding var showingCreate: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                Button { } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                }
                .tint(.primary)

                Button { showingCreate = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(FMSTheme.amber)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Priority Badge
// ─────────────────────────────────────────────

struct FMSPriorityBadge: View {
    let priority: WOPriority

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(priority.tint).frame(width: 6, height: 6)
            Text(priority.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(priority.tint)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(priority.bg)
        .clipShape(Capsule())
    }
}

// ─────────────────────────────────────────────
// MARK: - Stat Card  (Dashboard)
// ─────────────────────────────────────────────

struct FMSStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.13))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(FMSTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(FMSTheme.card(colorScheme)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// ─────────────────────────────────────────────
// MARK: - Section Label
// ─────────────────────────────────────────────

struct FMSSectionLabel: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(FMSTheme.textTertiary)
                .tracking(0.8)
            Spacer()
            if let t = trailing {
                Text(t).font(.caption).foregroundColor(FMSTheme.alertOrange)
            }
        }
    }
}
