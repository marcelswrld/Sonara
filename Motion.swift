import SwiftUI

// =====================================================================
// Motion — reusable "dynamic" building blocks so the whole app feels
// alive: an animated aurora background, shimmer, float, pulse, press
// springs, and a shine sweep. These animate REAL content, not empty
// state, so motion is always visible.
// =====================================================================

// MARK: - Animated aurora background (slow drifting color clouds)

struct AuroraBackground: View {
    @State private var t = false
    var body: some View {
        ZStack {
            Theme.Palette.ink
            // three drifting radial blooms
            Circle().fill(Theme.Palette.mint.opacity(0.18))
                .frame(width: 380, height: 380).blur(radius: 120)
                .offset(x: t ? -120 : 120, y: t ? -220 : -140)
            Circle().fill(Color(hex: 0x7C5CFF).opacity(0.20))
                .frame(width: 420, height: 420).blur(radius: 130)
                .offset(x: t ? 140 : -100, y: t ? 260 : 180)
            Circle().fill(Theme.Palette.brass.opacity(0.10))
                .frame(width: 300, height: 300).blur(radius: 110)
                .offset(x: t ? 100 : -140, y: t ? -40 : 120)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                t.toggle()
            }
        }
    }
}

// MARK: - Float (gentle vertical bob)

struct Float: ViewModifier {
    var amount: CGFloat = 6
    var duration: Double = 3
    var delay: Double = 0
    @State private var up = false
    func body(content: Content) -> some View {
        content
            .offset(y: up ? -amount : amount)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
                    up.toggle()
                }
            }
    }
}
extension View {
    func floating(_ amount: CGFloat = 6, duration: Double = 3, delay: Double = 0) -> some View {
        modifier(Float(amount: amount, duration: duration, delay: delay))
    }
}

// MARK: - Pulse (scale breathing)

struct Pulse: ViewModifier {
    var min: CGFloat = 0.97
    var max: CGFloat = 1.03
    var duration: Double = 2
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(on ? max : min)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    on.toggle()
                }
            }
    }
}
extension View {
    func pulsing(min: CGFloat = 0.97, max: CGFloat = 1.03, duration: Double = 2) -> some View {
        modifier(Pulse(min: min, max: max, duration: duration))
    }
}

// MARK: - Shimmer (light sweep across a view, e.g. loading + accents)

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white.opacity(0.35), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.6)
                    .blendMode(.plusLighter)
            }
            .mask(content)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

// MARK: - Press spring (tactile scale-down on tap)

struct PressSpring: ViewModifier {
    @State private var pressed = false
    let action: () -> Void
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.94 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
            .onTapGesture {
                pressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    pressed = false; action()
                }
            }
    }
}
extension View {
    func pressSpring(_ action: @escaping () -> Void) -> some View {
        modifier(PressSpring(action: action))
    }
}

// MARK: - Count-up number (animates from 0 to value)

struct CountUp: View {
    let value: Int
    var duration: Double = 1.0
    var font: Font = .system(size: 28, weight: .heavy, design: .rounded)
    var color: Color = Theme.Palette.chalk
    @State private var shown: Double = 0
    var body: some View {
        Text("\(Int(shown))")
            .font(font).foregroundStyle(color)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) { shown = Double(value) }
            }
            .onChange(of: value) { new in
                withAnimation(.easeOut(duration: 0.6)) { shown = Double(new) }
            }
    }
}

// MARK: - Flow layout (wrap items to next line) — shared helper

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


struct MomentumBadge: View {
    let percent: Int   // e.g. +18
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: percent >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text("\(abs(percent))%").font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(percent >= 0 ? Theme.Palette.mint : Color(hex: 0xFF6B6B))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background((percent >= 0 ? Theme.Palette.mint : Color(hex: 0xFF6B6B)).opacity(0.14),
                    in: Capsule())
    }
}
