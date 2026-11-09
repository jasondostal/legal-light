import SwiftUI
import HoursCore

/// The zone map from the web page, drawn natively. Same projection
/// (kilometres on a plane tangent at mid-Wisconsin), same layers, same colours:
///   hours  the A–F longitude bands + the northern/southern table line
///   duck   northern / southern / open water, split by US 10 and US 41
///   both   duck zones shaded, A–F as dashed lines, both lines
/// Pinch or double-tap to zoom, drag to pan once zoomed, tap to read any spot.
struct ZoneMap: View {
    enum Layer: String, CaseIterable { case hours, duck, both
        var label: String { self == .hours ? "Hours zones" : self == .duck ? "Duck zones" : "Both" }
    }

    let spot: Spot
    var useSpot: (Double, Double) -> Void

    @AppStorage("map.layer") private var layerRaw = Layer.hours.rawValue
    @State private var zoom: CGFloat = 1
    @State private var center: CGPoint? = nil   // km; nil = fit the state
    @State private var pinchStart: (zoom: CGFloat, center: CGPoint)? = nil
    @State private var dragStart: CGPoint? = nil
    /// A finger is down: draw geometry and the essential labels only (towns,
    /// counties and water names come back when the gesture ends).
    @State private var interacting = false
    @State private var pick: (lat: Double, lon: Double)? = nil
    @State private var pulse = false

