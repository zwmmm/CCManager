# CCManager Design System

## 1. Concept & Vision

CCManager is a minimal, utility-focused macOS menu-bar application for managing AI provider configurations (Claude Code / Codex). The aesthetic is **developer-tool minimalism** — monospaced typography throughout, a restrained neutral base, and a single customizable brand accent drawn from traditional Chinese pigments. It feels like a well-crafted CLI tool given a native macOS shell: purposeful, quiet, and fast.

---

## 2. Design Language

### 2.1 Aesthetic Direction

**Reference**: Linear.app meets macOS System Settings — clean list-panel layouts, monospaced code aesthetics, and native macOS chrome (NSColor system backgrounds, floating panels with subtle borders).

### 2.2 Color Palette

#### Brand Color (User-Selectable)
The single accent color is fully user-customizable via a palette of **500+ traditional Chinese pigments** organized into 10 categories. Default brand color: **粉绿** `#83cbac`.

| Token | Hex | Usage |
|---|---|---|
| `brandColor` | `#83cbac` (default) | CTAs, active states, ON badges, toggles |

#### Static Palette — 10 Chinese Color Categories

| Category | Chinese Name | Description |
|---|---|---|
| `group0` | 白月 | Neutrals, grays, off-whites |
| `group1` | 朱砂 | Cinnabar reds, burnt oranges, coffee browns |
| `group2` | 落霞 | Sunset oranges, golden yellows |
| `group3` | 秋禾 | Harvest golds, amber |
| `group4` | 苔青 | Yellow-greens, olive, lime |
| `group5` | 柳烟 | Sage greens, teals |
| `group6` | 沧浪 | Ocean blues, cobalt, navy |
| `group7` | 晴岚 | Lavender, purple-gray |
| `group8` | 暮山 | Magentas, rose pinks |
| `group9` | 桃夭 | Vibrant reds, peach, coral |

#### Semantic Tokens (Static)

| Token | Value | Usage |
|---|---|---|
| `background` | `NSColor.windowBackgroundColor` | Main view backgrounds |
| `surface` | `NSColor.controlBackgroundColor` | Cards, input fields, list rows |
| `separator` | `NSColor.separatorColor` | Dividers, hairlines |
| `textPrimary` | `.primary` (adaptive) | Main readable text |
| `textSecondary` | `.secondary` (adaptive) | Labels, captions, metadata |
| `textTertiary` | `.tertiary` (adaptive) | Placeholders, disabled |
| `destructive` | `.red` | Delete actions, error states |

### 2.3 Typography

**Font Family**: SF Pro (system) with `design: .monospaced` as the consistent voice across all text — reinforcing the developer-tool identity.

#### Type Scale

| Style | Size | Weight | Usage |
|---|---|---|---|
| `caption2` | 9pt | Bold | Tiny badges ("ON", "ACTIVE") |
| `caption` | 10pt | Bold | Section labels ("APPEARANCE", "THEME COLOR") |
| `footnote` | 11pt | Medium | Secondary metadata, status messages |
| `subheadline` | 12pt | Medium | Button labels, tab text |
| `body` | 13pt | Medium | Form fields, body text |
| `headline` | 14pt | Semibold | List item names |
| `title3` | 16pt | Semibold | Empty state titles |
| `title2` | 20pt | Bold | Detail card provider name |

**Line Heights**: Default system line heights. `lineLimit: 1` used for ellipsizing long names/URLs.

### 2.4 Spacing Scale

Values are multiples of 4px with a secondary 2px step.

| Token | Value | Usage |
|---|---|---|
| `--space-0` | 0 | Separator-only gaps |
| `--space-2` | 2 | Tight internal padding |
| `--space-4` | 4 | List item vertical spacing |
| `--space-6` | 6 | Icon-to-label gaps |
| `--space-8` | 8 | Inline element gaps |
| `--space-10` | 10 | Form label spacing |
| `--space-12` | 12 | Card internal padding |
| `--space-14` | 14 | Section padding |
| `--space-16` | 16 | Main content horizontal padding |
| `--space-18` | 18 | Settings sheet horizontal padding |
| `--space-20` | 20 | Primary content padding |
| `--space-24` | 24 | Card vertical padding |

### 2.5 Corner Radius Scale

| Token | Value | Usage |
|---|---|---|
| `--radius-sm` | 5px | Small inner elements (icon frames) |
| `--radius-md` | 6px | Tag buttons, compact rows |
| `--radius-md2` | 7px | Editor picker rows |
| `--radius-lg` | 8px | Provider list rows, input fields |
| `--radius-xl` | 10px | Cards, color grid container |
| `--radius-2xl` | 12px | Large cards, floating panel |
| `--radius-pill` | Capsule / full | Badges, pills, circular buttons |

PixelAvatarView uses a proportional radius: `size * 0.15`.

### 2.6 Shadows

Minimal. Only Toast uses a shadow:

```
shadow(color: .black.opacity(0.15), radius: 4, y: 2)
```

