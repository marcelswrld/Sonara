# Sonara — fixes + restore missing file

## FIRST: the last build failed because ProfileView.swift is MISSING
from your GitHub repo (it exists in the code but never got pushed —
lost in one of the zip shuffles). Add ProfileView.swift to the repo.

## Replace/add ALL of these in your Sonara repo, then commit + push:
- ProfileView.swift   — ADD THIS (it's missing from the repo; that's what broke the build)
- PitchView.swift     — green line removed; keyboard Done button
- SpotifyCore.swift   — Sonara's own client id (standalone); sonara://callback
- project.yml         — sonara URL scheme + excludes git/sample/doc junk
- codemagic.yaml      — cleanup step before build

## HOW TO CONFIRM nothing else is missing
On GitHub, open your Sonara repo and check these 15 files are ALL there:
App, CatalogPanel, CatalogValuationEngine, DiscoverView, DiscoveryStore,
LaunchView, PitchView, ProfileView, ProjectionEngine, ProjectionEngineTests,
SpotifyAPI, SpotifyCore, StreakEngine, Theme, WrappedView
If any others are missing, tell me and I'll send them.

## Spotify dashboard (for login): redirect URI must include exactly
    sonara://callback

## After pushing: run "Sonara - TestFlight", assign build to your test group.
