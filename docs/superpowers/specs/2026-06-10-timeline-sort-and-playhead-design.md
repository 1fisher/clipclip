# Timeline Track Sorting & Playhead Enhancement Design

## Summary
Two targeted improvements to the clipclip video editor timeline:
1. Sort tracks by type (video first, audio second) instead of by insertion order
2. Fix the red playhead to be smoothly draggable with playback-seeking on both handle drag and timeline background drag/tap

## Changes

### 1. Track Sorting (`EditorViewModel`)
- `refreshTracks()`: Sort tracks with all `.video` tracks first (by orderIndex), then all `.audio` tracks (by orderIndex)
- `addTrack()`: Assign new orderIndex based on position within the same type group
- `ensureDefaultTracks()`: Keep video at 0, audio at 1 (already correct)

### 2. Playhead Drag & Timeline Seek (`TimelineView`, `PlayheadView`)
- Connect PlayheadView's `onDrag` to call `seekToPlayheadPosition(x:)` on the ViewModel
- Add a background drag gesture on the timeline track area that:
  - Sets `isPlayheadDragging = true` on drag start
  - Calls `seekToPlayheadPosition(x:)` during drag
  - Sets `isPlayheadDragging = false` on drag end
- The existing `timeObserver` already respects `isPlayheadDragging` to avoid fighting with user drag

### Files Modified
| File | What changes |
|------|-------------|
| `EditorViewModel.swift` | Track sorting logic, addTrack index assignment |
| `TimelineView.swift` | Playhead drag callback wiring, background drag gesture |
| `PlayheadView.swift` | No changes needed (already has drag gesture) |
