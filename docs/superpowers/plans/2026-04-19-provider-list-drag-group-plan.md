# Provider List Drag & Group Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给侧边栏供应商列表增加拖拽排序和分组折叠功能，默认扁平模式，支持设置中开启按类型分组。

**Architecture:** 分组功能通过 `ThemeManager` 的 UserDefaults 键控制，分组切换时重分配 sortOrder；拖拽使用 `List` + `.onMove`，分组模式下两个 List 各自独立排序。

**Tech Stack:** SwiftUI, macOS 13+, UserDefaults, `List.onMove`

---

## File Map

| File | Responsibility |
|------|----------------|
| `Sources/Managers/ThemeManager.swift` | 新增 `providerGroupingEnabled` 和两个折叠状态的 UserDefaults 封装 |
| `Sources/Stores/ProviderStore.swift` | 新增 `reassignSortOrderOnGroupingEnabled()`、`moveProviderInGroup(groupType:from:to:)` |
| `Sources/Views/CollapsibleGroup.swift` | 新建：可折叠分组组件 |
| `Sources/Views/ContentView.swift` | 修改 SidebarView 支持 flat/grouped 布局切换 |
| `Sources/Views/ThemeSettingsView.swift` | 在 General 分区新增 Toggle |

---

## Task 1: ThemeManager — 添加分组和折叠状态属性

**Files:**
- Modify: `Sources/Managers/ThemeManager.swift:1-66`

- [ ] **Step 1: 添加分组功能总开关属性**

在 `ThemeManager` 的 `init()` 之后、第一个 `Published` 属性之前的位置，添加：

```swift
var providerGroupingEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "providerGroupingEnabled") }
    set { UserDefaults.standard.set(newValue, forKey: "providerGroupingEnabled") }
}

var providerGroupCollapsed_claudeCode: Bool {
    get { UserDefaults.standard.bool(forKey: "providerGroupCollapsed_claudeCode") }
    set { UserDefaults.standard.set(newValue, forKey: "providerGroupCollapsed_claudeCode") }
}

var providerGroupCollapsed_codex: Bool {
    get { UserDefaults.standard.bool(forKey: "providerGroupCollapsed_codex") }
    set { UserDefaults.standard.set(newValue, forKey: "providerGroupCollapsed_codex") }
}
```

验证：`git diff Sources/Managers/ThemeManager.swift` 确认新增 3 个属性。

---

## Task 2: ProviderStore — 添加分组排序和重分配方法

**Files:**
- Modify: `Sources/Stores/ProviderStore.swift:62-76`

- [ ] **Step 1: 修改 `moveProvider` 支持分组模式**

将现有 `moveProvider(from:to:)` 方法替换为带 `groupType` 参数的版本：

```swift
func moveProvider(from source: IndexSet, to destination: Int, inGroup groupType: ProviderType? = nil) {
    var reorderedProviders = providers

    if let groupType = groupType {
        // 分组模式：只移动同 groupType 的 provider，保持其他不变
        let groupProviders = providers.filter { $0.type == groupType }.sorted { $0.sortOrder < $1.sortOrder }
        var mutableGroup = groupProviders
        mutableGroup.move(fromOffsets: source, toOffset: destination)

        // 重新分配组内 sortOrder
        for (index, provider) in mutableGroup.enumerated() {
            if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                providers[idx].sortOrder = index
            }
        }
        // 非同组 provider 不动（sortOrder 保持不变）
    } else {
        // 扁平模式：全量移动
        reorderedProviders.move(fromOffsets: source, toOffset: destination)
        for (index, provider) in reorderedProviders.enumerated() {
            if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                providers[idx].sortOrder = index
            }
        }
    }

    // 批量保存
    for provider in providers {
        do {
            try database.updateProvider(provider)
        } catch {
            print("Move provider error: \(error)")
        }
    }
    loadProviders()
}
```

- [ ] **Step 2: 添加 `reassignSortOrderOnGroupingEnabled` 方法**

在 `moveProvider` 方法之后添加：

