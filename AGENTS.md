# AGENTS.md — ClipClip Video Editor

## Project Overview

ClipClip is a **macOS-native multi-track video editor** built with SwiftUI, SwiftData, and AVFoundation. It supports importing video files, arranging clips on a multi-track timeline (video + audio), trimming, splitting, joining clips, and exporting the final composition as MP4. The UI is in **Chinese (中文)** for user-facing strings.

The Xcode project lives inside the `clipclip/` subdirectory. All source paths below are relative to `clipclip/clipclip/`.

## Build & Run

```
# Open the project
open clipclip/clipclip.xcodeproj

# Build from CLI
xcodebuild -project clipclip/clipclip.xcodeproj -scheme clipclip build

# Run tests
xcodebuild -project clipclip/clipclip.xcodeproj -scheme clipclip test
```

- Target: macOS (uses `NSViewRepresentable`, `AVPlayerView`, `NSImage`, `AppKit`)
- Swift version: Swift 5+ with async/await, SwiftUI `@Observable` macro
- Minimum deployment target is set in the Xcode project (macOS 14+ implied by `@Observable` and SwiftData features)

## Architecture

### Data Layer (SwiftData `@Model`)

| Model | File | Description |
|-------|------|-------------|
| `Project` | `Models/Project.swift` | Top-level container. Has `tracks: [Track]` (cascade delete). Persisted via SwiftData. |
| `Track` | `Models/Track.swift` | A video or audio track. Has `type` (`.video` / `.audio`), `orderIndex`, `isMuted`, `clips: [Clip]` (cascade delete). Belongs to a `Project`. |
| `Clip` | `Models/Clip.swift` | A media clip on a track. Key fields: `assetLocalIdentifier` (filename in ImportedVideos), `startTime`/`endTime` (trim range within the source asset), `sortIndex` (order in track), `speed`, `volume`. Belongs to a `Track`. |

**Relationships**: `Project →[cascade] Track →[cascade] Clip`. Each child has a back-reference (`clip.track`, `track.project`).

### ViewModel Layer (`@Observable`)

| ViewModel | File | Role |
|-----------|------|------|
| `EditorViewModel` | `ViewModels/EditorViewModel.swift` | Central brain of the editor. Owns `AVPlayer`, manages tracks/clips, handles playback, trim, split, join, move, undo/redo. ~550 lines. |
| `ExportViewModel` | `ViewModels/ExportViewModel.swift` | Wraps `VideoExporter`, tracks export state/progress. |
| `ProjectListViewModel` | `ViewModels/ProjectListViewModel.swift` | CRUD for projects via SwiftData `ModelContext`. |

### Engine Layer

| Class | File | Role |
|-------|------|------|
| `VideoComposer` | `Engines/VideoComposer.swift` | Builds `AVMutableComposition` from tracks/clips. Has both multi-track and legacy single-track APIs. Uses `VideoResolver` typealias `(Clip) -> URL`. |
| `VideoExporter` | `Engines/VideoExporter.swift` | Exports composition to MP4 via `AVAssetExportSession`. Reports progress through `ExportState` enum. |
| `ThumbnailGenerator` | `Engines/ThumbnailGenerator.swift` | Generates `NSImage` thumbnails at specific timestamps using `AVAssetImageGenerator`. |

### View Layer (SwiftUI)

**Navigation**: `clipclipApp` → `ContentView` (NavigationStack) → `ProjectListView` → `VideoEditorView`

**Main Editor Layout** (`VideoEditorView`): Three-panel layout with responsive wide/narrow variants (breakpoint at 600px width):
- **Left**: `MaterialImportView` — imported clip list
- **Center**: `PreviewPlayerView` — video preview with custom seek bar
- **Right**: `CameraControlView` — multi-camera angle selector
- **Bottom**: `TimelineView` — multi-track timeline with ruler, playhead, clip drag/drop

**Timeline components**:
- `TimelineView` → `TrackRowView` → `TimelineClipView` (per clip, with waveform/thumbnails)
- `TimelineRulerView` — time scale ruler above tracks
- `PlayheadView` — draggable red playhead line
- `TrackHeaderView` — track name, mute toggle, delete
- `TrimHandleView` — drag handles for clip trimming (leading/trailing)
- `WaveformView` — Canvas-based waveform renderer for audio clips

### Utility Layer

