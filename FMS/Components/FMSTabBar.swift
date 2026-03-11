import SwiftUI

public struct FMSTabItem<Content: View>: Identifiable {
    public let id: String
    public let title: String
    public let icon: String
    public let content: () -> Content
    
    public init(_ title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.id = title
        self.title = title
        self.icon = icon
        self.content = content
    }
}

/// A role-agnostic tab shell that wraps the native `TabView`.
/// Each role provides its own set of `FMSTabItem`s — the shell handles
/// tinting and the system liquid glass tab bar on iOS 26+.
///
public struct FMSTabShell: View {
    private let tabs: [FMSTabItem<AnyView>]
    
    public init<each V: View>(@FMSTabBuilder _ builder: () -> (repeat FMSTabItem<each V>)) {
        let built = builder()
        var items: [FMSTabItem<AnyView>] = []
        repeat items.append((each built).erased())
        self.tabs = items
    }
    
    public var body: some View {
        TabView {
            ForEach(tabs) { tab in
                Tab(tab.title, systemImage: tab.icon) {
                    tab.content()
                }
            }
        }
        .tint(FMSTheme.amber)
    }
}

// MARK: - Type Erasure Helper

extension FMSTabItem {
    func erased() -> FMSTabItem<AnyView> {
        FMSTabItem<AnyView>(title, icon: icon) {
            AnyView(content())
        }
    }
}

// MARK: - Result Builder

@resultBuilder
public struct FMSTabBuilder {
    public static func buildBlock<each V: View>(_ tabs: repeat FMSTabItem<each V>) -> (repeat FMSTabItem<each V>) {
        (repeat each tabs)
    }
}
