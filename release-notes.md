### Features

- Add a full Codex OAuth provider flow with device-code login, ChatGPT account support, and dedicated provider details in the UI
- Add Codex OAuth account creation and login screens with verification URL/code guidance and shared Codex-style avatars

### Bug Fixes

- Write Codex OAuth credentials into the correct local Codex files only when applying the provider configuration
- Make Codex and Codex OAuth share a single active slot and improve OAuth account parsing, persistence, and network error handling

### Others

- Add dedicated test coverage for Codex OAuth login parsing, database persistence, config writing, and request building
