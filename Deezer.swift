import Foundation
import AVFoundation

// =====================================================================
// Deezer — free 30-second track previews, NO API key and NO auth.
// Spotify stopped serving preview_url to new apps, so we find the same
// artist on Deezer (exact name match) and play that artist's own top songs.
// Endpoints: /search/artist, /artist/{id}/top, /track/{id}.
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

    /// Strict, ASCII-only query encoding: names like "Earth, Wind & Fire",
    /// "+44" or Japanese names always reach Deezer intact (on iOS 16 too).
    private static let queryAllowed = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func get(_ path: String, _ params: [(String, String)]) async -> Data? {
        let query = params.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? value)"
        }.joined(separator: "&")
        guard let url = URL(string: "\(base)/\(path)?\(query)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    // MARK: Wire types

    struct ArtistHit: Codable, Equatable {
        let id: Int
        let name: String
        let nb_fan: Int?
    }

    private struct TrackItem: Codable {
        let id: Int
        let title: String
        let readable: Bool?
        let preview: String?
        let duration: Int?
        let artist: Who?
        let album: Al?
        struct Who: Codable { let id: Int?; let name: String? }
        struct Al: Codable { let cover_medium: String?; let cover_big: String? }
    }

    private struct Page<T: Codable>: Codable { let data: [T]? }

    // MARK: Matching

    /// Folds case, accents and punctuation so "Beyoncé", "BEYONCE" and
    /// "Beyonce" compare equal. Letters from every script are kept.
    static func normalize(_ name: String) -> String {
        var s = name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        s = s.replacingOccurrences(of: "&", with: " and ")
        s = s.replacingOccurrences(of: "[^\\p{L}\\p{N} ]", with: "", options: .regularExpression)
        var words = s.split(separator: " ").map(String.init)
        if words.first == "the", words.count > 1 { words.removeFirst() }
        return words.joined(separator: " ")
    }

    /// The Deezer artist that really is `name`: same name once case, accents
    /// and punctuation are ignored. When several share the name, the one with
    /// the most fans wins. No match means no previews, never someone else's.
    static func bestMatch(for name: String, in hits: [ArtistHit]) -> ArtistHit? {
        let target = normalize(name)
        guard !target.isEmpty else { return nil }
        let squeezed = target.replacingOccurrences(of: " ", with: "")
        let same = hits.filter { normalize($0.name) == target }
        let pool = same.isEmpty
            ? hits.filter { normalize($0.name).replacingOccurrences(of: " ", with: "") == squeezed }
            : same
        return pool.max { ($0.nb_fan ?? 0) < ($1.nb_fan ?? 0) }
    }

    // MARK: Endpoints

    /// That artist's own most popular songs that have a 30-second preview.
    static func topTracks(forArtistNamed name: String, limit: Int = 8) async -> [DZTrack] {
        guard let data = await get("search/artist", [("q", name), ("limit", "15")]),
              let hits = (try? JSONDecoder().decode(Page<ArtistHit>.self, from: data))?.data,
              let artist = bestMatch(for: name, in: hits),
              let topData = await get("artist/\(artist.id)/top", [("limit", "25")]),
              let items = (try? JSONDecoder().decode(Page<TrackItem>.self, from: topData))?.data
        else { return [] }
        let playable = items.filter { $0.readable != false && !($0.preview ?? "").isEmpty }
        // Songs where they're the main artist first, then their features.
        let own = playable.filter { $0.artist?.id == artist.id }
        let rest = playable.filter { $0.artist?.id != artist.id }
        return (own + rest).prefix(limit).compactMap { item in
            guard let preview = item.preview, let url = URL(string: preview) else { return nil }
            let cover = item.album?.cover_big ?? item.album?.cover_medium
            return DZTrack(id: item.id, title: item.title,
                           artist: item.artist?.name ?? artist.name,
                           previewURL: url,
                           coverURL: cover.flatMap(URL.init(string:)),
                           duration: item.duration ?? 30)
        }
    }

    /// A freshly signed preview link (Deezer links expire after a while).
    static func freshPreview(trackID: Int) async -> URL? {
        guard let data = await get("track/\(trackID)", []),
              let item = try? JSONDecoder().decode(TrackItem.self, from: data),
              let preview = item.preview, !preview.isEmpty else { return nil }
        return URL(string: preview)
    }

    /// Seconds until a signed preview link stops working (nil if unsigned).
    static func secondsLeft(on url: URL, now: Date = Date()) -> TimeInterval? {
        let text = url.absoluteString
        guard let range = text.range(of: "exp=") else { return nil }
        let digits = text[range.upperBound...].prefix { $0.isASCII && $0.isNumber }
        guard let expiry = TimeInterval(String(digits)) else { return nil }
        return expiry - now.timeIntervalSince1970
    }
}

// =====================================================================
// PreviewAudio — tiny AVPlayer wrapper so any screen can play a 30s clip.
// =====================================================================
@MainActor
final class PreviewAudio: ObservableObject {
    @Published private(set) var playingID: Int?
    @Published private(set) var isLoading = false
    /// A preview that wouldn't play even with a fresh link.
    @Published private(set) var failedID: Int?
    private var player: AVPlayer?
    private var statusWatch: NSKeyValueObservation?
    private var endWatch: NSObjectProtocol?
    private var token = UUID()

    func toggle(_ track: DZTrack) {
        if playingID == track.id { stop(); return }
        play(track)
    }

    func play(_ track: DZTrack) {
        guard let url = track.previewURL else { return }
        stop()
        let request = UUID()
        token = request
        playingID = track.id
        failedID = nil
        Task {
            var link = url
            // An old or nearly expired link gets swapped for a fresh one.
            if let left = Deezer.secondsLeft(on: link), left < 60,
               let fresh = await Deezer.freshPreview(trackID: track.id) {
                link = fresh
            }
            guard self.token == request else { return }
            self.start(link, for: track, retryAllowed: true)
        }
    }

    private func start(_ url: URL, for track: DZTrack, retryAllowed: Bool) {
        // allow audio in silent mode
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        player = p
        let request = token
        statusWatch = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in
                guard let self, self.token == request else { return }
                await self.recover(track, retryAllowed: retryAllowed)
            }
        }
        if let endWatch { NotificationCenter.default.removeObserver(endWatch) }
        // auto-clear when the 30s preview ends
        endWatch = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.token == request else { return }
                    self.stop()
                }
            }
        p.play()
    }

    /// The link was rejected: try once more with a fresh one, then give up.
    private func recover(_ track: DZTrack, retryAllowed: Bool) async {
        let request = token
        if retryAllowed, let fresh = await Deezer.freshPreview(trackID: track.id), token == request {
            start(fresh, for: track, retryAllowed: false)
        } else if token == request {
            stop()
            failedID = track.id
        }
    }

    func stop() {
        token = UUID()
        player?.pause()
        player = nil
        statusWatch = nil
        if let endWatch { NotificationCenter.default.removeObserver(endWatch) }
        endWatch = nil
        playingID = nil
    }
}
