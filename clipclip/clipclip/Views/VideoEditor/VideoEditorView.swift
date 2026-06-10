import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

/// Main video editor screen with multi-track timeline, preview, and track controls.
struct VideoEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let project: Project
    @State private var editorVM: EditorViewModel
    @State private var exportVM = ExportViewModel()
    @State private var isShowingExporter = false
    @State private var isShowingFilePicker = false
    @State private var exportedVideoURL: URL?
    @State private var isShowingSaveDialog = false

    init(project: Project) {
        self.project = project
        self._editorVM = State(initialValue: EditorViewModel(project: project))
    }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > 600

            if isWide {
                wideLayout(width: geometry.size.width)
            } else {
                narrowLayout
            }
        }
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("", systemImage: "arrow.uturn.backward") {
                    editorVM.undo()
                }
                .disabled(!editorVM.canUndo)

                Button("", systemImage: "arrow.uturn.forward") {
                    editorVM.redo()
                }
                .disabled(!editorVM.canRedo)

                Button("Export", systemImage: "square.and.arrow.up") {
                    startExport()
                }
                .disabled(editorVM.allClips.isEmpty)
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.movie, .video, .mpeg4Movie],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                editorVM.addClips(from: urls)
            case .failure(let error):
                print("Import failed: \(error)")
            }
        }
        .fileExporter(
            isPresented: $isShowingSaveDialog,
            document: exportedVideoURL.map { ExportedVideo(url: $0) },
            contentType: .mpeg4Movie,
            defaultFilename: "\(project.title).mp4"
        ) { result in
            switch result {
            case .success:
                exportVM.markComplete()
            case .failure(let error):
                print("Save failed: \(error)")
            }
        }
        .sheet(isPresented: $isShowingExporter) {
            exportSheet
        }
        .overlay {
            if case .failed(let error) = exportVM.exportState {
                ErrorBanner(message: error) {
                    exportVM.reset()
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    // MARK: - Wide Layout

    private func wideLayout(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Top section: Material | Preview | Camera
            HStack(spacing: 0) {
                MaterialImportView(
                    clips: editorVM.allClips,
                    onAddMaterial: { isShowingFilePicker = true },
                    onSelectClip: { editorVM.selectClip($0) },
                    selectedClipID: $editorVM.selectedClipID,
                    selectedCamera: $editorVM.selectedCamera
                )
                .frame(width: width * 0.25)

                Divider()

                // Preview
                VStack(spacing: 12) {
                    PreviewPlayerView(editorVM: editorVM)
                        .frame(minWidth: 280)
                }
                .padding()
                .frame(maxWidth: .infinity)

                Divider()

                CameraControlView(selectedCamera: $editorVM.selectedCamera)
                    .frame(width: width * 0.25)
            }

            Divider()

            // Timeline section
            VStack(spacing: 0) {
                timelineContent
                Divider()
                timelineToolbar
                    .padding()
            }
        }
    }

    // MARK: - Narrow Layout

    private var narrowLayout: some View {
        VStack(spacing: 0) {
            PreviewPlayerView(editorVM: editorVM)
                .frame(height: 240)

            Divider()

            HStack(spacing: 0) {
                MaterialImportView(
                    clips: editorVM.allClips,
                    onAddMaterial: { isShowingFilePicker = true },
                    onSelectClip: { editorVM.selectClip($0) },
                    selectedClipID: $editorVM.selectedClipID,
                    selectedCamera: $editorVM.selectedCamera
                )
                .frame(width: 120)

                Divider()

                CameraControlView(selectedCamera: $editorVM.selectedCamera)
                    .frame(width: 100)
            }
            .frame(height: 120)

            Divider()

            timelineContent

            timelineToolbar
                .padding(.horizontal)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        VStack(spacing: 0) {
            TimelineRulerView(
                totalDuration: editorVM.totalDuration.seconds,
                timeScale: editorVM.timeScale
            )

            TimelineView(
                tracks: editorVM.tracks,
                selectedClipID: $editorVM.selectedClipID,
                timeScale: editorVM.timeScale,
                playheadPosition: editorVM.playheadPosition,
                totalDuration: editorVM.totalDuration.seconds,
                onSelect: { editorVM.selectClip($0) },
                onMoveClip: { clipID, targetTrackID, targetIndex in
                    editorVM.moveClip(clipID, toTrack: targetTrackID, toIndex: targetIndex)
                },
                onTrimStart: { id, newStart in editorVM.updateTrimStart(newStart) },
                onTrimEnd: { id, newEnd in editorVM.updateTrimEnd(newEnd) },
                onTrimBegin: { id in editorVM.beginTrimming(clipID: id) },
                onTrimEndAction: { editorVM.endTrimming() }
            )
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            editorVM.seekToPlayheadPosition(x: location.x)
        }
        .overlay(alignment: .top) {
            PlayheadDragOverlay(
                playheadPosition: editorVM.playheadPosition,
                trackCount: editorVM.tracks.count,
                onSeek: { x in editorVM.seekToPlayheadPosition(x: x) }
            )
            .allowsHitTesting(true)
        }
    }

    // MARK: - Toolbar

    private var timelineToolbar: some View {
        HStack(spacing: 16) {
            Button(action: { isShowingFilePicker = true }) {
                Label("添加", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)

            Button(action: splitAction) {
                Label("分割", systemImage: "scissors")
            }
            .buttonStyle(.bordered)
            .disabled(editorVM.selectedClipID == nil)

            Button(action: joinAction) {
                Label("拼接", systemImage: "link.badge.plus")
            }
            .buttonStyle(.bordered)
            .disabled(!canJoin)

            Button(action: deleteAction) {
                Label("删除", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(editorVM.selectedClipID == nil)

            Spacer()

            // Timeline zoom
            HStack(spacing: 6) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundStyle(.secondary)
                Slider(value: $editorVM.timeScale, in: 30...300)
                    .frame(width: 100)
                Image(systemName: "plus.magnifyingglass")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Join Logic

    private var canJoin: Bool {
        guard let id = editorVM.selectedClipID else { return false }
        return editorVM.findJoinCandidate(for: id) != nil
    }

    private func joinAction() {
        guard let id = editorVM.selectedClipID,
              let (clipA, clipB) = editorVM.findJoinCandidate(for: id) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            editorVM.joinClips(clipA, clipB)
        }
    }

    // MARK: - Actions

    private func splitAction() {
        guard let id = editorVM.selectedClipID else { return }
        editorVM.splitClip(at: id, atTime: editorVM.currentTime)
    }

    private func deleteAction() {
        guard let id = editorVM.selectedClipID else { return }
        editorVM.deleteClip(id)
    }

    // MARK: - Export

    private func startExport() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        exportedVideoURL = tempURL
        Task {
            await exportVM.export(
                tracks: editorVM.tracks,
                to: tempURL,
                videoResolver: EditorViewModel.videoURL(for:)
            )
        }
        isShowingExporter = true
    }

    // MARK: - Export Sheet

    private var exportSheet: some View {
        VStack(spacing: 24) {
            if exportVM.isExporting {
                ExportProgressView(progress: exportVM.progress) {
                    exportVM.reset()
                    isShowingExporter = false
                }
            } else if exportVM.isCompleted {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("导出完成!")
                        .font(.title2.bold())
                    Text("选择保存位置")
                        .foregroundStyle(.secondary)
                    Button("保存...") {
                        isShowingSaveDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                    Button("完成") {
                        isShowingExporter = false
                        exportVM.reset()
                    }
                }
            } else {
                ProgressView("准备导出...")
            }
        }
        .padding(40)
        .interactiveDismissDisabled(exportVM.isExporting)
    }
}

// MARK: - Exported Video Document

struct ExportedVideo: FileDocument {
    static var readableContentTypes: [UTType] { [.mpeg4Movie] }

    var url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url)
    }
}
