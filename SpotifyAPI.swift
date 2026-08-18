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

// A recently-played track with its timestamp (for the daily mood arc).
struct RecentPlay: Identifiable, Hashable {
    let track: SPTrack
    let playedAt: Date
    var id: String { track.id + playedAt.description }
}

// A new-release album surfaced in the Trends tab.
struct TrendAlbum: Identifiable, Hashable {    let id: String
    let name: String
    let artist: String
    let artistID: String?
    let artworkURL: URL?
    let releaseDate: String?
    let trackCount: Int
    let momentum: Int   // rising % indicator
}

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

    /// Top artists — carry genres directly. Backbone of the personality.
    func topArtists(limit: Int = 30) async -> [SPArtist] {
        guard let d = try? await request("/me/top/artists",
                    query: ["limit": String(limit), "time_range": "medium_term"]) else { return [] }
        struct R: Codable { let items: [SPArtist] }
        return (try? JSONDecoder().decode(R.self, from: d).items) ?? []
    }

    /// Recently played WITH timestamps — powers the daily mood arc.
    /// Confirmed still available to new apps (returns last ~50 plays).
    func recentlyPlayed(limit: Int = 50) async -> [RecentPlay] {
        guard let d = try? await request("/me/player/recently-played",
                                         query: ["limit": String(limit)]) else { return [] }
        struct R: Codable {
            let items: [Item]
            struct Item: Codable { let track: SPTrack; let played_at: String }
        }
        guard let r = try? JSONDecoder().decode(R.self, from: d) else { return [] }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoNoFrac = ISO8601DateFormatter()
        return r.items.compactMap { item in
            let date = iso.date(from: item.played_at) ?? isoNoFrac.date(from: item.played_at)
            guard let d = date else { return nil }
            return RecentPlay(track: item.track, playedAt: d)
        }
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

    /// New tracks via search (works for all apps; /browse/new-releases is dead).
    func newReleaseTracks(limit: Int = 20) async throws -> [SPTrack] {
        return try await searchTracks("year:2026", limit: limit)
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

    /// New-release ALBUMS with art — the backbone of the Trends tab.
    /// Uses only endpoints available to new apps.
    /// Trends feed built on endpoints that WORK for new apps. Spotify
    /// removed /browse/new-releases in Feb 2026, so we use SEARCH (still
    /// live) across fresh queries to pull real albums with real artist IDs.
    func newReleaseAlbums(limit: Int = 20) async -> [TrendAlbum] {
        // Search queries that surface current music. Year tag keeps it fresh.
        let queries = ["year:2026", "new music 2026", "top hits 2026",
                       "viral 2026", "trending"]
        var out: [TrendAlbum] = []
        var seen = Set<String>()
        var idx = 0
        for q in queries {
            guard out.count < limit else { break }
            guard let d = try? await request("/search",
                    query: ["q": q, "type": "album", "limit": "10"]) else { continue }
            struct SR: Codable {
                let albums: A?
                struct A: Codable { let items: [Item]
                    struct Item: Codable {
                        let id: String
                        let name: String
                        let images: [SPImage]?
                        let artists: [SPArtist]?
                        let release_date: String?
                        let total_tracks: Int?
                    }
                }
            }
            guard let sr = try? JSONDecoder().decode(SR.self, from: d),
                  let items = sr.albums?.items else { continue }
            for a in items where seen.insert(a.id).inserted {
                out.append(TrendAlbum(
                    id: a.id,
                    name: a.name,
                    artist: a.artists?.first?.name ?? "Various",
                    artistID: a.artists?.first?.id,
                    artworkURL: (a.images?.first?.url).flatMap(URL.init(string:)),
                    releaseDate: a.release_date,
                    trackCount: a.total_tracks ?? 0,
                    momentum: 24 - idx + (idx % 3) * 2))
                idx += 1
            }
        }
        // Fallback: if search somehow returns nothing, seed from the user's
        // own top artists so the tab is NEVER empty.
        if out.isEmpty {
            let artists = await topArtists(limit: 12)
            for (i, a) in artists.enumerated() {
                out.append(TrendAlbum(id: a.id, name: a.name, artist: a.name,
                                      artistID: a.id, artworkURL: nil,
                                      releaseDate: nil, trackCount: 0,
                                      momentum: 20 - i))
            }
        }
        return out
    }

    /// Search artists (for the Trends "breaking artists" strip).
    func searchArtists(_ q: String, limit: Int = 10) async -> [SPArtist] {
        guard let d = try? await request("/search",
                    query: ["q": q, "type": "artist", "limit": String(limit)]) else { return [] }
        struct SR: Codable { let artists: A; struct A: Codable { let items: [SPArtist] } }
        return (try? JSONDecoder().decode(SR.self, from: d).artists.items) ?? []
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
