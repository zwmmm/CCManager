# Dashboard UI Redesign Design

**Date:** 2026-04-23

## Goal

Reimagine the macOS dashboard UI for CCManager so it feels closer to Linear, Raycast, Vercel, and Notion while preserving all existing provider-management logic and interactions.

## Constraints

- Change only SwiftUI presentation and interaction styling.
- Do not change provider data flow, persistence, config writing, or selection logic.
- Keep the current screen structure as sidebar plus detail panel.
- Preserve existing actions: add, settings, edit, select provider, apply config, open config files, and delete from context menu.

## Visual Direction

- Default to a premium dark-mode presentation with soft depth and restrained contrast.
- Use layered charcoal surfaces instead of flat black.
- Introduce subtle gradients, soft shadows, low-contrast borders, and glow on active states.
- Keep typography minimal and sharp with monospace accents for configuration content.
- Increase whitespace and vertical rhythm so the layout breathes more.

## Sidebar

- Widen the sidebar to roughly 260 points.
- Render provider rows as rounded cards with larger padding and quieter inactive states.
- Highlight the active row with a soft tinted fill, a faint border, and a light outer glow.
- Keep the right-side status affordance, but make it feel like a compact premium toggle/status pill rather than a bright badge.
- Move the bottom actions into an icon-only toolbar with small rounded buttons and subtle hover depth.

## Main Panel

- Center the selected provider profile in the upper portion of the detail pane.
- Increase avatar size and separate title, subtitle, model, and status into a clearer hierarchy.
- Replace the current header block with a more integrated hero section that relies on spacing and background depth rather than heavy framing.

## Config Card

- Present configuration values inside a single premium card with a soft border and layered background.
- Keep labels uppercase and muted.
- Keep values monospace and more visually prominent.
- Show a copy affordance only on hover for each row.

## Actions

- Make `Apply Config` the dominant blue primary action.
- Make `Edit` a quieter ghost/subtle secondary button.
- Preserve all existing button handlers.

## Verification

- `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release build`
- Verify that no non-UI logic changes are introduced while compiling the redesigned screen.
