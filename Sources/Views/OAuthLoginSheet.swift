import SwiftUI

struct OAuthLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var deviceCode: String = ""
    @State private var verificationUrl: String = "https://auth.openai.com/codex/device"
    @State private var pollingState: PollingState = .idle
    @State private var errorMessage: String?
    @State private var loginTask: Task<Void, Never>?

    enum PollingState {
        case idle
        case polling
        case success
        case error
    }

    let onComplete: (String, String, String, String, String?) -> Void
    // (accountId, accessToken, refreshToken, idToken, displayName)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LOGIN CHATGPT")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    loginTask?.cancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            content
        }
        .frame(width: 340)
        .onAppear {
            startLoginFlow()
        }
        .onDisappear {
            loginTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch pollingState {
        case .idle:
            IdleContent(deviceCode: deviceCode, verificationUrl: verificationUrl)
        case .polling:
            PollingContent(deviceCode: deviceCode)
        case .success:
            SuccessContent()
        case .error:
            ErrorContent(message: errorMessage ?? "Unknown error")
        }
    }

    private func startLoginFlow() {
        loginTask = Task {
            do {
                // 1. Start Device Code flow
                let info = try await OAuthLoginManager.shared.startLogin()
                await MainActor.run {
                    self.deviceCode = info.userCode
                    self.verificationUrl = info.verificationUrl
                    self.pollingState = .polling
                }

                // 2. Poll for authorization
                let result = try await OAuthLoginManager.shared.pollForAuth()

                // 3. Callback
                await MainActor.run {
                    self.pollingState = .success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.onComplete(result.accountId, result.accessToken, result.refreshToken, result.idToken, result.displayName)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.pollingState = .error
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

struct IdleContent: View {
    let deviceCode: String
    let verificationUrl: String

    var body: some View {
        VStack(spacing: 20) {
            Text("1. Open this link in your browser and sign in:")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(verificationUrl)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(verificationUrl, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("2. Enter this one-time code:")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(deviceCode.isEmpty ? "Loading..." : deviceCode)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(deviceCode, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(deviceCode.isEmpty)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(18)
    }
}

struct PollingContent: View {
    let deviceCode: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Waiting for authorization...")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("Code: \(deviceCode)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

struct SuccessContent: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("Login Successful!")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
        .padding(40)
    }
}

struct ErrorContent: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)

            Text("Error: \(message)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}