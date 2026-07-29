import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: SpotifyAuth
    @EnvironmentObject var api: SpotifyAPI
    @EnvironmentObject var store: DiscoveryStore
    @State private var user: SPUser?

    var body: some View {
        ZStack {
            Theme.Palette.ink.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    avatar
                    if auth.isSignedIn {
                        stats
                        badges
                        Button("Sign out") { auth.signOut(); user = nil }
                            .font(Theme.Type_.body(15, weight: .semibold))
                            .foregroundStyle(Theme.Palette.mist)
                    } else {
                        Button { auth.signIn() } label: {
                            Text("Connect Spotify")
                                .font(Theme.Type_.body(16, weight: .semibold))
                                .padding(.vertical, 12).padding(.horizontal, 24)
                                .background(Theme.Palette.mint, in: Capsule())
                                .foregroundStyle(Theme.Palette.ink)
                        }
                        if let e = auth.lastError {
                            Text(e).font(Theme.Type_.caption())
                                .foregroundStyle(Theme.Palette.mist)
                        }
                    }
                }
                .padding(Theme.Space.l)
            }
        }
        .task(id: auth.isSignedIn) {
            if auth.isSignedIn { user = try? await api.me() }
        }
    }

    private var avatar: some View {
        VStack(spacing: Theme.Space.s) {
            Group {
                if let s = user?.images?.first?.url, let url = URL(string: s) {
                    AsyncImage(url: url) { $0.resizable() } placeholder: { Theme.Palette.panel }
                } else {
                    Theme.Palette.panel
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.Palette.hairline, lineWidth: 1))
            Text(user?.display_name ?? (auth.isSignedIn ? "Spotify listener" : "Not signed in"))
                .font(Theme.Type_.display(22)).foregroundStyle(Theme.Palette.chalk)
        }
    }

    private var stats: some View {
        HStack(spacing: Theme.Space.l) {
            StatPair(label: "Saved", value: "\(store.liked.count)")
            StatPair(label: "Streak", value: "\(store.streak.current)d")
            StatPair(label: "Best", value: "\(store.streak.longest)d")
        }
    }

    private var badges: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("BADGES").font(Theme.Type_.caption()).tracking(1.4)
                .foregroundStyle(Theme.Palette.mist)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: Theme.Space.s) {
                ForEach(Badge.allCases) { b in
                    let earned = store.badges.contains(b)
                    VStack(spacing: 4) {
                        Image(systemName: earned ? "rosette" : "lock")
                            .foregroundStyle(earned ? Theme.Palette.mint : Theme.Palette.mist)
                        Text(b.rawValue).font(Theme.Type_.caption())
                            .foregroundStyle(earned ? Theme.Palette.chalk : Theme.Palette.mist)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, Theme.Space.s)
                    .background(Theme.Palette.panel,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
