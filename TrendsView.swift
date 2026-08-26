import SwiftUI

// =====================================================================
// TrendsView — REAL chart data from Last.fm (free), categorised by
// genre. No fake percentages: every number shown (listeners, plays) is
// real data from Last.fm. Tap an artist for a full stats screen.
// =====================================================================

struct TrendsView: View {
    @EnvironmentObject var auth: SpotifyAuth
    @EnvironmentObject var api: SpotifyAPI
    @Binding var routeToPitchArtist: PitchSeed?
    @Binding var selectedTab: Int

    @State private var selectedGenre: String? = nil      // nil = Global
    @State private var artists: [LFArtist] = []
    @State private var page = 1
    @State private var loading = false
    @State private var loadingMore = false
    @State private var detailArtist: LFArtist?

    private var genres: [String] { LastFM.genreBuckets }

    var body: some View {
        ZStack {
            AuroraBackground()
            content
        }
        .task { if artists.isEmpty { await load(reset: true) } }
        .sheet(item: $detailArtist) { a in
            ArtistDetailSheet(artist: a) { seed in
                detailArtist = nil
                routeToPitchArtist = seed
                selectedTab = 2
            }
            .environmentObject(api)
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                header
                genrePicker
                if loading && artists.isEmpty {
                    loadingState
                } else if artists.isEmpty {
                    emptyState
                } else {
                    artistList
                    loadMoreButton
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
            Text(selectedGenre == nil
                 ? "Most-listened artists right now"
                 : "Top \(selectedGenre!.capitalized) artists")
                .font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist)
        }
    }

    // Genre categories — fixes the "random artists" problem
    private var genrePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Global", isOn: selectedGenre == nil) {
                    selectedGenre = nil; Task { await load(reset: true) }
                }
                ForEach(genres, id: \.self) { g in
                    chip(g.capitalized, isOn: selectedGenre == g) {
                        selectedGenre = g; Task { await load(reset: true) }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chip(_ label: String, isOn: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isOn ? Theme.Palette.ink : Theme.Palette.chalk)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(isOn ? Theme.Palette.mint : Theme.Palette.panel, in: Capsule())
                .overlay(Capsule().stroke(Theme.Palette.hairline, lineWidth: isOn ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private var artistList: some View {
        VStack(spacing: 10) {
            ForEach(Array(artists.enumerated()), id: \.element.id) { i, a in
                Button { detailArtist = a } label: {
                    ArtistRow(rank: i + 1, artist: a)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadMoreButton: some View {
        Button {
            Task { await loadMore() }
        } label: {
            HStack(spacing: 8) {
                if loadingMore { ProgressView().tint(Theme.Palette.ink) }
                Text(loadingMore ? "Loading…" : "Load more")
                    .font(Theme.Type_.body(15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.Palette.mint, in: Capsule())
            .foregroundStyle(Theme.Palette.ink)
        }
        .buttonStyle(.plain)
        .disabled(loadingMore)
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16).fill(Theme.Palette.panel)
                    .frame(height: 72).shimmering()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 40))
                .foregroundStyle(Theme.Palette.mint).pulsing()
            Text("Couldn't load charts").font(Theme.Type_.display(19))
                .foregroundStyle(Theme.Palette.chalk)
            Button { Task { await load(reset: true) } } label: {
                Text("Retry").font(Theme.Type_.body(15, weight: .semibold))
                    .padding(.vertical, 10).padding(.horizontal, 24)
                    .background(Theme.Palette.mint, in: Capsule())
                    .foregroundStyle(Theme.Palette.ink)
            }
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }

    // MARK: data
    private func load(reset: Bool) async {
        if reset { loading = true; page = 1; artists = [] }
        let fetched = await fetchPage(page)
        artists = fetched
        loading = false
    }

    private func loadMore() async {
        loadingMore = true
        page += 1
        let more = await fetchPage(page)
        // de-dupe by name
        var seen = Set(artists.map(\.name))
        artists.append(contentsOf: more.filter { seen.insert($0.name).inserted })
        loadingMore = false
    }

    private func fetchPage(_ p: Int) async -> [LFArtist] {
        if let g = selectedGenre {
            var list = await LastFM.topArtists(genre: g, limit: 12, page: p)
            // enrich the first few with REAL listener/play stats
            list = await enrich(list, count: 12)
            return list
        } else {
            let list = await LastFM.globalTopArtists(limit: 12, page: p)
            return await enrich(list, count: 12)
        }
    }

    // tag.getTopArtists doesn't include stats, so fetch real ones.
    private func enrich(_ list: [LFArtist], count: Int) async -> [LFArtist] {
        var out: [LFArtist] = []
        await withTaskGroup(of: LFArtist.self) { group in
            for a in list.prefix(count) {
                group.addTask {
                    async let infoT = LastFM.artistInfo(name: a.name)
                    async let imgT = api.artistImage(named: a.name)
                    let (info, img) = await (infoT, imgT)
                    return LFArtist(name: a.name,
                                    listeners: info?.listeners ?? a.listeners,
                                    playcount: info?.playcount ?? a.playcount,
                                    imageURL: img ?? a.imageURL,
                                    genre: a.genre)
                }
            }
            for await r in group { out.append(r) }
        }
        // preserve original ordering
        let order = Dictionary(uniqueKeysWithValues: list.enumerated().map { ($1.name, $0) })
        return out.sorted { (order[$0.name] ?? 0) < (order[$1.name] ?? 0) }
    }
}

// MARK: - Artist row (real stats, no fake %)

struct ArtistRow: View {
    let rank: Int
    let artist: LFArtist
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Text("\(rank)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Palette.mint)
                .frame(width: 26)
            Group {
                if let url = artist.imageURL {
                    AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) }
                        placeholder: { Theme.Palette.panel }
                        .id(url)          // prevents SwiftUI reusing a stale image
                } else {
                    Theme.Palette.panel.overlay(
                        Image(systemName: "music.mic").foregroundStyle(Theme.Palette.mist))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(artist.name).font(Theme.Type_.body(15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.chalk).lineLimit(1)
                if artist.listeners > 0 {
                    Text("\(artist.listenersText) listeners · \(artist.playsText) plays")
                        .font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist)
                    SuperfanBadge(score: artist.superfanScore, label: artist.superfanLabel)
                } else if let g = artist.genre {
                    Text(g.capitalized).font(Theme.Type_.caption())
                        .foregroundStyle(Theme.Palette.mist)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.Palette.mist)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.Palette.panel.opacity(0.85))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Palette.hairline, lineWidth: 1)))
    }
}
