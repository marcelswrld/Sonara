import SwiftUI

// Brief branded splash on cold start, then reveals the tab bar.
// Keeps the first impression on-brand instead of a blank flash.
struct LaunchGate<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var done = false

    var body: some View {
        ZStack {
            if done {
                content.transition(.opacity)
            } else {
                SonaraSplash()
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(nanoseconds: 1_100_000_000)
                        withAnimation(.easeOut(duration: 0.4)) { done = true }
                    }
            }
        }
    }
}

struct SonaraSplash: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Theme.Palette.ink.ignoresSafeArea()
            Circle()
                .fill(Theme.mintGlow)
                .frame(width: 260, height: 260)
                .blur(radius: 100)
                .opacity(0.30)
                .scaleEffect(pulse ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
            VStack(spacing: Theme.Space.s) {
                Text("Sonara")
                    .font(Theme.Type_.display(46))
                    .foregroundStyle(Theme.Palette.chalk)
                Text("discover · pitch")
                    .font(Theme.Type_.caption())
                    .tracking(3)
                    .foregroundStyle(Theme.Palette.mint)
            }
        }
        .onAppear { pulse = true }
    }
}
