import Foundation
import SwiftUI

// =====================================================================
// MoodEngine — the heart of Sonara's "who you are musically" features.
//
// WHY THIS WORKS ON A NEW SPOTIFY APP: Spotify still gives new apps
// artist GENRES (via /artists/{id}) plus top artists/tracks and
// recently-played-with-timestamps. Genres encode energy/valence/mood,
// so we map genre -> mood via a BUNDLED table baked into the app. No
// blocked endpoints, no live dependency that can rate-limit or vanish.
// Everything computes locally and instantly.
// =====================================================================

// A point in Russell's valence–arousal space (the standard mood model),
// plus an "organic vs electronic" third axis for texture.
struct MoodVector {
    var energy: Double      // 0 = calm, 1 = intense (arousal)
    var valence: Double     // 0 = dark/sad, 1 = bright/happy
    var organic: Double     // 0 = electronic/synthetic, 1 = acoustic/organic
    var bass: Double         // 0 = airy, 1 = heavy low-end

    static let neutral = MoodVector(energy: 0.5, valence: 0.5, organic: 0.5, bass: 0.5)

    static func average(_ vs: [MoodVector]) -> MoodVector {
        guard !vs.isEmpty else { return .neutral }
        func m(_ kp: (MoodVector) -> Double) -> Double { vs.map(kp).reduce(0,+) / Double(vs.count) }
        return MoodVector(energy: m(\.energy), valence: m(\.valence),
                          organic: m(\.organic), bass: m(\.bass))
    }
}

// =====================================================================
// Bundled genre -> mood table. Keyed by SUBSTRING so any of Spotify's
// thousands of micro-genres resolves to the nearest family (e.g.
// "melodic dubstep" matches "dubstep"). Ordered most-specific first.
// Values are informed by Every Noise's organic/mechanical + dense/spiky
// axes and general genre knowledge.
// =====================================================================
enum GenreMood {
    // (substring, energy, valence, organic, bass)
    static let table: [(key: String, e: Double, v: Double, o: Double, b: Double)] = [
        // electronic / bass
        ("dubstep",      0.92, 0.55, 0.05, 0.98),
        ("drum and bass",0.90, 0.60, 0.05, 0.90),
        ("trap",         0.80, 0.50, 0.10, 0.95),
        ("techno",       0.85, 0.45, 0.05, 0.80),
        ("house",        0.78, 0.70, 0.10, 0.75),
        ("edm",          0.88, 0.72, 0.08, 0.82),
        ("electro",      0.80, 0.62, 0.10, 0.78),
        ("trance",       0.82, 0.68, 0.08, 0.70),
        ("synth",        0.65, 0.62, 0.15, 0.55),
        ("ambient",      0.20, 0.45, 0.35, 0.30),
        ("lo-fi",        0.30, 0.55, 0.45, 0.55),
        ("lofi",         0.30, 0.55, 0.45, 0.55),
        ("idm",          0.60, 0.45, 0.20, 0.60),
        ("hardstyle",    0.97, 0.50, 0.03, 0.92),
        // hip-hop / r&b
        ("drill",        0.78, 0.35, 0.08, 0.95),
        ("hip hop",      0.72, 0.55, 0.15, 0.85),
        ("hip-hop",      0.72, 0.55, 0.15, 0.85),
        ("rap",          0.75, 0.52, 0.12, 0.88),
        ("r&b",          0.55, 0.60, 0.35, 0.70),
        ("rnb",          0.55, 0.60, 0.35, 0.70),
        ("soul",         0.50, 0.65, 0.55, 0.55),
        ("funk",         0.72, 0.80, 0.50, 0.72),
        ("neo soul",     0.48, 0.62, 0.55, 0.60),
        // rock / metal
        ("metal",        0.92, 0.40, 0.25, 0.75),
        ("hardcore",     0.95, 0.42, 0.20, 0.72),
        ("punk",         0.88, 0.55, 0.30, 0.60),
        ("grunge",       0.75, 0.40, 0.40, 0.62),
        ("hard rock",    0.85, 0.55, 0.35, 0.65),
        ("classic rock", 0.70, 0.62, 0.50, 0.55),
        ("indie rock",   0.62, 0.58, 0.50, 0.48),
        ("alt",          0.65, 0.52, 0.45, 0.52),
        ("rock",         0.72, 0.58, 0.42, 0.58),
        ("emo",          0.68, 0.35, 0.40, 0.55),
        ("shoegaze",     0.50, 0.45, 0.45, 0.55),
        // pop
        ("k-pop",        0.80, 0.78, 0.20, 0.68),
        ("hyperpop",     0.85, 0.70, 0.10, 0.80),
        ("dance pop",    0.78, 0.78, 0.20, 0.65),
        ("electropop",   0.72, 0.72, 0.25, 0.60),
        ("indie pop",    0.58, 0.68, 0.45, 0.45),
        ("art pop",      0.55, 0.60, 0.40, 0.45),
        ("pop",          0.68, 0.75, 0.35, 0.55),
        // chill / acoustic / folk
        ("folk",         0.35, 0.55, 0.85, 0.30),
        ("acoustic",     0.30, 0.58, 0.90, 0.28),
        ("singer-songwriter",0.35,0.52,0.80,0.30),
        ("indie folk",   0.38, 0.55, 0.80, 0.32),
        ("chill",        0.32, 0.60, 0.50, 0.45),
        ("bedroom",      0.40, 0.55, 0.55, 0.45),
        ("dream",        0.42, 0.55, 0.45, 0.45),
        // jazz / classical / world
        ("jazz",         0.40, 0.60, 0.80, 0.45),
        ("classical",    0.30, 0.55, 0.95, 0.25),
        ("piano",        0.28, 0.55, 0.92, 0.20),
        ("orchestra",    0.45, 0.55, 0.90, 0.35),
        ("blues",        0.45, 0.45, 0.75, 0.50),
        ("country",      0.50, 0.60, 0.70, 0.45),
        ("reggae",       0.55, 0.75, 0.55, 0.65),
        ("reggaeton",    0.78, 0.75, 0.20, 0.82),
        ("latin",        0.72, 0.78, 0.40, 0.62),
        ("afrobeat",     0.70, 0.78, 0.45, 0.68),
        ("afro",         0.68, 0.76, 0.45, 0.68),
        ("gospel",       0.55, 0.75, 0.65, 0.45),
        ("disco",        0.78, 0.82, 0.40, 0.65),
        ("house music",  0.78, 0.72, 0.10, 0.75),
    ]