```swift
func reassignSortOrderOnGroupingEnabled() {
    // 从扁平切换到分组模式时：
    // 1. 按现有 sortOrder 遍历
    // 2. Claude Code 组内重新分配 0, 1, 2…
    // 3. Codex 组内重新分配 0, 1, 2…
    let sortedProviders = providers.sorted { $0.sortOrder < $1.sortOrder }
    var claudeCodeOrder = 0
    var codexOrder = 0

    for provider in sortedProviders {
        switch provider.type {
        case .claudeCode:
            if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                providers[idx].sortOrder = claudeCodeOrder
                claudeCodeOrder += 1
            }
        case .codex:
            if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                providers[idx].sortOrder = codexOrder
                codexOrder += 1
            }
        }
    }

    for provider in providers {
        do {
            try database.updateProvider(provider)
        } catch {
            print("Reassign sort order error: \(error)")
        }
    }
    loadProviders()
}
```

验证：`git diff Sources/Stores/ProviderStore.swift` 确认方法签名正确。

---

## Task 3: 新建 CollapsibleGroup 组件

**Files:**
- Create: `Sources/Views/CollapsibleGroup.swift`

- [ ] **Step 1: 创建 CollapsibleGroup.swift**

```swift
import SwiftUI

struct CollapsibleGroup<Content: View>: View {
    @Binding var isExpanded: Bool
    let title: String
    let count: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)

                    if !isExpanded {
                        Text("(\(count))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .transition(.opacity)
            }
        }
    }
}
```

验证：`swiftc -typecheck Sources/Views/CollapsibleGroup.swift` 确认无语法错误。

---

## Task 4: ContentView — 重构 SidebarView 支持 Flat/Grouped 切换

**Files:**
- Modify: `Sources/Views/ContentView.swift:77-248`

- [ ] **Step 1: 在 SidebarView 中添加 @AppStorage 引用**

在 `SidebarView` struct 体内添加：

```swift
@AppStorage("providerGroupingEnabled") private var groupingEnabled: Bool = false
@AppStorage("providerGroupCollapsed_claudeCode") private var isClaudeCodeCollapsed: Bool = false
@AppStorage("providerGroupCollapsed_codex") private var isCodexCollapsed: Bool = false
@State private var editMode: EditMode = .active
```

- [ ] **Step 2: 替换 body 的 ScrollView + VStack 为条件分支**

将 `SidebarView` 的 body 中从 `ScrollView { VStack(spacing: 4) { ForEach... } }` 开始的内容，替换为：

```swift
var body: some View {
    VStack(spacing: 0) {
        if groupingEnabled {
            groupedListView
        } else {
            flatListView
        }
        // Footer HStack 保持不变...
    }
}
```

- [ ] **Step 3: 添加 `flatListView` computed property**

在 `SidebarView` 末尾（`rowView` 方法之后、`EmptyStateView` 之前）添加：

```swift
@ViewBuilder
private var flatListView: some View {
    List(selection: $selectedProviderId) {
        ForEach(providerStore.providers.sorted { $0.sortOrder < $1.sortOrder }) { provider in
            rowView(for: provider)
                .tag(provider.id)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .onMove { indices, newOffset in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                providerStore.moveProvider(from: indices, to: newOffset)
            }
        }
    }
    .listStyle(.plain)
    .environment(\.editMode, $editMode)
    .scrollContentBackground(.hidden)
}
```

- [ ] **Step 4: 添加 `groupedListView` computed property**

在 `flatListView` 之后添加：

