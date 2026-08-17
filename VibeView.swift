import SwiftUI

// =====================================================================
// VibeView — "who you are musically." The unique, visual heart of the
// app. Shows a living MOOD ORB colored by the user's taste, a
// personality title + descriptors, top genres, and a DAILY MOOD ARC
// built from when they listen to what. All from data new apps can read.
// =====================================================================

struct VibeView: View {
    @EnvironmentObject var auth: SpotifyAuth
    @EnvironmentObject var mood: MoodEngine

    var body: some View {
        ZStack {
            AuroraBackground()
            if !auth.isSignedIn {
                connectPrompt
            } else {
                content
            }
        }
        .task(id: auth.isSignedIn) { if auth.isSignedIn { await mood.refresh() } }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                Text("Your Vibe").font(Theme.Type_.display(32))
                    .foregroundStyle(Theme.Palette.chalk)

                if mood.loading && mood.personality == nil {
                    loadingState
                } else if let p = mood.personality {
                    MoodOrb(personality: p)
                    personalityCard(p)
                    if !p.topGenres.isEmpty { genresCard(p) }
                    if !mood.dayArc.isEmpty { dayArcCard }
                } else {
                    emptyState
                }
            }
            .padding(Theme.Space.l)
            .padding(.bottom, 40)
        }
    }

    // MARK: Personality
    private func personalityCard(_ p: Personality) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("YOU ARE").font(Theme.Type_.caption()).tracking(2)
                .foregroundStyle(Theme.Palette.mist)
            Text(p.title)
                .font(Theme.Type_.display(30))
                .foregroundStyle(LinearGradient(colors: [p.color, p.accent],
                                                startPoint: .leading, endPoint: .trailing))
            Text(p.blurb).font(Theme.Type_.body(15))
                .foregroundStyle(Theme.Palette.mist)
            FlowChips(p.descriptors, color: p.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .background(cardBG)
    }

    private func genresCard(_ p: Personality) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("YOUR TOP GENRES").font(Theme.Type_.caption()).tracking(1.5)
                .foregroundStyle(Theme.Palette.mist)
            ForEach(Array(p.topGenres.enumerated()), id: \.offset) { i, g in
                GenreBar(name: g.0, weight: Double(g.1),
                         maxWeight: Double(p.topGenres.first?.1 ?? 1),
                         color: p.accent, index: i)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .background(cardBG)
    }

    // MARK: Daily mood arc
    private var dayArcCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("YOUR DAY IN MOOD").font(Theme.Type_.caption()).tracking(1.5)
                .foregroundStyle(Theme.Palette.mist)
            Text("Energy through the hours you listen")
                .font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist.opacity(0.7))
            DayArcChart(points: mood.dayArc)
                .frame(height: 160)
            HStack {
                Label("Calm", systemImage: "moon.fill").font(Theme.Type_.caption())
                    .foregroundStyle(Color(hex: 0x6FA8DC))
                Spacer()
                Label("Energetic", systemImage: "flame.fill").font(Theme.Type_.caption())
                    .foregroundStyle(Theme.Palette.mint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .background(cardBG)
    }

    private var cardBG: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .fill(Theme.Palette.panel.opacity(0.85))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Theme.Palette.hairline, lineWidth: 1))
    }

    private var loadingState: some View {
        VStack(spacing: Theme.Space.l) {
            Circle().fill(Theme.Palette.panel).frame(width: 200, height: 200)
                .shimmering()
            RoundedRectangle(cornerRadius: 16).fill(Theme.Palette.panel)
                .frame(height: 120).shimmering()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "waveform.path.ecg").font(.system(size: 44))
                .foregroundStyle(Theme.Palette.mint).pulsing()
            Text("Building your vibe…").font(Theme.Type_.display(20))
                .foregroundStyle(Theme.Palette.chalk)
            Text(mood.lastError ?? "Listen on Spotify a little, then pull back here.")
                .font(Theme.Type_.body(14)).foregroundStyle(Theme.Palette.mist)
                .multilineTextAlignment(.center)
            Button { Task { await mood.refresh() } } label: {
                Text("Refresh").font(Theme.Type_.body(15, weight: .semibold))
                    .padding(.vertical, 10).padding(.horizontal, 24)
                    .background(Theme.Palette.mint, in: Capsule())
                    .foregroundStyle(Theme.Palette.ink)
            }
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }

    private var connectPrompt: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "waveform.path.ecg").font(.system(size: 46))
                .foregroundStyle(Theme.Palette.mint).pulsing()
            Text("Connect Spotify to reveal your vibe")
                .font(Theme.Type_.display(20)).foregroundStyle(Theme.Palette.chalk)
                .multilineTextAlignment(.center)
            Button { auth.signIn() } label: {
                Text("Connect Spotify").font(Theme.Type_.body(16, weight: .semibold))
                    .padding(.vertical, 12).padding(.horizontal, 24)
                    .background(Theme.Palette.mint, in: Capsule())
                    .foregroundStyle(Theme.Palette.ink)
            }
        }
        .padding(Theme.Space.xl)
    }
}

