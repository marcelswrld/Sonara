# Sonara — Discover fix (new-Spotify-app endpoint limits)

Login works now. Discover was empty because Spotify DISABLED the
/recommendations endpoint for apps created after Nov 2024 (Sonara's app
is new). Fixed by switching Discover to endpoints that still work.

## Replace these 2 files, commit, push, run "Sonara - TestFlight":
- SpotifyAPI.swift   — Discover now layers: your top tracks -> new releases
                       -> saved tracks -> search. First non-empty wins.
- DiscoverView.swift — real "Retry" button (the old "pull to retry" had no
                       pull gesture); clearer empty/error messages.

## Expected after this build
- Discover fills with tracks (from your top tracks / new releases / search).
- Swiping right saves them, which then makes Wrapped count > 0.
- If it's STILL empty, tap Retry and tell me what happens — we may need to
  add scopes or use a different mix.

## Note on album art / previews
Some new-release tracks may lack artwork or 30s previews (Spotify limits
previews for new apps too). Core swipe/save still works. If previews are
important, tell me and we'll adjust.
