# Elise — Documentation

Qt 6 / QML car infotainment frontend running on Raspberry Pi 5 under cage.

## Index

- [architecture.md](architecture.md) — overview, controllers, state model, z-order
- [components.md](components.md) — every QML component and its public API
- [theming.md](theming.md) — Theme tokens (spacing/radii/fonts/icons) and System colors
- [interactions.md](interactions.md) — gestures, state transitions, hit-testing model
- [build-deploy.md](build-deploy.md) — cross-compile and deploy to the Pi

## Source layout

```
src/elise/
├─ main.cpp        # engine bootstrap
├─ core/           # C++ controllers (System, Player, Navigation)
├─ ui/             # QML module `Elise` (Theme is a singleton)
└─ icons/          # white-fill SVGs colorized at runtime
```

Docs live outside `src/` so they are never copied into the build tree or the
target image.