Floating panel (StatusMenuPanel) uses `hasShadow = true` (NSWindow native).

### 2.7 Motion Philosophy

**Principle**: Responsive, snappy, never decorative. Animations communicate state changes, not aesthetics.

| Pattern | Timing | Usage |
|---|---|---|
| Spring enter | `response: 0.35~0.4, dampingFraction: 0.8` | Modal sheets, list item changes |
| Spring micro | `response: 0.2~0.3, dampingFraction: 0.8` | Selection changes, toggles |
| EaseOut press | `duration: 0.12` | Button press scale (0.92x) |
| EaseOut hover | `duration: 0.15` | Row hover scale (1.01x) |
| Opacity fade | `duration: 0.2` | View transitions |
| Tab switch | `duration: 0.18` | Provider type tab indicator |

Entrance orchestration: `scaleEffect(0.96 → 1) + opacity(0 → 1)` with 0.05s delay.

---

## 3. Layout & Structure

### 3.1 App Architecture

```
┌─────────────────────────────────────────────────────┐
│  Sidebar (240px fixed)  │  Detail Panel (flex)      │
│  ─────────────────────  │  ────────────────────────  │
│  [Provider List]         │  [Provider Header Card]   │
│  [Footer: + / ⚙ / ✎]   │  [Config Info Section]    │
│                         │  [Action Buttons]          │
└─────────────────────────────────────────────────────┘
```

- **Sidebar**: Fixed 240px, `windowBackgroundColor`, scrollable provider list, fixed footer buttons
- **Detail Panel**: Flexible width, `windowBackgroundColor`, scrollable, empty state when nothing selected
- **Modals**: Sheet presentation for Add/Edit Provider and Settings
- **Menu Bar Panel**: Floating `NSPanel` (280×400), rounded 12px, subtle border

### 3.2 Visual Pacing

- **Section rhythm**: 16px section header + 10px spacing + 0px gap between content blocks
- **Dividers**: `Divider()` (macOS native hairline) between every major section
- **Card depth**: Cards use `controlBackgroundColor` to create subtle elevation without shadows
- **Settings panel**: Fixed 340px width, scrollable content, sticky footer with Done button

---

## 4. Components

### 4.1 Buttons

#### Circular Icon Button
Used in sidebar footer for `+`, settings, and config actions.
```swift
Image(systemName: "plus")
    .font(.system(size: 12, weight: .semibold, design: .monospaced))
    .frame(width: 24, height: 24)
    .background(brandColor)
    .foregroundStyle(.black)
    .clipShape(Circle())
```
State: Pressed → `ScaleButtonStyle` (0.92x scale, 0.12s easeOut).

#### Bordered Button
```swift
.buttonStyle(.bordered)
// Used for: Cancel, Test, secondary actions
```

#### Bordered Prominent Button
```swift
.buttonStyle(.borderedProminent)
.tint(brandColor)
// Used for: Save, Add, Apply Config, Done
```

### 4.2 ScaleButtonStyle
```swift
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
```
Applied to all icon buttons and list toolbar buttons.

### 4.3 Cards

Provider detail header card:
```swift
.background(Color(nsColor: .controlBackgroundColor))
.clipShape(RoundedRectangle(cornerRadius: 12))
.padding(.vertical, 24)
```

Config info section:
```swift
.background(Color(nsColor: .controlBackgroundColor))
.clipShape(RoundedRectangle(cornerRadius: 10))
```

### 4.4 Provider List Row
```swift
HStack(spacing: 10) {
    PixelAvatarView(name: provider.name, type: provider.type, size: 28)
    VStack(alignment: .leading, spacing: 2) {
        Text(provider.name)   // 14pt semibold monospaced
        Text(provider.type.rawValue)  // 10pt, .secondary
    }
    Spacer()
    if provider.isActive {
        Text("ON")  // 9pt bold, brand bg, capsule
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(brandColor).clipShape(Capsule())
    }
}
.padding(.vertical, 8).padding(.horizontal, 10)
.background(isSelected ? brandColor.opacity(0.2) : Color.clear)
.clipShape(RoundedRectangle(cornerRadius: 8))
```
States: default, hover (scale 1.01x), selected (brandColor 20% opacity bg).

### 4.5 ON / Active Badge
- **Badge pill**: `Capsule()`, brand color bg, `.black` text, 9pt bold
- **Dot indicator**: 8px `Circle()`, brand color fill, used in menu bar panel

### 4.6 Toast Notification
```swift
HStack(spacing: 8) {
    Image(systemName: icon)  // 12pt semibold
    Text(message)            // 13pt medium monospaced
}
.foregroundStyle(.black)
.padding(.horizontal, 16).padding(.vertical, 10)
.background(brandColor)
.clipShape(Capsule())
.shadow(color: .black.opacity(0.15), radius: 4, y: 2)
```
Animation: `transition(.move(edge: .top).combined(with: .opacity))`, auto-dismiss 2s.

