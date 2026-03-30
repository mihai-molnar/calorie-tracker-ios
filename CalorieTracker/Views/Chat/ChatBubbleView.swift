import SwiftUI

struct TutorialView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome! Here's how to get started:")
                .font(.headline)

            TutorialRow(icon: "scalemass", text: "Log your weight — \"I weigh 82kg today\"")
            TutorialRow(icon: "fork.knife", text: "Log a meal — \"I had 2 eggs and toast for breakfast\"")
            TutorialRow(icon: "camera.fill", text: "Snap a photo of your plate and tap send")
            TutorialRow(icon: "list.bullet", text: "Plan ahead — \"What if I have pasta for dinner?\"")
            TutorialRow(icon: "minus.circle", text: "Fix mistakes — \"Remove the toast\" or \"I only ate half\"")

            Text("The more detail you give (portions, ingredients, brands), the better the estimate.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct TutorialRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

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
