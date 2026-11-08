import Foundation

public enum Locate {
    /// Even-odd point in polygon over all rings (outer + holes).
    static func inRings(lon: Double, lat: Double, _ rings: [Ring]) -> Bool {
        var inside = false
        for p in rings {
            var j = p.count - 1
            for i in 0..<p.count {
                let xi = p[i][0], yi = p[i][1], xj = p[j][0], yj = p[j][1]
                if (yi > lat) != (yj > lat) && lon < (xj - xi) * (lat - yi) / (yj - yi) + xi { inside.toggle() }
                j = i
            }
        }
        return inside
    }

    public struct Where: Equatable, Sendable {
        public var county: String?
        public var area: Area
        public var inside: Bool
        public var snapped = false
        /// Distance to the nearest county outline when outside the state.
        public var km: Double?
    }

    /// The county for a point. Points just outside every outline (open water on
    /// Lake Michigan, Green Bay or the Mississippi; outline simplification) snap
    /// to the nearest county within 15 km; farther is "outside Wisconsin", and
    /// takes the nearer area so times stay sensible.
    public static func county(lat: Double, lon: Double, geo: Geo = Bundled.geo) -> Where {
        for c in geo.counties {
            for poly in c.polys where inRings(lon: lon, lat: lat, poly) {
                return Where(county: c.name, area: c.area, inside: true)
            }
        }
        var best: Geo.County?
        var bestD = Double.infinity
        let cosLat = cos(lat * Sun.rad)
        for c in geo.counties {
            for poly in c.polys {
                for ring in poly {
                    for v in ring {
                        let dx = (v[0] - lon) * cosLat, dy = v[1] - lat
                        let dd = dx * dx + dy * dy
                        if dd < bestD { bestD = dd; best = c }
                    }
                }
            }
        }
        let km = bestD.squareRoot() * 111
        if let best, km < 15 { return Where(county: best.name, area: best.area, inside: true, snapped: true) }
        return Where(county: nil, area: best?.area ?? (lat >= 44.6 ? .north : .south), inside: false, km: km)
    }

    public enum DuckZone: String, Sendable { case north, south, open
        public var name: String {
            switch self { case .north: return "Northern"; case .south: return "Southern"; case .open: return "Open Water" }
        }
    }

    nonisolated(unsafe) private static var northRing: [Ring]?

    /// Duck (and Canada goose) zone. Lake Michigan and Green Bay water is Open
    /// Water (legally: more than 500 ft off the mainland shore). On land the
    /// split is US 10 from Minnesota to US 41, then US 41 north to Marinette;
    /// east of 41 is southern. km = distance to that line.
    public static func duckZone(lat: Double, lon: Double, where w: Where, data: DuckData = Bundled.ducks) -> (zone: DuckZone, km: Double?)? {
        if data.openWater.contains(where: { inRings(lon: lon, lat: lat, $0) }) { return (.open, nil) }
        guard w.inside else { return nil }
        let L = data.duckLine
        if northRing == nil {
            northRing = [L + [[L[L.count - 1][0], 48], [-93.6, 48], [-93.6, L[0][1]]]]
        }
        let c = cos(lat * Sun.rad)
        var best = Double.infinity
        for i in 1..<L.count {
            let ax = (L[i - 1][0] - lon) * c, ay = L[i - 1][1] - lat, bx = (L[i][0] - lon) * c, by = L[i][1] - lat
            let dx = bx - ax, dy = by - ay
            let len = dx * dx + dy * dy
            let t = max(0, min(1, -(ax * dx + ay * dy) / (len == 0 ? 1 : len)))
            best = min(best, hypot(ax + t * dx, ay + t * dy))
        }
        let north = inRings(lon: lon, lat: lat, northRing!)
        return (north ? .north : .south, best * 111)
    }

    /// The nearest named town, for a friendly label on a GPS fix.
    public static func nearestPlace(lat: Double, lon: Double, geo: Geo = Bundled.geo) -> (place: Geo.Place, km: Double)? {
        let c = cos(lat * Sun.rad)
        return geo.places.map { p -> (Geo.Place, Double) in
            let dx = (p.lon - lon) * c, dy = p.lat - lat
            return (p, (dx * dx + dy * dy).squareRoot() * 111)
        }.min { $0.1 < $1.1 }
    }
}
