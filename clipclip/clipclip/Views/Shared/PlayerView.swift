import SwiftUI
import AVKit

/// NSViewRepresentable wrapper around AVPlayerView for embedding the video player.
struct PlayerView: NSViewRepresentable {
    let player: AVPlayer
    var showsPlaybackControls: Bool = true

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = showsPlaybackControls ? .default : .none
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

/// Lightweight player wrapper without controls (for custom controls overlay).
struct SilentPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
