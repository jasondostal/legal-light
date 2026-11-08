# Third-party data and code

- **Wisconsin DNR, 2026 shooting hours tables** (public government data): the four Zone A
  tables (northern/southern × waterfowl & spring turkey / deer, bear, small game & fall turkey)
  and the early-teal table, transcribed verbatim into `HoursCore/Sources/HoursCore/Resources/official.json`.
  Source PDFs are linked from <https://dnr.wisconsin.gov/topic/hunt/regulations>.
- **U.S. Census Bureau cartographic boundaries and TIGER/Line** (public domain): county outlines
  (`cb_2023_us_county_5m`), Great Lakes water, and the US 10 / US 41 duck-zone line, built by
  ducktyping.dev's `scripts/gen-shooting-hours-map.py` and copied in by `tools/gen-data.mjs`.
- **NOAA solar calculator equations** (Meeus, public domain): the computed fallback in `Sun.swift`.
- **Silkscreen** (Jason Kottke, SIL Open Font License 1.1) and **JetBrains Mono** (JetBrains,
  SIL Open Font License 1.1): `Shared/Fonts/`, licences alongside.

The engine is a port of the ducktyping.dev shooting-hours toy, also by Jason Dostal.
