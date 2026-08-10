# Sonara — round 1 fixes + build fix (git-junk in archive)

Replace these files in your Sonara repo, commit, push, run
"Sonara - TestFlight".

## Files in this package
- PitchView.swift    — green line removed; keyboard Done button
- SpotifyCore.swift  — Sonara's OWN client id (standalone); sonara://callback
- project.yml        — sonara URL scheme + excludes git/sample/doc junk
- codemagic.yaml     — cleanup step strips .sample/.git/docs before build

## Why the last build failed
The build was copying git hook files (update.sample, pre-push.sample, etc.)
into the app because a .git folder sat inside the source folder XcodeGen
scans. project.yml now excludes them and codemagic.yaml deletes them before
generating the project. Fixed two ways for safety.

## Spotify dashboard (required for login)
Sonara's Spotify app must list redirect URI EXACTLY:
    sonara://callback
developer.spotify.com/dashboard -> Sonara -> Settings -> Redirect URIs

## After pushing
- Codemagic: run "Sonara - TestFlight".
- App Store Connect: assign new build to your internal test group.

## Possible follow-up (not a blocker)
New Spotify apps have limited /recommendations + previews. If Discover
loads empty after login works, tell me and I'll switch its data source.
