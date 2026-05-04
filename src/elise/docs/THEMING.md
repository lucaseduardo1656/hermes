# Theming

## Color Tokens

Accessed in QML as `System.<token>`.

| Token          | Dark           | Light          | Notes                   |
|----------------|----------------|----------------|-------------------------|
| background     | #0A0A0A        | #F5F5F5        | Window base             |
| surface        | #1C1C1C        | #FFFFFF        | Card backgrounds        |
| surface2       | #2A2A2A        | #EBEBEB        | Secondary surfaces      |
| accent         | #C6A75E        | #C6A75E        | Brand gold, never changes |
| accentDim      | #9A7F44        | #9A7F44        | Pressed accent state    |
| textPrimary    | #EAEAEA        | #111111        | Main text               |
| textSecondary  | #909090        | #555555        | Supporting text         |
| textMuted      | #555555        | #999999        | Timestamps, metadata    |
| textDisabled   | #333333        | #BBBBBB        | Inactive labels         |
| border         | #2E2E2E        | #DDDDDD        | Dividers, card edges    |
| overlay        | rgba(0,0,0,180)| rgba(0,0,0,80) | Modal backdrops         |
| pressOverlay   | rgba(255,255,255,18) | (same)   | Pressed state tint      |

## Switching Themes

```qml
System.darkTheme = false  // switch to light
System.darkTheme = true   // switch to dark (default)
```

All bindings on `System.<token>` update automatically via `themeChanged()` signal.

## SVG Icon System

Icons are monochrome white SVGs (`fill="white"`).

`SvgIcon` component applies colorization via `MultiEffect.colorization`:

```qml
SvgIcon {
    source: "qrc:/icons/play.svg"
    color:  System.accent       // gold
    size:   24
}
```

When `System.darkTheme` changes, update `SvgIcon.color` binding to automatically adapt.

## Accent Color Usage

The gold accent (`#C6A75E`) is used sparingly:
- Active play/pause button background
- Progress bar fill
- Navigation distance text
- Active nav direction icon
- Notification: never (use surface colors instead)

## Typography

| Role       | Size | Weight      |
|------------|------|-------------|
| Track title| 15–18px | Medium (500) |
| Artist     | 12–13px | Normal (400) |
| Album      | 11px    | Normal (400) |
| Timestamp  | 10–11px | Normal (400) |
| Nav label  | 13px    | Medium (500) |
| Nav distance | 12px  | Medium (500) |
