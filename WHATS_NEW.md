# Sonara — Trends pivot + full visual overhaul (FULL SOURCE, push everything)

## The big decision (made for Mark)
Swipe-discovery is GONE. Spotify blocks the data it needs (recommendations,
previews, audio features) for new apps, and we can't get extended access.
Replaced with TRENDS — built only on data Spotify DOES give new apps
(new releases, album art, artist search), framed as investment signal that
feeds Pitch. This makes Sonara ONE product: spot rising artists -> value
their catalog.

Tabs are now: Trends · Pitch · Wrapped · Profile (4, clean).

## New: Trends tab (TrendsView.swift)
- Animated HERO that rotates through rising releases every few seconds
- "Climbing" horizontal strip with momentum % badges
- "Fresh Releases" grid — real album art
- Tap any release -> jumps to Pitch with a "valuing a rising artist" banner
- Everything runs on data that's actually there, so it looks FULL

## New: Motion toolkit (Motion.swift) — the "dynamic" you asked for
Reusable, applied across the app:
- AuroraBackground: slow drifting color clouds behind screens
- floating(), pulsing(), shimmering(), pressSpring() modifiers
- CountUp animated numbers, MomentumBadge rising indicators
These animate REAL content, so motion is visible (last time it animated
empty data, which is why nothing moved).

## Removed
- DiscoverView, TasteMapView, TasteProfile (couldn't work without the
  blocked Spotify data). Clean removal, no dangling refs.

## Pitch
- Now accepts a routed artist from Trends (shows a banner).
- Green line already removed; keyboard Done button already added.

## HONEST STATE
- Previews still limited by Spotify (unchanged reality) — but Trends
  doesn't rely on previews, so it's not a problem here.
- Momentum % is a derived signal from release recency/position (Spotify
  gives new apps no real chart numbers). It reads as "what's fresh &
  rising," which is honest, not fake precision.

## Build
Push ALL files (full source here to avoid missing-file issues).
Run "Sonara - TestFlight". No signing/env changes.