    private var layer: Layer { Layer(rawValue: layerRaw) ?? .hours }
    private static let geo = MapGeometry.shared
    private static let zmax: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHead(text: "The map")
                Spacer()
            }
            LayerPicker(selection: layer) { layerRaw = $0.rawValue }
            GeometryReader { gp in
                let size = gp.size
                let v = view(size)
                ZStack(alignment: .topLeading) {
                    // The map and its gestures. The buttons must NOT live inside this
                    // layer: its tap gestures swallowed every tap meant for them
                    // (Jason, 2026-11-09: "the double arrow button does nothing").
                    ZStack(alignment: .topLeading) {
                        Canvas { ctx, sz in draw(&ctx, sz, v) }
                        me(v)
                    }
                    .contentShape(Rectangle())
                    .gesture(magnify(size), including: .all)
                    .simultaneousGesture(drag(size), including: zoom > 1.01 ? .all : .subviews)
                    .gesture(SpatialTapGesture(count: 2).onEnded { e in zoomAt(e.location, by: 2, size) }
                        .exclusively(before: SpatialTapGesture().onEnded { e in
                            let p = v.unproject(e.location)
                            withAnimation(.snappy) { pick = (p.lat, p.lon) }
                        }))
                    zoomButtons.padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .allowsHitTesting(true)
                }
            }
            .frame(height: 380)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("zonemap")
            .background(Theme.water)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.line))
            readout
            legend
            #if DEBUG
            Color.clear.frame(width: 1, height: 1)   // UI tests read the zoom here
                .accessibilityElement()
                .accessibilityIdentifier("mapzoom")
                .accessibilityValue(String(format: "zoom %.2f", zoom))
            #endif
        }
        .panel()
        .onAppear { pulse = true }
        // Follow the spot: after a GPS fix or a town pick, a zoomed-in map stayed
        // parked wherever you'd left it (east coast, in Jason's case).
        .onChange(of: "\(spot.lat),\(spot.lon)") { _, _ in
            pick = nil
            if zoom > 1.01 { withAnimation(.snappy) { center = spotKm } }
        }
    }

    // MARK: view transform: screen = km * s + t

    struct ViewXf {
        let s: CGFloat, tx: CGFloat, ty: CGFloat, zoom: CGFloat, size: CGSize
        var affine: CGAffineTransform { CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: tx, ty: ty) }
        func point(lat: Double, lon: Double) -> CGPoint {
            CGPoint(x: MapGeometry.px(lon) * s + tx, y: MapGeometry.py(lat) * s + ty)
        }
        func unproject(_ p: CGPoint) -> (lat: Double, lon: Double) {
            MapGeometry.unproject(x: (p.x - tx) / s, y: (p.y - ty) / s)
        }
    }

    private func fitScale(_ size: CGSize) -> CGFloat {
        let b = Self.geo.bounds
        return min(size.width / (b.width * 1.06), size.height / (b.height * 1.06))
    }

    private func clamped(_ c: CGPoint) -> CGPoint {
        let b = Self.geo.bounds
        return CGPoint(x: min(b.maxX, max(b.minX, c.x)), y: min(b.maxY, max(b.minY, c.y)))
    }

    private func view(_ size: CGSize) -> ViewXf {
        let s0 = fitScale(size), s = s0 * zoom
        let c = zoom <= 1.001 ? CGPoint(x: Self.geo.bounds.midX, y: Self.geo.bounds.midY) : clamped(center ?? CGPoint(x: Self.geo.bounds.midX, y: Self.geo.bounds.midY))
        return ViewXf(s: s, tx: size.width / 2 - c.x * s, ty: size.height / 2 - c.y * s, zoom: zoom, size: size)
    }

    private func currentCenter(_ size: CGSize) -> CGPoint {
        let v = view(size)
        return CGPoint(x: (size.width / 2 - v.tx) / v.s, y: (size.height / 2 - v.ty) / v.s)
    }

    /// Zoom by f keeping the km point under `at` where it is.
    private func zoomAt(_ at: CGPoint, by f: CGFloat, _ size: CGSize, from base: (zoom: CGFloat, center: CGPoint)? = nil) {
        let s0 = fitScale(size)
        let z0 = base?.zoom ?? zoom
        let c0 = base?.center ?? currentCenter(size)
        let s = s0 * z0
        let k = CGPoint(x: (at.x - size.width / 2) / s + c0.x, y: (at.y - size.height / 2) / s + c0.y)
        let z = min(Self.zmax, max(1, z0 * f))
        let s2 = s0 * z
        let c = CGPoint(x: k.x - (at.x - size.width / 2) / s2, y: k.y - (at.y - size.height / 2) / s2)
        if base == nil {
            withAnimation(.snappy) { zoom = z; center = clamped(c) }
        } else { zoom = z; center = clamped(c) }
    }

    private func magnify(_ size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { g in
                if pinchStart == nil { pinchStart = (zoom, currentCenter(size)); interacting = true }
                zoomAt(g.startLocation, by: g.magnification, size, from: pinchStart)
            }
            .onEnded { _ in pinchStart = nil; interacting = false }
    }

    private func drag(_ size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { g in
                guard zoom > 1.01 else { return }
                if dragStart == nil { dragStart = currentCenter(size); interacting = true }
                let s = fitScale(size) * zoom
                center = clamped(CGPoint(x: dragStart!.x - g.translation.width / s, y: dragStart!.y - g.translation.height / s))
            }
            .onEnded { _ in dragStart = nil; interacting = false }
    }

    private var zoomButtons: some View {
        VStack(spacing: 6) {
            mapButton("plus", id: "Zoom in") { zoom = min(Self.zmax, zoom * 1.8); if center == nil { center = spotKm } }
            mapButton("minus", id: "Zoom out") { zoom = max(1, zoom / 1.8) }
            mapButton("location.fill", id: "Center on your spot") { zoom = max(zoom, 4); center = spotKm }
            if zoom > 1.01 { mapButton("arrow.down.right.and.arrow.up.left", id: "Whole state") { zoom = 1; center = nil } }
        }
    }

    private var spotKm: CGPoint { CGPoint(x: MapGeometry.px(spot.lon), y: MapGeometry.py(spot.lat)) }

    private func mapButton(_ icon: String, id: String, _ act: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { act() } } label: {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
                .frame(width: 34, height: 34)
                .foregroundStyle(Theme.bone)
                .background(Theme.night.opacity(0.85), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(id)
    }

    // MARK: drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ v: ViewXf) {
        let g = Self.geo, t = v.affine
        let wi = g.wi.applying(t)
        let nb = g.neighbors.applying(t)
        ctx.fill(nb, with: .color(Theme.neighbor))
        ctx.stroke(nb, with: .color(Theme.neighborEdge), lineWidth: 1)
        if layer != .hours {
            let ow = g.openWater.applying(t)
            ctx.fill(ow, with: .color(Theme.openWater))
            ctx.stroke(ow, with: .color(Theme.openWaterEdge), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        ctx.fill(wi, with: .color(Theme.land))

        if layer != .duck {
            ctx.drawLayer { c in
                c.clip(to: wi)
                if layer == .hours {
                    for (i, band) in g.bands.enumerated() {
                        c.fill(Path(band).applying(t), with: .color(Theme.mallard.opacity(0.03 + 0.04 * Double(i))))
                    }
                }
                c.stroke(g.meridians.applying(t), with: .color(Theme.mallard.opacity(layer == .both ? 0.9 : 0.7)),
                         style: StrokeStyle(lineWidth: layer == .both ? 1.4 : 1.2, dash: [5, 4]))
            }
        }
        if layer != .hours {
            ctx.fill(wi, with: .color(Theme.duckSouth))
            ctx.drawLayer { c in
                c.clip(to: g.northClip.applying(t))
                c.fill(wi, with: .color(Theme.duckNorth))
            }
        }
        ctx.stroke(wi, with: .color(Theme.county), lineWidth: 0.7)
        if layer != .duck {
            ctx.stroke(g.areaLine.applying(t), with: .color(Theme.lantern), lineWidth: 2.2)
        }
        if layer != .hours {
            let dl = g.duckLine.applying(t)
            ctx.stroke(dl, with: .color(Theme.night), style: StrokeStyle(lineWidth: 5, lineJoin: .round))
            ctx.stroke(dl, with: .color(Theme.bone), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
        }
        if let pick {
            let q = v.point(lat: pick.lat, lon: pick.lon)
            var cross = Path()
            cross.move(to: CGPoint(x: q.x - 9, y: q.y)); cross.addLine(to: CGPoint(x: q.x - 3, y: q.y))
            cross.move(to: CGPoint(x: q.x + 3, y: q.y)); cross.addLine(to: CGPoint(x: q.x + 9, y: q.y))
            cross.move(to: CGPoint(x: q.x, y: q.y - 9)); cross.addLine(to: CGPoint(x: q.x, y: q.y - 3))
            cross.move(to: CGPoint(x: q.x, y: q.y + 3)); cross.addLine(to: CGPoint(x: q.x, y: q.y + 9))
            ctx.stroke(cross, with: .color(Theme.bone), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: q.x - 2.5, y: q.y - 2.5, width: 5, height: 5)), with: .color(Theme.bone))
        }
        drawLabels(&ctx, v)
    }

    /// Labels in screen pixels, first come first served so they never overlap
    /// (the web page's `room()` logic).
    private func drawLabels(_ ctx: inout GraphicsContext, _ v: ViewXf) {
        var placed: [CGRect] = [CGRect(x: v.size.width - 48, y: v.size.height - 170, width: 48, height: 170)]
        let me = MapLookup.at(spot.lat, spot.lon)
        let myZone = LongitudeZone.at(lon: spot.lon).id
        let myDuck = me.duck?.zone
        let myArea = spot.areaOverride ?? me.w.area
        let busy = interacting
        let p = v.point(lat: spot.lat, lon: spot.lon)
        placed.append(CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20))

        func label(_ s: String, _ at: CGPoint, size: CGFloat, color: Color, anchor: UnitPoint = .center,
                   pixel: Bool = false, bold: Bool = false, kern: CGFloat = 0, halo: Bool = true) -> Bool {
            let w = CGFloat(s.count) * size * (pixel ? 0.78 : 0.62) + 4 + CGFloat(s.count) * kern, h = size + 4
            let x = anchor == .leading ? at.x - 2 : anchor == .trailing ? at.x - w + 2 : at.x - w / 2
            let r = CGRect(x: x, y: at.y - h / 2, width: w, height: h)
            guard r.minX > 2, r.minY > 2, r.maxX < v.size.width - 2, r.maxY < v.size.height - 2,
                  !placed.contains(where: { $0.intersects(r) }) else { return false }
            placed.append(r)
            let font: Font = pixel ? .pixel(size, bold: bold) : .mono(size, bold ? .bold : .regular)
            if halo {   // laid out once, stamped four times
                let shadow = ctx.resolve(Text(s).font(font).kerning(kern).foregroundStyle(Theme.night))
                for d in [CGSize(width: -1, height: 0), CGSize(width: 1, height: 0), CGSize(width: 0, height: -1), CGSize(width: 0, height: 1)] {
                    ctx.draw(shadow, at: CGPoint(x: at.x + d.width, y: at.y + d.height), anchor: anchor)
                }
            }
            ctx.draw(ctx.resolve(Text(s).font(font).kerning(kern).foregroundStyle(color)), at: at, anchor: anchor)
            return true
        }

        // you
        let name = spot.name ?? "you"
        _ = label(name, CGPoint(x: p.x + 11, y: p.y), size: 12, color: Theme.lantern, anchor: .leading, bold: true)
            || label(name, CGPoint(x: p.x - 11, y: p.y), size: 12, color: Theme.lantern, anchor: .trailing, bold: true)
            || label(name, CGPoint(x: p.x, y: p.y - 14), size: 12, color: Theme.lantern, bold: true)

        // zone headlines pinned to the top edge
        if layer != .duck {
            for (k, b) in MapGeometry.bandLons.enumerated() {
                let x0 = max(4, MapGeometry.px(b.1) * v.s + v.tx), x1 = min(v.size.width - 4, MapGeometry.px(b.0) * v.s + v.tx)
                guard x1 - x0 >= 34 else { continue }
                let z = LongitudeZone.all[k]
                _ = label("\(z.id) +\(z.minutes)", CGPoint(x: (x0 + x1) / 2, y: 14), size: 12,
                          color: z.id == myZone ? Theme.lantern : Theme.mallard, bold: true)
            }
        }

        // big area labels: the first candidate spot with room wins
        typealias Big = (String, Bool, [(Double, Double)], String?)
        let big: [Big] = layer != .hours ? [
            ("NORTHERN ZONE", myDuck == .north, [(45.75, -90.25), (46.1, -89.5)], nil),
            ("SOUTHERN ZONE", myDuck == .south, [(43.35, -89.85), (42.85, -90.6), (43.7, -88.9)], nil),
            ("OPEN WATER", myDuck == .open, [(43.75, -87.35), (44.3, -87.25)], nil),
        ] : [
            ("NORTHERN TABLE", myArea == .north, [(45.95, -90.3), (46.2, -89.6)], "Powers, MI times"),
            ("SOUTHERN TABLE", myArea == .south, [(43.3, -90.45), (42.85, -90.6), (43.65, -88.95)], "Sheboygan times"),
        ]
        for b in big {
            for c in b.2 {
                let q = v.point(lat: c.0, lon: c.1)
                let water = b.0 == "OPEN WATER"
                let col = b.1 ? Theme.lantern : water ? Color(hex: 0x8fc0f0) : Theme.bone
                if label(b.0, q, size: v.zoom < 2 ? 11 : 12, color: col, bold: true, kern: 1.5) {
                    if let sub = b.3, v.zoom < 2.2 { _ = label(sub, CGPoint(x: q.x, y: q.y + 15), size: 10, color: Theme.reed) }
                    break
                }
            }
        }
        if layer != .hours {
            for (pt, n) in [(Self.geo.shield10, "10"), (Self.geo.shield41, "41")] {
                let q = v.point(lat: pt.y, lon: pt.x)
                let r = CGRect(x: q.x - 11, y: q.y - 9, width: 22, height: 18)
                if !placed.contains(where: { $0.intersects(r) }) {
                    placed.append(r)
                    ctx.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(Theme.bone))
                    ctx.stroke(Path(roundedRect: r, cornerRadius: 4), with: .color(Theme.night), lineWidth: 1.5)
                    ctx.draw(Text(n).font(.mono(11, .bold)).foregroundStyle(Theme.ink), at: q)
                }
            }
        }
        if busy { return }
        for (lat, lon, n) in [(46.95, -90.2, "LAKE SUPERIOR"), (43.05, -87.35, "LAKE MICHIGAN"), (45.05, -87.55, "GREEN BAY")] {
            if layer != .hours && n == "LAKE MICHIGAN" { continue }
            _ = label(n, v.point(lat: lat, lon: lon), size: 10, color: Theme.waterLabel, kern: 1.5, halo: false)
        }
        if v.zoom < 3 {
            for (lat, lon, n) in [(46.1, -93.2, "MN"), (43.15, -91.75, "IA"), (42.3, -89.6, "IL"), (46.15, -88.15, "MI")] {
                _ = label(n, v.point(lat: lat, lon: lon), size: 11, color: Theme.stateLabel, kern: 2, halo: false)
            }
        }
        if v.zoom >= 1.8 {
            for t in Bundled.geo.places where t.seat || v.zoom >= 3.5 {
                let q = v.point(lat: t.lat, lon: t.lon)
                guard q.x > 0, q.x < v.size.width, q.y > 0, q.y < v.size.height else { continue }
                let ok = label(t.name, CGPoint(x: q.x + 5, y: q.y), size: 11, color: Theme.reed, anchor: .leading)
                    || label(t.name, CGPoint(x: q.x - 5, y: q.y), size: 11, color: Theme.reed, anchor: .trailing)
                    || label(t.name, CGPoint(x: q.x, y: q.y - 9), size: 11, color: Theme.reed)
                if ok || v.zoom >= 2.6 {
                    ctx.fill(Path(ellipseIn: CGRect(x: q.x - 2.2, y: q.y - 2.2, width: 4.4, height: 4.4)), with: .color(Theme.reed))
                }
            }
        }
        if v.zoom >= 2.6 {
            for c in Bundled.map.countyLabels {
                let q = v.point(lat: c.lat, lon: c.lon)
                guard q.x > -50, q.x < v.size.width + 50, q.y > -20, q.y < v.size.height + 20 else { continue }
                _ = label(c.name.uppercased(), q, size: 10, color: Theme.countyLabel, kern: 1, halo: false)
            }
        }
    }

    /// Your dot, with the web page's pulse ring (a real view, so it animates
    /// without redrawing the whole map).
    private func me(_ v: ViewXf) -> some View {
        let p = v.point(lat: spot.lat, lon: spot.lon)
        return ZStack {
            Circle().stroke(Theme.lantern, lineWidth: 2)
                .frame(width: 14, height: 14)
                .scaleEffect(pulse ? 2.6 : 1).opacity(pulse ? 0 : 0.9)
                .animation(.easeOut(duration: 2).repeatForever(autoreverses: false), value: pulse)
            Circle().fill(Theme.lantern).frame(width: 12, height: 12)
                .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
        }
        .position(p)
        .allowsHitTesting(false)
    }

    // MARK: readout

    private var readout: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let pick {
                describe(lat: pick.lat, lon: pick.lon, prefix: String(format: "%.4f, %.4f: ", pick.lat, pick.lon))
                HStack(spacing: 8) {
                    Button { useSpot(pick.lat, pick.lon); withAnimation { self.pick = nil } } label: {
                        Text("Use this spot").font(.mono(13, .bold)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.mallard, in: RoundedRectangle(cornerRadius: 7))
                    }
                    Button { withAnimation { self.pick = nil } } label: {
                        Text("Clear").font(.mono(13)).foregroundStyle(Theme.bone)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.line))
                    }
                }
                .buttonStyle(.plain)
            } else {
                describe(lat: spot.lat, lon: spot.lon, prefix: "You: ")
            }
        }
    }

    private func describe(lat: Double, lon: Double, prefix: String) -> some View {
        let a = MapLookup.at(lat, lon)
        let w = a.w
        let z = LongitudeZone.at(lon: lon)
        let d = a.duck
        var t = Text(prefix).foregroundStyle(Theme.reed)
        if !w.inside && d == nil {
            t = t + Text("Outside Wisconsin.").foregroundStyle(Theme.lantern)
        } else {
            if let c = w.county { t = t + Text("\(c) Co.").bold().foregroundStyle(Theme.bone) + Text(" · ").foregroundStyle(Theme.reed) }
            t = t + Text("Zone ").foregroundStyle(Theme.reed) + Text(z.id).bold().foregroundStyle(Theme.bone)
                + Text(" (+\(z.minutes) min), \(w.area.rawValue)ern table").foregroundStyle(Theme.reed)
            if let d { t = t + Text(" · ").foregroundStyle(Theme.reed) + Text(d.zone.name).bold().foregroundStyle(Theme.bone) + Text(" duck zone").foregroundStyle(Theme.reed) }
        }
        return VStack(alignment: .leading, spacing: 4) {
            t.font(.mono(12))
            if d?.zone == .open {
                Text("Open Water starts 500 ft off the mainland shore, rooted vegetation included. Closer in is the southern zone.")
                    .font(.mono(11)).foregroundStyle(Theme.comment)
            } else if let km = d?.km, km < 1.5 {
                Text("Within \(km < 0.1 ? "100 m" : String(format: "%.1f km", km)) of the US 10 / US 41 line: check which side of the highway you're on.")
                    .font(.mono(11)).foregroundStyle(Theme.lantern)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            switch layer {
            case .hours:
                swatch(Theme.mallard.opacity(0.4), "zones A–F, +4 min per degree west")
                line(Theme.lantern, "table line")
            case .duck, .both:
                swatch(Theme.duckNorth, "northern"); swatch(Theme.duckSouth, "southern"); swatch(Theme.openWater, "open water")
            }
        }
        .font(.mono(10)).foregroundStyle(Theme.reed)
        .lineLimit(1).minimumScaleFactor(0.7)
    }
    private func swatch(_ c: Color, _ s: String) -> some View {
        HStack(spacing: 5) { RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 10, height: 10); Text(s) }
    }
    private func line(_ c: Color, _ s: String) -> some View {
        HStack(spacing: 5) { Rectangle().fill(c).frame(width: 14, height: 2.5); Text(s) }
    }
}

