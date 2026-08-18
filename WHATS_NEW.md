# Sonara — fixes for "taps do nothing" + "Vibe empty"

## THE TWO BUGS YOU HIT — both fixed

### 1. Trends taps did nothing → FIXED
The cards used a custom tap gesture that got SWALLOWED by the scrolling
view (a known SwiftUI issue). Replaced with real Buttons, which scroll
views respect. Tapping Climbing / Fresh Releases now jumps to Pitch and
shows the ARTIST'S NAME in a banner so it's obvious the tap worked.

### 2. Vibe was empty despite listening → FIXED (this was a real bug)
The daily-mood arc calls Spotify's recently-played endpoint, which needs
the "user-read-recently-played" permission — which was MISSING from the
login scopes. Added it (plus follow scopes). ALSO made the personality
bulletproof: if your top artists' genres don't match the built-in table,
it now derives your mood from the genre NAMES instead of showing nothing.
It will only be empty if your account truly has no top artists yet.

## IMPORTANT: you must re-authorize Spotify
Because the login PERMISSIONS changed (added recently-played), you need to:
1. Delete & reinstall the app on your phone (or sign out in Profile), OR
2. Just sign out and back in.
Otherwise your existing login token won't have the new permission and the
daily mood arc will still be empty. This is a one-time thing.

## Files changed
- SpotifyCore.swift — added user-read-recently-played + follow scopes
- MoodEngine.swift — bulletproof personality (name-based fallback)
- TrendsView.swift — Buttons instead of gesture; routes artist NAME
- PitchView.swift — banner shows the tapped artist's name

## Build
Push ALL files (full source). Run "Sonara - TestFlight".
Repo must have these 17 .swift files (NO WrappedView, NO DiscoverView,
NO TasteMapView/TasteProfile):
App, CatalogPanel, CatalogValuationEngine, DiscoveryStore, LaunchView,
MoodEngine, Motion, PitchView, ProfileView, ProjectionEngine,
ProjectionEngineTests, SpotifyAPI, SpotifyCore, StreakEngine, Theme,
TrendsView, VibeView

## AFTER INSTALLING: sign out & back in (for the new permission), then
listen to a few songs and open Vibe. The mood orb + personality should
populate from your top artists immediately; the daily arc fills from your
recent plays.
