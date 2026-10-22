import SwiftUI
import TitliCore

/// A glass tile laid out like the web design: label at the top, a 3D object peeking in, content at the bottom.
struct ObjectTile<Bottom: View>: View {
    var glow: Color
    var label: String
    var labelColor: Color = Theme.mute
    var image: String?
    var imageWidth: CGFloat = 96
    /// Offset of the image from the tile's top-trailing corner (or bottom-trailing with `imageAtBottom`).
    var imageOffset: CGSize = .zero
    var imageAtBottom = false
    var height: CGFloat = 132
    @ViewBuilder var bottom: Bottom

    var body: some View {
        GlassTile(glow: glow, minHeight: height) {
            ZStack(alignment: .topLeading) {
                if let image {
                    Image(Theme.img(image)).resizable().scaledToFit().frame(width: imageWidth)
                        .offset(imageOffset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: imageAtBottom ? .bottomTrailing : .topTrailing)
                        .allowsHitTesting(false)
                }
                Label12(text: label, color: labelColor)
                bottom.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(height: height - 32)
        }
    }
}

struct HomeTiles: View {
    var memories: [Memory]
    var open: (Memory) -> Void
    var ask: (String) -> Void

    var body: some View {
        let given = memories.filter { $0.kind == .give }
        let out = given.reduce(0) { $0 + ($1.amount ?? 0) }
        let people = Set(given.compactMap(\.person)).count
        let next = memories.filter { $0.kind == .remind }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }.first
        let docs = memories.filter { $0.kind == .doc }
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { if let p = given.first?.person { ask("\(p) ko kitna diya?") } } label: {
                    ObjectTile(glow: Theme.pink, label: "Bahar hai", image: "ring", imageWidth: 96, imageOffset: CGSize(width: 10, height: -20)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Format.inr(out)).font(.jakarta(28, .extraBold)).tracking(-1.1).foregroundStyle(Theme.ink)
                            Text(people > 0 ? "\(people) log ke paas" : "Kisi ke paas nahi").font(.jakarta(12, .medium)).foregroundStyle(Theme.mute)
                        }
                    }
                }
                Button { if let next { open(next) } } label: {
                    ObjectTile(glow: Theme.violet, label: next?.sub ?? "Yaad dilana", labelColor: Theme.deep, image: "gas", imageWidth: 74, imageOffset: CGSize(width: 12, height: -10)) {
                        Text(next?.title ?? "“Kal 10 baje bijli bill bharna”")
                            .font(.jakarta(16, .extraBold)).tracking(-0.3).lineLimit(2)
                            .foregroundStyle(next == nil ? Theme.mute : Theme.ink)
                            .padding(.trailing, 30)
                    }
                }
            }
            HStack(spacing: 10) {
                Button { if let d = docs.first { open(d) } } label: {
                    ObjectTile(glow: Theme.cyan, label: "Kaagaz · \(docs.count)", image: "card", imageWidth: 160, imageOffset: CGSize(width: 14, height: 22), imageAtBottom: true) { EmptyView() }
                }
                GlassTile(glow: Theme.amber) {
                    VStack(alignment: .leading, spacing: 0) {
                        Label12(text: "Haal hi mein")
                        Spacer(minLength: 4)
                        ForEach(memories.prefix(3)) { m in
                            HStack(spacing: 8) {
                                Image(Theme.pearl(m.kind)).resizable().frame(width: 14, height: 14)
                                Text(m.person ?? m.doc ?? m.title).lineLimit(1).truncationMode(.tail)
                                Spacer(minLength: 4)
                                Text(value(m)).foregroundStyle(color(m)).lineLimit(1).fixedSize()
                            }
                            .font(.jakarta(12.5, .bold)).foregroundStyle(Theme.ink)
                            .frame(height: 23)
                        }
                    }
                    .frame(height: 100)
                }
            }
        }
        .buttonStyle(PressStyle())
    }

    private func value(_ m: Memory) -> String {
        if let a = m.amount, m.kind == .give || m.kind == .take { return (m.kind == .give ? "−" : "+") + Format.number(a) }
        return Format.short(m.dueDate ?? m.created)
    }
    private func color(_ m: Memory) -> Color {
        m.kind == .give ? Theme.give : m.kind == .take ? Color(hex: 0x1F8F8A) : Theme.mute
    }
}

/// What a single memory looks like once understood: who, how much, by when; or the document and where it is.
struct MemoryTiles: View {
    var memory: Memory

