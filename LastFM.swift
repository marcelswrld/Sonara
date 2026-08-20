import Foundation

// =====================================================================
// LastFM — fills the gap Spotify leaves. New Spotify apps get artist
// objects with EMPTY genres, so we fetch genre/mood tags from Last.fm's
// free API instead (artist.getTopTags). Tags like "hip-hop", "chill",
// "rock", "electronic" map straight into our GenreMood table.
//
// SETUP: get a free key at https://www.last.fm/api/account/create and
// paste it below. Until then, this returns [] and Vibe falls back to
// whatever Spotify genres exist (usually none for new apps).
// =====================================================================

enum LastFM {
    // TODO: paste your free Last.fm API key here.
    static let apiKey = "ad15712aae414b221acfa51829830574"   // <-- Last.fm key

    static var isConfigured: Bool { !apiKey.isEmpty }

    /// Top genre/mood tags for an artist, most-weighted first.
    static func topTags(artist: String) async -> [String] {
        guard isConfigured else { return [] }
        let name = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artist
        let urlStr = "https://ws.audioscrobbler.com/2.0/?method=artist.gettoptags"
            + "&artist=\(name)&api_key=\(apiKey)&format=json&autocorrect=1"
        guard let url = URL(string: urlStr),
              let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        struct R: Codable {
            let toptags: TopTags?
            struct TopTags: Codable { let tag: [Tag]?
                struct Tag: Codable { let name: String; let count: Int? } }
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data),
              let tags = r.toptags?.tag else { return [] }
        // keep meaningful tags (drop noise), most-weighted first
        return tags
            .sorted { ($0.count ?? 0) > ($1.count ?? 0) }
            .map { $0.name.lowercased() }
            .prefix(8)
            .map { $0 }
    }
}
