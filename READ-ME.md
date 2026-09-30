# Aimnubis: artist search bubble

## Apply
1. GitHub Desktop -> Sonara repo -> Repository -> Show in Explorer.
2. Drag TrendsView.swift and LastFM.swift into that folder -> Replace.
3. GitHub Desktop should show exactly these 2 changed files. Commit, push.
4. Run the Aimnubis build in Codemagic, then install from TestFlight.

## What you get (Trends tab)
- Glossy "bubble" search bar under the Trends title: frosted glass, soft top
  highlight, mint magnifier bubble. Tap it and it grows slightly, glows
  mint-to-violet, the magnifier tilts, and a Cancel button slides in.
- Results appear as you type (after a short pause): same rows as Trends, with
  real listeners, plays and Superfan Score. Tap one for the full artist sheet
  (bio, top tracks, previews, "Value this artist").
- Recent searches show as bubble chips when you tap the bar (up to 8, with
  Clear). Scrolling the results hides the keyboard.
- No match -> a friendly floating-bubble "No artists found" message.

Search uses Last.fm (same free key Trends already uses), so no new accounts
or costs.
