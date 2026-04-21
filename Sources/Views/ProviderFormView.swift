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
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !baseUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        (type == .codexOAuth ? true : !apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "EDIT PROVIDER" : "NEW PROVIDER")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Type tabs
            HStack(spacing: 0) {
                ForEach(ProviderType.allCases) { t in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { type = t }
                    } label: {
                        VStack(spacing: 0) {
                            Text(t.rawValue)
                                .font(.system(size: 13, weight: type == t ? .semibold : .regular, design: .monospaced))
                                .foregroundStyle(type == t ? themeManager.brandColor : Color.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                            Rectangle()
                                .fill(type == t ? themeManager.brandColor : Color.clear)
                                .frame(height: 2)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 0.5)
            }

            // Scrollable content
            ScrollView {
                VStack(spacing: 14) {
                    fieldGroup("NAME", text: $name, placeholder: "My Provider")
                    if type != .codexOAuth {
                        fieldGroup("API KEY", text: $apiKey, placeholder: "sk-...", isSecure: true)
                    }
                    fieldGroup("BASE URL", text: $baseUrl, placeholder: baseUrlPlaceholder)

                    // OAuth Account section (only for codexOAuth)
                    if type == .codexOAuth {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ACCOUNT")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            if oauthIsLoggedIn {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.system(size: 12))
                                    Text(oauthDisplayName.isEmpty ? "Logged in" : oauthDisplayName)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button("Refresh Token") {
                                        showOAuthLogin = true
                                    }
                                    .font(.system(size: 11, design: .monospaced))
                                    .buttonStyle(.bordered)
                                    Button("Logout") {
                                        oauthIsLoggedIn = false
                                        oauthDisplayName = ""
                                        pendingOauthTokens = nil
                                    }
                                    .font(.system(size: 11, design: .monospaced))
                                    .buttonStyle(.bordered)
                                }
                                .padding(10)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Button {
                                    showOAuthLogin = true
                                } label: {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                        Text("Login with ChatGPT")
                                    }
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(themeManager.brandColor)
                            }
                        }
                    }

                    fieldGroup("MODEL (OPTIONAL)", text: $model, placeholder: modelPlaceholder)

                    // Advanced model settings (only for Claude Code)
                    if type == .claudeCode {
                        DisclosureGroup(isExpanded: $showAdvancedModels) {
                            VStack(spacing: 12) {
                                fieldGroup("THINKING MODEL", text: $thinkingModel, placeholder: "Uses main model if empty")
                                fieldGroup("HAIKU MODEL", text: $haikuModel, placeholder: "Uses main model if empty")
                                fieldGroup("SONNET MODEL", text: $sonnetModel, placeholder: "Uses main model if empty")
                                fieldGroup("OPUS MODEL", text: $opusModel, placeholder: "Uses main model if empty")
                            }
                            .padding(.top, 8)
                        } label: {
                            Text("ADVANCED MODEL SETTINGS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(18)

                // Presets — filtered by current type (not shown for codexOAuth)
                if type != .codexOAuth {
                    let filteredPresets = PresetProvider.presets.filter { $0.type == type }
                    if !filteredPresets.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filteredPresets, id: \.name) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    Text(preset.name)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(themeManager.brandColor.opacity(0.15))
                                        .clipShape(Capsule())
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                // Test result message
                if let msg = testMessage {
                    HStack(spacing: 4) {
                        Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(testSuccess ? .green : .red)
                        Text(msg)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await testProvider() }
                } label: {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Test")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!isValid || isTesting)

                Button(isEditing ? "Save" : "Add") {
                    saveProvider()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.brandColor)
                .disabled(!isValid)
            }
            .padding(18)
        }
        .frame(width: 380)
        .frame(maxHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
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
            }
        }
        .sheet(isPresented: $showOAuthLogin) {
            OAuthLoginSheet { accountId, accessToken, refreshToken, idToken, displayName in
                self.oauthIsLoggedIn = true
                self.oauthDisplayName = displayName ?? "ChatGPT Account"
                self.pendingOauthTokens = (accessToken, refreshToken, idToken)
                self.showOAuthLogin = false
            }
        }
    }

    private func fieldGroup(_ label: String, text: Binding<String>, placeholder: String, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if isSecure {
                SecureField(placeholder, text: text)
                    .font(.system(size: 13, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 13, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
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
        switch mode {
        case .add:
            provider = Provider(
                name: name.trimmingCharacters(in: .whitespaces),
                type: type,
                apiKey: type == .codexOAuth ? nil : apiKey.trimmingCharacters(in: .whitespaces),
                baseUrl: baseUrl.trimmingCharacters(in: .whitespaces),
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
                name: name.trimmingCharacters(in: .whitespaces),
                type: type,
                apiKey: type == .codexOAuth ? nil : apiKey.trimmingCharacters(in: .whitespaces),
                baseUrl: baseUrl.trimmingCharacters(in: .whitespaces),
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
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            apiKey: apiKey.trimmingCharacters(in: .whitespaces),
            baseUrl: baseUrl.trimmingCharacters(in: .whitespaces),
            model: model.isEmpty ? nil : model.trimmingCharacters(in: .whitespaces),
            thinkingModel: thinkingModel.isEmpty ? nil : thinkingModel.trimmingCharacters(in: .whitespaces),
            haikuModel: haikuModel.isEmpty ? nil : haikuModel.trimmingCharacters(in: .whitespaces),
            sonnetModel: sonnetModel.isEmpty ? nil : sonnetModel.trimmingCharacters(in: .whitespaces),
            opusModel: opusModel.isEmpty ? nil : opusModel.trimmingCharacters(in: .whitespaces)
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
}
