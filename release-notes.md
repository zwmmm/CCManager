### Bug Fixes

- Improve CLI path resolution to check target path when which command misses it
- Fix LaunchAtLoginManager.refreshStatusAsync() to return enabled status
- Fix ThemeSettingsView launch at login toggle with proper local state management to avoid sync issues

### Others

- Add unit test for resolveInstalledCLIPath function