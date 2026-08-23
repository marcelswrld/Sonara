import Foundation
import AVFoundation

// =====================================================================
// Deezer — free 30-second track previews, NO API key and NO auth.
// Spotify stopped serving preview_url to new apps, so we resolve the
// same song on Deezer's public search API and play its preview.
// Endpoint: https://api.deezer.com/search?q=...  -> items have `preview`
// (a direct MP3 URL) and album cover art.
// =====================================================================

struct DZTrack: Identifiable, Hashable {
    let id: Int
    let title: String
    let artist: String
    let previewURL: URL?
    let coverURL: URL?
    let duration: Int
}

enum Deezer {
    private static let base = "https://api.deezer.com"

    /// Find a playable preview for an artist (optionally a specific track).
    static func search(artist: String, track: String? = nil, limit: Int = 10) async -> [DZTrack] {
        var q = "artist:\"\(artist)\""
        if let t = track, !t.isEmpty { q += " track:\"\(t)\"" }
        guard let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(base)/search?q=\(encoded)&limit=\(limit)")
        else { return [] }
        guard let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        struct R: Codable {
            let data: [Item]?
            struct Item: Codable {
                let id: Int
                let title: String
                let preview: String?
                let duration: Int?
                let artist: A?
                let album: Al?
                struct A: Codable { let name: String }
                struct Al: Codable { let cover_medium: String?; let cover_big: String? }
            }
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data), let items = r.data
        else { return [] }
        return items.compactMap { i in
            guard let p = i.preview, !p.isEmpty, let purl = URL(string: p) else { return nil }
            let cover = i.album?.cover_big ?? i.album?.cover_medium
            return DZTrack(id: i.id, title: i.title,
                           artist: i.artist?.name ?? artist,
                           previewURL: purl,
                           coverURL: cover.flatMap(URL.init(string:)),
                           duration: i.duration ?? 30)
        }
    }
}

// =====================================================================
// PreviewAudio — tiny AVPlayer wrapper so any screen can play a 30s clip.
// =====================================================================
@MainActor
final class PreviewAudio: ObservableObject {
    @Published private(set) var playingID: Int?
    @Published private(set) var isLoading = false
    private var player: AVPlayer?

    func toggle(_ track: DZTrack) {
        if playingID == track.id { stop(); return }
        play(track)
    }

    func play(_ track: DZTrack) {
        guard let url = track.previewURL else { return }
        stop()
        // allow audio in silent mode
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let p = AVPlayer(url: url)
        player = p
        playingID = track.id
        p.play()
        // auto-clear when the 30s preview ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.stop() }
            }
    }

    func stop() {
        player?.pause()
        player = nil
        playingID = nil
    }
}
