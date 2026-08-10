# Sonara — Discover fix + certificate-limit fix

## Two things in this package:

### A) Discover data fix (login already works!)
Replace these, they fix the empty Discover:
- SpotifyAPI.swift   — Discover now uses your top tracks / new releases /
                       saved / search instead of the disabled /recommendations
- DiscoverView.swift — working Retry button, clearer messages

### B) The build failed on a CERTIFICATE LIMIT
"You already have a current Distribution certificate" + "Found 5
certificates" = Apple's account hit its distribution-cert cap. Every past
build made a new throwaway cert and they piled up.

TWO WAYS TO FIX — pick one:

**Option 1 (safest — do this first, 2 min, no code):**
Manually delete old certs in Apple's portal:
  developer.apple.com/account -> Certificates -> filter "Distribution"
  -> you'll see several "iOS Distribution" / "Apple Distribution" certs.
  Delete the OLDER ones, keep 1 (or delete all if none are used by other
  apps). Then re-run the CURRENT build (no code change needed) — but it
  will still try to make a new one, which now succeeds because there's room.
  IMPORTANT: if Mark's OTHER apps (MyPitch/Musiclips) use a cert, don't
  delete that one. When unsure, delete the ones created most recently by
  these Sonara build attempts.

**Option 2 (automated — use the codemagic.yaml in this zip):**
It auto-deletes distribution certs before creating a fresh one. Convenient,
BUT it deletes ALL distribution certs on the account — only use this if
you're sure no other app depends on them. Since this is Mark's account with
other apps, OPTION 1 IS SAFER.

## Recommended path
1. Push SpotifyAPI.swift + DiscoverView.swift (the Discover fix).
2. Do Option 1 manually (delete surplus certs in Apple portal).
3. Re-run "Sonara - TestFlight" with your EXISTING codemagic.yaml.
Only fall back to Option 2's codemagic.yaml if Option 1 is unclear.
