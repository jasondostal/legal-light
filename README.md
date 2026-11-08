# Legal Light (working name)

Wisconsin legal shooting hours on your phone, with a lock-screen countdown.
Native take on [ducktyping.dev/playground/shooting-hours](https://ducktyping.dev/playground/shooting-hours/).

All four rule sets (Wis. Admin. Code NR 10.06): ducks & geese, deer / bear / small game /
fall turkey, spring turkey, early teal. Times come from the DNR's published tables
(reference town + longitude zone), not the sun at your spot. Offline: everything is on
the phone.

## Layout

- `HoursCore/` — Swift package: the engine (port of `ducktyping/public/shooting-hours-engine.js`),
  bundled DNR tables / county outlines / duck-zone line, and tests.
- `App/` — SwiftUI app. `Widget/` — WidgetKit extension (home + lock screen, per-widget rule set).
- `tools/gen-data.mjs` — regenerates the bundled data and test fixtures from the ducktyping repo.
  Each season: add the new DNR tables to the web toy's fixture, then rerun this.
- `tools/gen-icon.py` — `uv run --with pillow tools/gen-icon.py`.

## Build

```sh
xcodegen generate                       # after adding files
(cd HoursCore && swift test)            # the gate: DNR tables + 4,992 cases vs the JS engine
xcodebuild -project ShootingHours.xcodeproj -scheme ShootingHours \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -derivedDataPath DerivedData-sim build CODE_SIGNING_ALLOWED=NO
xcrun simctl launch booted dev.ducktyping.shootinghours -gallery   # debug: every widget family, live
```

Device builds need the App Group `group.dev.ducktyping.shootinghours` (app ↔ widget share the spot),
which Xcode's automatic signing creates once an Apple ID is signed in to Xcode → Settings → Accounts.
