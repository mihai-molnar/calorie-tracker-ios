import SwiftUI

struct ChatView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel: ChatViewModel?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let vm = viewModel {
                // Stats bar
                StatsBarView(
                    totalCalories: vm.totalCalories,
                    dailyCalorieTarget: vm.dailyCalorieTarget,
                    weightKg: vm.weightKg,
                    progress: vm.calorieProgress
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

                // Input bar
                HStack(spacing: 12) {
                    TextField("What did you eat?", text: Binding(
                        get: { vm.messageText },
                        set: { vm.messageText = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
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
                            .font(.title2)
                    }
                    .disabled(!vm.canSend)
                }
                .padding(.horizontal)
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
    }
}
