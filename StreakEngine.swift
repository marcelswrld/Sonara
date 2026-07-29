import Foundation

// Milestone 2 — daily discovery streaks, badges, milestones.
// NOTE: streaks must ultimately validate against a SERVER date, not the
// device clock, or users game it by changing their clock. This local
// engine is the UI/logic layer; swap `now` for a server timestamp when
// the backend endpoint exists.
struct StreakState: Codable, Equatable {
    var current: Int = 0
    var longest: Int = 0
    var lastActiveDay: Date? = nil
    var totalDiscovered: Int = 0
}

enum Badge: String, CaseIterable, Identifiable {
    case firstFind = "First find"
    case week = "7-day streak"
    case month = "30-day streak"
    case century = "100 discovered"
    var id: String { rawValue }
    var milestone: Int {
        switch self {
        case .firstFind: return 1
        case .week: return 7
        case .month: return 30
        case .century: return 100
        }
    }
}

enum StreakEngine {
    /// Call when the user discovers/saves a track. `now` should be a
    /// server date in production.
    static func register(_ s: StreakState, now: Date, calendar: Calendar = .current) -> StreakState {
        var next = s
        next.totalDiscovered += 1
        let today = calendar.startOfDay(for: now)
        if let last = s.lastActiveDay {
            let lastDay = calendar.startOfDay(for: last)
            let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            switch gap {
            case 0:  break                      // already counted today
            case 1:  next.current += 1          // consecutive day
            default: next.current = 1           // streak broken, restart
            }
        } else {
            next.current = 1
        }
        next.longest = max(next.longest, next.current)
        next.lastActiveDay = today
        return next
    }

    static func earnedBadges(_ s: StreakState) -> [Badge] {
        Badge.allCases.filter { badge in
            switch badge {
            case .century: return s.totalDiscovered >= 100
            default:       return s.longest >= badge.milestone
            }
        }
    }
}