    static func vector(for genre: String) -> MoodVector? {
        let g = genre.lowercased()
        for row in table where g.contains(row.key) {
            return MoodVector(energy: row.e, valence: row.v, organic: row.o, bass: row.b)
        }
        return nil
    }

    /// When a genre string doesn't match the table, infer a rough mood from
    /// keywords in the NAME so the personality is never empty for a user who
    /// clearly has listening history. Errs toward neutral-but-plausible.
    static func heuristicVector(for genre: String) -> MoodVector {
        let g = genre.lowercased()
        var v = MoodVector.neutral
        func bump(_ kp: WritableKeyPath<MoodVector, Double>, _ x: Double) {
            v[keyPath: kp] = Swift.min(Swift.max(v[keyPath: kp] + x, 0), 1)
        }
        // energy cues
        for w in ["hard","heavy","core","speed","thrash","aggress","rave","bass","drill"] where g.contains(w) { bump(\.energy, 0.25); bump(\.bass, 0.2) }
        for w in ["chill","calm","sleep","ambient","soft","slow","dream","mellow","quiet","lo-fi","lofi"] where g.contains(w) { bump(\.energy, -0.25) }
        // valence cues
        for w in ["happy","sunny","tropical","dance","party","pop","feel good","upbeat"] where g.contains(w) { bump(\.valence, 0.2) }
        for w in ["sad","dark","doom","depress","melanch","gloom","emo","goth"] where g.contains(w) { bump(\.valence, -0.25) }
        // organic cues
        for w in ["acoustic","folk","singer","piano","classical","jazz","blues","country","orchestr"] where g.contains(w) { bump(\.organic, 0.3) }
        for w in ["electro","synth","edm","techno","house","digital","cyber","future"] where g.contains(w) { bump(\.organic, -0.3); bump(\.energy, 0.15) }
        return v
    }
}

// =====================================================================
// The computed personality result.
// =====================================================================
struct Personality {
    let mood: MoodVector
    let title: String           // "Zenned-Out Hippie"
    let descriptors: [String]   // ["High energy", "Bright", "Bass-heavy"]
    let blurb: String           // one-liner
    let topGenres: [(String, Int)]
    let sampleSize: Int
    // for the visual: a color derived from the mood
    var color: Color { MoodPalette.color(for: mood) }
    var accent: Color { MoodPalette.accent(for: mood) }
}

enum MoodPalette {
    // valence -> hue (dark/blue to bright/gold), energy -> saturation/vibrance
    static func color(for m: MoodVector) -> Color {
        // low valence => indigo/violet, high valence => warm gold/orange
        let cold = Color(hex: 0x5B4B8A)   // violet
        let warm = Color(hex: 0xF5A15E)   // warm orange
        let base = cold.blend(to: warm, fraction: m.valence)
        return base
    }
    static func accent(for m: MoodVector) -> Color {
        // energy pushes toward mint (electric) vs soft blue (calm)
        let calm = Color(hex: 0x6FA8DC)
        let electric = Color(hex: 0x1DB954)
        return calm.blend(to: electric, fraction: m.energy)
    }
}

