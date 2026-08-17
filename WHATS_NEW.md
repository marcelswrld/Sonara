# Sonara — "Vibe" music-personality + daily-mood (FULL SOURCE, push all)

## The new point of the app: YOUR VIBE
A whole new tab that gives Sonara a real identity, built ENTIRELY on data
Spotify still gives new apps (top artists' genres + recently-played with
timestamps). No blocked endpoints. Works the moment you log in. No outside
API, nothing that can rate-limit or break.

### What it shows
- A living MOOD ORB — a glowing, rotating, pulsing sphere colored by YOUR
  taste (violet=moody -> gold=bright), speed tied to your energy, bass
  rings that swell with your low-end preference.
- A PERSONALITY TITLE from your listening: "High-Bass Head", "Zenned-Out
  Hippie", "Midnight Driver", "Sunlit Maximalist", etc. + a one-liner +
  descriptor chips (High energy / Bright & upbeat / Bass-heavy...).
- TOP GENRES as animated bars.
- YOUR DAY IN MOOD — an energy curve across the hours you actually listen,
  built from recently-played timestamps ("calm mornings, high-energy
  nights"). Fills in more as you listen.

### How it works (honest)
Spotify still exposes artist GENRES + recently-played. Genres encode
energy/valence/mood, so a bundled table (baked into the app) maps them to
a mood profile locally. It's a taste-level read, not per-song truth — but
it's real, instant, and outage-proof. We can later enrich with a free
Last.fm key for richer mood words if you want (optional, not required).

## Changes
- NEW: MoodEngine.swift (mood table + personality/day-arc logic)
- NEW: VibeView.swift (the orb, personality, genres, day arc)
- SpotifyAPI.swift: added topArtists + recentlyPlayed (with timestamps)
- App.swift: added Vibe tab; tabs are now Trends · Vibe · Pitch · Profile
- Theme.swift: added Color.blend; Motion.swift: added shared FlowLayout
- REMOVED WrappedView (it was the boring "15 tracks" screen — Vibe replaces it)

## Trends tap fix
Tapping a Trends card now routes to Pitch (tab index corrected).

## Build
Push ALL files (full source). Run "Sonara - TestFlight". No signing/env changes.
IMPORTANT: delete WrappedView.swift from your repo (it's removed here) —
same drag-and-drop caveat as before: dragging won't delete repo files.
Your repo should have exactly these 17 .swift files:
App, CatalogPanel, CatalogValuationEngine, DiscoveryStore, LaunchView,
MoodEngine, Motion, PitchView, ProfileView, ProjectionEngine,
ProjectionEngineTests, SpotifyAPI, SpotifyCore, StreakEngine, Theme,
TrendsView, VibeView
