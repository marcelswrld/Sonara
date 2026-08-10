# Sonara fixes — round 1 + standalone Spotify

Replace these 3 files in your Sonara repo, commit, push, run
"Sonara - TestFlight". Then assign the new build to your TestFlight group.

## What changed
1. PitchView.swift
   - Removed the stray green line in the Securitized Value box.
   - Added keyboard "Done" button + tap-to-dismiss for the revenue field.
2. SpotifyCore.swift
   - Now uses SONARA'S OWN Spotify client ID (9f8cd743...), fully
     standalone — no Musiclips dependency.
   - Redirect changed to "sonara://callback".
3. project.yml
   - Registers the matching "sonara" URL scheme.

## REQUIRED in the Spotify dashboard (you already created the app)
Confirm the Sonara Spotify app's Redirect URIs include EXACTLY:
    sonara://callback
(developer.spotify.com/dashboard -> Sonara -> Settings -> Redirect URIs)
If it's not there, login bounces back empty. Add it and Save.

## After pushing
- Codemagic: just run "Sonara - TestFlight" (nothing to configure).
- App Store Connect: new build appears under TestFlight; assign it to your
  internal testing group like before. Re-answer export compliance if asked.

## Possible follow-up (not a blocker to build)
Sonara's Spotify app is brand new. Spotify limits /recommendations and
preview_url for apps created after Nov 2024. If Discover loads empty after
login works, tell me — I'll switch Discover to a supported data source
(new releases / search / user's top tracks). Login/Profile/Wrapped are
unaffected.
