import SceneKit
import SwiftUI
import TitliCore

/// The hero card: the live titli on a soft pearl card, with tags for the two newest memories.
struct HeroCard: View {
    var memories: [Memory]
    var mode: HeroMode
    var focus: Memory?
    var capLeft: String
    var capRight: String
    @State private var tagPoints: [CGPoint] = []

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                HeroSceneView(memories: memories, mode: mode, focus: focus) { tagPoints = $0 }
                HStack {
                    Text(capLeft)
                    Spacer()
                    Text(capRight)
                }
                .font(.jakarta(12, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.5))
                .padding(.horizontal, 18).padding(.top, 14)
                if mode == .home {
                    ForEach(Array(zip(tagPoints, memories.prefix(2)).enumerated()), id: \.offset) { i, pair in
                        HeroTag(title: pair.1.title, sub: pair.1.sub)
                            .alignmentGuide(.leading) { d in -min(max(8, pair.0.x + 18), geo.size.width - d.width - 8) }
                            .alignmentGuide(.top) { d in -min(max(30, pair.0.y - d.height / 2 + (i == 0 ? 34 : -30)), geo.size.height - d.height - 8) }
                            .transition(.opacity)
                    }
                }
            }
        }
        .background(LinearGradient(colors: [Color(hex: 0xFBFAF7), Theme.card], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.35), radius: 20, y: 18)
        .animation(.easeInOut(duration: 0.3), value: mode)
    }
}

struct HeroTag: View {
    var title: String
    var sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.jakarta(12, .bold)).foregroundStyle(Theme.ink)
            Text(sub).font(.jakarta(10.5, .semibold)).foregroundStyle(Theme.ink.opacity(0.5))
        }
        .lineLimit(1)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 8)
        .fixedSize()
    }
}

struct HeroSceneView: UIViewRepresentable {
    var memories: [Memory]
    var mode: HeroMode
    var focus: Memory?
    var onTags: ([CGPoint]) -> Void

    final class Coordinator { let hero = HeroScene(); var ids: [UUID] = []; var mode: HeroMode?; var focus: UUID? }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let v = ResizingSCNView(frame: .zero, options: nil)
        v.hero = context.coordinator.hero
        v.scene = context.coordinator.hero.scene
        v.delegate = context.coordinator.hero
        v.backgroundColor = .clear
        v.isOpaque = false
        v.antialiasingMode = .multisampling4X
        v.rendersContinuously = true
        v.preferredFramesPerSecond = 60
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        let c = context.coordinator
        c.hero.onTags = onTags
        let ids = memories.prefix(5).map(\.id)
        if ids != c.ids { c.ids = ids; c.hero.setMemories(memories) }
        if mode != c.mode || focus?.id != c.focus { c.mode = mode; c.focus = focus?.id; c.hero.setMode(mode, focus: focus) }
    }
}

private final class ResizingSCNView: SCNView {
    var hero: HeroScene?
    override func layoutSubviews() { super.layoutSubviews(); hero?.resize(bounds.size) }
}
