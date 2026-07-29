import SwiftUI

// Discover — Musiclips' swipe concept on real Spotify data.
// Signed in: recommendations seeded from the user's top tracks
// (Musiclips' strategy), artwork, 30s preview, like = save to library
// + streak. Signed out: a connect prompt over a designed idle deck.
struct DiscoverView: View {
    @EnvironmentObject var auth: SpotifyAuth
    @EnvironmentObject var api: SpotifyAPI
    @EnvironmentObject var store: DiscoveryStore
    @EnvironmentObject var player: PreviewPlayer

    @State private var deck: [SPTrack] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Theme.Palette.ink.ignoresSafeArea()
            VStack(spacing: Theme.Space.m) {
                header
                ZStack {
                    if auth.isSignedIn {
                        realDeck
                    } else {
                        connectPrompt
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                controls
            }
            .padding(.vertical, Theme.Space.m)
        }
        .task(id: auth.isSignedIn) { if auth.isSignedIn { await load() } }
        .onDisappear { player.stop() }
    }

    private func load() async {
        loading = true; errorText = nil
        do { deck = try await api.recommendations(limit: 20) }
        catch { errorText = "Couldn't load tracks. Pull to retry." }
        loading = false
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Discover").font(Theme.Type_.display(30))
                    .foregroundStyle(Theme.Palette.chalk)
                Text("\(store.streak.current)-day streak · \(store.liked.count) saved")
                    .font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist)
            }
            Spacer()
            if loading { ProgressView().tint(Theme.Palette.mint) }
        }
        .padding(.horizontal, Theme.Space.l)
    }

    @ViewBuilder private var realDeck: some View {
        if let errorText {
            Text(errorText).font(Theme.Type_.body(14))
                .foregroundStyle(Theme.Palette.mist)
        } else if deck.isEmpty && !loading {
            emptyState
        } else {
            ZStack {
                ForEach(Array(deck.prefix(3).enumerated().reversed()), id: \.element.id) { index, track in
                    TrackCard(track: track,
                              isPlaying: player.playingTrackID == track.id)
                        .offset(index == 0 ? dragOffset : .zero)
                        .rotationEffect(.degrees(index == 0 ? Double(dragOffset.width / 18) : 0))
                        .scaleEffect(1 - CGFloat(index) * 0.04)
                        .offset(y: CGFloat(index) * -10)
                        .gesture(index == 0 ? dragGesture : nil)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: dragOffset)
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { v in
                if abs(v.translation.width) > 110 { decide(liked: v.translation.width > 0) }
                else { dragOffset = .zero }
            }
    }

    private func decide(liked: Bool) {
        guard let top = deck.first else { return }
        withAnimation(.easeIn(duration: 0.18)) {
            dragOffset = CGSize(width: liked ? 600 : -600, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if liked {
                store.registerLike(top)
                Task { try? await api.saveToLibrary(trackID: top.id) }
            }
            player.stop()
            if !deck.isEmpty { deck.removeFirst() }
            dragOffset = .zero
            if deck.count < 5 { Task { await load() } } // top-up like Musiclips
        }
    }

    private var controls: some View {
        HStack(spacing: Theme.Space.xl) {
            RoundControl(symbol: "xmark", tint: Theme.Palette.mist) { decide(liked: false) }
            RoundControl(symbol: player.playingTrackID == nil ? "play.fill" : "pause.fill",
                         tint: Theme.Palette.chalk, big: true) {
                if let top = deck.first { player.toggle(top) }
            }
            RoundControl(symbol: "heart.fill", tint: Theme.Palette.mint) { decide(liked: true) }
        }
        .opacity(auth.isSignedIn && !deck.isEmpty ? 1 : 0.3)
        .disabled(!auth.isSignedIn || deck.isEmpty)
    }

    private var connectPrompt: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "waveform").font(.system(size: 44))
                .foregroundStyle(Theme.Palette.mint)
            Text("Connect Spotify to start swiping")
                .font(Theme.Type_.display(20)).foregroundStyle(Theme.Palette.chalk)
            Button { auth.signIn() } label: {
                Text("Connect Spotify")
                    .font(Theme.Type_.body(16, weight: .semibold))
                    .padding(.vertical, 12).padding(.horizontal, 24)
                    .background(Theme.Palette.mint, in: Capsule())
                    .foregroundStyle(Theme.Palette.ink)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.s) {
            Text("Deck's empty").font(Theme.Type_.display(22))
                .foregroundStyle(Theme.Palette.chalk)
            Button("Reload") { Task { await load() } }
                .tint(Theme.Palette.mint)
        }
    }
}

struct TrackCard: View {
    let track: SPTrack
    let isPlaying: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let url = track.artworkURL {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Theme.Palette.panel
                    }
                } else { Theme.Palette.panel }
            }
            .frame(height: 460)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.cardWash)

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                if isPlaying {
                    Label("PREVIEW", systemImage: "waveform")
                        .font(Theme.Type_.caption()).tracking(1.2)
                        .foregroundStyle(Theme.Palette.mint)
                } else if track.preview_url == nil {
                    Text("NO PREVIEW AVAILABLE")
                        .font(Theme.Type_.caption()).tracking(1.2)
                        .foregroundStyle(Theme.Palette.mist)
                }
                Text(track.name ?? "Unknown")
                    .font(Theme.Type_.display(26)).foregroundStyle(Theme.Palette.chalk)
                    .lineLimit(2)
                Text(track.artistLine)
                    .font(Theme.Type_.body(15, weight: .medium))
                    .foregroundStyle(Theme.Palette.mist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.m)
            .background(.ultraThinMaterial.opacity(0.6),
                        in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .padding(Theme.Space.s)
        }
        .frame(height: 460)
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .stroke(Theme.Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }
}

struct RoundControl: View {
    let symbol: String
    let tint: Color
    var big = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: big ? 24 : 19, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: big ? 68 : 54, height: big ? 68 : 54)
                .background(Theme.Palette.panel, in: Circle())
                .overlay(Circle().stroke(Theme.Palette.hairline, lineWidth: 1))
        }
    }
}
