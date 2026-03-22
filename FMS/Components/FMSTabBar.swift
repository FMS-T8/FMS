import SwiftUI

/// A reusable tab definition for FMSTabShell.
public struct FMSTabItem<Content: View>: Identifiable {
    public let id: String
    public let title: String
    public let icon: String
    public let content: () -> Content

    /// Creates a new FMSTabItem.
    public init(id: String, title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.title = title
        self.icon = icon
        self.content = content
    }
}

/// A role-based tab shell that wraps the native `TabView`.
/// Each role provides its own set of `FMSTabItem`s — the shell handles
/// tinting and the system liquid glass tab bar on iOS 26+.
///
public struct FMSTabShell: View {
    private let tabs: [FMSTabItem<AnyView>]

    /// Creates a new FMSTabShell with the given tab items.
    public init<each V: View>(@FMSTabBuilder _ builder: () -> (repeat FMSTabItem<each V>)) {
        let built = builder()
        var items: [FMSTabItem<AnyView>] = []
        repeat items.append((each built).erased())
        self.tabs = items
    }

    public var body: some View {
        let tabViews = ForEach(tabs) { tab in
            tab.content()
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
        }
        
        return TabView {
            tabViews
        }
        .tint(FMSTheme.amber)
    }
}

// MARK: - Type Erasure Helper

extension FMSTabItem {
    /// Type-erases the content view to AnyView for use in heterogeneous tab arrays.
    func erased() -> FMSTabItem<AnyView> {
        FMSTabItem<AnyView>(id: id, title: title, icon: icon) {
            AnyView(content())
        }
    }
}

// MARK: - Result Builder

/// Result builder for FMSTabItem definitions.
@resultBuilder
public struct FMSTabBuilder {
    /// Builds a tuple of FMSTabItems for use in FMSTabShell.
    public static func buildBlock<each V: View>(_ tabs: repeat FMSTabItem<each V>) -> (repeat FMSTabItem<each V>) {
        (repeat each tabs)
    }
}
