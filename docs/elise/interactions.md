# Interactions

How user input drives the state machine, and the rules that keep buttons
working without a global tap overlay.

## State transitions

```
                    tap on bar (non-button)         tap on info area
                  ┌─────────────────────────┐    ┌────────────────────┐
                  │                         ▼    ▼                    │
              ┌───┴───┐  drag up         ┌──────┐  drag up      ┌──────────┐
              │collap.│ ───────────────▶ │ half │ ────────────▶ │ expanded │
              └───────┘                  └──────┘               └──────────┘
                  ▲     chevron-down or     ▲    chevron-down       │
                  │     drag down or        │    or drag down       │
                  │     blocker tap         └────────────────────────┘
                  │
                  └────────────────── (close)
```

| From      | Trigger                                                       | To         |
|-----------|---------------------------------------------------------------|------------|
| collapsed | tap on bar (non-button area)                                  | half       |
| collapsed | drag up far enough to cross 28% / 72% of full height          | half / expanded |
| half      | tap on info area (artwork + title region of expanded layout)  | expanded   |
| half      | drag up                                                       | expanded   |
| half      | chevron-down in controls Row                                  | collapsed  |
| half      | tap on GlobalInputBlocker (anywhere above the card)           | collapsed  |
| half      | drag down                                                     | collapsed  |
| expanded  | chevron-down                                                  | half       |
| expanded  | drag down past 28% threshold                                  | half       |
| expanded  | drag down past 72% threshold                                  | collapsed  |
| expanded  | tap on GlobalInputBlocker (only the slim strip above card)    | collapsed  |

## Drag mechanics

`DragHandler` at the root of `PlayerCard` (`yAxis.enabled: true`):

- **Active**: the card's `_liveH` tracks the finger; `height` = `_liveH`
  while `_dragging` is true so the card resizes in real time without an
  animation Behavior fighting the input.
- **Released**: snap state is chosen by the final fraction of `_liveH /
  expandedH`:

  ```
  fraction < 0.28  → collapsed
  fraction < 0.72  → half
  otherwise        → expanded
  ```

  After choosing, `_snapH` is set and the height Behavior animates over
  `Theme.durSlow` (260 ms, `Easing.InOutCubic`).

- **Tap vs. drag**: `DragHandler` has its own internal threshold and only
  fires when the pointer translates beyond it. A simple tap does *not*
  trigger drag, so play/pause/skip buttons keep working.

## Hit-testing model

Qt Quick's `MouseArea.pressed` event always accepts and never propagates to
sibling MouseAreas. So the rule is:

> **Declare the tap zone first, declare child interactive items after.**
> Qt Quick stacks declared-later items above declared-earlier ones at the
> same depth. The buttons declared after the tap zone win the hit test on
> their footprint; everything else falls through to the tap zone.

Concrete examples:

### Collapsed bar

```qml
Item {
    id: _collapsedView

    MouseArea {                        // 1st child → lowest sibling z
        anchors.fill: parent
        onClicked: stateChangeRequested("half")
    }

    Row {                              // 2nd child → above the tap zone
        IconBtn { ... }                // wins taps on its rectangle
        Rectangle { /* play */ MouseArea { ... } }
        IconBtn { ... }
    }
}
```

### Expanded top section

```qml
Item {
    MouseArea {                        // tap zone, declared first
        anchors {
            left: parent.left
            right: _expControls.left   // does NOT cover controls Row
        }
        enabled: playerState === "half"
        onClicked: stateChangeRequested("expanded")
    }

    Rectangle { id: _expArt }
    Row { id: _expControls; ... }
    Column { /* info, contains scrub MouseArea */ }
}
```

The tap zone:

- Is anchored to exclude `_expControls` (so transport buttons receive their
  own taps directly, regardless of declaration order).
- Is gated `enabled: playerState === "half"` so taps in expanded state do
  nothing (the user is already at the top — they should hit the chevron to
  step down).

## Menu drag-to-dismiss

`Menu.qml`'s header hosts a `DragHandler`. While dragging, the menu's `y`
tracks the finger (down only). On release:

- Drag distance > 30 % of viewport height → emit `closed()` and snap to
  `y = parent.height`.
- Otherwise → snap back to `y = 0`.

The chevron-down button in the header is the explicit close affordance for
non-touch users (or anyone who prefers a tap).

## GlobalInputBlocker

Sized to cover only the screen area *above* the player card
(`height: parent.height - _player.height`). Tapping anywhere inside the
player never dismisses it; tapping above (the map area) does.

When the player is fully expanded, the blocker collapses to height 0 and
stops intercepting anything — the player handles its own dismiss via the
chevron and drag.
