### Features

- Replace Sparkle with a custom app update flow backed by GitHub Release appcast assets
- Add a custom Markdown update window with install progress states and automatic relaunch
- Add startup and periodic background update checks

### Bug Fixes

- Avoid cached appcast responses during update checks
- Improve app relaunch reliability after replacing the application bundle

### Others

- Update the release workflow to generate appcast.xml as a release artifact
- Update release documentation and remove obsolete Sparkle signing requirements
