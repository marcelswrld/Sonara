import SwiftUI

// =====================================================================
// TrendsView — replaces swipe-discovery. Built ONLY on data Spotify
// gives new apps (new releases, album art, artist search), framed as
// investment signal that feeds Pitch. Rich, animated, tappable.
// Tapping an album/artist routes to Pitch with that artist prefilled.
// =====================================================================

struct TrendsView: View {
    @EnvironmentObject var auth: SpotifyAuth
    @EnvironmentObject var api: SpotifyAPI
    @Binding var routeToPitchArtist: String?
    @Binding var selectedTab: Int

    @State private var albums: [TrendAlbum] = []
    @State private var loading = false
    @State private var heroIndex = 0
    @State private var appear = false
    @State private var debug = ""

    var body: some View {
        ZStack {
            AuroraBackground()
            if auth.isSignedIn {
                content
            } else {
                connectPrompt
            }
        }
        .task(id: auth.isSignedIn) { if auth.isSignedIn && albums.isEmpty { await load() } }
    }

    private func load() async {
        loading = true
        let fetched = await api.newReleaseAlbums(limit: 24)
        albums = fetched.sorted { $0.momentum > $1.momentum }
        debug = "Loaded \(albums.count) albums · signedIn=\(auth.isSignedIn)"
        loading = false
        withAnimation(.easeOut(duration: 0.7)) { appear = true }
        // cycle the hero
        startHeroCycle()
    }

    private func startHeroCycle() {
        guard albums.count > 1 else { return }
        Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                heroIndex = (heroIndex + 1) % min(albums.count, 5)
            }
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                header
                if loading && albums.isEmpty {
                    loadingState
                } else {
                    if !albums.isEmpty { hero }
                    risingSection
                    freshSection
                }
            }
            .padding(Theme.Space.l)
            .padding(.bottom, 40)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Trends").font(Theme.Type_.display(32))
                .foregroundStyle(Theme.Palette.chalk)
            Text("What's rising — tap to value the catalog")
                .font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist)
            if !debug.isEmpty {
                Text(debug).font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.Palette.mint.opacity(0.7))
            }
        }
    }

    // MARK: Hero — big rotating featured rising release
    @ViewBuilder private var hero: some View {
        let a = albums[min(heroIndex, albums.count - 1)]
        ZStack(alignment: .bottomLeading) {
            if let url = a.artworkURL {
                AsyncImage(url: url) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { Theme.Palette.panel }
            } else { Theme.Palette.panel }

            LinearGradient(colors: [.clear, .black.opacity(0.85)],
                           startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack {
                    Text("RISING NOW").font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.5).foregroundStyle(Theme.Palette.mint)
                    MomentumBadge(percent: a.momentum)
                }
                Text(a.name).font(Theme.Type_.display(26))
                    .foregroundStyle(.white).lineLimit(2)
                Text(a.artist).font(Theme.Type_.body(15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Button {
                    route(to: a.artist)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Value this artist").font(Theme.Type_.body(14, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Palette.ink)
                    .padding(.vertical, 10).padding(.horizontal, 18)
                    .background(Theme.Palette.mint, in: Capsule())
                }
                .padding(.top, 4)
            }
            .padding(Theme.Space.l)
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Theme.Palette.mint.opacity(0.3), lineWidth: 1))
        .shadow(color: Theme.Palette.mint.opacity(0.15), radius: 30, y: 14)
        .id(a.id) // triggers transition on hero change
        .transition(.opacity.combined(with: .scale(scale: 1.03)))
    }

    // MARK: Rising — horizontal momentum strip
    private var risingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            sectionTitle("Climbing", "flame.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.m) {
                    ForEach(Array(albums.prefix(10).enumerated()), id: \.element.id) { i, a in
                        RisingCard(album: a) { route(to: a.artist) }
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(Double(i) * 0.06), value: appear)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: Fresh — grid of new releases
    private var freshSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            sectionTitle("Fresh Releases", "sparkles")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(albums.enumerated()), id: \.element.id) { i, a in
                    FreshCard(album: a) { route(to: a.artist) }
                        .opacity(appear ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(Double(i) * 0.03), value: appear)
                }
            }
        }
    }

    private func sectionTitle(_ t: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Palette.mint)
            Text(t).font(Theme.Type_.display(20)).foregroundStyle(Theme.Palette.chalk)
        }
    }

    private var loadingState: some View {
        VStack(spacing: Theme.Space.m) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 20).fill(Theme.Palette.panel)
                    .frame(height: 120).shimmering()
            }
        }
    }

    private var connectPrompt: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 46))
                .foregroundStyle(Theme.Palette.mint).pulsing()
            Text("Connect Spotify to see what's rising")
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

    private func route(to artistID: String?) {
        routeToPitchArtist = artistID
        withAnimation { selectedTab = 2 } // jump to Pitch
    }
}

// MARK: - Cards

struct RisingCard: View {
    let album: TrendAlbum
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    artwork(album.artworkURL, size: 150)
                    MomentumBadge(percent: album.momentum).padding(8)
                }
                Text(album.name).font(Theme.Type_.body(14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.chalk).lineLimit(1)
                Text(album.artist).font(Theme.Type_.caption())
                    .foregroundStyle(Theme.Palette.mist).lineLimit(1)
            }
            .frame(width: 150)
        }
        .buttonStyle(.plain)
    }
}

struct FreshCard: View {
    let album: TrendAlbum
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 8) {
                artwork(album.artworkURL, size: nil)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(album.name).font(Theme.Type_.body(13, weight: .semibold))
                            .foregroundStyle(Theme.Palette.chalk).lineLimit(1)
                        Text(album.artist).font(Theme.Type_.caption())
                            .foregroundStyle(Theme.Palette.mist).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Palette.mint)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Palette.panel)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.Palette.hairline, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }
}

// shared artwork loader
@ViewBuilder
func artwork(_ url: URL?, size: CGFloat?) -> some View {
    Group {
        if let url {
            AsyncImage(url: url) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Theme.Palette.panel.overlay(ProgressView().tint(Theme.Palette.mint))
            }
        } else {
            Theme.Palette.panel.overlay(
                Image(systemName: "music.note").foregroundStyle(Theme.Palette.mist))
        }
    }
    .frame(width: size, height: size ?? 150)
    .frame(maxWidth: size == nil ? .infinity : size)
    .aspectRatio(1, contentMode: .fill)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
}
