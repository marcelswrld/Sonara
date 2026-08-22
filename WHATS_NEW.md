# Sonara — REAL data, no paid API needed

## The answer to "any other free APIs?" — YES: Last.fm (key you already have)
I tested Last.fm's full endpoint list against their live docs. Beyond the
genre tags we were already using, it ALSO provides — free, no extra key:
  • tag.getTopArtists   -> top artists BY GENRE  (fixes "random artists")
  • chart.getTopArtists -> real global chart      (fixes "new music 2024" junk)
  • artist.getInfo      -> REAL listeners + playcount (replaces my fake %)
  • artist.getTopTracks -> real top tracks (artist detail screen)
No Viberate (EUR300/mo) and no Soundcharts needed for Trends.

## FIXED: the fake momentum numbers
You were right — the old "+23% rising" was FAKE (computed from list
position). It's GONE. Trends now shows only REAL numbers: actual listener
counts and play counts from Last.fm.

## FIXED: random/uncategorised artists
Trends now has genre category chips: Global, Hip-Hop, Pop, Rock,
Electronic, R&B, Indie, Jazz, Classic Rock. Pick one, get the real top
artists for it. No more "new music 2024" garbage.

## NEW: "Load more" (your idea)
Loads the next page of artists on demand. Works around any per-call limit.

## NEW: Artist detail screen (tap any artist)
Real stats: listeners, total plays, genre tags, biography, and top 5
tracks with play counts. Plus "Value this artist's catalog" -> Pitch.
This replaces the old "tap does nothing but say enter revenue".

## FIXED: Vibe didn't reflect your recent oldies
The personality was built from your 6-month history. Now it weights:
  recent (last 4 weeks) x3, what you just played x2, 6-month x1
So a new listening phase actually changes your vibe.

## Files
NEW: ArtistDetailSheet.swift
REWRITTEN: LastFM.swift (full client), TrendsView.swift
CHANGED: MoodEngine.swift (recency weighting), SpotifyAPI.swift (time ranges)

## 19 files now — make sure your repo matches:
App, ArtistDetailSheet, CatalogPanel, CatalogValuationEngine,
DiscoveryStore, LastFM, LaunchView, MoodEngine, Motion, PitchView,
ProfileView, ProjectionEngine, ProjectionEngineTests, SpotifyAPI,
SpotifyCore, StreakEngine, Theme, TrendsView, VibeView

## For MARK's black screen
The app is iOS-only — it will NOT run on a MacBook. On his iPhone 11 it
should work (iOS 16+). Most likely he has a stale/broken old build:
have him DELETE the app and reinstall the newest TestFlight build.
If still black, get the crash log (App Store Connect -> TestFlight ->
Crashes) and send it over.
