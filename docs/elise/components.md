# Components

All QML components live in `src/elise/ui/` and are registered as the `Elise`
QML module. Import with `import Elise`.

---

## Theme (singleton)

`Theme.qml` — design tokens. Access via `Theme.<token>` from any QML file.

Categories:

- **Spacing** (4-pt grid): `spaceXS`, `spaceS`, `spaceM`, `spaceL`, `spaceXL`,
  `spaceXXL`, `space3XL`
- **Radii**: `radiusS`, `radiusM`, `radiusL`, `radiusXL`
- **Fonts**: `fontTiny`, `fontCaption`, `fontSmall`, `fontBody`, `fontLabel`,
  `fontMedium`, `fontLarge`, `fontTitle`, `fontDisplay`
- **Icons**: `iconXS`, `iconS`, `iconM`, `iconL`, `iconXL`
- **Durations**: `durFast`, `durNormal`, `durSlow`, `durSlower`
- **Tappable sizes**: `btnSmall`, `btnMedium`, `btnLarge`, `btnXLarge`
- **Player geometry**: `playerCollapsedH`, `playerHalfH`, `playerSideInset`,
  `playerCollapsedArt`, `playerExpandedArt`, `playerGridArt`
- **Drag pill**: `dragPillW`, `dragPillH`, `dragPillR`
- **Menu**: `menuHeaderH`
- **Misc**: `dragSnapVelocity`, `borderHairline`

Colors are NOT in Theme — they live in `System` (C++). See
[theming.md](theming.md).

---

## Main.qml

Root `Window`. Owns `playerState` (string). Lays out all layers by z-order
and propagates state changes from children.

**Properties**: `playerState ∈ { collapsed, half, expanded }`

---

## MapView

Fullscreen map base layer. Currently a placeholder gradient.

**Props**: `interactive: bool` — when false, a MouseArea blocks all touches.

---

## PlayerCard

Three-state collapsible media player anchored to the bottom of the screen.

**Props**: `playerState: string` — controlled by parent  
**Signals**: `stateChangeRequested(newState: string)`

**States**:
- `collapsed` (`Theme.playerCollapsedH`): artwork + title + transport
- `half` (`Theme.playerHalfH`): top section of expanded layout (info row only)
- `expanded` (full screen): info row + tabs + browse grids

**Drag**: a root-level `DragHandler` lets the user swipe the card up/down.
Snaps to nearest state by position on release. DragHandler does not fire on
taps (only on actual translation), so internal MouseAreas keep working.

**Tap zones** (one per view):
- `_collapsedView` — full-bar `MouseArea` declared first → buttons declared
  after the Row win their hits, the rest goes to the tap zone (→ half).
- `_expandedView` top section — `MouseArea` covering left+center area only
  (excludes the controls Row) → fires only when state is `half` (→ expanded).

**Inline components**:
- `IconBtn` — square tappable icon with subtle pressed-state background
- `BrowseSection` — heading + horizontal Repeater grid (used for FAVORITES /
  TOP STATIONS placeholder content)

---

## NavigationOverlay

Top toast card showing the next turn-by-turn instruction. Visible whenever
`Nav.active` is true. Reads `Nav.instruction`, `Nav.distance`, `Nav.direction`.

---

## NotificationLayer

Stack of toasts at the top of the screen. Newest first, slides in from above,
auto-dismisses after 4 s with a fade.

**Method**: `show(message: string, type?: "info" | "warning" | "error")`

---

## GlobalInputBlocker

Transparent full-screen overlay that catches taps when active. Used to
dismiss the player by tapping outside it.

**Props**: `active: bool`  
**Signals**: `dismissed()` — emitted when user taps the blocker

In Main.qml the blocker is sized to cover only the area *above* the player
card (`height: parent.height - _player.height`) so tapping inside the player
never dismisses it.

---

## SvgIcon

Colorizable monochrome SVG primitive. Uses `MultiEffect.colorization` to
tint a white-fill SVG to any color at runtime.

**Props**:
- `source: url` — SVG file (e.g. `"qrc:/icons/play.svg"`)
- `color: color` — target tint (default `System.textPrimary`)
- `size: real` — applied to both width and height (default 24)

All shipped icons must be `fill="white"` (not stroke) for colorization to
work.

---

## Fab

Circular floating action button. Default-styled in `System.accent` with a
hairline shadow ring. Used for primary entry points (e.g. opening Settings).

**Props**:
- `icon: url`
- `color: color` (default `System.accent`)
- `size: int` (default `Theme.btnMedium`)

**Signals**: `clicked()`

---

## Menu

Reusable full-screen menu surface. Animates in from the bottom and supports
drag-down-to-dismiss from the header.

**Props**:
- `title: string` — shown centered in the header
- `open: bool` — toggle to show/hide
- default property `content` — slot any QML inside; it fills the area below
  the header

**Signals**: `closed()` — emitted on chevron-down or successful drag dismissal

**Behavior**:
- Closed → menu sits at `y = parent.height` (off-screen below)
- Open → menu animates to `y = 0`
- Drag down on the header beyond 30 % of viewport height → dismiss; else snap
  back open
- Header height: `Theme.menuHeaderH`

---

## SettingsMenu

`Menu` instance with placeholder sections (`GERAL`, `CONECTIVIDADE`).
Concrete actions wire here later.

```qml
SettingsMenu { id: _settings; z: 1200 }
// elsewhere: _settings.open = true
```
