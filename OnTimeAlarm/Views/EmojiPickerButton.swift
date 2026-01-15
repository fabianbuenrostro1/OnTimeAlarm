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
    var placeholder: String = ""
    var autoFocus: Bool = false
    var onCommit: (() -> Void)?
    var onEmojiSelected: ((String) -> Void)?
    
    func makeUIView(context: Context) -> UIEmojiTextField {
        let textField = UIEmojiTextField()
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        textField.font = .systemFont(ofSize: 40)
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.tintColor = .clear // Hide cursor
        return textField
    }
    
    func updateUIView(_ uiView: UIEmojiTextField, context: Context) {
        uiView.text = text
        
        // Auto-focus when requested
        if autoFocus && !uiView.isFirstResponder {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                uiView.becomeFirstResponder()
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
            // Only take the first character (emoji) if multiple are entered
            if let text = textField.text {
                if text.count > 1 {
                    // Keep only the last character (most recently typed emoji)
                    let lastChar = String(text.suffix(1))
                    textField.text = lastChar
                    parent.text = lastChar
                    parent.onEmojiSelected?(lastChar)
                } else if !text.isEmpty {
                    parent.text = text
                    parent.onEmojiSelected?(text)
                }
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onCommit?()
            return true
        }
    }
}

/// A tappable emoji picker button that presents the emoji keyboard
struct EmojiPickerButton: View {
    @Binding var selectedEmoji: String
    @State private var showingPicker = false
    
    var body: some View {
        Button {
            showingPicker = true
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
        .sheet(isPresented: $showingPicker) {
            EmojiPickerSheet(selectedEmoji: $selectedEmoji)
                .presentationDetents([.height(320)])
        }
    }
}

/// Sheet view containing the emoji text field - auto-focuses keyboard on appear
struct EmojiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String
    @State private var tempEmoji: String = ""
    @State private var shouldFocus: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose an Emoji")
                .font(.headline)
                .padding(.top, 24)
            
            ZStack {
                Circle()
                    .strokeBorder(Color.blue, lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .background(Circle().fill(Color(.systemGray6)))
                
                EmojiTextField(
                    text: $tempEmoji,
                    placeholder: "",
                    autoFocus: shouldFocus,
                    onEmojiSelected: { emoji in
                        // Auto-dismiss after selecting an emoji
                        selectedEmoji = emoji
                        dismiss()
                    }
                )
                .frame(width: 80, height: 80)
            }
            
            Text("Pick any emoji from the keyboard")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .onAppear {
            tempEmoji = selectedEmoji
            // Trigger auto-focus after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                shouldFocus = true
            }
        }
    }
}

#Preview {
    EmojiPickerButton(selectedEmoji: .constant("📍"))
}

