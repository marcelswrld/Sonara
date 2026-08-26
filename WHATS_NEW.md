# Aimnubis — 5 fixes (each verified before shipping)

## 1) RENAMED to "Aimnubis"
The app now DISPLAYS as Aimnubis (home screen + splash screen).
IMPORTANT: I deliberately did NOT rename the internal Xcode
project/target/scheme — codemagic.yaml references "scheme Sonara", and
renaming it would break your build. Only the user-visible name changed.
Bundle ID stays com.mhr.sonara (that's fine — bundle IDs never need to
match the display name).
YOU STILL NEED TO: rename the app in App Store Connect (App Information
-> Name) so the store listing matches.

## 2) FIXED: wrong artist photos (Michael Jackson for Olivia Rodrigo)
Two causes, both fixed:
 a) The image lookup grabbed Spotify's FIRST search result without
    checking it was the right artist. It now searches 5 results and
    verifies the name matches (accent/punctuation-insensitive). If no
    result matches, it shows a placeholder rather than the WRONG face.
 b) SwiftUI was recycling list rows and reusing a previous row's loaded
    image. Fixed by giving each image a stable identity.

## 3) FIXED: everyone had "Cult following 100"
The math was broken: real Last.fm ratios run 10-300 plays per listener,
but the formula divided by 15 — so anything over 15 hit the 100 cap.
Rebuilt on a log scale across the real range and re-tested with realistic
numbers:
    12 plays/listener  ->   6  Casual reach
    22 plays/listener  ->  23  Casual reach
    30 plays/listener  ->  32  Casual reach
   127 plays/listener  ->  74  Devoted fans
   250 plays/listener  ->  94  Cult following
"Cult following" is now genuinely rare.

## 4) FIXED: was Vibe "High-Bass Head" for everyone? YES — and fixed
Real bug: "High-Bass Head" was scored on a SINGLE value (bass, usually
0.7+) while every other personality was a PRODUCT of two values
(0.5 x 0.5 = 0.25). A single value beats a product nearly every time, so
bass won by default. All eight personalities now score on two traits.
Simulated 12 listener profiles -> 7 DIFFERENT titles:
   Hip-hop/trap -> High-Bass Head      Oldies/soul  -> Acoustic Soul
   Folk         -> Zenned-Out Hippie   EDM/house    -> Electric Dreamer
   Indie/dream  -> Sunlit Maximalist   Sad/emo      -> Midnight Driver
   Ambient      -> Mellow Optimist     Classical    -> Zenned-Out Hippie
Also corrected the genre table: metal/punk/grunge were wrongly marked
"electronic" (they're guitar music = organic).

## 5) FIXED: X button didn't close the artist screen
It was inside the scrolling content, so it scrolled away and was easy to
miss. It's now PINNED above the scroll view (always visible, bigger tap
target) and I added a drag-down indicator so you can also swipe to close.

## Build
Push all 20 files. Scheme/workflow unchanged, so just run
"Sonara - TestFlight" as usual. The app will install showing "Aimnubis".
