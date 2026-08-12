import SwiftUI

// =====================================================================
// TasteMapView — the "coolest thing in the app." An interactive genre
// heat-map: each saved genre is a glowing cell whose size + color reflect
// how strongly it defines your taste. Cells breathe, respond to taps, and
// the whole grid can be dragged to parallax. Below it, an animated DNA
// spectrum of audio features.
// =====================================================================

struct TasteMapView: View {
    @EnvironmentObject var taste: TasteEngine
    @State private var appear = false
    @State private var parallax: CGSize = .zero
    @State private var selectedGenre: String?

    var body: some View {
        let map = taste.map
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                header(map)

                if map.totalSaved == 0 {
                    emptyState
                } else {
                    heatMap(map)
                    if !map.dna.isEmpty { dnaSpectrum(map) }
                    tasteTypeCard(map)
                }
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.Palette.ink.ignoresSafeArea())
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { appear = true } }
    }

    // MARK: Header
    private func header(_ map: TasteMap) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Taste Map").font(Theme.Type_.display(30))
                .foregroundStyle(Theme.Palette.chalk)
            Text("\(map.totalSaved) saved · \(map.topGenre ?? "building…")")
                .font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist)
        }
    }

    // MARK: Heat map — the centerpiece
    private func heatMap(_ map: TasteMap) -> some View {
        // Flow-layout of glowing cells sized by intensity.
        FlowGrid(spacing: 10) {
            ForEach(Array(map.genreHeat.enumerated()), id: \.element.genre) { i, cell in
                HeatCell(genre: cell.genre,
                         intensity: cell.intensity,
                         index: i,
                         selected: selectedGenre == cell.genre,
                         appear: appear)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            selectedGenre = selectedGenre == cell.genre ? nil : cell.genre
                        }
                    }
            }
        }
        .padding(Theme.Space.m)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.Palette.panel)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.Palette.hairline, lineWidth: 1))
        )
        // draggable parallax for a tactile, 3D-ish feel
        .rotation3DEffect(.degrees(parallax.width / 20), axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(-parallax.height / 20), axis: (x: 1, y: 0, z: 0))
        .gesture(DragGesture()
            .onChanged { parallax = $0.translation }
            .onEnded { _ in withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { parallax = .zero } })
    }

    // MARK: DNA spectrum
    private func dnaSpectrum(_ map: TasteMap) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("YOUR AUDIO DNA").font(Theme.Type_.caption()).tracking(1.4)
                .foregroundStyle(Theme.Palette.mist)
            ForEach(Array(map.dna.enumerated()), id: \.element.label) { i, d in
                DNABar(label: d.label, value: d.value, index: i, appear: appear)
            }
        }
        .padding(Theme.Space.m)
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .fill(Theme.Palette.panel)
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Theme.Palette.hairline, lineWidth: 1)))
    }

    private func tasteTypeCard(_ map: TasteMap) -> some View {
        VStack(spacing: Theme.Space.s) {
            Text("YOU ARE A").font(Theme.Type_.caption()).tracking(2)
                .foregroundStyle(Theme.Palette.mist)
            Text(map.tasteType)
                .font(Theme.Type_.display(28))
                .foregroundStyle(Theme.mintGlow)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Space.l)
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .fill(Theme.Palette.panel)
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Theme.Palette.mint.opacity(0.4), lineWidth: 1)))
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 44)).foregroundStyle(Theme.Palette.mint.opacity(0.6))
            Text("Start swiping to build your map")
                .font(Theme.Type_.display(20)).foregroundStyle(Theme.Palette.chalk)
            Text("Every artist you save adds color and shape to your taste.")
                .font(Theme.Type_.body(14)).foregroundStyle(Theme.Palette.mist)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }
}

// MARK: - Heat cell

struct HeatCell: View {
    let genre: String
    let intensity: Double     // 0...1
    let index: Int
    let selected: Bool
    let appear: Bool
    @State private var breathe = false

    // color ramp: cool violet (low) -> mint -> warm gold (high)
    private var color: Color {
        // interpolate across three stops by intensity
        let stops: [(Double, Color)] = [
            (0.0, Color(hex: 0x5B4B8A)),   // violet
            (0.5, Color(hex: 0x1DB954)),   // mint
            (1.0, Color(hex: 0xF5A15E))    // warm
        ]
        return Self.ramp(intensity, stops)
    }

    private var size: CGFloat { 54 + CGFloat(intensity) * 66 } // 54...120

    var body: some View {
        Text(genre)
            .font(.system(size: 11 + intensity * 4, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .padding(6)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color)
                    .shadow(color: color.opacity(0.7), radius: selected ? 22 : 12,
                            x: 0, y: selected ? 0 : 6)
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(selected ? 0.9 : 0.15), lineWidth: selected ? 2 : 1))
            .scaleEffect((appear ? 1 : 0.2) * (breathe ? 1.04 : 0.98) * (selected ? 1.12 : 1))
            .opacity(appear ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7)
                        .delay(Double(index) * 0.05), value: appear)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2 + Double(index % 5) * 0.3)
                                .repeatForever(autoreverses: true)) { breathe = true }
            }
    }

    static func ramp(_ t: Double, _ stops: [(Double, Color)]) -> Color {
        let clamped = min(max(t, 0), 1)
        for i in 0..<stops.count - 1 {
            let (t0, c0) = stops[i], (t1, c1) = stops[i + 1]
            if clamped >= t0 && clamped <= t1 {
                let f = (clamped - t0) / (t1 - t0)
                return c0.blend(to: c1, fraction: f)
            }
        }
        return stops.last!.1
    }
}

// MARK: - DNA bar

struct DNABar: View {
    let label: String
    let value: Double     // 0...1
    let index: Int
    let appear: Bool

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Text(label).font(Theme.Type_.caption())
                .foregroundStyle(Theme.Palette.mist)
                .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.panel).frame(height: 10)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: 0x1DB954), Color(hex: 0x7C5CFF)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: appear ? geo.size.width * value : 0, height: 10)
                        .animation(.easeOut(duration: 0.8).delay(Double(index) * 0.08), value: appear)
                }
            }
            .frame(height: 10)
            Text("\(Int(value * 100))")
                .font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.chalk)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Simple flow layout (wrap cells to next line)

struct FlowGrid<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content
    var body: some View {
        // iOS16-friendly wrap using Layout
        FlowLayout(spacing: spacing) { content }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.minX + maxWidth { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

// MARK: - Color helpers

extension Color {
    func blend(to other: Color, fraction: Double) -> Color {
        let f = min(max(fraction, 0), 1)
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, bl1: CGFloat = 0, al1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, bl2: CGFloat = 0, al2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &bl1, alpha: &al1)
        b.getRed(&r2, green: &g2, blue: &bl2, alpha: &al2)
        return Color(red: Double(r1 + (r2 - r1) * f),
                     green: Double(g1 + (g2 - g1) * f),
                     blue: Double(bl1 + (bl2 - bl1) * f))
    }
}
