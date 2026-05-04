# Architecture

## High-level structure

```
src/elise/
├─ main.cpp                  # Engine bootstrap, registers controllers
├─ core/                     # C++ controllers exposed to QML as context props
│   ├─ SystemController.*    # Color tokens, dark/light mode
│   ├─ PlayerController.*    # Music daemon HTTP client + QMediaPlayer
│   └─ NavigationController.*# Turn-by-turn nav state
├─ ui/                       # QML module `Elise`
│   ├─ Theme.qml             # SINGLETON: spacing/radius/font/icon tokens
│   ├─ Main.qml              # Root window, owns playerState, lays out layers
│   ├─ MapView.qml           # Background map (placeholder)
│   ├─ PlayerCard.qml        # 3-state media player
│   ├─ NavigationOverlay.qml # Top toast for next turn
│   ├─ NotificationLayer.qml # Toast stack at top of screen
│   ├─ GlobalInputBlocker.qml# Blocks map taps when player is open
│   ├─ Fab.qml               # Floating action button (settings cog)
│   ├─ Menu.qml              # Reusable full-screen menu surface
│   ├─ SettingsMenu.qml      # Settings menu instance built on Menu
│   └─ SvgIcon.qml           # Colorizable monochrome SVG icon
└─ icons/                    # White-fill SVGs colorized via MultiEffect
```

Controllers are exposed as Qt context properties named `System`, `Player`,
`Nav` (set in `main.cpp`).

## State model

The Window owns a single string `playerState ∈ { collapsed, half, expanded }`.
Components are purely controlled — `PlayerCard` emits `stateChangeRequested`
and never mutates its own state. The Window applies the new state, which in
turn drives anchor margins, z-order, opacity, etc.

```
[user gesture] ── Component ──▶ stateChangeRequested(s)
                                       │
                                       ▼
                            Window.playerState = s
                                       │
                                       ▼
            all bindings (height, z, anchors, blocker) re-evaluate
```

## Z-order layout

Items are stacked in the Window. `z` values:

| z     | Item                                                 |
|-------|------------------------------------------------------|
|   0   | MapView (always behind)                              |
|  50   | GlobalInputBlocker (active when player ≠ collapsed)  |
| 600   | Fab (settings cog)                                   |
| 700   | PlayerCard (collapsed / half)                        |
| 800   | NavigationOverlay                                    |
| 900   | PlayerCard (expanded — promoted above nav)           |
| 1000  | NotificationLayer                                    |
| 1100  | InputPanel (Qt Virtual Keyboard)                     |
| 1200  | SettingsMenu (full-screen, drag-to-dismiss)          |

The PlayerCard's z is dynamic: 700 normally, 900 when fully expanded, so the
expanded card covers NavigationOverlay (which would otherwise float on top).
The Fab sits at z=600 below the PlayerCard so the expanded card visually
covers it as it grows.

## Backend wiring (PlayerController)

```
elise (QML) ──HTTP──▶ hermes-music (FastAPI on 127.0.0.1:8765)
              ▲
              │ /resolve, /played, /home, /search, /status
              ▼
        local sqlite + yt-dlp + audio cache
```

Stream URLs are resolved on demand from a track ID, then handed to
`QMediaPlayer` (lazy-initialized on first use to avoid GStreamer crashing at
startup before the daemon is ready).

`PlayerController` polls `/status` every 8 s while idle so the QML side knows
when the daemon comes up.

## Input handling on Wayland / cage

The Pi runs `cage` (single-app wlroots compositor). Touch input is the
WaveShare WS170120 (`0eef:0005`). cage logs

```
Input device WaveShare WS170120 cannot be mapped to an output device
```

This is informational — touch events still reach Qt as `wl_touch` events and
synthesized pointer events, so MouseAreas work. A udev rule under
`board/hermes-pi5/rootfs-overlay/etc/udev/rules.d/` may set
`ENV{WL_OUTPUT}="HDMI-A-1"` to silence the warning if multi-output ever
becomes a real problem.

## Why no global tap overlay any more

Earlier iterations placed a `MouseArea` at the Window level on top of the
player to intercept "expand bar" taps. Two problems:

1. Qt Quick's `pressed` event always accepts and never propagates — the
   player's own button MouseAreas (play/pause) never received their press,
   so the bar expanded but buttons did nothing.
2. The overlay had to know the player's height and exclude the buttons area —
   coupling that ought not exist between sibling components.

The current design puts tap zones *inside* `PlayerCard`. Tap zones are
declared **first** within their parent so child button MouseAreas (declared
after) win the hit test. Buttons fire their actions; everything else falls
through to the tap zone, which emits the state change. See
[interactions.md](interactions.md).
