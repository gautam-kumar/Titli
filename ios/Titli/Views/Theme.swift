import SwiftUI
import TitliCore

enum Theme {
    static let ink = Color(hex: 0x101014)
    static let paper = Color(hex: 0xF2F1F5)
    static let pink = Color(hex: 0xFF4FA3)
    static let violet = Color(hex: 0x7B61FF)
    static let cyan = Color(hex: 0x00C2FF)
    static let amber = Color(hex: 0xFFB547)
    static let line = Color(hex: 0x0A0A0B).opacity(0.08)
    static let mute = Color(hex: 0x0A0A0B).opacity(0.5)
    static let aurora = LinearGradient(stops: [.init(color: cyan, location: 0), .init(color: violet, location: 0.4), .init(color: pink, location: 0.7), .init(color: amber, location: 1)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
    static let shadow = Color(red: 90 / 255, green: 60 / 255, blue: 160 / 255)

    static func glow(_ k: Memory.Kind) -> Color {
        switch k { case .give: pink; case .take, .note: cyan; case .doc, .remind: violet }
    }
    static func pearl(_ k: Memory.Kind) -> String {
        switch k { case .give: "pPink"; case .take, .note: "pCyan"; case .doc, .remind: "pViolet" }
    }
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
