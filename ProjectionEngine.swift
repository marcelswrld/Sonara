import Foundation

// =====================================================================
// ProjectionEngine — the SAME math as the MyPitch fix
// (01-mypitch-fix/RevenueStreamTableViewCell.swift). One source of
// truth; if an assumption changes, change it in both places until the
// old app is retired.
//
//   Year i nominal  = base × (1 + growth)^i
//   Year i PV       = nominal ÷ (1 + discount)^i
//   Valuation       = Σ PV
//
// Defaults pending Mark's written sign-off (ASSUMPTIONS_EMAIL_DRAFT.md):
// discount 10% (Kosyuk & Stoikov 2022), growth −5% base case, 5 years.
// =====================================================================

struct ProjectionAssumptions: Equatable {
    var growthRate: Double
    var discountRate: Double
    var years: Int

    static let base         = ProjectionAssumptions(growthRate: -0.05, discountRate: 0.10, years: 5)
    static let conservative = ProjectionAssumptions(growthRate: -0.10, discountRate: 0.10, years: 5)
    static let optimistic   = ProjectionAssumptions(growthRate:  0.03, discountRate: 0.10, years: 5)
}

struct ProjectedYear: Identifiable {
    let id: Int          // 1 = next year
    let nominal: Double
    let presentValue: Double
}

struct ProjectionResult {
    let years: [ProjectedYear]
    let nominalTotal: Double
    let presentValueTotal: Double
}

enum ProjectionEngine {

    static func project(baseRevenue: Double,
                        assumptions: ProjectionAssumptions) -> ProjectionResult {
        guard baseRevenue > 0, assumptions.years > 0 else {
            return ProjectionResult(years: [], nominalTotal: 0, presentValueTotal: 0)
        }
        var rows: [ProjectedYear] = []
        var nominalTotal = 0.0, pvTotal = 0.0
        for i in 1...assumptions.years {
            let nominal = baseRevenue * pow(1 + assumptions.growthRate, Double(i))
            let pv = nominal / pow(1 + assumptions.discountRate, Double(i))
            rows.append(ProjectedYear(id: i, nominal: nominal, presentValue: pv))
            nominalTotal += nominal
            pvTotal += pv
        }
        return ProjectionResult(years: rows, nominalTotal: nominalTotal, presentValueTotal: pvTotal)
    }

    static func parseMoney(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    static func shortMoney(_ value: Double) -> String {
        let v = abs(value)
        switch v {
        case 0:            return "$0"
        case ..<1:         return String(format: "$%.2f", value)
        case ..<1_000:     return String(format: "$%.0f", value)
        case ..<1_000_000: return String(format: "$%.1fk", value / 1_000)
        default:           return String(format: "$%.2fM", value / 1_000_000)
        }
    }
}
