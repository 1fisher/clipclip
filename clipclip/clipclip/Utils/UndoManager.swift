import Foundation

/// Simple snapshot-based undo/redo manager for project state.
final class ProjectUndoManager {
    private let maxStackSize: Int
    private var undoStack: [[TrackSnapshot]] = []
    private var redoStack: [[TrackSnapshot]] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init(maxStackSize: Int = 50) {
        self.maxStackSize = maxStackSize
    }

    /// Captures the current state before performing an operation.
    func captureState(tracks: [TrackSnapshot]) {
        undoStack.append(tracks)
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    /// Undo: returns the previous state, saving current to redo.
    func undo(current tracks: [TrackSnapshot]) -> [TrackSnapshot]? {
        guard !undoStack.isEmpty else { return nil }
        redoStack.append(tracks)
        return undoStack.removeLast()
    }

    /// Redo: returns the next state, saving current to undo.
    func redo(current tracks: [TrackSnapshot]) -> [TrackSnapshot]? {
        guard !redoStack.isEmpty else { return nil }
        undoStack.append(tracks)
        return redoStack.removeLast()
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

/// Lightweight snapshot of a clip for undo/redo.
struct ClipSnapshot: Equatable {
    let id: UUID
    let assetLocalIdentifier: String
    let startTime: Double
    let endTime: Double
    let sortIndex: Int
    let trackID: UUID

    init(clip: Clip) {
        self.id = clip.id
        self.assetLocalIdentifier = clip.assetLocalIdentifier
        self.startTime = clip.startTime
        self.endTime = clip.endTime
        self.sortIndex = clip.sortIndex
        self.trackID = clip.track?.id ?? UUID()
    }
}

/// Lightweight snapshot of a track for undo/redo.
struct TrackSnapshot: Equatable {
    let id: UUID
    let type: TrackType
    let orderIndex: Int
    let isMuted: Bool
    let clips: [ClipSnapshot]

    init(track: Track) {
        self.id = track.id
        self.type = track.type
        self.orderIndex = track.orderIndex
        self.isMuted = track.isMuted
        self.clips = track.clips
            .sorted(by: { $0.sortIndex < $1.sortIndex })
            .map(ClipSnapshot.init)
    }
}
