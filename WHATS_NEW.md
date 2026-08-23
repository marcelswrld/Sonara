# Sonara — playback, real artist photos, Superfan Score, working Pitch handoff

## 1) PLAYBACK — now works (free, no key)
Spotify won't give previews to new apps, so I added DEEZER's public API
(no key, no auth). On the artist screen you get a "PLAY A PREVIEW" list —
tap any track for a real 30-second clip. Plays in silent mode too.
NEW FILE: Deezer.swift (search + AVPlayer wrapper).
Honest note: coverage is good but not universal — if Deezer doesn't have
a track, the section simply doesn't appear (no dead buttons).

## 2) FIXED: white stars instead of artist photos
Last.fm deliberately serves a placeholder star for every artist (they
dropped image licensing). Fixed by resolving the REAL photo from Spotify
by artist name (we already have Spotify auth). Applies to the Trends list
and the artist detail hero.

## 3) FIXED: "Value this artist" did nothing with numbers
It now PREFILLS the Pitch calculator with an estimated annual revenue
derived from the artist's real play data, so you land on a populated
valuation instead of an empty form. The banner says it's an estimate and
you can edit it to refine. (Routing now carries name + revenue.)

## 4) NEW + UNIQUE: SUPERFAN SCORE
Sonara's own derived metric: plays per listener. High = a small obsessive
fanbase; low = wide but casual reach. Labels: Cult following / Devoted
fans / Steady listeners / Casual reach. Shown as a badge in the Trends
list and a full card on the artist screen.
Why it's genuinely useful here: repeat listening predicts DURABLE
streaming revenue, which is exactly what the Pitch valuation models. It
ties the discovery half of the app to the valuation half — something no
generic music app does.

## Files
NEW: Deezer.swift, ArtistDetailSheet.swift
CHANGED: LastFM.swift, TrendsView.swift, PitchView.swift, App.swift,
         SpotifyAPI.swift, Motion.swift

## 20 files — repo must match:
App, ArtistDetailSheet, CatalogPanel, CatalogValuationEngine, Deezer,
DiscoveryStore, LastFM, LaunchView, MoodEngine, Motion, PitchView,
ProfileView, ProjectionEngine, ProjectionEngineTests, SpotifyAPI,
SpotifyCore, StreakEngine, Theme, TrendsView, VibeView

## Build
Push all 20, fresh build, reinstall. Open Trends -> tap an artist ->
you should see a real photo, superfan score, previews you can play, and
"Value this artist's catalog" landing on a filled-in Pitch.
