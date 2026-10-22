import SwiftUI
import TitliCore

/// A colour theme. Each keeps the same four roles: c1 leads (money given, the main glow),
/// c2 is the deep partner (documents, reminders), c3 the cool highlight, c4 the warm spark.
/// Same values as themes.js on the web.
struct Palette: Equatable, Identifiable {
    let id: String, name: String, mood: String
    let c1: Int, c2: Int, c3: Int, c4: Int, deep: Int, give: Int, bg: Int, card: Int, shadow: Int
    let wing: [Int], body: Int, rim: Int, hemi: Int, note: Int

    static let neel = Palette(id: "neel", name: "Neel", mood: "Neela, shaant", c1: 0x2F6BFF, c2: 0x3341C7, c3: 0x14C8B4, c4: 0xFFB547, deep: 0x3341C7, give: 0x2F6BFF, bg: 0xEFF2F6, card: 0xEAF0F7, shadow: 0x1E3C78,
                              wing: [0x14215E, 0x2F6BFF, 0x9EF0E0], body: 0x0E1633, rim: 0xCFE3FF, hemi: 0xD4E0F5, note: 0x5C8BFF)
    static let kesar = Palette(id: "kesar", name: "Kesar", mood: "Kesariya, garam", c1: 0xF2762E, c2: 0x0F7C78, c3: 0x2BB3A3, c4: 0xF5C04A, deep: 0x0F7C78, give: 0xD9601C, bg: 0xF5F1EC, card: 0xF6F0E8, shadow: 0x6E461E,
                               wing: [0x0B3B3A, 0x13968F, 0xFFD98A], body: 0x1F1A14, rim: 0xFFE1C4, hemi: 0xF3E4D2, note: 0x3FB8A8)
    static let mor = Palette(id: "mor", name: "Mor", mood: "Mor pankh, taaza", c1: 0x0E9F8E, c2: 0x155E9C, c3: 0x38BDF8, c4: 0xF4B740, deep: 0x155E9C, give: 0x0B8577, bg: 0xEEF3F3, card: 0xEBF3F3, shadow: 0x14465A,
                             wing: [0x0B2E4F, 0x1F7BC4, 0xB8F5E6], body: 0x0B1E2E, rim: 0xC9F2EA, hemi: 0xD2E6EE, note: 0x3AA9D6)
    static let gulaal = Palette(id: "gulaal", name: "Gulaal", mood: "Holi ke rang", c1: 0xFF4FA3, c2: 0x7B61FF, c3: 0x00C2FF, c4: 0xFFB547, deep: 0x6A55D8, give: 0xE0336F, bg: 0xF2F1F5, card: 0xF1ECF7, shadow: 0x5A3CA0,
                                wing: [0x3B1FA8, 0x5B6BFF, 0xFFD27A], body: 0x1B1233, rim: 0xFFC6EF, hemi: 0xD9CCFF, note: 0x9D8BFF)
    static let all = [neel, kesar, mor, gulaal]
    static let storageKey = "theme"
    /// The theme in use. Views rebuild (via `.id`) whenever it changes.
    static var active = named(UserDefaults.standard.string(forKey: storageKey))
    static func named(_ id: String?) -> Palette { all.first { $0.id == id } ?? neel }
}

enum Theme {
    static let ink = Color(hex: 0x101014)
    static var p: Palette { Palette.active }
    static var paper: Color { Color(hex: p.bg) }
    static var card: Color { Color(hex: p.card) }
    static var pink: Color { Color(hex: p.c1) }
    static var violet: Color { Color(hex: p.c2) }
    static var cyan: Color { Color(hex: p.c3) }
    static var amber: Color { Color(hex: p.c4) }
    static var deep: Color { Color(hex: p.deep) }
    static var give: Color { Color(hex: p.give) }
    static let line = Color(hex: 0x0A0A0B).opacity(0.08)
    static let mute = Color(hex: 0x0A0A0B).opacity(0.5)
    static var aurora: LinearGradient { LinearGradient(stops: [.init(color: cyan, location: 0), .init(color: violet, location: 0.4), .init(color: pink, location: 0.7), .init(color: amber, location: 1)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var shadow: Color { Color(hex: p.shadow) }

    static func glow(_ k: Memory.Kind) -> Color {
        switch k { case .give: pink; case .take, .note: cyan; case .doc, .remind: violet }
    }
    static func pearl(_ k: Memory.Kind) -> String {
        switch k { case .give: img("pPink"); case .take, .note: img("pCyan"); case .doc, .remind: img("pViolet") }
    }
    /// Tile objects are pre-rendered per theme; Gulaal uses the originals and the diya keeps its own colour.
    static func img(_ name: String) -> String { p.id == "gulaal" || name == "diya" ? name : "\(name)-\(p.id)" }
}

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: opacity)
    }
}

extension Font {
    enum SoraWeight: String { case extraLight = "ExtraLight", regular = "Regular", medium = "Medium" }
    enum JakartaWeight: String { case medium = "Medium", semibold = "SemiBold", bold = "Bold", extraBold = "ExtraBold" }
    static func sora(_ size: CGFloat, _ w: SoraWeight = .regular) -> Font { .custom("Sora-\(w.rawValue)", size: size) }
    static func jakarta(_ size: CGFloat, _ w: JakartaWeight = .semibold) -> Font { .custom("PlusJakartaSans-\(w.rawValue)", size: size) }
}

/// Soft aurora light behind the glass tiles.
struct Aura: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                Theme.paper
                Circle().fill(Theme.pink.opacity(0.3)).frame(width: 300, height: 300).position(x: 60, y: g.size.height * 0.55 + 150)
                Circle().fill(Theme.violet.opacity(0.3)).frame(width: 280, height: 280).position(x: g.size.width - 60, y: g.size.height * 0.64 + 140)
                Circle().fill(Theme.cyan.opacity(0.22)).frame(width: 240, height: 240).position(x: g.size.width * 0.15 + 120, y: g.size.height * 0.82 + 120)
            }
            .blur(radius: 60)
        }
        .ignoresSafeArea()
    }
}

/// Frosted glass tile with a coloured glow in its corner, matching the web .gt tile.
struct GlassTile<Content: View>: View {
    var glow: Color
    var minHeight: CGFloat = 132
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    LinearGradient(colors: [.white.opacity(0.82), .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    GeometryReader { g in
                        Circle()
                            .fill(RadialGradient(colors: [glow, glow.opacity(0)], center: .center, startRadius: 0, endRadius: 75))
                            .frame(width: 220, height: 220)
                            .opacity(0.55)
                            .position(x: g.size.width + 20, y: g.size.height + 0)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.95), lineWidth: 1))
            .shadow(color: Theme.shadow.opacity(0.3), radius: 20, y: 18)
    }
}

struct Label12: View {
    var text: String
    var color: Color = Theme.mute
    var body: some View { Text(text).font(.jakarta(12, .semibold)).foregroundStyle(color) }
}
