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
