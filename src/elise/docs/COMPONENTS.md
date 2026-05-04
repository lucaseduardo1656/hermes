# Components

## Main.qml

Root window. Owns `playerState` string. Orchestrates all layers via z-ordering and property binding.

**Props**: none (root)  
**State**: `playerState: string` ("collapsed" | "half" | "expanded")  
**Context props read**: System, Player, Nav

---

## MapView.qml

Fullscreen map base layer. Currently a placeholder gradient; replace with QtLocation or custom tile renderer.

**Props**:
- `interactive: bool` — when false, a MouseArea blocks all touches

---

## PlayerCard.qml

Three-state collapsible player card anchored to screen bottom.

**Props**:
- `playerState: string` — current state (set by parent)

**Signals**:
- `stateChangeRequested(newState: string)` — emitted on tap or drag-release

**States**:
- `collapsed` (15%): artwork + title + prev/play/next inline
- `half` (42%): artwork + info + progress + controls
- `expanded` (100%): full artwork + info + progress + controls + source selection

**Internal components**:
- `_IconBtn` — inline component: icon button with press feedback
- `_SourceBtn` — inline component: source selector button (BT/USB/Radio)

---

## NavigationOverlay.qml

Top card shown when `Nav.active === true`. Displays direction icon, instruction, and distance.

**Binds to**: Nav.active, Nav.instruction, Nav.distance, Nav.direction

---

## NotificationLayer.qml

Floating toast stack at top of screen. Stacks vertically, newest first.

**Methods**:
- `show(message: string, type: string)` — types: "info" (default), "warning", "error"

Auto-dismisses after 4 seconds. Fades out (300ms) then removes from model.

---

## GlobalInputBlocker.qml

Transparent full-screen overlay. Active when player is not collapsed. Captures touches that would otherwise reach MapView.

**Props**:
- `active: bool`

**Signals**:
- `dismissed()` — emitted when user taps outside the player (i.e., on this blocker)

---

## SvgIcon.qml (ui/components/)

Colorizable SVG icon primitive. Uses `MultiEffect.colorization` to tint monochrome white SVGs to any color at runtime.

**Props**:
- `source: url` — SVG file (e.g., `"qrc:/icons/play.svg"`)
- `color: color` — target tint color (default: `System.textPrimary`)
- `size: real` — icon size in px (default: 24, applies to both width and height)
