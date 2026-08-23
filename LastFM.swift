import Foundation

// =====================================================================
// LastFM — free API (key below) that fills every gap Spotify leaves for
// new apps. Provides:
//   • artist genre/mood TAGS  (Spotify strips genres for new apps)
//   • REAL charts by genre    (tag.getTopArtists)
//   • REAL global charts      (chart.getTopArtists)
//   • REAL listener/playcount stats per artist (artist.getInfo)
//   • Top tracks per artist   (artist.getTopTracks)
// All endpoints are unauthenticated beyond the API key.
// =====================================================================

struct LFArtist: Identifiable, Hashable {
    let name: String
    let listeners: Int
    let playcount: Int
    let imageURL: URL?
    let genre: String?          // the tag/genre bucket it came from
    var id: String { name }

    // Human-friendly stat strings
    var listenersText: String { LastFM.compact(listeners) }
    var playsText: String { LastFM.compact(playcount) }

    /// SUPERFAN SCORE — plays per listener. A real, derived signal:
    /// high = a small but obsessive fanbase (repeat listening), low = wide
    /// but casual reach. Directly relevant to catalog value, because loyal
    /// repeat listeners produce more durable streaming revenue.
    var playsPerListener: Double {
        guard listeners > 0 else { return 0 }
        return Double(playcount) / Double(listeners)
    }
    var superfanScore: Int {
        // ~5 plays/listener is average; map to a 0-100 feel.
        guard playsPerListener > 0 else { return 0 }
        return Swift.min(Int((playsPerListener / 15.0) * 100), 100)
    }
    var superfanLabel: String {
        switch superfanScore {
        case 70...: return "Cult following"
        case 45..<70: return "Devoted fans"
        case 25..<45: return "Steady listeners"
        default: return "Casual reach"
        }
    }

    /// Rough annual streaming revenue estimate from real play data.
    /// Last.fm plays are a SAMPLE of global listening, so we scale up and
    /// apply a typical per-stream payout. This is an ESTIMATE to seed the
    /// Pitch calculator, never presented as fact.
    var estimatedAnnualRevenue: Double {
        guard playcount > 0 else { return 0 }
        let scaleFactor = 60.0        // Last.fm sample -> global listening
        let perStream = 0.0035        // typical blended payout
        let annualShare = 0.18        // share of lifetime plays in a year
        return Double(playcount) * scaleFactor * perStream * annualShare
    }
}

struct LFTrack: Identifiable, Hashable {
    let name: String
    let playcount: Int
    var id: String { name }
}

enum LastFM {
    static let apiKey = "ad15712aae414b221acfa51829830574"
    static var isConfigured: Bool { !apiKey.isEmpty }
    private static let base = "https://ws.audioscrobbler.com/2.0/"

    // Genre buckets shown in Trends (categorised, no random junk).
    static let genreBuckets = ["hip-hop", "pop", "rock", "electronic",
                               "r&b", "indie", "jazz", "classic rock"]

