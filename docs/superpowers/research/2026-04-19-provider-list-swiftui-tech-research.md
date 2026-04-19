# Provider List Drag & Group — SwiftUI Tech Research

**Date:** 2026-04-19
**Swift Version:** Apple Swift 6.3 (swiftlang-6.3.0.123.5)
**macOS Target:** macOS 13+
**Spec:** `2026-04-19-provider-list-drag-group-design.md`

---

## Tech 1: SwiftUI List `.onMove` (Drag & Drop Reordering)

### Quick Reference

| Pattern | Usage |
|---------|-------|
| `List` + `.onMove` on `ForEach` | Native macOS drag-to-reorder |
| `LazyVStack` + `.onMove` | **不支持**，静默失败，无报错 |
| `EditMode` 必须为 `.active` | macOS 上拖拽手柄才显示 |

### Best Practice: Native List Reorder

```swift
struct FlatProviderList: View {
    @EnvironmentObject var store: ProviderStore
    @State private var editMode: EditMode = .active

    var body: some View {
        List(selection: $store.selectedProviderId) {
            ForEach(store.providers) { provider in
                ProviderRowView(provider: provider)
                    .tag(provider.id)
            }
            .onMove { indices, newOffset in
                store.moveProvider(from: indices, to: newOffset)
            }
        }
        .listStyle(.sidebar)
        .environment(\.editMode, $editMode)
    }
}
```

### Grouped Mode: 同组内拖拽

**方案：按 type 分支验证**

由于 `.onMove` 的 `indices` 相对于当前 `ForEach` 的数据源，分组模式下直接对分组后的 `ForEach` 应用 `.onMove`，`indices` 自动对应分组内的索引。关键是在 `ProviderStore.moveProvider` 里验证源和目标属于同一 type，拒绝跨组移动：

```swift
// ProviderStore.swift
func moveProvider(from indices: IndexSet, to newOffset: Int, in groupType: ProviderType? = nil) {
    // groupType == nil → 扁平模式，全局自由移动
    // groupType != nil → 分组模式，只允许同组内移动
}
```

### Common Pitfalls

| 问题 | 表现 | 原因 | 解决 |
|------|------|------|------|
| `.onMove` 在 `LazyVStack` 上不工作 | 拖拽无反应 | `LazyVStack` 不支持 | 用 `List` 替代 |
| macOS 拖拽手柄不出现 | 长按无反应 | `EditMode` 不是 `.active` | `.environment(\.editMode, $editMode)` |
| 跨组拖拽 | 分组顺序错乱 | 未校验 type 一致性 | 在 `.onMove` 闭包内校验 source/dest type |
| `.onMove` 写在 `List` 而非 `ForEach` 上 | 拖拽无效 | API 绑定位置错误 | `.onMove` 必须贴在 `ForEach` 上 |
| 拖拽时调用 `save()` | UI 卡顿 | save 触发重绘打断拖拽 | 拖拽结束后再 save，可用 `Task { }` 延迟 |

---

## Tech 2: Collapsible Group (DisclosureGroup)

### Quick Reference

| API | 版本 | 用途 |
|-----|------|------|
| `DisclosureGroup` | macOS 11+ | 原生折叠组件 |
| `.rotationEffect` + chevron | 任意 | 折叠箭头旋转动画 |
| `Animation.spring(response:dampingFraction:)` | 任意 | 展开/折叠动画 |

### Best Practice: 自定义 CollapsibleGroup 组件

```swift
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

### 状态持久化

折叠状态通过 `UserDefaults`（`ThemeManager` 封装）存储：

```swift
// ThemeManager.swift 中添加
var isClaudeCodeGroupCollapsed: Bool {
    get { UserDefaults.standard.bool(forKey: "providerGroupCollapsed_claudeCode") }
    set { UserDefaults.standard.set(newValue, forKey: "providerGroupCollapsed_claudeCode") }
}
```

---

## Tech 3: State Management — Flat vs Grouped 切换

### 关键模式

**每个模式封装为独立子视图：**

```swift
struct ProviderListContainer: View {
    @AppStorage("providerGroupingEnabled") private var groupingEnabled: Bool = false

    var body: some View {
        Group {
            if groupingEnabled {
                GroupedProviderList()
            } else {
                FlatProviderList()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: groupingEnabled)
    }
}
```

### 防止闪烁

- 切换时用 `withAnimation` 包裹状态变更
- 使用 `.transition(.opacity)` 让两个分支淡入淡出
- **不要**用 `.id()` 切换，那会摧毁视图状态

### 数据派生

```swift
// computed property，按 sortOrder 排序
private var sortedProviders: [Provider] {
    store.providers.sorted { $0.sortOrder < $1.sortOrder }
}

// 分组模式下派生分组数据
private var groupedProviders: (claudeCode: [Provider], codex: [Provider]) {
    let sorted = sortedProviders
    return (
        sorted.filter { $0.type == .claudeCode },
        sorted.filter { $0.type == .codex }
    )
}
```

### @Observable / @AppStorage 混用注意

`ThemeManager` 是 `ObservableObject`，通过 `@EnvironmentObject` 注入。如需在 `@Observable` 类中使用 `@AppStorage`，使用 `@ObservationIgnored` 避免冲突：

```swift
@Observable
@MainActor
final class ProviderStore {
    @ObservationIgnored @AppStorage("providerGroupingEnabled") var groupingEnabled = false
}
```

---

## 架构决策汇总

| 决策 | 选择 | 原因 |
|------|------|------|
| 列表组件 | `List` + `.onMove` | `LazyVStack` 不支持 `.onMove` |
| 分组拖拽 | 按 type 分支校验 | 避免跨组移动，`.onMove` indices 相对当前 ForEach，无跨组问题 |
| EditMode | `.active` | macOS 拖拽手柄必须 |
| 折叠组件 | 自定义 `CollapsibleGroup` | DisclosureGroup 样式定制化成本高 |
| 模式切换 | `if/else` + `.transition(.opacity)` | 防止闪烁，保留视图状态 |
| 折叠持久化 | UserDefaults（ThemeManager 封装） | 与现有 settings 体系一致 |

---

## 已知限制

1. **分组切换时 sortOrder 重分配**：从分组 OFF → ON 时，需要遍历现有数据按 type 重分配 sortOrder，实现时注意在数据库事务中完成，避免中断导致数据不一致。
2. **拖拽时禁止 save**：`.onMove` 闭包内不要同步调用 `save()`，使用 `Task { }` 在拖拽结束后延迟保存。
