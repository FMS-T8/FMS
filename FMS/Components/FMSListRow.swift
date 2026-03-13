import SwiftUI

struct FMSListRow: View {
    let systemImage: String?
    let text: String
    let textColor: Color
    let isLoading: Bool
    
    init(systemImage: String? = nil, text: String, textColor: Color, isLoading: Bool = false) {
        self.systemImage = systemImage
        self.text = text
        self.textColor = textColor
        self.isLoading = isLoading
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: FMSTheme.textSecondary))
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(FMSTheme.alertOrange)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(textColor)
            Spacer()
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
    }
}
