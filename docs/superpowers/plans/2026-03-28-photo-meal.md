# Photo Meal Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to attach a photo of their meal alongside optional text in the chat, so the AI can visually estimate calories.

**Architecture:** iOS captures/selects a photo, compresses and base64-encodes it, sends it with the chat message. Backend passes it to OpenAI as a vision content block. Images are not stored — only text is persisted.

**Tech Stack:** SwiftUI, PhotosUI, UIKit (UIImagePickerController for camera), FastAPI, OpenAI gpt-4o (vision)

**Spec:** `docs/superpowers/specs/2026-03-28-photo-meal-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `backend/app/routers/chat.py` | Modify | Add `image` field to `ChatRequest`, build vision content array for OpenAI |
| `CalorieTracker/Models/ChatMessage.swift` | Modify | Add `image` field to `ChatRequest` |
| `CalorieTracker/Services/SSEClient.swift` | Modify | Pass optional image in request body |
| `CalorieTracker/ViewModels/ChatViewModel.swift` | Modify | Add `selectedImage` state, compress/encode on send |
| `CalorieTracker/Views/Chat/ChatView.swift` | Modify | Add camera button, thumbnail preview |
| `CalorieTracker/Views/Chat/ChatBubbleView.swift` | Modify | Render `[Photo]` prefix distinctly |
| `CalorieTracker/Info.plist` | Modify | Add `NSCameraUsageDescription` |

---

### Task 1: Backend — Add Image Support to Chat Endpoint

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker/backend/app/routers/chat.py`

- [ ] **Step 1: Add `image` field to `ChatRequest`**

In `chat.py`, update the `ChatRequest` model:

```python
class ChatRequest(BaseModel):
    message: str
    image: str | None = None
```

- [ ] **Step 2: Build vision content array when image is present**

In the `chat()` function, replace the line that appends the user message to the OpenAI messages list (currently `messages.append({"role": "user", "content": body.message})`):

```python
    if body.image:
        user_content = [
            {"type": "text", "text": body.message or "What's in this photo?"},
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{body.image}"}},
        ]
    else:
        user_content = body.message

    messages.append({"role": "user", "content": user_content})
```

- [ ] **Step 3: Prefix stored message when image was attached**

Update the line that stores the user message in the database (currently `supabase.table("chat_messages").insert({"daily_log_id": daily_log_id, "role": "user", "content": body.message}).execute()`):

```python
    stored_content = f"[Photo] {body.message}" if body.image else body.message
    supabase.table("chat_messages").insert({
        "daily_log_id": daily_log_id, "role": "user", "content": stored_content,
    }).execute()
```

- [ ] **Step 4: Verify the backend starts without errors**

Run: `cd /Users/mihai/AI/calorie-tracker/backend && python -c "from app.routers.chat import router; print('OK')"`

Expected: `OK`

- [ ] **Step 5: Commit**

```bash
cd /Users/mihai/AI/calorie-tracker
git add backend/app/routers/chat.py
git commit -m "feat: add image support to chat endpoint for vision-based calorie estimation"
```

---

### Task 2: iOS — Update Models and SSEClient for Image Support

**Files:**
- Modify: `CalorieTracker/Models/ChatMessage.swift`
- Modify: `CalorieTracker/Services/SSEClient.swift`

- [ ] **Step 1: Add `image` field to `ChatRequest`**

In `ChatMessage.swift`, update:

```swift
struct ChatRequest: Codable {
    let message: String
    let image: String?

    init(message: String, image: String? = nil) {
        self.message = message
        self.image = image
    }
}
```

- [ ] **Step 2: Update `SSEClient.sendMessage` to accept optional image**

In `SSEClient.swift`, update the method signature and body:

```swift
    func sendMessage(_ message: String, image: String? = nil, token: String) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("chat"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(ChatRequest(message: message, image: image))

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw APIError.unknown
                    }

                    if http.statusCode == 401 {
                        throw APIError.unauthorized
                    }

                    guard (200...299).contains(http.statusCode) else {
                        throw APIError.serverError(message: "Chat request failed with status \(http.statusCode)")
                    }

                    let parser = SSEParser()
                    for try await line in bytes.lines {
                        if let event = parser.feed(line: line) {
                            continuation.yield(event)
                            if case .done = event {
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
```

- [ ] **Step 3: Verify project builds**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED (the `image` parameter defaults to `nil` so existing callers are unaffected).

- [ ] **Step 4: Commit**

```bash
git add CalorieTracker/Models/ChatMessage.swift CalorieTracker/Services/SSEClient.swift
git commit -m "feat: add optional image field to ChatRequest and SSEClient"
```

---

### Task 3: iOS — Add Image Handling to ChatViewModel

**Files:**
- Modify: `CalorieTracker/ViewModels/ChatViewModel.swift`

- [ ] **Step 1: Add image state and helper method**

Add the following imports and properties to `ChatViewModel`:

At the top of the file, add:
```swift
import UIKit
```

Add a new property after `var dataApplied = false`:
```swift
    var selectedImage: UIImage?
```

Add a helper method after `calorieProgress`:
```swift
    func base64EncodedImage() -> String? {
        guard let image = selectedImage else { return nil }

        // Resize to max 1024px on longest side
        let maxDimension: CGFloat = 1024
        let size = image.size
        let scale: CGFloat
        if size.width > maxDimension || size.height > maxDimension {
            scale = maxDimension / max(size.width, size.height)
        } else {
            scale = 1.0
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }

        // Compress to JPEG at 0.5 quality
        guard let data = resized.jpegData(compressionQuality: 0.5) else { return nil }
        return data.base64EncodedString()
    }
```

- [ ] **Step 2: Update `streamChat` to pass image**

Update the `streamChat` method to accept and pass the image:

