import SwiftUI
import UIKit

/// A UITextField subclass that forces the emoji keyboard to appear
class UIEmojiTextField: UITextField {
    
    override var textInputContextIdentifier: String? { "" }
    
    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage == "emoji" {
                return mode
            }
        }
        return super.textInputMode
    }
}

/// SwiftUI wrapper for a TextField that shows the native emoji keyboard
struct EmojiTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    var onEmojiSelected: ((String) -> Void)?
    
    func makeUIView(context: Context) -> UIEmojiTextField {
        let textField = UIEmojiTextField()
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        textField.font = .systemFont(ofSize: 40)
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.tintColor = .clear // Hide cursor
        textField.textColor = .clear // Hide text (we show emoji separately)
        textField.backgroundColor = .clear
        return textField
    }
    
    func updateUIView(_ uiView: UIEmojiTextField, context: Context) {
        // Handle first responder
        if isFirstResponder && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if !isFirstResponder && uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.resignFirstResponder()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiTextField
        
        init(_ parent: EmojiTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            guard let text = textField.text, !text.isEmpty else { return }
            
            // Take only the last character (newest emoji)
            let lastChar = String(text.suffix(1))
            textField.text = lastChar
            parent.text = lastChar
            parent.onEmojiSelected?(lastChar)
            
            // Dismiss keyboard after selection
            DispatchQueue.main.async {
                textField.resignFirstResponder()
                self.parent.isFirstResponder = false
            }
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.parent.isFirstResponder = false
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.isFirstResponder = false
            return true
        }
    }
}

/// A tappable emoji picker button - opens keyboard directly on tap
struct EmojiPickerButton: View {
    @Binding var selectedEmoji: String
    @State private var isKeyboardActive = false
    @State private var tempEmoji: String = ""
    
    var body: some View {
        ZStack {
            // Hidden emoji text field (captures keyboard input)
            EmojiTextField(
                text: $tempEmoji,
                isFirstResponder: $isKeyboardActive,
                onEmojiSelected: { emoji in
                    selectedEmoji = emoji
                }
            )
            .frame(width: 1, height: 1)
            .opacity(0)
            
            // Visible button
            Button {
                tempEmoji = selectedEmoji
                isKeyboardActive = true
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.blue, lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(Color(.systemBackground)))
                    
                    Text(selectedEmoji)
                        .font(.system(size: 44))
                }
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            tempEmoji = selectedEmoji
        }
    }
}

#Preview {
    EmojiPickerButton(selectedEmoji: .constant("📍"))
}