// MARK: - The living Mood Orb (the signature visual)

struct MoodOrb: View {
    let personality: Personality
    @State private var rotate = false
    @State private var pulse = false

    var body: some View {
        let m = personality.mood
        ZStack {
            // outer glow
            Circle()
                .fill(RadialGradient(colors: [personality.color.opacity(0.6), .clear],
                                     center: .center, startRadius: 10, endRadius: 150))
                .frame(width: 300, height: 300)
                .scaleEffect(pulse ? 1.08 : 0.95)

            // rotating gradient core — energy drives speed feel
            Circle()
                .fill(AngularGradient(colors: [personality.color, personality.accent,
                                               personality.color],
                                      center: .center))
                .frame(width: 190, height: 190)
                .blur(radius: 6)
                .rotationEffect(.degrees(rotate ? 360 : 0))

            // inner sheen
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.35), .clear],
                                     center: UnitPoint(x: 0.35, y: 0.3),
                                     startRadius: 2, endRadius: 90))
                .frame(width: 190, height: 190)

            // bass rings — more rings/energy = heavier low end
            ForEach(0..<3) { i in
                Circle().stroke(personality.accent.opacity(0.4 - Double(i) * 0.1),
                                lineWidth: 2)
                    .frame(width: 210 + CGFloat(i) * 30, height: 210 + CGFloat(i) * 30)
                    .scaleEffect(pulse ? 1.0 + m.bass * 0.06 : 1.0)
            }

            VStack(spacing: 2) {
                Text("\(Int(m.energy * 100))")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("ENERGY").font(.system(size: 10, weight: .bold)).tracking(2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .onAppear {
            withAnimation(.linear(duration: max(4, 14 - m.energy * 10)).repeatForever(autoreverses: false)) {
                rotate = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Small components

struct FlowChips: View {
    let items: [String]
    let color: Color
    init(_ items: [String], color: Color) { self.items = items; self.color = color }
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { t in
                Text(t).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(color.opacity(0.22), in: Capsule())
                    .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
            }
        }
    }
}

struct GenreBar: View {
    let name: String
    let weight: Double
    let maxWeight: Double
    let color: Color
    let index: Int
    @State private var appear = false
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Text(name).font(Theme.Type_.body(13, weight: .medium))
                .foregroundStyle(Theme.Palette.chalk)
                .frame(width: 110, alignment: .leading).lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.panel).frame(height: 12)
                    Capsule().fill(LinearGradient(colors: [color, color.opacity(0.6)],
                                                  startPoint: .leading, endPoint: .trailing))
                        .frame(width: appear ? geo.size.width * (weight / max(maxWeight,1)) : 0,
                               height: 12)
                }
            }
            .frame(height: 12)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(Double(index) * 0.1)) { appear = true }
        }
    }
}

// MARK: - Daily mood arc chart

struct DayArcChart: View {
    let points: [MoodEngine.HourMood]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let sorted = points.sorted { $0.hour < $1.hour }
            ZStack {
                // gridlines
                ForEach(0..<4) { i in
                    let y = h * CGFloat(i) / 3
                    Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y)) }
                        .stroke(Theme.Palette.hairline.opacity(0.4), lineWidth: 0.5)
                }
                if sorted.count >= 2 {
                    // energy area
                    energyPath(sorted, w: w, h: h, close: true)
                        .fill(LinearGradient(colors: [Theme.Palette.mint.opacity(0.35), .clear],
                                             startPoint: .top, endPoint: .bottom))
                    // energy line
                    energyPath(sorted, w: w, h: h, close: false)
                        .stroke(LinearGradient(colors: [Color(hex: 0x6FA8DC), Theme.Palette.mint],
                                               startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    // dots
                    ForEach(sorted) { pt in
                        let x = xPos(pt.hour, w: w)
                        let y = h - CGFloat(pt.energy) * h
                        Circle().fill(Theme.Palette.chalk)
                            .frame(width: 7, height: 7).position(x: x, y: y)
                    }
                } else {
                    Text("Listen through the day to fill this in")
                        .font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func xPos(_ hour: Int, w: CGFloat) -> CGFloat {
        CGFloat(hour) / 23.0 * w
    }
    private func energyPath(_ pts: [MoodEngine.HourMood], w: CGFloat, h: CGFloat, close: Bool) -> Path {
        Path { p in
            guard let first = pts.first else { return }
            let start = CGPoint(x: xPos(first.hour, w: w), y: h - CGFloat(first.energy) * h)
            if close { p.move(to: CGPoint(x: start.x, y: h)); p.addLine(to: start) }
            else { p.move(to: start) }
            for pt in pts.dropFirst() {
                p.addLine(to: CGPoint(x: xPos(pt.hour, w: w), y: h - CGFloat(pt.energy) * h))
            }
            if close, let last = pts.last {
                p.addLine(to: CGPoint(x: xPos(last.hour, w: w), y: h))
                p.closeSubpath()
            }
        }
    }
}
