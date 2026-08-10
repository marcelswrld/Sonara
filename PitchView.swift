import SwiftUI
import Charts

// =====================================================================
// Pitch — the MyPitch concept, rebuilt on the corrected engine.
// Brass is the money color and appears only here. The signature
// element is the decay curve drawn behind the valuation.
// =====================================================================

struct PitchView: View {
    @State private var revenueInput: String = "50000"
    @State private var scenario: Scenario = .base
    @State private var sixYears = false

    enum Scenario: String, CaseIterable, Identifiable {
        case conservative = "Conservative"
        case base = "Base"
        case optimistic = "Optimistic"
        var id: String { rawValue }

        var assumptions: ProjectionAssumptions {
            switch self {
            case .conservative: return .conservative
            case .base:         return .base
            case .optimistic:   return .optimistic
            }
        }
        var note: String {
            switch self {
            case .conservative: return "−10%/yr · catalogs cool fast"
            case .base:         return "−5%/yr · median catalog decay"
            case .optimistic:   return "+3%/yr · sustained momentum"
            }
        }
    }

    private var result: ProjectionResult {
        var a = scenario.assumptions
        a.years = sixYears ? 6 : 5
        let base = ProjectionEngine.parseMoney(revenueInput) ?? 0
        return ProjectionEngine.project(baseRevenue: base, assumptions: a)
    }

    @FocusState private var revenueFocused: Bool