    var body: some View {
        let m = memory
        VStack(spacing: 10) {
            switch m.kind {
            case .give, .take:
                let who = (m.person ?? "").isEmpty ? "Kisi" : m.person!
                HStack(spacing: 10) {
                    ObjectTile(glow: Theme.glow(m.kind), label: m.kind == .give ? "Kisko" : "Kisse", height: 120) {
                        HStack(spacing: 10) {
                            ZStack {
                                Image(Theme.pearl(m.kind)).resizable().frame(width: 46, height: 46)
                                Text(String(who.prefix(1))).font(.jakarta(17, .extraBold)).foregroundStyle(.white).shadow(color: Color(red: 0.47, green: 0, blue: 0.23).opacity(0.4), radius: 2, y: 1)
                            }
                            Text(who).font(.jakarta(16, .extraBold)).tracking(-0.3).lineLimit(2).foregroundStyle(Theme.ink)
                        }
                    }
                    ObjectTile(glow: Theme.violet, label: "Kitna", image: "ring", imageWidth: 70, imageOffset: CGSize(width: 12, height: -12), height: 120) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Format.inr(m.amount ?? 0)).font(.jakarta(30, .extraBold)).tracking(-1.2).foregroundStyle(Theme.ink).minimumScaleFactor(0.6).lineLimit(1)
                            Text(m.kind == .give ? "Aapne diye" : "Aapko lautane hain").font(.jakarta(12, .medium)).foregroundStyle(Theme.mute)
                        }
                    }
                }
                if let due = m.due {
                    ObjectTile(glow: Theme.amber, label: "Kab tak", image: "diya", imageWidth: 130, imageOffset: CGSize(width: 8, height: -22)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(due + (m.dueDate.map { " · " + Format.short($0) } ?? "")).font(.jakarta(24, .extraBold)).tracking(-0.9).foregroundStyle(Theme.ink)
                            if let d = m.dueDate { Chip(text: "\(Format.short(d.addingTimeInterval(-86400))) ko yaad dilaungi") }
                        }
                    }
                }
            case .doc:
                ObjectTile(glow: Theme.violet, label: "Kaagaz", image: "card", imageWidth: 150, imageOffset: CGSize(width: 10, height: 30), imageAtBottom: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(m.doc ?? "Kaagaz").font(.jakarta(24, .extraBold)).tracking(-0.9).foregroundStyle(Theme.ink)
                        Chip(text: m.place ?? "Jagah nahi batayi")
                    }
                }
            case .remind:
                ObjectTile(glow: Theme.violet, label: m.sub, labelColor: Theme.deep, image: "gas", imageWidth: 84, imageOffset: CGSize(width: 6, height: -8)) {
                    Text((m.what ?? "").isEmpty ? m.raw : m.what!).font(.jakarta(20, .extraBold)).tracking(-0.4).foregroundStyle(Theme.ink).lineLimit(2).padding(.trailing, 90)
                }
            case .note:
                ObjectTile(glow: Theme.cyan, label: "Note") {
                    Text(m.raw).font(.jakarta(17, .extraBold)).foregroundStyle(Theme.ink).lineLimit(3)
                }
            }
        }
    }
}

struct AnswerTiles: View {
    var answer: Answer
    var replay: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if answer.kind == .money, let person = answer.person {
                GlassTile(glow: Theme.pink, minHeight: 0) {
                    ZStack(alignment: .topTrailing) {
                        Image(Theme.img("ring")).resizable().scaledToFit().frame(width: 100).offset(x: 8, y: -14)
                        VStack(alignment: .leading, spacing: 0) {
                            Label12(text: answer.net >= 0 ? "\(person) · baaki" : "\(person) ko dene hain")
                            Text(Format.inr(answer.net)).font(.sora(46, .extraLight)).tracking(-2.3).foregroundStyle(Theme.ink).padding(.top, 8)
                            VStack(spacing: 0) {
                                ForEach(Array(answer.entries.prefix(3).enumerated()), id: \.offset) { i, m in
                                    HStack(spacing: 8) {
                                        Image(Theme.pearl(m.kind)).resizable().frame(width: 14, height: 14)
                                        Text(Format.short(m.created) + (m.due.map { " · \($0) tak" } ?? m.why.map { " · \($0)" } ?? "")).lineLimit(1)
                                        Spacer()
                                        Text((m.kind == .give ? "" : "−") + Format.inr(m.amount ?? 0)).font(.jakarta(13.5, .extraBold))
                                    }
                                    .font(.jakarta(13.5, .semibold)).foregroundStyle(Theme.ink)
                                    .padding(.vertical, 9)
                                    .overlay(alignment: .top) { Theme.line.frame(height: 1) }
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                }
            } else if let f = answer.focus {
                MemoryTiles(memory: f)
            } else {
                GlassTile(glow: Theme.cyan) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label12(text: "Koi yaad nahi mili")
                        Text("Pehle boliye, jaise “Aadhaar card almari mein rakha hai”. Phir poochhiye “Aadhaar kahan hai?”")
                            .font(.jakarta(13, .medium)).foregroundStyle(Theme.ink.opacity(0.55))
                    }
                }
            }
            Button(action: replay) {
                GlassTile(glow: Theme.violet, minHeight: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            Image(Theme.img("play")).resizable().frame(width: 48, height: 48)
                            Image(systemName: "play.fill").font(.system(size: 15)).foregroundStyle(.white).offset(x: 1)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Label12(text: "Titli ka jawaab")
                            Text(answer.say).font(.jakarta(14, .bold)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading).lineLimit(3)
                        }
                    }
                }
            }
            .buttonStyle(PressStyle())
        }
    }
}

struct Chip: View {
    var text: String
    var body: some View {
        Text(text).font(.jakarta(11.5, .bold)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.white.opacity(0.9), in: Capsule())
    }
}