    private static func get(_ params: [String: String]) async -> Data? {
        guard isConfigured else { return nil }
        var comps = URLComponents(string: base)!
        var q = params
        q["api_key"] = apiKey
        q["format"] = "json"
        comps.queryItems = q.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Sonara/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    /// Genre/mood tags for an artist (feeds the mood engine).
    static func topTags(artist: String) async -> [String] {
        guard let d = await get(["method": "artist.gettoptags",
                                 "artist": artist, "autocorrect": "1"]) else { return [] }
        struct R: Codable { let toptags: T?
            struct T: Codable { let tag: [Tag]?
                struct Tag: Codable { let name: String; let count: Int? } } }
        guard let r = try? JSONDecoder().decode(R.self, from: d),
              let tags = r.toptags?.tag else { return [] }
        return tags.sorted { ($0.count ?? 0) > ($1.count ?? 0) }
            .prefix(8).map { $0.name.lowercased() }
    }

    /// REAL top artists for a genre — this is what Trends should show.
    static func topArtists(genre: String, limit: Int = 12, page: Int = 1) async -> [LFArtist] {
        guard let d = await get(["method": "tag.gettopartists", "tag": genre,
                                 "limit": String(limit), "page": String(page)]) else { return [] }
        struct R: Codable { let topartists: T?
            struct T: Codable { let artist: [A]?
                struct A: Codable {
                    let name: String
                    let image: [Img]?
                    struct Img: Codable { let text: String?; let size: String?
                        enum CodingKeys: String, CodingKey { case text = "#text"; case size } }
                } } }
        guard let r = try? JSONDecoder().decode(R.self, from: d),
              let arts = r.topartists?.artist else { return [] }
        return arts.map { a in
            let img = a.image?.first(where: { $0.size == "extralarge" })?.text
                   ?? a.image?.last?.text
            return LFArtist(name: a.name, listeners: 0, playcount: 0,
                            imageURL: (img?.isEmpty == false) ? URL(string: img!) : nil,
                            genre: genre)
        }
    }

    /// REAL global chart.
    static func globalTopArtists(limit: Int = 12, page: Int = 1) async -> [LFArtist] {
        guard let d = await get(["method": "chart.gettopartists",
                                 "limit": String(limit), "page": String(page)]) else { return [] }
        struct R: Codable { let artists: T?
            struct T: Codable { let artist: [A]?
                struct A: Codable {
                    let name: String
                    let listeners: String?
                    let playcount: String?
                    let image: [Img]?
                    struct Img: Codable { let text: String?; let size: String?
                        enum CodingKeys: String, CodingKey { case text = "#text"; case size } }
                } } }
        guard let r = try? JSONDecoder().decode(R.self, from: d),
              let arts = r.artists?.artist else { return [] }
        return arts.map { a in
            let img = a.image?.first(where: { $0.size == "extralarge" })?.text
                   ?? a.image?.last?.text
            return LFArtist(name: a.name,
                            listeners: Int(a.listeners ?? "0") ?? 0,
                            playcount: Int(a.playcount ?? "0") ?? 0,
                            imageURL: (img?.isEmpty == false) ? URL(string: img!) : nil,
                            genre: nil)
        }
    }

    /// REAL stats for one artist (listeners, plays, bio summary).
    static func artistInfo(name: String) async -> (listeners: Int, playcount: Int, bio: String?)? {
        guard let d = await get(["method": "artist.getinfo", "artist": name,
                                 "autocorrect": "1"]) else { return nil }
        struct R: Codable { let artist: A?
            struct A: Codable { let stats: S?; let bio: B?
                struct S: Codable { let listeners: String?; let playcount: String? }
                struct B: Codable { let summary: String? } } }
        guard let r = try? JSONDecoder().decode(R.self, from: d), let a = r.artist else { return nil }
        return (Int(a.stats?.listeners ?? "0") ?? 0,
                Int(a.stats?.playcount ?? "0") ?? 0,
                a.bio?.summary?.replacingOccurrences(of: "\n", with: " "))
    }

    /// Top tracks for an artist (artist detail screen).
    static func topTracks(artist: String, limit: Int = 5) async -> [LFTrack] {
        guard let d = await get(["method": "artist.gettoptracks", "artist": artist,
                                 "limit": String(limit), "autocorrect": "1"]) else { return [] }
        struct R: Codable { let toptracks: T?
            struct T: Codable { let track: [Tr]?
                struct Tr: Codable { let name: String; let playcount: String? } } }
        guard let r = try? JSONDecoder().decode(R.self, from: d),
              let ts = r.toptracks?.track else { return [] }
        return ts.map { LFTrack(name: $0.name, playcount: Int($0.playcount ?? "0") ?? 0) }
    }

    /// 1.2M -> "1.2M"
    static func compact(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...:     return String(format: "%.0fK", Double(n) / 1_000)
        default:           return "\(n)"
        }
    }
}