    var body: some View {
        ZStack {
            Theme.Palette.ink.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    Text("Pitch")
                        .font(Theme.Type_.display(30))
                        .foregroundStyle(Theme.Palette.chalk)

                    inputCard
                    scenarioPicker
                    valuationCard
                    yearTable
                    CatalogPanel()
                    disclosure
                }
                .padding(Theme.Space.l)
            }
            // Tap anywhere outside the field to dismiss the keypad.
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { revenueFocused = false }
        }
        .toolbar {
            // The decimal keypad has no return key; give it a Done button.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { revenueFocused = false }
            }
        }
    }

    // MARK: Input

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("LAST 12 MONTHS STREAMING REVENUE")
                .font(Theme.Type_.caption())
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.mist)
            HStack {
                Text("$")
                    .font(Theme.Type_.money(28))
                    .foregroundStyle(Theme.Palette.mist)
                TextField("0", text: $revenueInput)
                    .keyboardType(.decimalPad)
                    .focused($revenueFocused)
                    .font(Theme.Type_.money(28))
                    .foregroundStyle(Theme.Palette.chalk)
            }
            HStack {
                Toggle(isOn: $sixYears) {
                    Text("6-year horizon")
                        .font(Theme.Type_.body(14, weight: .medium))
                        .foregroundStyle(Theme.Palette.mist)
                }
                .tint(Theme.Palette.mint)
            }
        }
        .padding(Theme.Space.m)
        .background(Theme.Palette.panel,
                    in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .stroke(Theme.Palette.hairline, lineWidth: 1))
    }

    // MARK: Scenarios

    private var scenarioPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.s) {
                ForEach(Scenario.allCases) { s in
                    Button {
                        withAnimation(.snappy) { scenario = s }
                    } label: {
                        Text(s.rawValue)
                            .font(Theme.Type_.body(14, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                scenario == s ? Theme.Palette.mint.opacity(0.15) : Theme.Palette.panel,
                                in: Capsule())
                            .overlay(Capsule().stroke(
                                scenario == s ? Theme.Palette.mint : Theme.Palette.hairline,
                                lineWidth: 1))
                            .foregroundStyle(scenario == s ? Theme.Palette.mint : Theme.Palette.mist)
                    }
                }
            }
            Text(scenario.note)
                .font(Theme.Type_.caption())
                .foregroundStyle(Theme.Palette.mist)
        }
    }

    // MARK: Valuation (signature surface)

    private var valuationCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("SECURITIZED VALUE · TODAY'S DOLLARS")
                .font(Theme.Type_.caption())
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.mist)

            Text(ProjectionEngine.shortMoney(result.presentValueTotal))
                .font(Theme.Type_.money(44))
                .foregroundStyle(Theme.brassGlow)
                .contentTransition(.numericText())
                .animation(.snappy, value: result.presentValueTotal)

            HStack(spacing: Theme.Space.m) {
                StatPair(label: "Revenue path total",
                         value: ProjectionEngine.shortMoney(result.nominalTotal))
                StatPair(label: "Discount rate", value: "10%")
                StatPair(label: "Horizon", value: sixYears ? "6 yrs" : "5 yrs")
            }
        }
        .padding(Theme.Space.m)
        .background(Theme.Palette.panel,
                    in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .stroke(Theme.Palette.brass.opacity(0.4), lineWidth: 1))
    }

    // MARK: Chart + rows

    private var yearTable: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Chart(result.years) { row in
                BarMark(x: .value("Year", "Y\(row.id)"),
                        y: .value("Projected", row.nominal))
                .foregroundStyle(Theme.mintGlow)
                .cornerRadius(4)

                LineMark(x: .value("Year", "Y\(row.id)"),
                         y: .value("PV", row.presentValue))
                .foregroundStyle(Theme.Palette.brass)
                .symbol(Circle())
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Theme.Palette.hairline)
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(ProjectionEngine.shortMoney(d))
                                .font(Theme.Type_.caption())
                                .foregroundStyle(Theme.Palette.mist)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(Theme.Type_.caption())
                        .foregroundStyle(Theme.Palette.mist)
                }
            }
            .frame(height: 220)

            ForEach(result.years) { row in
                HStack {
                    Text("Year \(row.id)")
                        .font(Theme.Type_.body(14, weight: .medium))
                        .foregroundStyle(Theme.Palette.chalk)
                    Spacer()
                    Text(ProjectionEngine.shortMoney(row.nominal))
                        .font(Theme.Type_.caption())
                        .foregroundStyle(Theme.Palette.mint)
                    Text(ProjectionEngine.shortMoney(row.presentValue))
                        .font(Theme.Type_.caption())
                        .foregroundStyle(Theme.Palette.brass)
                        .frame(width: 76, alignment: .trailing)
                }
                .padding(.vertical, 6)
                Divider().overlay(Theme.Palette.hairline)
            }
        }
    }

    private var disclosure: some View {
        Text("Hypothetical projection, not an offer or a promise of income. Assumptions: \(scenario.note), 10% discount rate, per Kosyuk & Stoikov (2022). Configurable before release.")
            .font(Theme.Type_.caption())
            .foregroundStyle(Theme.Palette.mist.opacity(0.8))
    }
}

// MARK: - Pieces

struct StatPair: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.Type_.money(16, weight: .bold))
                .foregroundStyle(Theme.Palette.chalk)
            Text(label)
                .font(Theme.Type_.caption(10))
                .foregroundStyle(Theme.Palette.mist)
        }
    }
}

/// The decay-curve motif: a smooth line through the projected revenue
/// path. Reused on the Wrapped share card as a brand texture.
struct DecayCurve: Shape {
    let values: [Double]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard values.count > 1, let maxV = values.max(), maxV > 0 else { return p }
        let stepX = rect.width / CGFloat(values.count - 1)
        func pt(_ i: Int) -> CGPoint {
            CGPoint(x: CGFloat(i) * stepX,
                    y: rect.height * (1 - CGFloat(values[i] / maxV) * 0.9) )
        }
        p.move(to: pt(0))
        for i in 1..<values.count {
            let prev = pt(i - 1), cur = pt(i)
            let mid = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
            p.addQuadCurve(to: mid, control: prev)
            if i == values.count - 1 { p.addQuadCurve(to: cur, control: cur) }
        }
        return p
    }
}