| File | Contents |
|------|----------|
| `Utils/UndoManager.swift` | `ProjectUndoManager` with snapshot-based undo/redo (max 50 states). Uses `TrackSnapshot` / `ClipSnapshot` value types. |
| `Utils/CMTime+Extensions.swift` | `formatted` (MM:SS / HH:MM:SS display), `formattedDuration` on `Double`. |
| `Models/WaveformCache.swift` | Singleton `NSCache`-based waveform data cache (limit 50 entries). Async generation from audio files. |

## Key Patterns & Gotchas

### Video File Storage
- Imported videos are **copied** to `~/Documents/ImportedVideos/` with UUID filenames (`{UUID}.mp4`).
- `Clip.assetLocalIdentifier` stores the **filename only** (not a full path). Use `EditorViewModel.videoURL(for:)` to resolve the full path.
- Security-scoped resource access (`startAccessingSecurityScopedResource`) is handled during import in `EditorViewModel.addClip(from:)`.

### Track Sorting Convention
- Tracks are always sorted: **all video tracks first** (by `orderIndex`), then **all audio tracks** (by `orderIndex`). This is enforced in `refreshTracks()`.
- Each project always has at least one video and one audio track (`ensureDefaultTracks()`). Deleting the last track of a type is prevented.

### Clip Positioning
- Clips are positioned **sequentially** within a track using `sortIndex`. There is no explicit start-position field — clip layout is purely sort-order based.
- `sortIndex` is manually managed (incremented/decremented) on split, delete, move, and join operations. Be careful to keep indices consistent.
- Clip `startTime`/`endTime` represent the trim range **within the source asset** (not timeline position).

### Player Refresh Pattern
- `refreshTracks()` → `refreshPlayer()` rebuilds the entire `AVMutableComposition` on **every** structural change (add/delete/move clip, trim, mute toggle).
- During refresh, playback state (playing/paused, current time) is preserved.
- The `VideoComposer` has both a multi-track API (`tracks:`) and a legacy flat-clips API (`clips:`). New code should use the multi-track API.

### Undo/Redo
- Uses snapshot-based undo via `ProjectUndoManager` (not SwiftUI's built-in undo).
- `captureUndo()` must be called **before** mutating state. It snapshots all tracks/clips.
- `undo()`/`redo()` restore from snapshots and call `refreshTracks()`.

### Timeline Rendering Constants
- `trackHeight: CGFloat = 48` and `trackSpacing: CGFloat = 4` are defined as **global constants** in `TrackHeaderView.swift` and used throughout timeline views.
- `timeScale` (pixels per second, default 100, range 30–300) controls timeline zoom. It lives on `EditorViewModel`.

### Join Logic
- Two clips can be joined only if: same track, same `assetLocalIdentifier`, and their time boundaries are within 0.1 seconds of each other.
- `findJoinCandidate(for:)` checks both previous and next clips.

### Split Minimum Size
- Split requires at least 0.5 seconds on each side of the split point.

### Drag & Drop
- Clip dragging uses `DragGesture(minimumDistance: 2)` (instant drag, no long-press required).
- Cross-track moves are allowed only between tracks of the **same type** (video→video, audio→audio).
- After a move, auto-join is attempted with animation.

### Sandbox
- App is sandboxed (`com.apple.security.app-sandbox = true`).
- Has read-write access to user-selected files (`files.user-selected.read-write`).

### UI Language
- All user-facing strings are in **Chinese** (e.g., "素材导入", "添加素材", "视频轨道", "机位控制", "分割", "拼接", "导出完成!").
- Code identifiers and comments are in English.

### Testing
- Uses Swift Testing framework (`import Testing`, `@Test func`, `#expect`), **not** XCTest.
- Test target: `clipclipTests` — currently only a placeholder test.
- UI test target: `clipclipUITests`.

### Preview Provider
- `clipclipApp` is the `@main` entry point. Default window size is 1200×800.
- `ModelContainer` is configured with `Project`, `Track`, `Clip` in the schema. On load failure, it deletes the existing store and retries.
- `#Preview` blocks use `inMemory: true` model containers.

### Global Track Color Convention
- Video tracks: `Color.accentColor` (blue)
- Audio tracks: `Color.green`
- This convention is repeated per-view (not centralized). If changing track colors, search for `track.type == .video` color assignments.

### Design Specs
- Active design docs live in `docs/superpowers/specs/` and describe planned changes with file-level impact tables.
