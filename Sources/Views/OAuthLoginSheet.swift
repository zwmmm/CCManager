import SwiftUI
import AppKit

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
            HStack {
                Text("ChatGPT Login")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    loginTask?.cancel()
                    Task {
                        await OAuthLoginManager.shared.cancelCurrentLogin()
                    }
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            content
        }
        .frame(width: 336)
        .onAppear {
            startLoginFlow()
        }
        .onDisappear {
            loginTask?.cancel()
            Task {
                await OAuthLoginManager.shared.cancelCurrentLogin()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch pollingState {
        case .idle:
            IdleContent(deviceCode: deviceCode, verificationUrl: verificationUrl)
        case .polling:
            PollingContent(deviceCode: deviceCode, verificationUrl: verificationUrl)
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
        OAuthAuthorizationDetails(statusText: "Loading login...", deviceCode: deviceCode, verificationUrl: verificationUrl)
            .padding(16)
    }
}

struct PollingContent: View {
    let deviceCode: String
    let verificationUrl: String

    var body: some View {
        OAuthAuthorizationDetails(
            statusText: "Waiting for approval",
            deviceCode: deviceCode,
            verificationUrl: verificationUrl
        )
        .padding(16)
    }
}

private struct OAuthAuthorizationDetails: View {
    let statusText: String
    let deviceCode: String
    let verificationUrl: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)

                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            authorizationSection(
                title: "Open browser",
                primaryActionIcon: "arrow.up.right.square",
                primaryAction: {
                    guard let url = URL(string: verificationUrl) else { return }
                    NSWorkspace.shared.open(url)
                },
                valueView: AnyView(
                    Text(verificationUrl)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                )
            )

            authorizationSection(
                title: "Enter code",
                primaryActionIcon: nil,
                primaryAction: nil,
                valueView: AnyView(
                    Text(deviceCode.isEmpty ? "Loading..." : deviceCode)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                )
            )
        }
        .padding(.vertical, 14)
    }

    private func authorizationSection(
        title: String,
        primaryActionIcon: String?,
        primaryAction: (() -> Void)?,
        valueView: AnyView
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            HStack {
                valueView
                Spacer()
                if let primaryActionIcon, let primaryAction {
                    Button(action: primaryAction) {
                        Image(systemName: primaryActionIcon)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(title == "Open browser" ? verificationUrl : deviceCode, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(title == "Enter code" && deviceCode.isEmpty)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

struct SuccessContent: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.green)

            Text("Login complete")
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(32)
    }
}

struct ErrorContent: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.red)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }
}
