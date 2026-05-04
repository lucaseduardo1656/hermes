# Theming

Two layers:

1. **`Theme.qml`** (QML singleton) — non-color tokens (sizes, durations, etc.)
2. **`System`** (C++ controller, exposed as context property) — color tokens
   that switch between dark and light themes at runtime

## Color tokens (`System.<token>`)

| Token            | Dark            | Light           | Usage                     |
|------------------|-----------------|-----------------|---------------------------|
| `background`     | #0A0A0A         | #F5F5F5         | Window base               |
| `surface`        | #1C1C1C         | #FFFFFF         | Card backgrounds          |
| `surface2`       | #2A2A2A         | #EBEBEB         | Secondary surfaces        |
| `accent`         | #C6A75E         | #C6A75E         | Brand gold (constant)     |
| `accentDim`      | #9A7F44         | #9A7F44         | Pressed accent            |
| `textPrimary`    | #EAEAEA         | #111111         | Main text                 |
| `textSecondary`  | #909090         | #555555         | Supporting text           |
| `textMuted`      | #555555         | #999999         | Timestamps, metadata      |
| `textDisabled`   | #333333         | #BBBBBB         | Inactive labels           |
| `border`         | #2E2E2E         | #DDDDDD         | Dividers, card edges      |
| `overlay`        | rgba(0,0,0,180) | rgba(0,0,0,80)  | Modal backdrops           |
| `pressOverlay`   | rgba(255,255,255,18) | (same)     | Pressed-state tint        |

Switch theme:

```qml
System.darkTheme = false   // light
System.darkTheme = true    // dark (default)
```

All bindings to `System.<token>` update automatically via the `themeChanged`
signal.

## Non-color tokens (`Theme.<token>`)

### Spacing — 4-pt grid

| Token       | Value |
|-------------|-------|
| `spaceXS`   | 4     |
| `spaceS`    | 8     |
| `spaceM`    | 12    |
| `spaceL`    | 16    |
| `spaceXL`   | 20    |
| `spaceXXL`  | 24    |
| `space3XL`  | 32    |

### Corner radii

| Token       | Value |
|-------------|-------|
| `radiusS`   | 8     |
| `radiusM`   | 12    |
| `radiusL`   | 14    |
| `radiusXL`  | 18    |

### Font sizes (semantic)

| Token         | Value | Typical use                    |
|---------------|-------|--------------------------------|
| `fontTiny`    | 10    | Smallest meta                  |
| `fontCaption` | 11    | Captions, timestamps           |
| `fontSmall`   | 12    | Secondary body                 |
| `fontBody`    | 13    | Body text                      |
| `fontLabel`   | 14    | Form labels, list items        |
| `fontMedium`  | 15    | Emphasized labels              |
| `fontLarge`   | 16    | Tab labels                     |
| `fontTitle`   | 18    | Card titles, menu titles       |
| `fontDisplay` | 20    | Hero text (track title etc.)   |

### Icon sizes

| Token     | Value |
|-----------|-------|
| `iconXS`  | 14    |
| `iconS`   | 18    |
| `iconM`   | 22    |
| `iconL`   | 26    |
| `iconXL`  | 32    |

### Animation durations (ms)

| Token        | Value | Use                           |
|--------------|-------|-------------------------------|
| `durFast`    | 150   | Pressed-state color flash     |
| `durNormal`  | 220   | Most transitions              |
| `durSlow`    | 260   | State changes (height etc.)   |
| `durSlower`  | 300   | Toast fade-out                |

### Tappable sizes

| Token       | Value |
|-------------|-------|
| `btnSmall`  | 36    |
| `btnMedium` | 44    |
| `btnLarge`  | 56    |
| `btnXLarge` | 64    |

### Player card geometry

| Token                | Value | Meaning                                       |
|----------------------|-------|-----------------------------------------------|
| `playerCollapsedH`   | 88    | Height of the bottom bar                      |
| `playerHalfH`        | 180   | Height of the half-expanded info card         |
| `playerSideInset`    | 12    | Left/right gap from screen when not expanded  |
| `playerCollapsedArt` | 40    | Thumbnail in the collapsed bar                |
| `playerExpandedArt`  | 76    | Artwork in the expanded view                  |
| `playerGridArt`      | 110   | Album squares in browse grids                 |

### Drag pill / menu / hairlines

| Token              | Value | Use                                  |
|--------------------|-------|--------------------------------------|
| `dragPillW`        | 36    | Width of cosmetic drag indicator     |
| `dragPillH`        | 4     | Height of drag indicator             |
| `dragPillR`        | 2     | Corner radius of drag indicator      |
| `menuHeaderH`      | 64    | Height of `Menu` header bar          |
| `borderHairline`   | 1     | 1-px border / divider                |
| `dragSnapVelocity` | 600   | px/s threshold for fast snap (unused yet) |

## Authoring rules

- **Never** hard-code spacing, radius, font, icon size, duration, or button
  height in component QML. Use a Theme token. Add a token if none fits.
- **Never** hard-code a color. Use `System.<token>`. Add a `Q_PROPERTY` to
  `SystemController` if a new color is genuinely needed (and confirm it
  works in both dark and light).
- The brand accent gold (`System.accent`) is used sparingly: play/pause
  background, progress bar fill, nav distance text, active nav direction
  icon. Avoid for general UI surfaces.

## SVG icon convention

Icons under `src/elise/icons/` are monochrome `fill="white"` SVGs. `SvgIcon`
applies `MultiEffect.colorization` to recolor them to any token at runtime.
Stroke-based icons will not colorize correctly — convert to fills before
adding.
