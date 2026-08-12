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
struct AlbumTracksResponse: Codable { let items: [SPTrack] }

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

    func topTracks(limit: Int = 20) async throws -> [SPTrack] {
        let d = try await request("/me/top/tracks", query: ["limit": String(limit),
                                                            "time_range": "medium_term"])
        return try JSONDecoder().decode(TopTracksResponse.self, from: d).items
    }

    /// The user's saved/liked tracks.
    func savedTracks(limit: Int = 20) async throws -> [SPTrack] {
        let d = try await request("/me/tracks", query: ["limit": String(limit)])
        struct SavedResponse: Codable { let items: [SavedItem]
            struct SavedItem: Codable { let track: SPTrack } }
        return try JSONDecoder().decode(SavedResponse.self, from: d).items.map(\.track)
    }

    /// New-release albums → their tracks. Works for all apps.
    func newReleaseTracks(limit: Int = 20) async throws -> [SPTrack] {
        let d = try await request("/browse/new-releases", query: ["limit": "20"])
        struct NR: Codable { let albums: Albums
            struct Albums: Codable { let items: [Album]
                struct Album: Codable { let id: String } } }
        let albumIDs = (try? JSONDecoder().decode(NR.self, from: d).albums.items.map(\.id)) ?? []
        guard !albumIDs.isEmpty else { return [] }
        // Pull tracks from the first few albums.
        var tracks: [SPTrack] = []
        for id in albumIDs.prefix(8) {
            if let ad = try? await request("/albums/\(id)/tracks", query: ["limit": "3"]),
               let resp = try? JSONDecoder().decode(AlbumTracksResponse.self, from: ad) {
                // album-track objects lack album art; attach the album id via search fallback later
                tracks.append(contentsOf: resp.items)
            }
            if tracks.count >= limit { break }
        }
        return Array(tracks.prefix(limit))
    }

    /// Search as a universal fallback (always available).
    func searchTracks(_ q: String, limit: Int = 20) async throws -> [SPTrack] {
        let d = try await request("/search", query: ["q": q, "type": "track",
                                                     "limit": String(limit)])
        struct SearchResponse: Codable { let tracks: Tracks
            struct Tracks: Codable { let items: [SPTrack] } }
        return try JSONDecoder().decode(SearchResponse.self, from: d).tracks.items
    }

    /// Discover feed. `/recommendations` is disabled for apps created after
    /// Nov 2024, so we layer sources that DO work: the user's top tracks →
    /// new releases → their saved tracks → a broad search. First non-empty
    /// result wins; results are de-duplicated.
    func recommendations(limit: Int = 20) async throws -> [SPTrack] {
        var pool: [SPTrack] = []
        if let top = try? await topTracks(limit: limit) { pool += top }
        if pool.count < limit, let nr = try? await newReleaseTracks(limit: limit) { pool += nr }
        if pool.count < limit, let saved = try? await savedTracks(limit: limit) { pool += saved }
        if pool.count < limit, let s = try? await searchTracks("year:2024-2026", limit: limit) { pool += s }
        // de-dupe by id, keep only tracks we can show
        var seen = Set<String>()
        let deck = pool.filter { seen.insert($0.id).inserted }
        if deck.isEmpty {
            // last resort so the screen is never empty
            return try await searchTracks("top hits", limit: limit)
        }
        return Array(deck.prefix(limit))
    }

    /// Musiclips' likeTrack: save to the user's Spotify library.
    func saveToLibrary(trackID: String) async throws {
        _ = try await request("/me/tracks", method: "PUT", query: ["ids": trackID])
    }

    /// Follow an artist on Spotify (used when saving artist-centric cards).
    func followArtist(artistID: String) async throws {
        _ = try? await request("/me/following", method: "PUT",
                                query: ["type": "artist", "ids": artistID])
    }

    /// Audio features for a track — feeds the DNA spectrum. May be
    /// restricted for new apps; returns nil gracefully if so.
    func audioFeatures(trackID: String) async -> AudioFeatures? {
        guard let d = try? await request("/audio-features/\(trackID)") else { return nil }
        struct AF: Codable {
            let energy: Double?; let danceability: Double?; let valence: Double?
            let acousticness: Double?; let instrumentalness: Double?; let tempo: Double?
        }
        guard let af = try? JSONDecoder().decode(AF.self, from: d) else { return nil }
        return AudioFeatures(energy: af.energy ?? 0, danceability: af.danceability ?? 0,
                             valence: af.valence ?? 0, acousticness: af.acousticness ?? 0,
                             instrumentalness: af.instrumentalness ?? 0, tempo: af.tempo ?? 0)
    }

    /// Full artist objects (for genres, which track objects don't include).
    func artistDetails(ids: [String]) async -> [SPArtist] {
        guard !ids.isEmpty else { return [] }
        let joined = ids.prefix(50).joined(separator: ",")
        guard let d = try? await request("/artists", query: ["ids": joined]) else { return [] }
        struct AR: Codable { let artists: [SPArtist] }
        return (try? JSONDecoder().decode(AR.self, from: d).artists) ?? []
    }

    /// Genres for a single track's primary artist (for taste seeds).
    func genresForTrack(_ track: SPTrack) async -> [String] {
        guard let artistID = track.artists?.first?.id else { return [] }
        let details = await artistDetails(ids: [artistID])
        return details.first?.genres ?? []
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
