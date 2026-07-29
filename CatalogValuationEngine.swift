import Foundation

// =====================================================================
// CatalogValuationEngine — the upgraded MyPitch methodology
// =====================================================================
// Combines two things:
//   1) The DCF spine from ProjectionEngine (sourced: Kosyuk & Stoikov
//      2022 fix r = 10%).
//   2) The tier-based MULTIPLIER model — how catalog deals are actually
//      quoted ("3.2x last-twelve-months revenue"), drawn from the
//      reference implementation Mark received.
//
// HONESTY BOUNDARY (read before showing any number to an investor):
//   • SOURCED      → discount rate 10%; multiplier = Σ discounted shares.
//   • APPROXIMATED → the revenue-share CURVES below. Kosyuk & Stoikov
//     publish these only as Figure 1 plots, not tables. These constants
//     are a curve FIT, not the paper's data. Every method that uses them
//     is marked `approximated:` so it can be swapped when Mark supplies
//     real Royalty-Exchange curve data.
//   • DO NOT SHIP AS DATA → the old "market ask = median x 1.05, bid =
//     bottom x 0.95" was fabricated. It is NOT reproduced here. Market
//     comparison stays out until we have real bid/ask numbers.
// =====================================================================

enum PerformanceTier: String, CaseIterable, Identifiable {
    case top    = "Top decile"
    case median = "Median"
    case bottom = "Bottom decile"
    var id: String { rawValue }
    var percentile: Double {
        switch self {
        case .top: return 0.90
        case .median: return 0.50
        case .bottom: return 0.10
        }
    }
}

struct CatalogInput {
    var ltmRevenue: Double        // last twelve months revenue
    var catalogAgeYears: Double   // dollar-weighted age
    var durationYears: Int        // 5 or 6 for MyPitch; up to 30 supported
    var discountRate: Double = 0.10
    var tier: PerformanceTier = .median
}

struct CatalogYear: Identifiable {
    let id: Int
    let revenueShare: Double        // share of LTM expected in year i
    let discountedShare: Double     // that share, discounted to today
    let projectedRevenue: Double    // share x LTM (nominal)
    let presentValue: Double        // discountedShare x LTM
}

struct CatalogValuation {
    let multiplier: Double          // Σ discountedShare — quote as "Nx"
    let estimatedValue: Double      // multiplier x LTM = present value total
    let tier: PerformanceTier
    let years: [CatalogYear]
    /// True where any figure derives from the approximated curves.
    let usesApproximatedCurves: Bool
}

enum CatalogValuationEngine {

    /// APPROXIMATED. Curve fit to Kosyuk & Stoikov Fig.1 behaviour:
    /// new songs decay across tiers; older top-decile songs grow;
    /// bottom decile decays throughout. Replace with sourced data
    /// when available — signature stays stable.
    static func approximatedRevenueShare(age: Double, yearOffset i: Int, percentile: Double) -> Double {
        let base: Double
        switch percentile {
        case 0.90:
            base = age < 3 ? 0.85 + Double(i) * 0.02 : 1.05 + Double(i) * 0.03
        case 0.50:
            base = 0.80 + Double(i) * 0.01
        case 0.10:
            base = age < 5 ? 0.70 + Double(i) * 0.005 : 0.65 + Double(i) * 0.008
        default:
            base = 0.80 + Double(i) * 0.01
        }
        let ageFactor  = exp(-age * 0.02)
        let yearFactor = exp(-Double(i) * 0.05)
        return min(max(base * ageFactor * yearFactor, 0.01), 3.0)
    }

    static func valuation(for input: CatalogInput) -> CatalogValuation {
        guard input.ltmRevenue > 0, input.durationYears > 0 else {
            return CatalogValuation(multiplier: 0, estimatedValue: 0,
                                    tier: input.tier, years: [],
                                    usesApproximatedCurves: true)
        }
        var multiplier = 0.0
        var rows: [CatalogYear] = []
        for i in 1...input.durationYears {
            let share = approximatedRevenueShare(age: input.catalogAgeYears,
                                                 yearOffset: i,
                                                 percentile: input.tier.percentile)
            let disc = share / pow(1 + input.discountRate, Double(i))
            multiplier += disc
            rows.append(CatalogYear(
                id: i,
                revenueShare: share,
                discountedShare: disc,
                projectedRevenue: share * input.ltmRevenue,
                presentValue: disc * input.ltmRevenue))
        }
        return CatalogValuation(
            multiplier: multiplier,
            estimatedValue: multiplier * input.ltmRevenue,
            tier: input.tier,
            years: rows,
            usesApproximatedCurves: true)
    }

    static func multiplier(for input: CatalogInput) -> Double {
        valuation(for: input).multiplier
    }
}
