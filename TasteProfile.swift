import Foundation
import SwiftUI

// =====================================================================
// TasteProfile — the payoff for swiping. Every saved track/artist feeds
// two things: a GENRE heat-map (which sounds you gravitate to) and an
// audio-feature DNA spectrum (energy, danceability, valence, etc.).
// Persists locally alongside DiscoveryStore.
// =====================================================================

// Spotify audio-features for a track (0...1 unless noted).
struct AudioFeatures: Codable, Hashable {
    let energy: Double
    let danceability: Double
    let valence: Double      // musical positivity
    let acousticness: Double
    let instrumentalness: Double
    let tempo: Double        // BPM

    static let zero = AudioFeatures(energy: 0, danceability: 0, valence: 0,
                                    acousticness: 0, instrumentalness: 0, tempo: 0)
}

// One saved thing that contributes to taste.
struct TasteSeed: Codable, Identifiable, Hashable {
    let id: String              // track or artist id
    let name: String
    let artist: String
    let genres: [String]
    let artworkURL: String?
    let features: AudioFeatures?
    let savedAt: Date
}

// Aggregated result the map renders.
struct TasteMap {
    // genre -> intensity 0...1 (for the heat-map cells)
    let genreHeat: [(genre: String, intensity: Double)]
    // averaged audio-feature DNA 0...1 (tempo normalized)
    let dna: [(label: String, value: Double)]
    let totalSaved: Int
    let topGenre: String?
    // a derived "taste type" label for flavor
    let tasteType: String
}

@MainActor
final class TasteEngine: ObservableObject {
    @Published private(set) var seeds: [TasteSeed] = []
    private let key = "taste.seeds.v1"

    init() { load() }

    func add(_ seed: TasteSeed) {
        guard !seeds.contains(where: { $0.id == seed.id }) else { return }
        seeds.insert(seed, at: 0)
        save()
    }

    func reset() { seeds = []; save() }

    var map: TasteMap {
        // --- genre heat ---
        var genreCounts: [String: Int] = [:]
        for s in seeds { for g in s.genres { genreCounts[g, default: 0] += 1 } }
        let maxCount = max(genreCounts.values.max() ?? 1, 1)
        let heat = genreCounts
            .map { (genre: $0.key.capitalized, intensity: Double($0.value) / Double(maxCount)) }
            .sorted { $0.intensity > $1.intensity }
            .prefix(12)
        // --- audio DNA (average of available features) ---
        let feats = seeds.compactMap(\.features)
        func avg(_ kp: (AudioFeatures) -> Double) -> Double {
            guard !feats.isEmpty else { return 0 }
            return feats.map(kp).reduce(0, +) / Double(feats.count)
        }
        let dna: [(String, Double)] = feats.isEmpty ? [] : [
            ("Energy", avg(\.energy)),
            ("Dance", avg(\.danceability)),
            ("Mood", avg(\.valence)),
            ("Acoustic", avg(\.acousticness)),
            ("Instrumental", avg(\.instrumentalness)),
            ("Tempo", min(avg(\.tempo) / 200.0, 1.0)) // normalize BPM to 0..1
        ]
        let top = heat.first?.genre
        return TasteMap(genreHeat: Array(heat),
                        dna: dna,
                        totalSaved: seeds.count,
                        topGenre: top,
                        tasteType: Self.tasteType(from: dna, topGenre: top))
    }

    // A little flavor label derived from the DNA.
    private static func tasteType(from dna: [(String, Double)], topGenre: String?) -> String {
        guard !dna.isEmpty else { return "Explorer" }
        let d = Dictionary(uniqueKeysWithValues: dna)
        let energy = d["Energy"] ?? 0, mood = d["Mood"] ?? 0, acoustic = d["Acoustic"] ?? 0
        switch (energy > 0.6, mood > 0.6, acoustic > 0.5) {
        case (true, true, _):   return "Sunlit Maximalist"
        case (true, false, _):  return "Midnight Driver"
        case (false, _, true):  return "Acoustic Wanderer"
        case (false, true, _):  return "Mellow Optimist"
        default:                return "Deep Listener"
        }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(seeds) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([TasteSeed].self, from: d) { seeds = v }
    }
}
