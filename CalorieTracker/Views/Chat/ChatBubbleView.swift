import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }

    private var hasPhoto: Bool { message.content.hasPrefix("[Photo]") }

    private var displayContent: String {
        if hasPhoto {
            let text = message.content.dropFirst("[Photo] ".count).trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? "" : text
        }
        return message.content
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if hasPhoto {
                    Label("Photo attached", systemImage: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(isUser ? .white.opacity(0.8) : .secondary)
                }

                if !displayContent.isEmpty {
                    Text(displayContent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isUser ? Color.blue : Color(.systemGray5))
            .foregroundStyle(isUser ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}
