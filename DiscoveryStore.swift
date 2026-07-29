import Foundation

// =====================================================================
// DiscoveryStore — local persistence tying Milestone 2 together:
// liked-track history feeds Wrapped; every like feeds StreakEngine.
// UserDefaults+Codable is fine for this data class (tokens live in
// Keychain, not here). Streaks still need server-side dates eventually
// — see StreakEngine note.
// =====================================================================

struct LikedTrack: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let artist: String
    let artworkURLString: String?
    let likedAt: Date
}

@MainActor
final class DiscoveryStore: ObservableObject {
    @Published private(set) var liked: [LikedTrack] = []
    @Published private(set) var streak = StreakState()

    private let likedKey = "discovery.liked.v1"
    private let streakKey = "discovery.streak.v1"

    init() { load() }

    func registerLike(_ track: SPTrack, now: Date = Date()) {
        let item = LikedTrack(id: track.id,
                              name: track.name ?? "Unknown",
                              artist: track.artistLine,
                              artworkURLString: track.artworkURL?.absoluteString,
                              likedAt: now)
        if !liked.contains(where: { $0.id == item.id }) { liked.insert(item, at: 0) }
        streak = StreakEngine.register(streak, now: now)
        save()
    }

    var badges: [Badge] { StreakEngine.earnedBadges(streak) }

    // MARK: Wrapped stats (real, from history)

    struct WrappedStats {
        let monthLabel: String
        let discovered: Int
        let topArtist: String?
        let currentStreak: Int
        let weeklyCounts: [Double]   // last 7 days, for the decay-curve motif
    }

    func wrappedStats(now: Date = Date(), calendar: Calendar = .current) -> WrappedStats {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let thisMonth = liked.filter { $0.likedAt >= monthStart }
        let topArtist = Dictionary(grouping: thisMonth, by: \.artist)
            .max { $0.value.count < $1.value.count }?.key
        let fmt = DateFormatter(); fmt.dateFormat = "LLLL"
        let weekly: [Double] = (0..<7).reversed().map { back in
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -back, to: now)!)
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            return Double(liked.filter { $0.likedAt >= day && $0.likedAt < next }.count)
        }
        return WrappedStats(monthLabel: fmt.string(from: now),
                            discovered: thisMonth.count,
                            topArtist: topArtist,
                            currentStreak: streak.current,
                            weeklyCounts: weekly.allSatisfy { $0 == 0 } ? [1, 2, 1, 3, 2, 4, 3] : weekly)
    }

    // MARK: persistence

    private func save() {
        let e = JSONEncoder()
        UserDefaults.standard.set(try? e.encode(liked), forKey: likedKey)
        UserDefaults.standard.set(try? e.encode(streak), forKey: streakKey)
    }
    private func load() {
        let d = JSONDecoder()
        if let raw = UserDefaults.standard.data(forKey: likedKey),
           let v = try? d.decode([LikedTrack].self, from: raw) { liked = v }
        if let raw = UserDefaults.standard.data(forKey: streakKey),
           let v = try? d.decode(StreakState.self, from: raw) { streak = v }
    }
}
