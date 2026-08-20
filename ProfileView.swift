import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: SpotifyAuth
    @EnvironmentObject var api: SpotifyAPI
    @EnvironmentObject var mood: MoodEngine
    @State private var user: SPUser?
    @State private var topArtistNames: [String] = []
    @State private var recentCount = 0

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Space.l) {
                    avatar
                    if auth.isSignedIn {
                        if let p = mood.personality { personalityStrip(p) }
                        statsRow
                        if let p = mood.personality, !p.topGenres.isEmpty { genreStrip(p) }
                        if !topArtistNames.isEmpty { topArtistsCard }
                        signOut
                    } else {
                        connect
                    }
                }
                .padding(Theme.Space.l)
                .padding(.bottom, 40)
            }
        }
        .task(id: auth.isSignedIn) {
            if auth.isSignedIn {
                user = try? await api.me()
                let artists = await api.topArtists(limit: 8)
                topArtistNames = artists.map(\.name)
                recentCount = await api.recentlyPlayed(limit: 50).count
                if mood.personality == nil { await mood.refresh() }
            }
        }
    }

    private var avatar: some View {
        VStack(spacing: Theme.Space.s) {
            Group {
                if let s = user?.images?.first?.url, let url = URL(string: s) {
                    AsyncImage(url: url) { $0.resizable() } placeholder: { Theme.Palette.panel }
                } else {
                    Theme.Palette.panel.overlay(
                        Image(systemName: "person.fill").font(.system(size: 32))
                            .foregroundStyle(Theme.Palette.mist))
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.Palette.mint.opacity(0.4), lineWidth: 2))
            Text(user?.display_name ?? (auth.isSignedIn ? "Spotify listener" : "Not signed in"))
                .font(Theme.Type_.display(24)).foregroundStyle(Theme.Palette.chalk)
        }
    }

    private func personalityStrip(_ p: Personality) -> some View {
        VStack(spacing: 6) {
            Text("YOUR VIBE").font(Theme.Type_.caption()).tracking(2)
                .foregroundStyle(Theme.Palette.mist)
            Text(p.title).font(Theme.Type_.display(26))
                .foregroundStyle(LinearGradient(colors: [p.color, p.accent],
                                                startPoint: .leading, endPoint: .trailing))
            FlowLayout(spacing: 6) {
                ForEach(p.descriptors, id: \.self) { d in
                    Text(d).font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(p.accent.opacity(0.22), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity).padding(Theme.Space.l)
        .background(card)
    }

    private var statsRow: some View {
        HStack(spacing: Theme.Space.m) {
            stat("\(topArtistNames.count)", "Top artists")
            stat("\(mood.personality?.topGenres.count ?? 0)", "Genres")
            stat("\(recentCount)", "Recent plays")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Palette.chalk)
            Text(label).font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Theme.Space.m)
        .background(card)
    }

    private func genreStrip(_ p: Personality) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("TOP GENRES").font(Theme.Type_.caption()).tracking(1.4)
                .foregroundStyle(Theme.Palette.mist)
            FlowLayout(spacing: 8) {
                ForEach(Array(p.topGenres.enumerated()), id: \.offset) { _, g in
                    Text(g.0).font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Palette.chalk)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Theme.Palette.mint.opacity(0.15), in: Capsule())
                        .overlay(Capsule().stroke(Theme.Palette.mint.opacity(0.4), lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(Theme.Space.l)
        .background(card)
    }

    private var topArtistsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("YOUR TOP ARTISTS").font(Theme.Type_.caption()).tracking(1.4)
                .foregroundStyle(Theme.Palette.mist)
            ForEach(Array(topArtistNames.prefix(8).enumerated()), id: \.offset) { i, name in
                HStack(spacing: Theme.Space.m) {
                    Text("\(i + 1)").font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.mint).frame(width: 22)
                    Text(name).font(Theme.Type_.body(15))
                        .foregroundStyle(Theme.Palette.chalk)
                    Spacer()
                }
                if i < min(topArtistNames.count, 8) - 1 {
                    Divider().overlay(Theme.Palette.hairline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(Theme.Space.l)
        .background(card)
    }

    private var signOut: some View {
        Button("Sign out") { auth.signOut(); user = nil; topArtistNames = [] }
            .font(Theme.Type_.body(15, weight: .semibold))
            .foregroundStyle(Theme.Palette.mist)
            .padding(.top, Theme.Space.s)
    }

    private var connect: some View {
        VStack(spacing: Theme.Space.m) {
            Button { auth.signIn() } label: {
                Text("Connect Spotify").font(Theme.Type_.body(16, weight: .semibold))
                    .padding(.vertical, 12).padding(.horizontal, 24)
                    .background(Theme.Palette.mint, in: Capsule())
                    .foregroundStyle(Theme.Palette.ink)
            }
            if let e = auth.lastError {
                Text(e).font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist)
            }
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .fill(Theme.Palette.panel.opacity(0.85))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Theme.Palette.hairline, lineWidth: 1))
    }
}
