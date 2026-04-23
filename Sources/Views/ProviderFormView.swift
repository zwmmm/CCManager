import SwiftUI

enum FormMode: Identifiable {
    case add
    case edit(Provider)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit: return "edit"
        }
    }
}

struct ProviderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    let mode: FormMode
    let onSave: (Provider) -> Void

    @State private var name: String = ""
    @State private var type: ProviderType = .claudeCode
    @State private var apiKey: String = ""
    @State private var baseUrl: String = ""
    @State private var model: String = ""
    @State private var thinkingModel: String = ""
    @State private var haikuModel: String = ""
    @State private var sonnetModel: String = ""
    @State private var opusModel: String = ""
    @State private var showAdvancedModels: Bool = false
    @State private var isTesting: Bool = false
    @State private var testMessage: String?
    @State private var testSuccess: Bool = false
    @State private var oauthIsLoggedIn: Bool = false
    @State private var oauthDisplayName: String = ""
    @State private var showOAuthLogin: Bool = false
    @State private var pendingOauthTokens: (accessToken: String, refreshToken: String, idToken: String)?

    private var baseUrlPlaceholder: String {
        switch type {
        case .claudeCode: return "https://api.anthropic.com"
        case .codex: return "https://api.openai.com/v1"
        case .codexOAuth: return "https://api.openai.com/v1"
        }
    }

    private var modelPlaceholder: String {
        switch type {
        case .claudeCode: return "claude-sonnet-4-20250514"
        case .codex: return "gpt-4o"
        case .codexOAuth: return "gpt-4o"
        }
    }

    private var isValid: Bool {
        if type == .codexOAuth {
            return oauthIsLoggedIn
        }

        return !name.trimmingCharacters(in: .whitespaces).isEmpty &&
            !baseUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
            !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            typeSelector

            ScrollView {
                VStack(spacing: 14) {
                    if type != .codexOAuth {
                        sectionCard(title: "Connection") {
                            VStack(spacing: 14) {
                                fieldGroup("Name", text: $name, placeholder: "My Provider")
                                fieldGroup("API Key", text: $apiKey, placeholder: "sk-...", isSecure: true)
                                fieldGroup("Base URL", text: $baseUrl, placeholder: baseUrlPlaceholder)
                            }
                        }
                    }

                    if type == .codexOAuth {
                        sectionCard(title: "Account") {
                            if oauthIsLoggedIn {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green.opacity(0.18))
                                            .frame(width: 24, height: 24)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.green)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(oauthDisplayName.isEmpty ? "Logged in" : oauthDisplayName)
                                            .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)

                                        Text("OAuth token stored locally")
                                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 8)

                                    HStack(spacing: 8) {
                                        Button("Refresh Token") {
                                            showOAuthLogin = true
                                        }
                                        .buttonStyle(FormSecondaryButtonStyle())

                                        Button("Logout") {
                                            oauthIsLoggedIn = false
                                            oauthDisplayName = ""
                                            pendingOauthTokens = nil
                                        }
                                        .buttonStyle(FormSecondaryButtonStyle())
                                    }
                                }
                                .padding(12)
                                .background(AppTheme.cardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.cardStroke, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            } else {
                                Button {
                                    showOAuthLogin = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("Login with ChatGPT")
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(FormPrimaryButtonStyle(accent: themeManager.brandColor))
                            }
                        }
                    }

                    sectionCard(title: "Model") {
                        VStack(spacing: 14) {
                            fieldGroup("Model (Optional)", text: $model, placeholder: modelPlaceholder)

                            if type == .claudeCode {
                                DisclosureGroup(isExpanded: $showAdvancedModels) {
                                    VStack(spacing: 14) {
                                        fieldGroup("Thinking Model", text: $thinkingModel, placeholder: "Uses main model if empty")
                                        fieldGroup("Haiku Model", text: $haikuModel, placeholder: "Uses main model if empty")
                                        fieldGroup("Sonnet Model", text: $sonnetModel, placeholder: "Uses main model if empty")
                                        fieldGroup("Opus Model", text: $opusModel, placeholder: "Uses main model if empty")
                                    }
                                    .padding(.top, 14)
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("Advanced Model Settings")
                                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .textCase(.uppercase)
                                        Spacer()
                                    }
                                }
                                .tint(themeManager.brandColor)
                            }
                        }
                    }

                    if type != .codexOAuth {
                        let filteredPresets = PresetProvider.presets.filter { $0.type == type }
                        if !filteredPresets.isEmpty {
                            sectionCard(title: "Presets") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(filteredPresets, id: \.name) { preset in
                                            Button {
                                                applyPreset(preset)
                                            } label: {
                                                Text(preset.name)
                                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                    .lineLimit(1)
                                            }
                                            .buttonStyle(FormPillButtonStyle(accent: themeManager.brandColor))
                                        }
                                    }
                                    .padding(.vertical, 1)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }

            Divider()
                .overlay(AppTheme.separator)

            footerView
        }
        .frame(width: 416)
        .frame(maxHeight: 640)
        .background(AppTheme.background)
        .fontDesign(.monospaced)
        .onAppear {
            if case .edit(let provider) = mode {
                name = provider.name
                type = provider.type
                apiKey = provider.apiKey ?? ""
                baseUrl = provider.baseUrl
                model = provider.model ?? ""
                thinkingModel = provider.thinkingModel ?? ""
                haikuModel = provider.haikuModel ?? ""
                sonnetModel = provider.sonnetModel ?? ""
                opusModel = provider.opusModel ?? ""
                oauthIsLoggedIn = provider.oauthAccountId != nil
                oauthDisplayName = provider.oauthDisplayName ?? ""
                if let accessToken = provider.oauthAccessToken,
                   let refreshToken = provider.oauthRefreshToken,
                   let idToken = provider.oauthIdToken {
                    pendingOauthTokens = (accessToken, refreshToken, idToken)
                }
            }
        }
        .sheet(isPresented: $showOAuthLogin) {
            OAuthLoginSheet { accountId, accessToken, refreshToken, idToken, displayName in
                self.oauthIsLoggedIn = true
                self.oauthDisplayName = displayName ?? "ChatGPT Account"
                self.name = self.oauthDisplayName
                self.pendingOauthTokens = (accessToken, refreshToken, idToken)
                self.showOAuthLogin = false
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Edit Provider" : "New Provider")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text("Compact provider config and auth setup")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(FormIconButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var typeSelector: some View {
        HStack(spacing: 6) {
            ForEach(ProviderType.allCases) { t in
                let isSelected = type == t

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { type = t }
                } label: {
                    HStack(spacing: 7) {
                        if isSelected {
                            Circle()
                                .fill(themeManager.brandColor)
                                .frame(width: 5, height: 5)
                                .shadow(color: themeManager.brandColor.opacity(0.45), radius: 5, x: 0, y: 0)
                        }

                        Text(t.rawValue)
                            .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium, design: .monospaced))
                            .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? themeManager.brandColor.opacity(0.16) : AppTheme.cardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? themeManager.brandColor.opacity(0.28) : AppTheme.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: isSelected ? themeManager.brandColor.opacity(0.08) : .clear, radius: 10, x: 0, y: 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(AppTheme.subtleFill)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(FormSecondaryButtonStyle())

            Spacer(minLength: 12)

            if let msg = testMessage {
                HStack(spacing: 5) {
                    Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(testSuccess ? .green : .red)
                    Text(msg)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Button {
                Task { await testProvider() }
            } label: {
                if isTesting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else {
                    Text("Test")
                }
            }
            .buttonStyle(FormSecondaryButtonStyle())
            .disabled(!isValid || isTesting)

            Button(isEditing ? "Save" : "Add") {
                saveProvider()
            }
            .buttonStyle(FormPrimaryButtonStyle(accent: themeManager.brandColor))
            .disabled(!isValid)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
                    .kerning(0.6)
                Spacer()
            }

            content()
        }
        .padding(14)
        .background(AppTheme.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func fieldGroup(_ label: String, text: Binding<String>, placeholder: String, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            if isSecure {
                SecureField(placeholder, text: text)
                    .fieldStyle()
            } else {
                TextField(placeholder, text: text)
                    .fieldStyle()
            }
        }
    }

    private func applyPreset(_ preset: PresetProvider) {
        name = preset.name
        type = preset.type
        baseUrl = preset.baseUrl
        model = preset.model ?? ""
    }

    private func saveProvider() {
        let provider: Provider
        let providerName = resolvedProviderName()
        let providerBaseUrl = resolvedBaseUrl()

        switch mode {
        case .add:
            provider = Provider(
                name: providerName,
                type: type,
                apiKey: type == .codexOAuth ? nil : apiKey.trimmingCharacters(in: .whitespaces),
                baseUrl: providerBaseUrl,
                model: model.isEmpty ? nil : model.trimmingCharacters(in: .whitespaces),
                thinkingModel: thinkingModel.isEmpty ? nil : thinkingModel.trimmingCharacters(in: .whitespaces),
                haikuModel: haikuModel.isEmpty ? nil : haikuModel.trimmingCharacters(in: .whitespaces),
                sonnetModel: sonnetModel.isEmpty ? nil : sonnetModel.trimmingCharacters(in: .whitespaces),
                opusModel: opusModel.isEmpty ? nil : opusModel.trimmingCharacters(in: .whitespaces),
                sortOrder: 0,
                oauthAccountId: type == .codexOAuth ? UUID().uuidString : nil,
                oauthAccessToken: type == .codexOAuth ? pendingOauthTokens?.accessToken : nil,
                oauthRefreshToken: type == .codexOAuth ? pendingOauthTokens?.refreshToken : nil,
                oauthIdToken: type == .codexOAuth ? pendingOauthTokens?.idToken : nil,
                oauthTokenExpiry: type == .codexOAuth ? Date() : nil,
                oauthDisplayName: type == .codexOAuth ? (oauthDisplayName.isEmpty ? nil : oauthDisplayName) : nil
            )
        case .edit(let existing):
            provider = Provider(
                id: existing.id,
                name: providerName,
                type: type,
                apiKey: type == .codexOAuth ? nil : apiKey.trimmingCharacters(in: .whitespaces),
                baseUrl: providerBaseUrl,
                model: model.isEmpty ? nil : model.trimmingCharacters(in: .whitespaces),
                thinkingModel: thinkingModel.isEmpty ? nil : thinkingModel.trimmingCharacters(in: .whitespaces),
                haikuModel: haikuModel.isEmpty ? nil : haikuModel.trimmingCharacters(in: .whitespaces),
                sonnetModel: sonnetModel.isEmpty ? nil : sonnetModel.trimmingCharacters(in: .whitespaces),
                opusModel: opusModel.isEmpty ? nil : opusModel.trimmingCharacters(in: .whitespaces),
                isActive: existing.isActive,
                sortOrder: existing.sortOrder,
                oauthAccountId: type == .codexOAuth ? (existing.oauthAccountId ?? UUID().uuidString) : nil,
                oauthAccessToken: type == .codexOAuth ? (pendingOauthTokens?.accessToken ?? existing.oauthAccessToken) : nil,
                oauthRefreshToken: type == .codexOAuth ? (pendingOauthTokens?.refreshToken ?? existing.oauthRefreshToken) : nil,
                oauthIdToken: type == .codexOAuth ? (pendingOauthTokens?.idToken ?? existing.oauthIdToken) : nil,
                oauthTokenExpiry: type == .codexOAuth ? existing.oauthTokenExpiry : nil,
                oauthDisplayName: type == .codexOAuth ? (oauthDisplayName.isEmpty ? existing.oauthDisplayName : oauthDisplayName) : nil
            )
        }
        onSave(provider)
        dismiss()
    }

    private func testProvider() async {
        guard isValid else { return }

        isTesting = true
        testMessage = nil

        let provider = Provider(
            name: resolvedProviderName(),
            type: type,
            apiKey: type == .codexOAuth ? nil : apiKey.trimmingCharacters(in: .whitespaces),
            baseUrl: resolvedBaseUrl(),
            model: model.isEmpty ? nil : model.trimmingCharacters(in: .whitespaces),
            thinkingModel: thinkingModel.isEmpty ? nil : thinkingModel.trimmingCharacters(in: .whitespaces),
            haikuModel: haikuModel.isEmpty ? nil : haikuModel.trimmingCharacters(in: .whitespaces),
            sonnetModel: sonnetModel.isEmpty ? nil : sonnetModel.trimmingCharacters(in: .whitespaces),
            opusModel: opusModel.isEmpty ? nil : opusModel.trimmingCharacters(in: .whitespaces),
            oauthAccessToken: type == .codexOAuth ? pendingOauthTokens?.accessToken : nil,
            oauthRefreshToken: type == .codexOAuth ? pendingOauthTokens?.refreshToken : nil,
            oauthIdToken: type == .codexOAuth ? pendingOauthTokens?.idToken : nil
        )

        let result = await ProviderTester.shared.test(provider: provider)

        isTesting = false

        switch result {
        case .success:
            testSuccess = true
            testMessage = "OK"
        case .failure(let error):
            testSuccess = false
            testMessage = error
        }
    }

    private func resolvedProviderName() -> String {
        if type == .codexOAuth {
            return oauthDisplayName.trimmingCharacters(in: .whitespaces).isEmpty ? "ChatGPT Account" : oauthDisplayName.trimmingCharacters(in: .whitespaces)
        }

        return name.trimmingCharacters(in: .whitespaces)
    }

    private func resolvedBaseUrl() -> String {
        if type == .codexOAuth {
            return ""
        }

        return baseUrl.trimmingCharacters(in: .whitespaces)
    }
}

private struct FormIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .background(configuration.isPressed ? AppTheme.hoverFill : AppTheme.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct FormSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(configuration.isPressed ? AppTheme.hoverFill : AppTheme.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct FormPrimaryButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.97))
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                LinearGradient(
                    colors: [
                        accent.opacity(configuration.isPressed ? 0.7 : 0.88),
                        accent.opacity(configuration.isPressed ? 0.55 : 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: accent.opacity(configuration.isPressed ? 0.14 : 0.22), radius: 10, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct FormPillButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.16 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            )
            .foregroundStyle(AppTheme.textPrimary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .font(.system(size: 12.5, design: .monospaced))
            .textFieldStyle(.plain)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(AppTheme.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