@MainActor
final class MoodEngine: ObservableObject {
    @Published private(set) var personality: Personality?
    @Published private(set) var dayArc: [HourMood] = []
    @Published private(set) var loading = false
    @Published private(set) var lastError: String?
    @Published private(set) var debug: String = ""

    struct HourMood: Identifiable {
        let id = UUID()
        let hour: Int          // 0..23
        let energy: Double
        let valence: Double
        let count: Int
    }

    private unowned let api: SpotifyAPI
    init(api: SpotifyAPI) { self.api = api }

    func refresh() async {
        loading = true; lastError = nil
        await computePersonality()
        await computeDayArc()
        loading = false
    }

    // MARK: Personality from top artists' genres
    private func computePersonality() async {
        var genreCounts: [String: Int] = [:]
        var vectors: [MoodVector] = []

        // Top-artists list does NOT include genres for new apps, so gather
        // the artist IDs, then fetch each artist's full record (which has
        // genres) individually.
        let topArtistsList = await api.topArtists(limit: 40)
        var artistIDs = Set(topArtistsList.map(\.id))

        // Also fold in the artists behind the user's top tracks.
        let tracks = (try? await api.topTracks(limit: 40)) ?? []
        for t in tracks { if let id = t.artists?.first?.id { artistIDs.insert(id) } }

        // Fetch full records (Spotify genres — usually EMPTY for new apps).
        let detailed = await api.artistDetails(ids: Array(artistIDs))
        var lastfmUsed = 0
        for a in detailed {
            var genres = a.genres ?? []
            // Spotify strips genres for new apps — fall back to Last.fm tags.
            if genres.isEmpty && LastFM.isConfigured {
                genres = await LastFM.topTags(artist: a.name)
                if !genres.isEmpty { lastfmUsed += 1 }
            }
            for g in genres {
                genreCounts[g, default: 0] += 1
                if let v = GenreMood.vector(for: g) { vectors.append(v) }
            }
        }

        // If genres exist but none matched the table, derive from names.
        if vectors.isEmpty && !genreCounts.isEmpty {
            for (g, count) in genreCounts {
                let v = GenreMood.heuristicVector(for: g)
                for _ in 0..<count { vectors.append(v) }
            }
        }

        // De-duplicate near-identical genres for a VARIED top list (so it's
        // not "hip hop / hip-hop / rap" three times).
        let top = Self.dedupedTopGenres(genreCounts, limit: 5)

        debug = "artists=\(detailed.count) lastfm=\(lastfmUsed) genres=\(genreCounts.count) vectors=\(vectors.count) key=\(LastFM.isConfigured ? "set" : "MISSING")"

        if vectors.isEmpty {
            personality = nil
            lastError = !LastFM.isConfigured
                ? "Spotify no longer provides genre data for new apps. Add a free Last.fm API key (in LastFM.swift) to unlock your vibe — takes 2 minutes."
                : detailed.isEmpty
                    ? "Couldn't load artists from Spotify. Tap Refresh."
                    : "Couldn't classify your artists yet. Tap Refresh."
            return
        }

        // Weight the mood toward your DOMINANT genres and push away from the
        // mushy center so distinct tastes get distinct personalities.
        let mood = Self.amplify(MoodVector.average(vectors))
        let title = Self.title(for: mood, topGenre: top.first?.0)
        personality = Personality(mood: mood, title: title,
                                  descriptors: Self.descriptors(for: mood),
                                  blurb: Self.blurb(for: mood, title: title),
                                  topGenres: Array(top), sampleSize: vectors.count)
        lastError = nil
    }

    // MARK: Daily mood from recently-played timestamps
    private func computeDayArc() async {
        let plays = await api.recentlyPlayed(limit: 50)
        guard !plays.isEmpty else { dayArc = []; return }
        var buckets: [Int: [MoodVector]] = [:]
        let ids = Array(Set(plays.compactMap { $0.track.artists?.first?.id }))
        let details = await api.artistDetails(ids: ids)

        // Build artistID -> mood vectors, using Last.fm tags when Spotify
        // genres are empty (same as the personality path).
        var vectorsByArtist: [String: [MoodVector]] = [:]
        for a in details {
            var genres = a.genres ?? []
            if genres.isEmpty && LastFM.isConfigured {
                genres = await LastFM.topTags(artist: a.name)
            }
            vectorsByArtist[a.id] = genres.compactMap { GenreMood.vector(for: $0) }
        }

        let cal = Calendar.current
        for play in plays {
            guard let artistID = play.track.artists?.first?.id else { continue }
            let vecs = vectorsByArtist[artistID] ?? []
            guard !vecs.isEmpty else { continue }
            let hour = cal.component(.hour, from: play.playedAt)
            buckets[hour, default: []].append(MoodVector.average(vecs))
        }
        dayArc = buckets.keys.sorted().map { h in
            let avg = MoodVector.average(buckets[h]!)
            return HourMood(hour: h, energy: avg.energy, valence: avg.valence, count: buckets[h]!.count)
        }
    }

