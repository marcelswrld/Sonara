import SwiftUI

// =====================================================================
// ArtistDetailSheet — the "give me info on the artist" screen. Real
// Last.fm data: listeners, total plays, biography, and top tracks.
// From here you can jump to Pitch to value their catalog.
// =====================================================================

struct ArtistDetailSheet: View {
    let artist: LFArtist
    let valueAction: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var listeners = 0
    @State private var playcount = 0
    @State private var bio: String?
    @State private var tracks: [LFTrack] = []
    @State private var tags: [String] = []
    @State private var loading = true

    var body: some View {
        ZStack {
            Theme.Palette.ink.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    hero
                    statsRow
                    if !tags.isEmpty { tagRow }
                    if let bio, !bio.isEmpty { bioCard(bio) }
                    if !tracks.isEmpty { topTracksCard }
                    valueButton
                }
                .padding(Theme.Space.l)
                .padding(.bottom, 30)
            }
        }
        .task { await load() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 26))
                        .foregroundStyle(Theme.Palette.mist)
                }
            }
            if let url = artist.imageURL {
                AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) }
                    placeholder: { Theme.Palette.panel }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            Text(artist.name).font(Theme.Type_.display(30))
                .foregroundStyle(Theme.Palette.chalk)
            if let g = artist.genre {
                Text(g.capitalized).font(Theme.Type_.caption())
                    .foregroundStyle(Theme.Palette.mint)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: Theme.Space.m) {
            statBox(LastFM.compact(listeners), "Listeners")
            statBox(LastFM.compact(playcount), "Total plays")
            statBox(tracks.isEmpty ? "—" : "\(tracks.count)", "Top tracks")
        }
    }

    private func statBox(_ v: String, _ l: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Palette.chalk)
            Text(l).font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Theme.Space.m)
        .background(card)
    }

    private var tagRow: some View {
        FlowLayout(spacing: 7) {
            ForEach(tags.prefix(6), id: \.self) { t in
                Text(t.capitalized)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.chalk)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Theme.Palette.mint.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(Theme.Palette.mint.opacity(0.35), lineWidth: 1))
            }
        }
    }

    private func bioCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ABOUT").font(Theme.Type_.caption()).tracking(1.5)
                .foregroundStyle(Theme.Palette.mist)
            Text(cleanBio(text)).font(Theme.Type_.body(14))
                .foregroundStyle(Theme.Palette.chalk.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l).background(card)
    }

    private var topTracksCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("TOP TRACKS").font(Theme.Type_.caption()).tracking(1.5)
                .foregroundStyle(Theme.Palette.mist)
            ForEach(Array(tracks.enumerated()), id: \.element.id) { i, t in
                HStack(spacing: Theme.Space.m) {
                    Text("\(i + 1)").font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.mint).frame(width: 20)
                    Text(t.name).font(Theme.Type_.body(14))
                        .foregroundStyle(Theme.Palette.chalk).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(LastFM.compact(t.playcount))
                        .font(Theme.Type_.caption()).foregroundStyle(Theme.Palette.mist)
                }
                if i < tracks.count - 1 { Divider().overlay(Theme.Palette.hairline) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l).background(card)
    }

    private var valueButton: some View {
        Button { valueAction(artist.name) } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Value this artist's catalog")
                    .font(Theme.Type_.body(15, weight: .semibold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Theme.Palette.mint, in: Capsule())
            .foregroundStyle(Theme.Palette.ink)
        }
        .buttonStyle(.plain)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .fill(Theme.Palette.panel.opacity(0.85))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Theme.Palette.hairline, lineWidth: 1))
    }

    private func cleanBio(_ s: String) -> String {
        // strip the trailing "Read more on Last.fm" link markup
        var t = s
        if let r = t.range(of: "<a href") { t = String(t[..<r.lowerBound]) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load() async {
        async let infoT = LastFM.artistInfo(name: artist.name)
        async let tracksT = LastFM.topTracks(artist: artist.name, limit: 5)
        async let tagsT = LastFM.topTags(artist: artist.name)
        let (info, tr, tg) = await (infoT, tracksT, tagsT)
        if let info {
            listeners = info.listeners; playcount = info.playcount; bio = info.bio
        } else {
            listeners = artist.listeners; playcount = artist.playcount
        }
        tracks = tr
        tags = tg
        loading = false
    }
}
