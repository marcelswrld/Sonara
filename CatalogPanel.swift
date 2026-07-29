import SwiftUI
import Charts

// Drop-in panel showing the tier-multiplier valuation. Add to any
// ScrollView with `CatalogPanel()`. Kept separate so PitchView stays
// readable and this can be A/B'd against the flat-growth view.
struct CatalogPanel: View {
    @State private var ltm = "100000"
    @State private var age = 5.0
    @State private var tier: PerformanceTier = .median
    @State private var sixYears = false

    private var valuation: CatalogValuation {
        CatalogValuationEngine.valuation(for: CatalogInput(
            ltmRevenue: ProjectionEngine.parseMoney(ltm) ?? 0,
            catalogAgeYears: age,
            durationYears: sixYears ? 6 : 5,
            tier: tier))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Multiplier valuation")
                .font(Theme.Type_.display(20))
                .foregroundStyle(Theme.Palette.chalk)

            // Inputs
            labeled("LAST 12 MONTHS REVENUE") {
                HStack {
                    Text("$").foregroundStyle(Theme.Palette.mist)
                    TextField("0", text: $ltm)
                        .keyboardType(.decimalPad)
                        .foregroundStyle(Theme.Palette.chalk)
                }
                .font(Theme.Type_.money(20))
            }

            labeled("CATALOG AGE · \(Int(age)) YRS") {
                Slider(value: $age, in: 1...20, step: 1).tint(Theme.Palette.mint)
            }

            Picker("Tier", selection: $tier) {
                ForEach(PerformanceTier.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Toggle("6-year horizon", isOn: $sixYears)
                .tint(Theme.Palette.mint)
                .font(Theme.Type_.body(14, weight: .medium))
                .foregroundStyle(Theme.Palette.mist)

            // Headline
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                Text(String(format: "%.2f×", valuation.multiplier))
                    .font(Theme.Type_.money(40))
                    .foregroundStyle(Theme.brassGlow)
                Text(ProjectionEngine.shortMoney(valuation.estimatedValue))
                    .font(Theme.Type_.money(20))
                    .foregroundStyle(Theme.Palette.chalk)
            }
            .contentTransition(.numericText())
            .animation(.snappy, value: valuation.multiplier)

            // Per-year share chart
            Chart(valuation.years) { y in
                BarMark(x: .value("Year", "Y\(y.id)"),
                        y: .value("Present value", y.presentValue))
                .foregroundStyle(Theme.mintGlow)
                .cornerRadius(4)
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine().foregroundStyle(Theme.Palette.hairline)
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text(ProjectionEngine.shortMoney(d))
                                .font(Theme.Type_.caption())
                                .foregroundStyle(Theme.Palette.mist)
                        }
                    }
                }
            }

            if valuation.usesApproximatedCurves {
                Label("Curves are modelled from published research, not a guarantee. Configurable before release.",
                      systemImage: "info.circle")
                    .font(Theme.Type_.caption())
                    .foregroundStyle(Theme.Palette.mist)
            }
        }
        .padding(Theme.Space.m)
        .background(Theme.Palette.panel,
                    in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .stroke(Theme.Palette.brass.opacity(0.4), lineWidth: 1))
    }

    @ViewBuilder
    private func labeled<C: View>(_ t: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(t).font(Theme.Type_.caption()).tracking(1.1)
                .foregroundStyle(Theme.Palette.mist)
            c()
        }
    }
}