    // Push mood values away from the neutral center so blended tastes still
    // land on a distinct personality instead of mushing to ~0.6 everything.
    static func amplify(_ m: MoodVector) -> MoodVector {
        func stretch(_ x: Double) -> Double {
            // expand around 0.5 by 1.6x, clamp 0...1
            Swift.min(Swift.max(0.5 + (x - 0.5) * 1.6, 0), 1)
        }
        return MoodVector(energy: stretch(m.energy), valence: stretch(m.valence),
                          organic: stretch(m.organic), bass: stretch(m.bass))
    }

    // Collapse near-duplicate genres ("hip hop"/"hip-hop"/"rap") into one
    // canonical family so the top list shows real variety.
    static func dedupedTopGenres(_ counts: [String: Int], limit: Int) -> [(String, Int)] {
        let families: [String: String] = [
            "hip-hop":"Hip-Hop","hip hop":"Hip-Hop","rap":"Hip-Hop","trap":"Hip-Hop","drill":"Hip-Hop",
            "r&b":"R&B","rnb":"R&B","neo soul":"R&B","soul":"R&B",
            "rock":"Rock","indie rock":"Rock","classic rock":"Rock","hard rock":"Rock","alt":"Rock",
            "pop":"Pop","dance pop":"Pop","electropop":"Pop","indie pop":"Pop","art pop":"Pop",
            "house":"Electronic","techno":"Electronic","edm":"Electronic","electro":"Electronic",
            "trance":"Electronic","dubstep":"Electronic","synth":"Electronic","electronic":"Electronic",
            "metal":"Metal","hardcore":"Metal","folk":"Folk","acoustic":"Folk","indie folk":"Folk",
            "jazz":"Jazz","classical":"Classical","country":"Country","latin":"Latin","reggae":"Reggae",
        ]
        var merged: [String: Int] = [:]
        for (g, c) in counts {
            let gl = g.lowercased()
            var fam = g.capitalized
            for (key, name) in families where gl.contains(key) { fam = name; break }
            merged[fam, default: 0] += c
        }
        return merged.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }

    // MARK: descriptor logic
    static func title(for m: MoodVector, topGenre: String?) -> String {
        // Score each personality; pick the strongest match so everyone gets
        // a specific, earned label (no lazy "Eclectic Explorer" default).
        var scores: [(String, Double)] = []
        scores.append(("High-Bass Head", m.bass))
        scores.append(("Zenned-Out Hippie", m.organic * (1 - m.energy)))
        scores.append(("Sunlit Maximalist", m.energy * m.valence))
        scores.append(("Midnight Driver", m.energy * (1 - m.valence)))
        scores.append(("Mellow Optimist", (1 - m.energy) * m.valence))
        scores.append(("Deep Introspective", (1 - m.energy) * (1 - m.valence)))
        scores.append(("Acoustic Soul", m.organic * m.valence))
        scores.append(("Electric Dreamer", (1 - m.organic) * m.energy))
        return scores.max { $0.1 < $1.1 }?.0 ?? "Eclectic Explorer"
    }

    static func descriptors(for m: MoodVector) -> [String] {
        var out: [String] = []
        out.append(m.energy > 0.66 ? "High energy" : m.energy < 0.4 ? "Laid-back" : "Balanced energy")
        out.append(m.valence > 0.66 ? "Bright & upbeat" : m.valence < 0.4 ? "Dark & moody" : "Emotionally mixed")
        out.append(m.organic > 0.6 ? "Organic & acoustic" : m.organic < 0.3 ? "Electronic & synthetic" : "Blended textures")
        if m.bass > 0.7 { out.append("Bass-heavy") }
        return out
    }

    static func blurb(for m: MoodVector, title: String) -> String {
        switch title {
        case "High-Bass Head": return "You live for the low end — the drop is the point."
        case "Zenned-Out Hippie": return "Warm, unplugged, and unhurried. Music as a slow exhale."
        case "Sunlit Maximalist": return "Big, bright, and loud — your playlist is a party."
        case "Midnight Driver": return "Dark energy and momentum. Best played after dark, windows down."
        case "Mellow Optimist": return "Gentle and hopeful — easy melodies with a smile."
        case "Deep Introspective": return "Quiet and contemplative. You listen inward."
        case "Acoustic Soul": return "Real instruments, real feeling. You value the human touch."
        case "Electric Dreamer": return "Synths, textures, and neon energy — you live in the future."
        case "Feel-Good Seeker": return "You chase the songs that lift you up."
        default: return "Your taste refuses a single box — and that's the vibe."
        }
    }
}
