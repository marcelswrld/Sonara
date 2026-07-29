# Sonara — the new combined app (Musiclips + MyPitch)

A fresh SwiftUI app where Musiclips (Discover) and MyPitch (Pitch) work
together under one login, one account, one design system — the unified
experience from the contract, not two apps bolted together.

## Status: structurally complete, ready for first CI build
All source is written, cross-checked (types, environment objects, test
target, iOS-16 API safety) and brace-balanced. Not yet run through a
compiler — that's the first Codemagic run.

## What works
- **One Spotify login** (PKCE, tokens in Keychain) shared across both halves
- **Discover** — real Spotify recommendations seeded from the user's top
  tracks, real artwork, 30s preview playback, swipe-to-save-to-library
- **Pitch** — the MyPitch valuation, two methods:
  - flat-growth projection (the bug-fixed engine), and
  - tier-based multiplier valuation (how catalog deals are quoted)
- **Wrapped** — real recap from the user's like history, rendered to a
  shareable image card
- **Profile** — real signed-in user, save/streak stats, badges
- **Gamification** — streaks + badges, unit-tested

## Build it
Push the CONTENTS of this folder to the root of `mhr-sonara`, connect in
Codemagic, run `unified-sim`. It uses XcodeGen (project.yml) so no Mac is
needed — the Xcode project generates on the build machine.

## Files
```
project.yml        XcodeGen spec (auth URL scheme, iOS 16, test target)
codemagic.yaml     CI (sim build active; TestFlight ready, needs .p8)
Sources/           app code (14 files)
Tests/             unit tests (projection, catalog, streaks)
```

## Known follow-ups (not blockers)
- Spotify "recommendations" + "preview_url": if this Spotify app
  registration has restricted endpoints, some previews/recs may be
  limited — reuse of Musiclips' existing registration is intended to
  preserve access. Confirm on first real device test.
- Rotate the old Spotify client secret (see 04-docs/SECURITY_ACTION_ITEMS).
- Server-side dates for streaks (cheat-proofing) when backend is ready.