### 4.7 PixelAvatarView
- DiceBear pixel art avatars (adventurer for Claude Code, open-peeps for Codex)
- `clipShape(RoundedRectangle(cornerRadius: size * 0.15))`
- Claude Code avatars are horizontally flipped (mirrored)
- Placeholder: gray 30% opacity with centered `ProgressView`

### 4.8 Color Picker Grid (Settings)
- Horizontal `ScrollView` for category tabs
- `LazyVGrid` with 5 columns, 8px spacing
- Color button: 32px circle, checkmark overlay when selected with 2px white border
- Selected category tab: brandColor 20% opacity bg + brandColor text

### 4.9 Theme Option Selector
```swift
HStack(spacing: 6) {
    Image(systemName: icon)  // 12pt
    Text(label)              // 11pt bold monospaced
}
.frame(maxWidth: .infinity)
.padding(.vertical, 10)
.background(isSelected ? brandColor.opacity(0.25) : Color.clear)
.clipShape(RoundedRectangle(cornerRadius: 6))
```
3 options: SYSTEM / LIGHT / DARK in a segmented pill container.

### 4.10 Form Fields
```swift
VStack(alignment: .leading, spacing: 6) {
    Text(label)  // 10pt bold caps, .secondary
    TextField(placeholder, text: text)
        .font(.system(size: 13, design: .monospaced))
        .textFieldStyle(.roundedBorder)
}
```
- Label: 10pt bold uppercase monospaced, secondary color
- Input: 13pt monospaced, `roundedBorder` style
- Secure fields use `SecureField`

### 4.11 Floating Panel (Menu Bar)
```swift
.frame(width: 280, height: 400)
.background(Color(nsColor: .windowBackgroundColor))
.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
)
```

### 4.12 Section Header
```swift
HStack {
    Text("APPEARANCE")
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(.secondary)
    Spacer()
}
.padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 10)
```

---

## 5. Animation Inventory

| Animation | Trigger | Spec |
|---|---|---|
| Sheet present | `sheet(isPresented:)` | `spring(response: 0.35, dampingFraction: 0.8)` |
| Provider select | `selectedProviderId` change | `spring(response: 0.2, dampingFraction: 0.8)` |
| Add/Edit provider | Modal dismiss → list update | `spring(response: 0.35, dampingFraction: 0.8)` |
| Delete provider | List remove | `spring(response: 0.3, dampingFraction: 0.8)` |
| Row hover | `onHover` | `scaleEffect(1.01)` + `easeOut(0.15)` |
| Row press | `onTapGesture` | `scaleEffect(0.97)` + `easeOut(0.12)` |
| Button press | `ScaleButtonStyle` | `scaleEffect(0.92)` + `easeOut(0.12)` |
| Tab switch | Provider type change | `easeInOut(0.18)` |
| Toast appear | `isPresented = true` | `spring(response: 0.35, dampingFraction: 0.8)` |
| Toast dismiss | 2s timer | `easeOut(0.2)` opacity |
| Card enter | `onAppear` | `scaleEffect(0.96→1) + opacity(0→1)` + `delay(0.05)` |
| Brand color change | User picks new color | `spring(response: 0.2~0.25, dampingFraction: 0.8)` |
| Active dot (panel) | Press feedback | `scaleEffect(1.5)` + `easeOut(0.12)` |

---

## 6. Do's and Don'ts

### Do
- Use `Font.system(..., design: .monospaced)` for ALL text — this is the project's typographic identity
- Use `NSColor.windowBackgroundColor` / `.controlBackgroundColor` instead of hardcoded colors for backgrounds
- Use `.foregroundStyle(.secondary)` for metadata text instead of explicit gray values
- Use `ScaleButtonStyle` for all icon-only buttons to provide tactile press feedback
- Use `brandColor.opacity(0.2)` for selected/hover backgrounds, not solid brandColor fills
- Use `spring(response: 0.3~0.4, dampingFraction: 0.8)` for list changes and modal transitions
- Use `Capsule()` for badge/pill shapes, `RoundedRectangle(cornerRadius: 8)` for list rows
- Use `contentShape(Rectangle())` before `.onTapGesture` / `.onHover` so the entire hit area responds
- Use the ChineseColor palette for the brand color picker; never introduce new saturated accent colors
- Respect the spacing scale: prefer 4px increments, use 2px only for tight icon-label gaps

### Don't
- **Don't** use `Color.gray` or `Color.black` directly — use semantic tokens or adaptive colors
- **Don't** mix SF Pro (default) with monospaced — always specify `design: .monospaced`
- **Don't** use `.cornerRadius(0)` on anything that should feel tactile; prefer 6–8px minimum
- **Don't** use shadow for elevation except Toast — cards should use `controlBackgroundColor` only
- **Don't** use `animation(.default)` — always specify explicit spring or easeOut curves
- **Don't** create one-off colors or padding values outside the defined scale
- **Don't** use `@Environment(\.colorScheme)` directly — go through `ThemeManager` for color scheme preference
- **Don't** add decorative animations — every animation must communicate state, not personality
