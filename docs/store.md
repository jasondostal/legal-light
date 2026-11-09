# App Store listing: Legal Light

**1.0 (7) resubmitted 2026-11-09** (reviewSubmission 7c28922b-…) after pulling 1.0 (5): the map's zoom/center/whole-state buttons never worked (tap gestures swallowed them), found in the field; 7 also follows spot changes, faster map, 44pt gear, running-hunt label, fresh screenshots. Earlier: **1.0 (5) submitted 2026-11-08 ~16:05 CST** (reviewSubmission db25d737-…). Builds 1–4 were
superseded: 2 narrower island timer, 3 icon+ring island and CFBundleName, 4 in-app header, 5 iPhone-only
(4 declared iPad, which demanded iPad screenshots). Blockers met on the first submit: contentRightsDeclaration
(USES_THIRD_PARTY_CONTENT) and App Privacy must be *published*, not just saved.

Record created 2026-11-08 by Jason as **Legal Light: WI Shooting Hours** (ASC app id 6832333458,
SKU `legal-light`, bundle id `dev.ducktyping.shootinghours`). `tools/asc/listing.py` pushes the
fields below through the API; App Privacy and pricing/availability are noted where they need the web UI.

## Name and subtitle (30 characters each)

- Name: `Legal Light: WI Shooting Hours` (30)
- Subtitle: `Deer & duck countdown widget` (28)

## Promotional text (170; changeable without review)

Legal light on your lock screen. Ducks, geese, deer, turkey and teal, straight from the DNR's own tables, with alerts and a Dynamic Island countdown. No signal needed.

## Description (4000)

How long until legal light? Legal Light counts down to Wisconsin shooting hours for the spot you're standing on, and puts the countdown on your lock screen, your home screen and the Dynamic Island.

Built in a duck boat before dawn, for the moment you want to know whether it's legal yet and the DNR's PDF is the last thing you want to dig up.

THE COUNTDOWN
• A big countdown to legal light, then to close
• All four Wisconsin rule sets: ducks and geese, deer / bear / small game / fall turkey, spring turkey, and the September early teal season
• Your county, hours zone and duck zone, with a warning when you're near the US 10 / US 41 duck line
• Use your location, pick a town, or tap the map

STRAIGHT FROM THE DNR
Wisconsin's legal hours aren't the sunrise at your spot. Each area uses one reference town's sunrise and sunset (Powers, Michigan for the north, Sheboygan for the south), plus 4 minutes for every degree of longitude west of 88° W. Legal Light reads the DNR's published 2026 tables directly and adds your zone's minutes. For years whose tables aren't in the app yet it computes them the same way (it matches all 2,920 entries of the 2026 tables within a minute) and says so.

ON YOUR LOCK SCREEN
• Lock screen widgets: a live countdown, the next opening or closing time, and an inline line above the clock
• Home screen widgets, small and medium, with the week ahead
• Each widget picks its own species: put a deer countdown next to a duck one
• Start a hunt countdown and it rides in the Dynamic Island and on the lock screen, switching from "legal light in" to "closes in" by itself at legal light

ALERTS
• A ping at legal light
• A heads-up 5, 10, 15 or 30 minutes before close
• Scheduled on the phone two weeks ahead, so they fire with no signal, and they get through Focus

THE ZONE MAP
• Hours zones A to F, the northern and southern tables, duck zones and open water
• Pinch to zoom, tap anywhere to read its zones and use it as your spot

AND
• Any week's open and close times, with a date picker
• Today at a glance: night, twilight, legal light and sunrise on one bar
• Sun and moon at your exact spot
• Pixel-art app icons: first light, mallard, teal, whitetail, fox squirrel or tom turkey, or let the icon follow what you're hunting

PRIVATE, OFFLINE
No account, no ads, no tracking, no analytics. Legal Light makes no network requests at all: everything is computed on your phone, and your location never leaves it. Open source on GitHub.

NOT THE LAW
The Wisconsin DNR's regulations and its published shooting hours tables govern. Check the season dates and rules before you hunt, and allow yourself a margin.

## Keywords (100, comma-separated; don't repeat name/subtitle words)

`hunting,waterfowl,goose,turkey,teal,sunrise,sunset,DNR,Wisconsin,dynamic island,timer,hunt,bow,gun`

## URLs

- Support: https://ducktyping.dev/legal-light/
- Marketing: https://ducktyping.dev/legal-light/
- Privacy policy: https://ducktyping.dev/legal-light/privacy/

## Category, rating, price

- Primary category: Sports; secondary: Utilities
- Age rating: "None" / No throughout → 4+ (no depictions of weapons: the app is a clock for regulated hours)
- Price: Free. Availability: United States (the app is Wisconsin regulations).
- Copyright: `2026 Jason Dostal`

## App Privacy (web UI only; the API can't set it)

"Do you or your third-party partners collect data from this app?" → **No** → "Data Not Collected".
Legal Light makes no network requests at all; location is used on device only.

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` in the Info.plist.

## Review notes

Legal Light needs no login and makes no network requests. It shows Wisconsin's legal hunting
hours (Wis. Admin. Code NR 10.06) from the DNR's published 2026 tables. Location is optional:
without it the app shows Stevens Point, WI; tap the location button (top right) to pick any
Wisconsin town, or tap the map ("Use this spot").

Widgets: add "Legal Light" from the home or lock screen widget gallery; each widget can be set to
a species (long-press → Edit Widget).

Live Activity: tap "Start hunt countdown" under the countdown. It shows a countdown to legal light
in the Dynamic Island and on the lock screen. At legal light a second, scheduled Live Activity
(iOS 26 scheduled start) takes over with a countdown to close and an alert. Started during legal
hours, it begins with the countdown to close. Stevens Point legal light today is shown on the
main screen.

Alerts (gear → Alerts) are local notifications at legal light and before close. Settings also has
selectable alternate app icons.

## Screenshots (6.9", 1320 × 2868)

`tools/store-shots.sh` writes `tools/shots/store/`: 01 deer opener countdown, 02 duck-zone map,
03 hours-zone map, 04 the week, 05 icons and alerts. Plus a real lock screen (widgets + Live
Activity) from Jason's phone, resized to 1320 × 2868.