```swift
    @MainActor
    private func streamChat(_ text: String, image: String? = nil, token: String) async throws {
        for try await event in sseClient.sendMessage(text, image: image, token: token) {
```

(The rest of the method body stays the same.)

- [ ] **Step 3: Update `send()` to encode and pass image**

In the `send()` method, after `let text = messageText.trimmingCharacters(in: .whitespaces)`, add image encoding and clear the image. Update the method:

```swift
    @MainActor
    func send() async {
        guard canSend, let token = authManager.token else { return }

        let text = messageText.trimmingCharacters(in: .whitespaces)
        let imageBase64 = base64EncodedImage()
        messageText = ""
        selectedImage = nil
        isSending = true
        errorMessage = nil

        // Add user message immediately
        let displayContent = imageBase64 != nil ? "[Photo] \(text)" : text
        let userMessage = ChatMessage(role: "user", content: displayContent)
        messages.append(userMessage)

        do {
            try await streamChat(text, image: imageBase64, token: token)
        } catch let error as APIError where error.isUnauthorized {
            if let newToken = await authManager.refreshToken() {
                do {
                    try await streamChat(text, image: imageBase64, token: newToken)
                } catch {
                    authManager.handleUnauthorized()
                }
            } else {
                authManager.handleUnauthorized()
            }
        } catch {
            errorMessage = "Failed to send message. Try again."
        }

        isSending = false
    }
```

- [ ] **Step 4: Update `canSend` to allow sending with only an image**

```swift
    var canSend: Bool {
        let hasText = !messageText.trimmingCharacters(in: .whitespaces).isEmpty
        let hasImage = selectedImage != nil
        return (hasText || hasImage) && !isSending
    }
```

- [ ] **Step 5: Verify project builds**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add CalorieTracker/ViewModels/ChatViewModel.swift
git commit -m "feat: add image selection, compression, and encoding to ChatViewModel"
```

---

### Task 4: iOS — Add Camera Button and Photo Preview to ChatView

**Files:**
- Modify: `CalorieTracker/Views/Chat/ChatView.swift`
- Modify: `CalorieTracker/Views/Chat/ChatBubbleView.swift`
- Modify: `CalorieTracker/Info.plist`

- [ ] **Step 1: Add `NSCameraUsageDescription` to Info.plist**

In `Info.plist`, add the camera usage description inside the top-level `<dict>`:

```xml
	<key>NSCameraUsageDescription</key>
	<string>Take a photo of your meal to estimate calories</string>
```

- [ ] **Step 2: Update ChatView with camera button and photo preview**

Replace `ChatView.swift` with:

```swift
import SwiftUI
import PhotosUI

struct ChatView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: ChatViewModel?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var photoPickerItem: PhotosPickerItem?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let vm = viewModel {
                // Stats bar
                StatsBarView(
                    totalCalories: vm.totalCalories,
                    dailyCalorieTarget: vm.dailyCalorieTarget,
                    weightKg: vm.weightKg,
                    progress: vm.calorieProgress,
                    dataApplied: Binding(
                        get: { vm.dataApplied },
                        set: { vm.dataApplied = $0 }
                    )
                )
                Divider()

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(vm.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }

                            if vm.isSending {
                                TypingIndicatorView()
                                    .id("typing")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable { await vm.loadHistory() }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: vm.messages.count) {
                        withAnimation {
                            if let lastId = vm.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: vm.isSending) {
                        if vm.isSending {
                            withAnimation {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }

                // Error message
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }

                Divider()

                // Photo preview
                if let image = vm.selectedImage {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            vm.selectedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }

                // Input bar
                HStack(spacing: 10) {
                    // Camera button
                    Menu {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                        Button {
                            showingImagePicker = true
                        } label: {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                    }

                    TextField("What did you eat?", text: Binding(
                        get: { vm.messageText },
                        set: { vm.messageText = $0 }
                    ))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .focused($isInputFocused)
                    .onSubmit {
                        if vm.canSend {
                            Task { await vm.send() }
                        }
                    }

                    Button {
                        Task { await vm.send() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                    }
                    .disabled(!vm.canSend)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                ProgressView()
            }
        }
        .task {
            let vm = ChatViewModel(authManager: authManager)
            self.viewModel = vm
            await vm.loadHistory()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, let vm = viewModel {
                Task { await vm.loadHistory() }
            }
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) {
            if let item = photoPickerItem {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel?.selectedImage = image
                    }
                    photoPickerItem = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                viewModel?.selectedImage = image
            }
            .ignoresSafeArea()
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImageCaptured: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
```

- [ ] **Step 3: Update ChatBubbleView to handle `[Photo]` prefix**

Replace `ChatBubbleView.swift` with:

```swift
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
```

- [ ] **Step 4: Build the project**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Run all tests**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(passed|failed)" | head -20`

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add CalorieTracker/Views/Chat/ChatView.swift CalorieTracker/Views/Chat/ChatBubbleView.swift CalorieTracker/Info.plist
git commit -m "feat: add camera button, photo preview, and photo indicator in chat bubbles"
```

---

### Task 5: Final Verification

- [ ] **Step 1: Full clean build (iOS)**

Run: `xcodebuild clean build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Full test suite (iOS)**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(passed|failed)" | head -30`

Expected: All tests pass.

- [ ] **Step 3: Verify backend starts**

Run: `cd /Users/mihai/AI/calorie-tracker/backend && python -c "from app.main import app; print('OK')"`

Expected: `OK`

- [ ] **Step 4: Commit plan**

```bash
cd /Users/mihai/AI/calorie-tracker-ios
git add docs/superpowers/plans/2026-03-28-photo-meal.md
git commit -m "docs: add photo meal feature implementation plan"
```
