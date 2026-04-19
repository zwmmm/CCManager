# Provider List Drag & Group Design

## Overview

给主页面的供应商列表增加拖拽排序和分组折叠功能。分组按 Provider 类型（Claude Code / Codex）自动分组，支持在设置中开启/关闭，默认关闭。

---

## Data Model

### UserDefaults Keys

| Key | Type | Default | Description |
|---|---|---|---|
| `providerGroupingEnabled` | `Bool` | `false` | 分组功能总开关 |
| `providerGroupCollapsed_claudeCode` | `Bool` | `false` | Claude Code 分组折叠状态 |
| `providerGroupCollapsed_codex` | `Bool` | `false` | Codex 分组折叠状态 |

### Provider Model

`sortOrder: Int` 字段已存在于 `Provider` 模型，作为全局排序字段，无需修改 schema。

---

## Behavior

### Grouping OFF (default)

- 供应商以扁平列表展示，按 `sortOrder` 升序排列
- 全列表应用 `.onMove { from, to }`，支持自由拖拽排序
- 切换到 Grouping ON 时，按类型重新分配 sortOrder（见下）

### Grouping ON

- 列表分为两个固定分组：**Claude Code** 和 **Codex**
- 每个分组独立排序，各自维护独立的 sortOrder（0, 1, 2…）
- 组间不可拖拽；组内可拖拽排序
- 每个分组 Header 可点击折叠/展开
- 切换回 OFF 时无需修改 sortOrder，直接按现有 sortOrder 扁平渲染

### Sort Reorder on Grouping ON

从 OFF 切换到 ON 时：

```
1. 读取所有 provider，按现有 sortOrder 排序
2. 重新分配 sortOrder：
   - 所有 Claude Code → sortOrder 0, 1, 2…（按原顺序）
   - 所有 Codex → sortOrder 0, 1, 2…（按原顺序）
3. 批量写回数据库
```

分组内拖拽时，更新同组内其他 provider 的 sortOrder，组间 sortOrder 互不影响。

### Collapse State Persistence

- 折叠状态变更后立即写入 UserDefaults
- 应用重启后读取并恢复折叠状态

---

## UI Structure

### Flat Mode

```
ScrollView {
    LazyVStack(spacing: 0) {
        ForEach(providerStore.providers) { provider in
            ProviderRowView(provider)
        }
    }
}
.listStyle(.plain)
.onMove { from, to in
    // move provider in flat list
}
```

### Grouped Mode

```
ScrollView {
    LazyVStack(spacing: 0) {

        // Claude Code Group
        CollapsibleGroup(
            title: "Claude Code",
            isCollapsed: $isClaudeCodeCollapsed,
            count: claudeCodeProviders.count
        ) {
            ForEach(claudeCodeProviders) { provider in
                ProviderRowView(provider)
            }
        }
        .onMove { from, to in
            // move within Claude Code group only
        }

        // Codex Group
        CollapsibleGroup(
            title: "Codex",
            isCollapsed: $isCodexCollapsed,
            count: codexProviders.count
        ) {
            ForEach(codexProviders) { provider in
                ProviderRowView(provider)
            }
        }
        .onMove { from, to in
            // move within Codex group only
        }
    }
}
```

### CollapsibleGroup Component

- Header: `HStack { Text(title); Spacer(); Text("(\(count))"); Image(systemName: chevron) }`
- 右侧 chevron 图标旋转动画指示折叠状态
- 折叠动画：`spring(response: 0.3, dampingFraction: 0.8)`
- 整个 header 可点击切换折叠状态

### Settings Entry

在 `ThemeSettingsView` 的 "通用"（General）分区添加：

```
Toggle("显示分组", isOn: $providerGroupingEnabled)
```

---

## Architecture

### Files to Modify

| File | Changes |
|---|---|
| `Sources/Managers/ThemeManager.swift` | 添加 `providerGroupingEnabled` 和折叠状态的 UserDefaults 包装属性 |
| `Sources/Stores/ProviderStore.swift` | 添加 `moveProviderWithinGroup(groupType:to:)`、`reassignSortOrderOnGroupingEnabled()` 方法 |
| `Sources/Views/ContentView.swift` | SidebarView 布局逻辑，支持 flat / grouped 切换 |
| `Sources/Views/ThemeSettingsView.swift` | 添加 Toggle 控件 |
| `Sources/Views/CollapsibleGroup.swift` | 新建分组折叠组件 |
| `Sources/Views/ProviderRowView.swift` | 提取 Row 组件（已有类似逻辑，确认是否需要新建） |

### State Flow

```
ThemeSettingsView
    └── providerGroupingEnabled (UserDefaults)
            └── ContentView/SidebarView
                    ├── Flat Mode: ForEach + .onMove (全局排序)
                    └── Grouped Mode: CollapsibleGroup × 2 + .onMove (组内排序)

UserDefaults
    ├── providerGroupingEnabled
    ├── providerGroupCollapsed_claudeCode
    └── providerGroupCollapsed_codex
```

---

## Animation Spec

| Animation | Spec |
|---|---|
| Group collapse/expand | `spring(response: 0.3, dampingFraction: 0.8)` |
| Row hover | `scaleEffect(1.01)` + `easeOut(0.15)` |
| Row press | `scaleEffect(0.97)` + `easeOut(0.12)` |
| Sort order change | `.onMove` 内部 `withAnimation(.spring(response: 0.3, dampingFraction: 0.8))` |
