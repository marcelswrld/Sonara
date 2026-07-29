import XCTest
@testable import Sonara

// Golden numbers independently computed (see PROJECTION_FIX_NOTES.md).
final class ProjectionEngineTests: XCTestCase {

    func testBaseCase50k() {
        let r = ProjectionEngine.project(baseRevenue: 50_000, assumptions: .base)
        XCTAssertEqual(r.years.count, 5)
        XCTAssertEqual(r.years[0].nominal, 47_500.00, accuracy: 0.01)
        XCTAssertEqual(r.years[0].presentValue, 43_181.82, accuracy: 0.01)
        XCTAssertEqual(r.years[4].nominal, 38_689.05, accuracy: 0.01)
        XCTAssertEqual(r.years[4].presentValue, 24_022.85, accuracy: 0.01)
        XCTAssertEqual(r.nominalTotal, 214_908.11, accuracy: 0.01)
        XCTAssertEqual(r.presentValueTotal, 164_521.92, accuracy: 0.01)
    }

    func testSixYearHorizon() {
        var a = ProjectionAssumptions.base
        a.years = 6
        let r = ProjectionEngine.project(baseRevenue: 50_000, assumptions: a)
        XCTAssertEqual(r.nominalTotal, 251_662.70, accuracy: 0.01)
        XCTAssertEqual(r.presentValueTotal, 185_268.93, accuracy: 0.01)
    }

    func testScenarioTotals() {
        XCTAssertEqual(ProjectionEngine.project(baseRevenue: 50_000, assumptions: .conservative).presentValueTotal,
                       142_504.24, accuracy: 0.01)
        XCTAssertEqual(ProjectionEngine.project(baseRevenue: 50_000, assumptions: .optimistic).presentValueTotal,
                       206_133.91, accuracy: 0.01)
    }

    func testMoneyParsing() {
        XCTAssertEqual(ProjectionEngine.parseMoney("$1,234.50"), 1234.50)
        XCTAssertEqual(ProjectionEngine.parseMoney(" 50000 "), 50000)
        XCTAssertNil(ProjectionEngine.parseMoney(""))
        XCTAssertNil(ProjectionEngine.parseMoney("abc"))
    }

    func testFormatterNoLongerShowsZeroMillions() {
        XCTAssertEqual(ProjectionEngine.shortMoney(1_500), "$1.5k")   // old bug: "$0.00M"
        XCTAssertEqual(ProjectionEngine.shortMoney(0), "$0")
        XCTAssertEqual(ProjectionEngine.shortMoney(2_340_000), "$2.34M")
    }

    func testZeroAndNegativeInputsAreSafe() {
        XCTAssertEqual(ProjectionEngine.project(baseRevenue: 0, assumptions: .base).presentValueTotal, 0)
        XCTAssertTrue(ProjectionEngine.project(baseRevenue: -10, assumptions: .base).years.isEmpty)
    }
}

final class CatalogValuationEngineTests: XCTestCase {

    func testMedianMultiplierAndValue() {
        let input = CatalogInput(ltmRevenue: 100_000, catalogAgeYears: 5,
                                 durationYears: 10, tier: .median)
        let v = CatalogValuationEngine.valuation(for: input)
        XCTAssertEqual(v.multiplier, 3.739, accuracy: 0.01)
        XCTAssertEqual(v.estimatedValue, 373_851, accuracy: 5)
        XCTAssertEqual(v.years.count, 10)
        XCTAssertTrue(v.usesApproximatedCurves) // must always warn
    }

    func testTierOrdering() {
        func mult(_ t: PerformanceTier) -> Double {
            CatalogValuationEngine.multiplier(
                for: CatalogInput(ltmRevenue: 100_000, catalogAgeYears: 5,
                                  durationYears: 10, tier: t))
        }
        XCTAssertGreaterThan(mult(.top), mult(.median))
        XCTAssertGreaterThan(mult(.median), mult(.bottom))
    }

    func testZeroRevenueIsSafe() {
        let v = CatalogValuationEngine.valuation(
            for: CatalogInput(ltmRevenue: 0, catalogAgeYears: 5,
                              durationYears: 5, tier: .median))
        XCTAssertEqual(v.estimatedValue, 0)
        XCTAssertTrue(v.years.isEmpty)
    }
}

final class StreakEngineTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    func day(_ s: String) -> Date {
        let f = DateFormatter(); f.calendar = cal; f.dateFormat = "yyyy-MM-dd"
        f.timeZone = cal.timeZone; return f.date(from: s)!
    }
    func testConsecutiveDaysBuildStreak() {
        var s = StreakState()
        s = StreakEngine.register(s, now: day("2026-01-01"), calendar: cal)
        s = StreakEngine.register(s, now: day("2026-01-02"), calendar: cal)
        s = StreakEngine.register(s, now: day("2026-01-03"), calendar: cal)
        XCTAssertEqual(s.current, 3)
        XCTAssertEqual(s.longest, 3)
    }
    func testGapResetsStreakButKeepsLongest() {
        var s = StreakState()
        for d in ["2026-01-01","2026-01-02"] { s = StreakEngine.register(s, now: day(d), calendar: cal) }
        s = StreakEngine.register(s, now: day("2026-01-05"), calendar: cal) // 3-day gap
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.longest, 2)
    }
    func testSameDayDoesNotDoubleCount() {
        var s = StreakState()
        s = StreakEngine.register(s, now: day("2026-01-01"), calendar: cal)
        s = StreakEngine.register(s, now: day("2026-01-01"), calendar: cal)
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.totalDiscovered, 2)
    }
    func testBadges() {
        var s = StreakState()
        var d = day("2026-01-01")
        for _ in 0..<7 { s = StreakEngine.register(s, now: d, calendar: cal); d = cal.date(byAdding: .day, value: 1, to: d)! }
        XCTAssertTrue(StreakEngine.earnedBadges(s).contains(.week))
    }
}
