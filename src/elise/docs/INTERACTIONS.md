# Interactions

## Player State Transitions

```
collapsed (15% height)
    │  drag up / tap
    ▼
half (42% height)
    │  drag up / tap
    ▼
expanded (100% height)
```

Reverse: drag down or tap drag handle. From expanded, "back" goes to half (never directly to collapsed).

## Drag Gesture

- **Drag handle**: top 52px strip of PlayerCard
- **During drag**: card height tracks finger in real-time (no animation)
- **On release**: snaps to nearest state with 260ms InOutCubic animation

### Snap Logic

```
velocity > 600 px/s  →  snap down (one level)
velocity < -600 px/s →  snap up (one level)
else:
  height < 28% screen → collapsed
  height < 72% screen → half
  height ≥ 72% screen → expanded
```

### Tap (no drag, < 8px movement)

| Current state | Result    |
|---------------|-----------|
| collapsed     | → half    |
| half          | → expanded|
| expanded      | → half    |

## Back Behavior

- Expanded → half (never skips to collapsed)
- Half → collapsed (via drag or global input blocker tap)
- Collapsed → stays (map is base)

## Map Interaction

MapView accepts gestures only when `playerState === "collapsed"`.

When player is half or expanded, `GlobalInputBlocker` (z:50) captures all touches above the player card. Tapping the blocker collapses the player to "collapsed".

## Notification Dismissal

- Auto-dismiss: 4 seconds
- Manual: tap ✕ button
- Each notification fades out (300ms) before removal

## Touch Targets

All interactive elements: minimum 44×44px.  
Play/pause buttons: 52×52px (half), 64×64px (expanded).  
Progress bars: hit area extended ±16px vertically.
