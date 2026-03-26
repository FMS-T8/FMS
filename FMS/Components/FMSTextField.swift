import SwiftUI

public struct FMSTextField: View {
    let label: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    var isSecure: Bool = false
    var trailingAction: (() -> Void)? = nil
    var trailingLabel: String? = nil
    
    @State private var isPasswordVisible: Bool = false
    

    
    public init(
        label: String,
        placeholder: String,
        icon: String,
        text: Binding<String>,
        isSecure: Bool = false,
        trailingAction: (() -> Void)? = nil,
        trailingLabel: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self.icon = icon
        self._text = text
        self.isSecure = isSecure
        self.trailingAction = trailingAction
        self.trailingLabel = trailingLabel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !label.isEmpty || (trailingLabel != nil && trailingAction != nil) {
                HStack {
                    if !label.isEmpty {
                        Text(label.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(FMSTheme.textSecondary)
                            .tracking(0.5)
                    }
                    
                    Spacer()
                    
                    if let trailingLabel = trailingLabel, let trailingAction = trailingAction {
                        Button(trailingLabel) {
                            trailingAction()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(FMSTheme.amber)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(FMSTheme.textTertiary)
                
                Group {
                    if isSecure && !isPasswordVisible {
                        SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(FMSTheme.textTertiary))
                    } else {
                        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(FMSTheme.textTertiary))
                    }
                }
                .font(.system(size: 15))
                .foregroundColor(FMSTheme.textPrimary)
                .autocorrectionDisabled()
                
                if isSecure {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundColor(FMSTheme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(FMSTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FMSTheme.borderLight, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 20) {
        FMSTextField(
            label: "Email Address",
            placeholder: "manager@fleetpro.com",
            icon: "envelope",
            text: .constant("")
        )
        
        FMSTextField(
            label: "Password",
            placeholder: "Required",
            icon: "lock",
            text: .constant(""),
            isSecure: true,
            trailingAction: {},
            trailingLabel: "Forgot?"
        )
    }
    .padding()
    .background(FMSTheme.backgroundPrimary)
}