/// The segmented control from the web page: marsh-line track, lantern selection.
struct LayerPicker: View {
    let selection: ZoneMap.Layer
    let pick: (ZoneMap.Layer) -> Void
    var body: some View {
        Segmented(items: ZoneMap.Layer.allCases.map { ($0.rawValue, $0.label) }, selected: selection.rawValue) {
            pick(ZoneMap.Layer(rawValue: $0)!)
        }
    }
}

struct Segmented: View {
    let items: [(id: String, label: String)]
    let selected: String
    let pick: (String) -> Void
    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.id) { it in
                let on = it.id == selected
                Button { pick(it.id) } label: {
                    Text(it.label)
                        .font(.mono(13, on ? .bold : .regular))
                        .foregroundStyle(on ? Theme.ink : Theme.reed)
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(on ? Theme.lantern : Theme.night, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Theme.line, in: RoundedRectangle(cornerRadius: 8))
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// Static geometry in kilometres, built once.
final class MapGeometry {
    static let shared = MapGeometry()

    static let lat0 = 44.75, lon0 = -89.85, ky = 111.32
    static let kx = ky * cos(lat0 * .pi / 180)
    static func px(_ lon: Double) -> CGFloat { CGFloat((lon - lon0) * kx) }
    static func py(_ lat: Double) -> CGFloat { CGFloat((lat0 - lat) * ky) }
    static func unproject(x: CGFloat, y: CGFloat) -> (lat: Double, lon: Double) { (lat0 - Double(y) / ky, Double(x) / kx + lon0) }
    /// (east, west) longitude edges of zones A…F.
    static let bandLons: [(Double, Double)] = [(-86.0, -88), (-88, -89), (-89, -90), (-90, -91), (-91, -92), (-92, -93.8)]

    let wi: Path, neighbors: Path, openWater: Path, northClip: Path, duckLine: Path, areaLine: Path, meridians: Path
    let bands: [CGRect]
    let bounds: CGRect
    let shield10: CGPoint, shield41: CGPoint   // (lon, lat)

    private static func ring(_ r: Ring, into p: inout Path, close: Bool = true) {
        for (i, v) in r.enumerated() {
            let pt = CGPoint(x: px(v[0]), y: py(v[1]))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        if close { p.closeSubpath() }
    }
    private static func polys(_ ps: [[Ring]]) -> Path {
        var p = Path()
        for poly in ps { for r in poly { ring(r, into: &p) } }
        return p
    }

    init() {
        let geo = Bundled.geo, md = Bundled.map, ducks = Bundled.ducks
        wi = Self.polys(geo.counties.flatMap { $0.polys })
        neighbors = Self.polys(md.neighbors.flatMap { $0 })
        openWater = Self.polys(ducks.openWater)
        let L = ducks.duckLine
        var nc = Path(); Self.ring(L + [[L[L.count - 1][0], 48], [-94, 48], [-94, L[0][1]]], into: &nc); northClip = nc
        var dl = Path(); Self.ring(L, into: &dl, close: false); duckLine = dl
        var al = Path(); for l in md.areaLine { Self.ring(l, into: &al, close: false) }; areaLine = al
        let yTop = Self.py(47.6), yBot = Self.py(42.0)
        bands = Self.bandLons.map { b in CGRect(x: Self.px(b.1), y: yTop, width: Self.px(b.0) - Self.px(b.1), height: yBot - yTop) }
        var m = Path()
        for lon in [-88.0, -89, -90, -91, -92] { m.move(to: CGPoint(x: Self.px(lon), y: yTop)); m.addLine(to: CGPoint(x: Self.px(lon), y: yBot)) }
        meridians = m
        var outer = Path(); for c in geo.counties { for poly in c.polys { Self.ring(poly[0], into: &outer) } }
        bounds = outer.boundingRect
        let near10 = L.min { abs($0[0] + 91.25) < abs($1[0] + 91.25) }!
        let near41 = L.filter { $0[0] > -88.3 }.min { abs($0[1] - 44.72) < abs($1[1] - 44.72) }!
        shield10 = CGPoint(x: near10[0], y: near10[1]); shield41 = CGPoint(x: near41[0], y: near41[1])
    }
}

/// County, area and duck zone for a point, memoised. The map's body and canvas
/// run on every pinch frame, and these scan every county outline and the
/// whole duck line; the answers only change when the point does.
enum MapLookup {
    struct Answer { let w: Locate.Where; let duck: (zone: Locate.DuckZone, km: Double?)? }
    nonisolated(unsafe) private static var cache: [String: Answer] = [:]

    static func at(_ lat: Double, _ lon: Double) -> Answer {
        let key = "\(lat),\(lon)"
        if let a = cache[key] { return a }
        let w = Locate.county(lat: lat, lon: lon)
        let a = Answer(w: w, duck: Locate.duckZone(lat: lat, lon: lon, where: w))
        if cache.count > 64 { cache.removeAll() }
        cache[key] = a
        return a
    }
}