```swift
@ViewBuilder
private var groupedListView: some View {
    ScrollView {
        LazyVStack(spacing: 0) {
            // Claude Code Group
            let claudeCodeProviders = providerStore.providers
                .filter { $0.type == .claudeCode }
                .sorted { $0.sortOrder < $1.sortOrder }

            CollapsibleGroup(
                isExpanded: $isClaudeCodeCollapsed,
                title: "Claude Code",
                count: claudeCodeProviders.count
            ) {
                List(selection: $selectedProviderId) {
                    ForEach(claudeCodeProviders) { provider in
                        rowView(for: provider)
                            .tag(provider.id)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onMove { indices, newOffset in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            providerStore.moveProvider(from: indices, to: newOffset, inGroup: .claudeCode)
                        }
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, $editMode)
                .scrollContentBackground(.hidden)
            }

            // Codex Group
            let codexProviders = providerStore.providers
                .filter { $0.type == .codex }
                .sorted { $0.sortOrder < $1.sortOrder }

            CollapsibleGroup(
                isExpanded: $isCodexCollapsed,
                title: "Codex",
                count: codexProviders.count
            ) {
                List(selection: $selectedProviderId) {
                    ForEach(codexProviders) { provider in
                        rowView(for: provider)
                            .tag(provider.id)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onMove { indices, newOffset in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            providerStore.moveProvider(from: indices, to: newOffset, inGroup: .codex)
                        }
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, $editMode)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}
```

- [ ] **Step 5: 移除旧的 ForEach 直接遍历代码**

在 `SidebarView.body` 中，删除原来的：

```swift
ScrollView {
    VStack(spacing: 4) {
        ForEach(providerStore.providers) { provider in
            rowView(for: provider)
        }
    }
    .padding(.horizontal, 8)
    .padding(.top, 8)
}
```

验证：`xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release build 2>&1 | grep -E "(error:|warning:.*ContentView)"` 确认无编译错误。

---

## Task 5: ThemeSettingsView — 添加分组 Toggle

**Files:**
- Modify: `Sources/Views/ThemeSettingsView.swift:60-70`

- [ ] **Step 1: 在 General 分区（Theme Color 之前）添加分组 Toggle**

找到 `Divider().padding(.horizontal: horizontalPadding)`（Theme Color 之前的那个），在此 `Divider` 之后、注释 `// Theme Color` 之前添加：

```swift
// Provider List Grouping
sectionHeader("GENERAL")

Toggle("显示分组", isOn: Binding(
    get: { ThemeManager.shared.providerGroupingEnabled },
    set: { newValue in
        let wasEnabled = ThemeManager.shared.providerGroupingEnabled
        ThemeManager.shared.providerGroupingEnabled = newValue
        if !wasEnabled && newValue {
            // 分组 OFF → ON：需要重分配 sortOrder
            ProviderStore.shared.reassignSortOrderOnGroupingEnabled()
        }
    }
))
.toggleStyle(.switch)
.tint(themeManager.brandColor)
.padding(.horizontal, horizontalPadding)
.padding(.bottom, 14)

Divider()
    .padding(.horizontal, horizontalPadding)

// Theme Color
```

验证：`xcodebuild ... build 2>&1 | grep -E "error:"` 确认无编译错误。

---

## 依赖关系

```
Task 1 (ThemeManager)  ──→ Task 5 (ThemeSettingsView uses it)
Task 1 (ThemeManager)  ──→ Task 4 (SidebarView uses it)
Task 2 (ProviderStore) ──→ Task 4 (SidebarView calls it)
Task 3 (CollapsibleGroup) ──→ Task 4 (SidebarView uses it)
Task 5 (ThemeSettingsView)  ──→ Task 2 (calls reassignSortOrderOnGroupingEnabled)
```

执行顺序：Task 1 → Task 2 → Task 3 → Task 4 → Task 5

---

## 验证清单

- [ ] `ThemeManager` 新增 3 个属性，编译通过
- [ ] `ProviderStore.moveProvider(inGroup:)` 分组内移动正常，跨组拒绝
- [ ] `ProviderStore.reassignSortOrderOnGroupingEnabled()` 正确重分配两组 sortOrder
- [ ] `CollapsibleGroup` 折叠/展开动画正常，chevron 旋转正常
- [ ] Flat 模式下拖拽排序正常
- [ ] Grouped 模式下每组内拖拽正常，组间不可拖拽
- [ ] 折叠状态切换后重启应用保持
- [ ] 设置 Toggle 关闭分组时无数据损坏
- [ ] 全项目构建无 error
