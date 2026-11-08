// Regenerates HoursCore's bundled data from the ducktyping.dev web toy, which
// stays the single source of truth for the DNR tables and the geography.
//   node tools/gen-data.mjs [path/to/ducktyping]   (default ../ducktyping)
// Writes:
//   HoursCore/Sources/HoursCore/Resources/official.json  DNR Zone A tables by year
//   HoursCore/Sources/HoursCore/Resources/geo.json       county outlines + towns
//   HoursCore/Sources/HoursCore/Resources/ducks.json     duck-zone line + open water
//   HoursCore/Tests/HoursCoreTests/Fixtures/fixture.json the DNR transcription (tests)
//   HoursCore/Tests/HoursCoreTests/Fixtures/web-cases.json engine answers to diff against
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const dt = resolve(process.argv[2] || new URL('../../ducktyping', import.meta.url).pathname);
const load = (f) => { const m = { exports: {} }; new Function('module', readFileSync(resolve(dt, f), 'utf8'))(m); return m.exports; };
const E = load('public/shooting-hours-engine.js');
const GEO = load('public/shooting-hours-geo.js');
const MD = load('public/shooting-hours-mapdata.js');
const FX = JSON.parse(readFileSync(resolve(dt, 'scripts/shooting-hours-fixture.json'), 'utf8'));
const out = (p, v) => { writeFileSync(new URL('../' + p, import.meta.url), JSON.stringify(v)); console.log('wrote', p); };

// Official tables. The engine embeds the same strings as the fixture; take the
// fixture (it has the source URLs) and keep the engine's per-month layout.
out('HoursCore/Sources/HoursCore/Resources/official.json', {
  source: FX._urls,
  years: { [FX.year]: {
    north: { waterfowl: FX['wf-north'], smallgame: FX['dg-north'] },
    south: { waterfowl: FX['wf-south'], smallgame: FX['dg-south'] },
  } },
});
out('HoursCore/Sources/HoursCore/Resources/geo.json', {
  counties: GEO.counties.map((c) => ({ name: c.name, area: c.area, polys: c.polys })),
  places: GEO.places.map(([name, county, lat, lon, seat]) => ({ name, county, lat, lon, seat: !!seat })),
});
out('HoursCore/Sources/HoursCore/Resources/ducks.json', { duckLine: MD.duckLine, openWater: MD.openWater });
out('HoursCore/Tests/HoursCoreTests/Fixtures/fixture.json', FX);

// Cross-check cases: the JS engine's own answers over a spread of places,
// dates and seasons, including years with no official table (computed path)
// and both DST changes. The Swift port must reproduce these exactly.
const cases = [];
const pts = GEO.places.filter((_, i) => i % 3 === 0).map((p) => [p[2], p[3]])
  .concat([[44.75, -87.85], [43.05, -87.75], [44.98, -93.27], [46.9, -90.5], [44.5253, -89.5504]]);
const dates = [];
for (const y of [2026, 2027, 2030]) for (const [m, d] of [[1, 1], [3, 7], [3, 8], [3, 9], [6, 21], [9, 1], [9, 26], [10, 31], [11, 1], [11, 7], [11, 21], [12, 21], [12, 31]]) dates.push({ y, m, d });
for (const [lat, lon] of pts) {
  const loc = E.locate(lat, lon, GEO);
  const dz = E.duckZone(lat, lon, loc, MD);
  for (const ymd of dates) for (const season of Object.keys(E.SEASONS)) {
    const h = E.shootingHours(ymd, lat, lon, loc.area, season);
    cases.push({ lat, lon, ymd, season, county: loc.county, area: loc.area, inside: loc.inside,
      duck: dz && dz.id, zone: h.zone.id, openMin: h.openMin, closeMin: h.closeMin, source: h.source,
      open: h.open, close: h.close, sunrise: h.local.sun.sunrise, sunset: h.local.sun.sunset });
  }
}
out('HoursCore/Tests/HoursCoreTests/Fixtures/web-cases.json', cases);
console.log(cases.length, 'cross-check cases');
