# Architecture

## Overview

Elise is a state-driven car infotainment UI. The map is always the base layer; all UI elements are floating overlays with explicit z-ordering.

## Layer Stack

| Z     | Component          | Role                                      |
|-------|--------------------|-------------------------------------------|
| 0     | MapView            | Fullscreen base, always rendered          |
| 50    | GlobalInputBlocker | Prevents map interaction when UI is open  |
| 700   | PlayerCard         | Mini/half player (collapsed & half states)|
| 800   | NavigationOverlay  | Turn-by-turn card (top of screen)         |
| 900   | PlayerCard         | Full player (expanded state, bumped up)   |
| 1000  | NotificationLayer  | Auto-dismissing toast cards               |
| 1100  | InputPanel         | Virtual keyboard                          |

## State Model

`Main.qml` owns the single `playerState: string` property:

```
"collapsed" → "half" → "expanded"
```

Child components signal requested state changes via `stateChangeRequested(string)`. `Main.qml` accepts and propagates the new state down.

## Directory Structure

```
src/elise/
├── core/               C++ controllers (logic only, no UI)
│   ├── SystemController   Theme + system state
│   ├── PlayerController   Playback + daemon HTTP client
│   └── NavigationController  Navigation state (stub)
├── ui/                 QML components (UI only, no logic)
│   ├── Main.qml           Root window + layer orchestration
│   ├── MapView.qml        Map base layer
│   ├── PlayerCard.qml     Collapsible player card
│   ├── NavigationOverlay.qml  Turn card
│   ├── NotificationLayer.qml  Toast stack
│   ├── GlobalInputBlocker.qml Input guard
│   └── components/
│       └── SvgIcon.qml    Colorizable icon primitive
├── icons/              Monochrome white SVG icons
└── docs/               This documentation
```

## Controller Pattern

Controllers are C++ QObjects registered as QML context properties:

- `System` → SystemController (theme colors, dark/light toggle)
- `Player` → PlayerController (playback state, daemon API client)
- `Nav`    → NavigationController (navigation state)

QML binds to their Q_PROPERTYs and calls their Q_SLOTs. No business logic lives in QML.

## Build

Cross-compiled for aarch64 via Buildroot. Build dir: `/tmp/hermes-cross-build/`.

```bash
cd /tmp/hermes-cross-build
/path/to/buildroot/output/host/bin/qt-cmake \
  -DQT_CHAINLOAD_TOOLCHAIN_FILE=.../toolchainfile.cmake \
  -DQT_ADDITIONAL_PACKAGES_PREFIX_PATH=.../staging/usr \
  /path/to/src/elise
make -j$(nproc)
scp -O elise root@192.168.0.100:/usr/bin/elise
```
