import SwiftUI

public enum BannerType {
    case error
    case warning
    case success
}

public struct BannerItem: Equatable {
    public let id: UUID
    public let type: BannerType
    public let message: String
    
    public init(type: BannerType, message: String) {
        self.id = UUID()
        self.type = type
        self.message = message
    }
}

@Observable
public class BannerManager {
    public var currentBanner: BannerItem?
    
    private var dismissTask: Task<Void, Never>?
    
    public init() {}
    
    @MainActor
    public func show(type: BannerType, message: String, duration: TimeInterval = 3.0) {
        dismissTask?.cancel()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentBanner = BannerItem(type: type, message: message)
        }
        
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }
    
    @MainActor
    public func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.25)) {
            currentBanner = nil
        }
    }
}
