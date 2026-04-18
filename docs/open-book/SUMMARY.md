# Open Book Summary: 开启自启功能 (Launch at Login)

## Task: 实现 macOS 开启自启功能

### 研究结果

**ctx7 findings:**
- ServiceManagement SMAppService 是 macOS 13+ 推荐方式
- 旧版 `SMLoginItemSetEnabled` 已废弃

**GitHub references:**
- rxhanson/Rectangle: `SMAppService.mainApp.status == .enabled` 检测状态
- JerryZLiu/Dayflow: `SMAppService.mainApp.register()` / `.unregister()` 注册/注销
- exo-explore/exo: 自动注册模式 `enableLaunchAtLoginIfNeeded()`

### Key APIs

```swift
import ServiceManagement

// 检测状态
SMAppService.mainApp.status // .enabled, .requiresApproval, .notRegistered, .notFound

// 启用
try SMAppService.mainApp.register()

// 禁用
try SMAppService.mainApp.unregister()
```

**状态枚举 (macOS 13+):**
- `.enabled` - 已注册
- `.requiresApproval` - 用户手动在系统设置中添加
- `.notRegistered` - 未注册
- `.notFound` - 未找到

### 注意事项

- 需要 `@available(macOS 13.0, *)` 检查
- `status` 是同步 XPC 调用，首次可能较慢（约 5 秒），建议异步预热
- `.requiresApproval` 也应视为"已启用"状态

### Wrong approach:
```swift
// 不要直接阻塞 UI 线程
let status = SMAppService.mainApp.status // 同步调用，可能卡住
```

### Right approach:
```swift
// 异步预热 + 缓存状态
Task {
    await refreshStatusAsync()
}

// 设置时同步调用（用户操作后）
func setEnabled(_ enabled: Bool) {
    do {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    } catch {
        // 处理错误
    }
}
```

## 实现总结

创建了以下文件：
- `Sources/Managers/LaunchAtLoginManager.swift` - 管理开启自启逻辑
- 修改 `Sources/Views/ThemeSettingsView.swift` - 添加 Toggle 开关
- 修改 `Sources/App/AppDelegate.swift` - 启动时异步预热状态

功能：
- 默认开启（`UserDefaults` 默认值 `true`）
- 可以在设置中关闭
- macOS 13+ 使用 SMAppService
- 异步状态同步避免阻塞 UI

## 参考链接
- https://github.com/rxhanson/Rectangle/blob/main/Rectangle/LaunchOnLogin.swift
- https://github.com/JerryZLiu/Dayflow/blob/main/Dayflow/Dayflow/System/LaunchAtLoginManager.swift