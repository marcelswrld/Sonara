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

    // Search bubble
    @State private var query = ""
    @State private var results: [LFArtist] = []
    @State private var searching = false
    @FocusState private var searchFocused: Bool
    @AppStorage("aimnubis.recentArtistSearches") private var recentRaw = ""

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearchMode: Bool { !trimmedQuery.isEmpty }
    private var recents: [String] { recentRaw.split(separator: "|").map(String.init) }

    private var genres: [String] { LastFM.genreBuckets }

    var body: some View {
        ZStack {
            AuroraBackground()
            content
        }
        .task { if artists.isEmpty { await load(reset: true) } }
        .task(id: trimmedQuery) { await runSearch(trimmedQuery) }
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
                SearchBubble(text: $query, focused: $searchFocused) {
                    searchFocused = false
                }
                if isSearchMode {
                    searchSection
                } else {
                    if searchFocused && !recents.isEmpty {
                        recentBubbles
                    }
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
            }
            .padding(Theme.Space.l)
            .padding(.bottom, 40)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isSearchMode)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: searchFocused)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: search

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(searching ? "Searching…" : "Results for \u{201C}\(trimmedQuery)\u{201D}")
                    .font(Theme.Type_.caption(13))
                    .foregroundStyle(Theme.Palette.mist)
                    .lineLimit(1)
                if searching {
                    ProgressView().scaleEffect(0.7).tint(Theme.Palette.mint)
                }
            }
            if searching && results.isEmpty {
                loadingState
            } else if results.isEmpty {
                noResults
            } else {
                ForEach(results) { a in
                    Button { open(a) } label: {
                        ArtistRow(rank: nil, artist: a)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: results)
        .transition(.opacity)
    }

    private var recentBubbles: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent").font(Theme.Type_.caption(13))
                    .foregroundStyle(Theme.Palette.mist)
                Spacer()
                Button("Clear") { recentRaw = "" }
                    .font(Theme.Type_.caption(12))
                    .foregroundStyle(Theme.Palette.mint)
            }
            FlowLayout(spacing: 8) {
                ForEach(recents, id: \.self) { name in
                    Button { query = name } label: {
                        BubbleChip(text: name, icon: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var noResults: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.Palette.mint.opacity(0.12)).frame(width: 76, height: 76)
                Circle().fill(Color(hex: 0x7C5CFF).opacity(0.16)).frame(width: 30, height: 30)
                    .offset(x: 38, y: -28)
                Circle().fill(Theme.Palette.mint.opacity(0.2)).frame(width: 14, height: 14)
                    .offset(x: -38, y: 26)
                Image(systemName: "music.mic").font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.Palette.mint)
            }
            .floating(5, duration: 2.6)
            Text("No artists found").font(Theme.Type_.display(18))
                .foregroundStyle(Theme.Palette.chalk)
            Text("Check the spelling, or try the artist's full name.")
                .font(Theme.Type_.caption(13)).foregroundStyle(Theme.Palette.mist)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }

    private func open(_ artist: LFArtist) {
        remember(artist.name)
        searchFocused = false
        detailArtist = artist
    }

    private func remember(_ name: String) {
        var list = recents.filter { $0.caseInsensitiveCompare(name) != .orderedSame }
        list.insert(name, at: 0)
        recentRaw = list.prefix(8).joined(separator: "|")
    }

    /// Runs when the text changes. SwiftUI cancels the previous run on every
    /// keystroke, so waiting briefly first means we only search once typing
    /// pauses, and an older search can never overwrite a newer one.
    private func runSearch(_ q: String) async {
        guard !q.isEmpty else {
            results = []
            searching = false
            return
        }
        searching = true
        try? await Task.sleep(nanoseconds: 350_000_000)
        if Task.isCancelled { return }
        let found = await LastFM.searchArtists(q, limit: 10)
        if Task.isCancelled { return }
        let enriched = await enrich(found, count: 10)
        if Task.isCancelled { return }
        results = enriched
        searching = false
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
    let rank: Int?
    let artist: LFArtist
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            if let rank {
                Text("\(rank)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Palette.mint)
                    .frame(width: 26)
            }
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

// MARK: - Search bubble

/// Glossy, glass-like search capsule. Grows slightly and glows mint-to-violet
/// while typing; the magnifier sits in its own little bubble.
struct SearchBubble: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var placeholder = "Search any artist"
    var onSubmit: () -> Void = {}

    var body: some View {
        let isOn = focused.wrappedValue
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Theme.mintGlow)
                    // glossy highlight, like light on a bubble
                    Circle()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0)],
                                             startPoint: .top, endPoint: .center))
                        .padding(2)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Palette.ink)
                }
                .frame(width: 32, height: 32)
                .scaleEffect(isOn ? 1.08 : 1)
                .rotationEffect(.degrees(isOn ? -8 : 0))

                TextField("", text: $text,
                          prompt: Text(placeholder).foregroundColor(Theme.Palette.mist))
                    .font(Theme.Type_.body(16, weight: .medium))
                    .foregroundStyle(Theme.Palette.chalk)
                    .tint(Theme.Palette.mint)
                    .focused(focused)
                    .submitLabel(.search)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onSubmit(onSubmit)

                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.Palette.mist)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background(BubbleBackground(isActive: isOn))
            .scaleEffect(isOn ? 1.015 : 1)
            .shadow(color: Theme.Palette.mint.opacity(isOn ? 0.35 : 0), radius: 18, y: 6)
            .contentShape(Capsule())
            .onTapGesture { focused.wrappedValue = true }

            if isOn {
                Button("Cancel") {
                    text = ""
                    focused.wrappedValue = false
                }
                .font(Theme.Type_.body(15, weight: .semibold))
                .foregroundStyle(Theme.Palette.mint)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isOn)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: text.isEmpty)
    }
}

/// Frosted glass capsule with a soft top highlight and a gradient rim.
struct BubbleBackground: View {
    var isActive: Bool
    var body: some View {
        ZStack {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(Theme.Palette.panel.opacity(0.55))
            Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0)],
                                          startPoint: .top, endPoint: .center))
            Capsule().strokeBorder(
                LinearGradient(colors: isActive
                                   ? [Theme.Palette.mint, Color(hex: 0x7C5CFF)]
                                   : [Color.white.opacity(0.22), Theme.Palette.hairline],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: isActive ? 1.5 : 1)
        }
    }
}

/// Small bubble used for recent searches.
struct BubbleChip: View {
    let text: String
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Palette.mint)
            }
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Palette.chalk)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(BubbleBackground(isActive: false))
    }
}
