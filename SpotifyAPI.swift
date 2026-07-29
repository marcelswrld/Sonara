import Foundation
import AVFoundation

// =====================================================================
// SpotifyAPI — the useful surface of Musiclips' 1275-line MainManager,
// ported to async/await. Models mirror Musiclips' Track/Album/Artist.
// Deliberately NOT ported: the "Canvas" video fetch — it called
// Spotify's private internal API (unofficial, ToS risk, breaks without
// notice). Flagged in STATUS doc for Mark.
// =====================================================================

// MARK: - Models (Musiclips-compatible shapes)

struct SPImage: Codable, Hashable { let url: String; let width: Int?; let height: Int? }

struct SPArtist: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let genres: [String]?
}

struct SPAlbum: Codable, Hashable {
    let name: String?
    let images: [SPImage]?
}

struct SPTrack: Codable, Hashable, Identifiable {
    let id: String
    let name: String?
    let artists: [SPArtist]?
    let album: SPAlbum?
    let preview_url: String?
    let external_urls: [String: String]?

    var artworkURL: URL? { (album?.images?.first?.url).flatMap(URL.init(string:)) }
    var artistLine: String { artists?.map(\.name).joined(separator: ", ") ?? "" }
}

struct SPUser: Codable {
    let id: String
    let display_name: String?
    let images: [SPImage]?
}

struct RecommendationsResponse: Codable { let tracks: [SPTrack] }
struct TopTracksResponse: Codable { let items: [SPTrack] }

// MARK: - API

@MainActor
final class SpotifyAPI: ObservableObject {
    private let auth: SpotifyAuth
    init(auth: SpotifyAuth) { self.auth = auth }

    enum APIError: Error { case notSignedIn, badResponse(Int) }

    private func request(_ path: String,
                         method: String = "GET",
                         query: [String: String] = [:]) async throws -> Data {
        guard let token = await auth.validToken() else { throw APIError.notSignedIn }
        var c = URLComponents(string: SpotifyConfig.apiBase + path)!
        if !query.isEmpty { c.queryItems = query.map { .init(name: $0, value: $1) } }
        var req = URLRequest(url: c.url!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw APIError.badResponse(code) }
        return data
    }

    func me() async throws -> SPUser {
        try JSONDecoder().decode(SPUser.self, from: await request("/me"))
    }

    func topTracks(limit: Int = 5) async throws -> [SPTrack] {
        let d = try await request("/me/top/tracks", query: ["limit": String(limit)])
        return try JSONDecoder().decode(TopTracksResponse.self, from: d).items
    }

    /// Same strategy as Musiclips: seed from the user's top tracks;
    /// fall back to genre seeds for brand-new accounts.
    func recommendations(limit: Int = 20) async throws -> [SPTrack] {
        let seeds = (try? await topTracks(limit: 5)) ?? []
        let query: [String: String] = seeds.isEmpty
            ? ["seed_genres": "pop,hip-hop,indie", "limit": String(limit)]
            : ["seed_tracks": seeds.prefix(5).map(\.id).joined(separator: ","),
               "limit": String(limit)]
        let d = try await request("/recommendations", query: query)
        return try JSONDecoder().decode(RecommendationsResponse.self, from: d).tracks
    }

    /// Musiclips' likeTrack: save to the user's Spotify library.
    func saveToLibrary(trackID: String) async throws {
        _ = try await request("/me/tracks", method: "PUT", query: ["ids": trackID])
    }
}

// MARK: - Preview player (Musiclips' 30-second "strip")

@MainActor
final class PreviewPlayer: ObservableObject {
    @Published private(set) var playingTrackID: String?
    private var player: AVPlayer?

    func play(_ track: SPTrack) {
        guard let s = track.preview_url, let url = URL(string: s) else { return }
        player?.pause()
        player = AVPlayer(url: url)
        player?.play()
        playingTrackID = track.id
    }
    func stop() {
        player?.pause()
        player = nil
        playingTrackID = nil
    }
    func toggle(_ track: SPTrack) {
        playingTrackID == track.id ? stop() : play(track)
    }
}
