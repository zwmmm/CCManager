# Open Book: Status Bar Menu with Main Window Restoration

## Problem Summary
After user closes the main window and clicks status bar to show main window, nothing happens. EXC_BAD_ACCESS errors occur.

## Root Causes Identified

1. **NSPanel vs NSPopover**: Current implementation uses NSPanel which requires manual click-outside handling
2. **isReleasedWhenClosed = true (default)**: Window is deallocated when closed, making stored reference invalid
3. **NSApp.mainWindow unreliable**: Returns nil after all windows closed

## Research Findings

### Task 1: NSPopover with Status Bar
- Use `popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)`
- Set `behavior = .transient` for auto-close on outside click
- Use `popover.performClose(sender)` to close

### Task 2: Window Restoration
- Set `window.isReleasedWhenClosed = false` so window object survives close
- Check `NSApp.windows` (not `mainWindow`) for hidden windows
- Use `makeKeyAndOrderFront(nil)` to show closed but allocated windows

## Implementation Plan

1. Convert `StatusBarController` from NSPanel to NSPopover
2. Set `isReleasedWhenClosed = false` on main window in AppDelegate
3. Fix `handleRestoreMainWindow` to use stored reference with isVisible check