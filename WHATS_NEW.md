# Sonara — Taste Map + Discover overhaul

## New / changed files (this is the FULL source — push all of it to be safe)
NEW:
- TasteProfile.swift   — taste engine: genre affinities + audio-feature DNA
- TasteMapView.swift   — the interactive heat-map + DNA spectrum (the star)
CHANGED:
- App.swift            — added a "Taste" tab + wired the taste engine
- DiscoverView.swift   — wider varied feed (no more 15-loop), header no
                         longer cut off, play disabled when no preview,
                         every save now feeds the Taste Map (genres + DNA)
- SpotifyAPI.swift     — audio-features, artist genres, follow-artist

## The Taste Map (new "Taste" tab)
- A colorful HEAT-MAP of your genres: each saved artist's genres become
  glowing cells, sized + colored by how much they define you (violet ->
  mint -> gold as intensity rises). Cells breathe, tap to highlight, and
  the whole grid tilts in 3D when you drag it.
- An animated AUDIO DNA spectrum: energy, danceability, mood, acoustic,
  instrumental, tempo — averaged from everything you save.
- A derived "taste type" label (e.g. "Midnight Driver").

## Discover fixes from your feedback
- "Discover"/streak no longer cut off on the left (safe-area padding).
- Feed is now wide + de-duplicated, keeps flowing instead of looping 15.
- Play button disables (dims) when Spotify gives no preview, so it's not
  a dead button.
- Saving follows the artist on Spotify AND builds your Taste Map.

## HONEST LIMITS (Spotify new-app API)
- PREVIEWS: Spotify withholds 30s previews for many tracks on new apps.
  Player works where previews exist; disabled where they don't. Full
  in-app playback would need the Spotify SDK (premium + their app) — a
  bigger build, worth a Mark conversation.
- AUDIO FEATURES: /audio-features may also be limited for new apps. If the
  DNA spectrum shows empty, that's why — the heat-map still works from
  genres. Extended API access (Mark petitions Spotify) unlocks both.

## Build
Push everything, run "Sonara - TestFlight". No new env/signing changes.
The Taste tab appears between Discover and Pitch.
