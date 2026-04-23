# Dashboard UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the provider dashboard UI into a premium dark macOS layout without changing any underlying provider logic.

**Architecture:** Keep all state and actions in the existing view hierarchy, and concentrate the work inside `ContentView.swift` by restyling the sidebar, empty state, detail hero, config rows, and action buttons. Add only small local helper views/modifiers when they improve clarity, and avoid touching shared logic or store behavior.

**Tech Stack:** SwiftUI, AppKit colors/materials, existing `ThemeManager`, existing `ProviderStore`

---

### Task 1: Restyle the shell layout

**Files:**
- Modify: `Sources/Views/ContentView.swift`

- [ ] Update the top-level split layout to use a wider sidebar, layered dark background, and softer panel separation while preserving the existing bindings and sheet flows.
- [ ] Replace the current sidebar footer presentation with a premium icon toolbar and keep the existing add/settings/open-config actions intact.

### Task 2: Redesign provider rows and empty state

**Files:**
- Modify: `Sources/Views/ContentView.swift`

- [ ] Restyle provider list rows with richer spacing, active glow, muted subtitles, and a compact active indicator without changing row tap or context menu behavior.
- [ ] Refresh the empty state to match the new premium dashboard tone while keeping it purely presentational.

### Task 3: Redesign the detail pane

**Files:**
- Modify: `Sources/Views/ContentView.swift`

- [ ] Rebuild the selected-provider hero section with stronger hierarchy, centered profile presentation, and refined status badge styling.
- [ ] Rework the configuration card into a softer premium panel and add hover-revealed copy buttons for rows without changing the displayed data.
- [ ] Restyle the action buttons so `Apply Config` becomes the clear primary action and `Edit` becomes a subdued secondary action.

### Task 4: Verify

**Files:**
- Modify: `Sources/Views/ContentView.swift`

- [ ] Run `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release build` and confirm the redesigned UI compiles successfully.
