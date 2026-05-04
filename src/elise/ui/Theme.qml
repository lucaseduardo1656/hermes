pragma Singleton
import QtQuick

// Design tokens for Elise UI.
// Colors live in `System` (C++ controller). Everything else here.
QtObject {
    // ── Spacing (4-pt grid) ───────────────────────────────────────────────────
    readonly property int spaceXS:   4
    readonly property int spaceS:    8
    readonly property int spaceM:    12
    readonly property int spaceL:    16
    readonly property int spaceXL:   20
    readonly property int spaceXXL:  24
    readonly property int space3XL:  32

    // ── Corner radii ──────────────────────────────────────────────────────────
    readonly property int radiusS:   8
    readonly property int radiusM:   12
    readonly property int radiusL:   14
    readonly property int radiusXL:  18

    // ── Font sizes (semantic) ─────────────────────────────────────────────────
    readonly property int fontTiny:     10
    readonly property int fontCaption:  11
    readonly property int fontSmall:    12
    readonly property int fontBody:     13
    readonly property int fontLabel:    14
    readonly property int fontMedium:   15
    readonly property int fontLarge:    16
    readonly property int fontTitle:    18
    readonly property int fontDisplay:  20

    // ── Icon sizes ────────────────────────────────────────────────────────────
    readonly property int iconXS:    14
    readonly property int iconS:     18
    readonly property int iconM:     22
    readonly property int iconL:     26
    readonly property int iconXL:    32

    // ── Animation durations (ms) ──────────────────────────────────────────────
    readonly property int durFast:    150
    readonly property int durNormal:  220
    readonly property int durSlow:    260
    readonly property int durSlower:  300

    // ── Standard tappable sizes ───────────────────────────────────────────────
    readonly property int btnSmall:   36
    readonly property int btnMedium:  44
    readonly property int btnLarge:   56
    readonly property int btnXLarge:  64

    // ── Player card geometry ──────────────────────────────────────────────────
    readonly property int playerCollapsedH:   88     // bottom bar height
    readonly property int playerHalfH:        180    // info-row height
    readonly property int playerSideInset:    12     // left/right gap from screen
    readonly property int playerCollapsedArt: 40     // thumbnail in collapsed bar
    readonly property int playerExpandedArt:  76     // artwork in expanded view
    readonly property int playerGridArt:      110    // grid item size

    // ── Gestures ──────────────────────────────────────────────────────────────
    readonly property int dragSnapVelocity:  600     // px/s to trigger fast snap

    // ── Drag pill indicator (top of cards/menus) ──────────────────────────────
    readonly property int dragPillW:    36
    readonly property int dragPillH:    4
    readonly property int dragPillR:    2

    // ── Menu surface ──────────────────────────────────────────────────────────
    readonly property int menuHeaderH:  64

    // ── Hairlines ─────────────────────────────────────────────────────────────
    readonly property int borderHairline: 1

    // ── Progress bar ──────────────────────────────────────────────────────────
    readonly property int progressBarH:    3
    readonly property real progressBarR:   1.5
    readonly property int progressRowH:    14    // hit-target height around the bar
    readonly property int progressTickMs:  500   // width animation cadence

    // ── Tabs / search field ───────────────────────────────────────────────────
    readonly property int tabH:        32
    readonly property int searchFieldW: 260

    // ── Navigation overlay ────────────────────────────────────────────────────
    readonly property int navOverlayH:  90    // total slot in window
    readonly property int navCardH:     64    // visible card inside the slot
    readonly property int navBadge:     40    // direction-icon badge size

    // ── Toast notifications ───────────────────────────────────────────────────
    readonly property int toastH:           48
    readonly property int toastSpacing:     6
    readonly property int toastSlideOffset: 60   // slide-in start y

    // ── Settings menu ─────────────────────────────────────────────────────────
    readonly property int settingsSidebarW:    220   // left navigation width
    readonly property int settingsSidebarItem: 52    // sidebar row height
    readonly property int settingsSummaryH:    56    // top summary bar height
    readonly property int settingsRowH:        56    // standard list-row height
    readonly property int statusDot:           8     // small status indicator
}




