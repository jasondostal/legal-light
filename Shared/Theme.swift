import SwiftUI
import HoursCore

/// ducktyping.dev's design system, carried over: a duck blind at dusk.
/// Marsh-night ground, mallard-green + lantern-amber accents, Silkscreen pixel
/// labels over JetBrains Mono. Dark-only by design: it's a night scene.
/// Shared by the app and the widget extension.
enum Theme {
    static let night = Color(hex: 0x081210)   // --marsh-night
    static let panel = Color(hex: 0x0d1a16)   // --marsh-panel
    static let line = Color(hex: 0x1c312a)    // --marsh-line
    static let mallard = Color(hex: 0x2bd98e)
    static let mallardDim = Color(hex: 0x178a59)
    static let lantern = Color(hex: 0xffb454)
    static let lanternSoft = Color(hex: 0xffd08a)
    static let bone = Color(hex: 0xd8e7de)
    static let reed = Color(hex: 0x7e978a)
    static let rust = Color(hex: 0xe0823d)
    static let sky = Color(hex: 0x6cc7ff)
    static let comment = Color(hex: 0x587a6b)
    static let ink = Color(hex: 0x04100c)     // text on mallard/lantern

    // the day bar
    static let dayFill = Color(hex: 0x2a4a3c)
    static let twilight = Color(hex: 0x17302a)
    static let darkFill = Color(hex: 0x0a1512)

    // the map
    static let water = Color(hex: 0x0a1a24)
    static let neighbor = Color(hex: 0x0e1915)
    static let neighborEdge = Color(hex: 0x1f342c)
    static let land = Color(hex: 0x11211b)
    static let county = Color(hex: 0x2c463b)
    static let duckNorth = Color(hex: 0x2bd98e).opacity(0.2)
    static let duckSouth = Color(hex: 0xffb454).opacity(0.16)
    static let openWater = Color(red: 96 / 255, green: 170 / 255, blue: 1).opacity(0.26)
    static let openWaterEdge = Color(hex: 0x5f9fe6)
    static let waterLabel = Color(hex: 0x6f9cc4)
    static let stateLabel = Color(hex: 0x3e5a4e)
    static let countyLabel = Color(hex: 0x4d6d5f)

    /// Same colour logic as the web page: waiting is lantern, legal is mallard,
    /// done is reed.
    static func color(_ s: HoursStatus.State) -> Color {
        switch s { case .before: return lantern; case .open: return mallard; case .after: return reed }
    }
    static func countColor(_ s: HoursStatus.State) -> Color {
        switch s { case .before: return bone; case .open: return mallard; case .after: return reed }
    }
    static func headline(_ s: HoursStatus.State) -> String {
        switch s {
        case .before: return "until legal light"
        case .open: return "of legal light left"
        case .after: return "until tomorrow's light"
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

extension Font {
    /// Silkscreen, the pixel display face (section heads, labels).
    static func pixel(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Silkscreen-Bold" : "Silkscreen-Regular", size: size)
    }
    /// JetBrains Mono, everything else.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("JetBrains Mono", size: size).weight(weight)
    }
}

/// "6:14" + small "a.m.", the way the web page sets big times.
struct BigTime: View {
    let date: Date
    var size: CGFloat = 34
    var color: Color = Theme.bone
    var body: some View {
        let s = Fmt.time(date)
        let parts = s.split(separator: " ", maxSplits: 1).map(String.init)
        HStack(alignment: .firstTextBaseline, spacing: size * 0.18) {
            Text(parts[0]).font(.mono(size, .bold)).kerning(-1).foregroundStyle(color)
            if parts.count > 1 { Text(parts[1]).font(.mono(size * 0.42)).foregroundStyle(Theme.reed) }
        }
        .monospacedDigit()
    }
}

/// A pixel-font section head: "THIS WEEK".
struct SectionHead: View {
    let text: String
    var color: Color = Theme.lantern
    var body: some View {
        Text(text.uppercased()).font(.pixel(10)).kerning(1).foregroundStyle(color)
    }
}

extension View {
    /// The bordered marsh panel every block sits in.
    func panel(padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.line))
    }
}
