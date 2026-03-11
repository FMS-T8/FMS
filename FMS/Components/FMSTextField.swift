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
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Adaptive colors
    private var textFieldBackground: Color {
        colorScheme == .dark ? Color(red: 20/255, green: 20/255, blue: 25/255) : .white
    }
    private var labelColor: Color {
        colorScheme == .dark ? Color(red: 170/255, green: 170/255, blue: 180/255) : Color(red: 130/255, green: 130/255, blue: 140/255)
    }
    private var placeholderColor: Color {
        colorScheme == .dark ? Color(red: 160/255, green: 160/255, blue: 170/255) : Color(red: 130/255, green: 130/255, blue: 140/255)
    }
    private var borderColor: Color {
        colorScheme == .dark ? Color(red: 40/255, green: 40/255, blue: 45/255) : Color(red: 230/255, green: 230/255, blue: 235/255)
    }
    private var textColor: Color {
        colorScheme == .dark ? Color(red: 230/255, green: 230/255, blue: 235/255) : .black
    }
    
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
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(labelColor)
                    .tracking(0.5)
                
                Spacer()
                
                if let trailingLabel = trailingLabel, let trailingAction = trailingAction {
                    Button(trailingLabel) {
                        trailingAction()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(FMSTheme.amber)
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(placeholderColor)
                
                Group {
                    if isSecure && !isPasswordVisible {
                        SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(placeholderColor))
                    } else {
                        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(placeholderColor))
                    }
                }
                .font(.system(size: 15))
                .foregroundColor(textColor)
                .autocorrectionDisabled()
                
                if isSecure {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundColor(placeholderColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(textFieldBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
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
    .background(Color(red: 245/255, green: 245/255, blue: 247/255))
}
