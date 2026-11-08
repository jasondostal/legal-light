# Legal Light

Wisconsin legal shooting hours on your phone: a countdown to legal light, lock-screen and
home-screen widgets, a Dynamic Island Live Activity, and alerts at legal light and before close.
The native version of [ducktyping.dev/playground/shooting-hours](https://ducktyping.dev/playground/shooting-hours/).

All four rule sets in Wis. Admin. Code NR 10.06: ducks & geese, deer / bear / small game /
fall turkey, spring turkey, and early teal. Times come from the DNR's published tables
(one reference town per area plus 4 minutes per degree of longitude west of 88° W), not the
sun at your spot. Everything runs on the phone: no account, no network, no tracking.

**Not the law.** The Wisconsin DNR's regulations and published tables govern.

## Layout

- `HoursCore/` — Swift package: the engine (a port of `ducktyping/public/shooting-hours-engine.js`),
  the bundled DNR tables, county outlines and duck-zone line, and tests.
- `App/` — SwiftUI app: countdown, zone map, week table, settings (icons, alerts).
- `Widget/` — WidgetKit extension: home and lock-screen widgets, the hunt Live Activity.
- `Shared/` — the ducktyping.dev theme, fonts, and the Live Activity model (compiled into both).
- `tools/gen-data.mjs` — regenerates the bundled data and test fixtures from the ducktyping repo.
  Each season: add the new DNR tables to the web toy's fixture, then rerun this.
- `tools/gen-icons.py` — the pixel-art app icons (`uv run --with pillow tools/gen-icons.py`).

## How the hunt Live Activity changes phase without a server

An app-started Live Activity can't change itself once the app is in the background, and the
`staleDate` redraw doesn't happen on a real phone. iOS 26 can schedule an activity to *start*
later, so a hunt is a chain: a lead-in counting to legal light, a "closes in" activity scheduled
to start at legal light (with its alert), and on long days a third one before the 8-hour cap.

## Build

```sh
xcodegen generate                       # after adding files
(cd HoursCore && swift test)            # the gate: DNR tables + 4,992 cases vs the JS engine
xcodebuild -project ShootingHours.xcodeproj -scheme ShootingHours \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -derivedDataPath DerivedData-sim build CODE_SIGNING_ALLOWED=NO
```

Debug launch arguments: `-gallery` (every widget family and the Live Activity, live), `-scroll map|week`,
`-settings`. Settings → Debug → "Test the flip" runs a 45-second hunt chain.

MIT licensed; see NOTICE.md for data and fonts.
