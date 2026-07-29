import SwiftUI

// Wrapped — real recap from DiscoveryStore. Renders the card to an
// image (ImageRenderer, iOS 16) so the share is a picture, like
// Spotify Wrapped's shareable cards.
struct WrappedView: View {
    @EnvironmentObject var store: DiscoveryStore
    @State private var shareImage: Image?

    var body: some View {
        let stats = store.wrappedStats()
        ZStack {
            Theme.Palette.ink.ignoresSafeArea()
            VStack(spacing: Theme.Space.l) {
                Text("Your Wrapped").font(Theme.Type_.display(30))
                    .foregroundStyle(Theme.Palette.chalk)
                RecapCard(stats: stats).padding(.horizontal, Theme.Space.l)
                if let shareImage {
                    ShareLink(item: shareImage,
                              preview: SharePreview("My \(stats.monthLabel) in music",
                                                    image: shareImage)) {
                        shareLabel
                    }
                } else {
                    Button { render(stats: stats) } label: { shareLabel }
                }
            }
        }
        .onAppear { render(stats: stats) }
    }

    private var shareLabel: some View {
        Label("Share card", systemImage: "square.and.arrow.up")
            .font(Theme.Type_.body(16, weight: .semibold))
            .padding(.vertical, 12).padding(.horizontal, 22)
            .background(Theme.Palette.mint, in: Capsule())
            .foregroundStyle(Theme.Palette.ink)
    }

    @MainActor private func render(stats: DiscoveryStore.WrappedStats) {
        let renderer = ImageRenderer(content: RecapCard(stats: stats)
            .frame(width: 360)
            .background(Theme.Palette.ink))
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }
}

struct RecapCard: View {
    let stats: DiscoveryStore.WrappedStats
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(stats.monthLabel.uppercased() + " RECAP")
                .font(Theme.Type_.caption()).tracking(1.4)
                .foregroundStyle(Theme.Palette.mint)
            Text("\(stats.discovered) tracks\ndiscovered")
                .font(Theme.Type_.display(34)).foregroundStyle(Theme.Palette.chalk)
            HStack(spacing: Theme.Space.l) {
                if let a = stats.topArtist { StatPair(label: "Top artist", value: a) }
                StatPair(label: "Streak", value: "\(stats.currentStreak) days")
            }
            DecayCurve(values: stats.weeklyCounts)
                .stroke(Theme.Palette.mint.opacity(0.5), lineWidth: 2)
                .frame(height: 46)
            Text("Sonara · discover & pitch")
                .font(Theme.Type_.caption(10)).foregroundStyle(Theme.Palette.mist)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.panel,
                    in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .stroke(Theme.Palette.hairline, lineWidth: 1))
    }
}
