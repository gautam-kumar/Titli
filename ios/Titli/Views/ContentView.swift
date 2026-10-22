import SwiftUI
import TitliCore

enum Screen: Equatable {
    case home, listen
    case saved(Memory)
    case answer(String, Answer)

    var hero: HeroMode {
        switch self { case .listen: .listen; case .answer: .answer; default: .home }
    }
}

struct ContentView: View {
    @State private var store = Store()
    @State private var voice = Voice()
    @State private var screen: Screen = .home
    @State private var typing = false
    @State private var typed = ""
    @State private var toast: String?
    @State private var demoTranscript: String?
    @State private var savedCount = 0
    @FocusState private var typerFocused: Bool
    @Environment(\.openURL) private var openURL

    private let quiet = ProcessInfo.processInfo.arguments.contains("-quiet")

    var body: some View {
        ZStack(alignment: .bottom) {
            Aura()
            VStack(spacing: 10) {
                header
                HeroCard(memories: store.memories, mode: screen.hero, focus: focusMemory, capLeft: capLeft, capRight: capRight)
                    .frame(minHeight: 150, maxHeight: .infinity)
                tiles
                    .id(tilesKey)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 14)), removal: .opacity))
                dock
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            if typing { typer.padding(.horizontal, 12).padding(.bottom, 82).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast).font(.sora(13)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.ink, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: screen)
        .animation(.easeOut(duration: 0.25), value: typing)
        .animation(.easeOut(duration: 0.3), value: toast)
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.impact(weight: .medium), trigger: voice.listening)
        .onAppear(perform: demo)
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                metaLeft
                Spacer()
                if screen == .home || screen == .listen {
                    Text("Hindi · Hinglish").font(.sora(12)).foregroundStyle(Theme.mute)
                } else {
                    Button("‹ Wapas") { goHome() }.font(.sora(12, .medium)).foregroundStyle(Theme.mute)
                }
            }
            greeting
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .frame(minHeight: 112, alignment: .top)
    }

    @ViewBuilder private var metaLeft: some View {
        switch screen {
        case .home: Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.sora(12)).foregroundStyle(Theme.mute)
        case .listen:
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                let s = Int(ctx.date.timeIntervalSince(voice.startedAt))
                Text("● Sun rahi hoon · 0:\(String(format: "%02d", max(0, s)))").font(.sora(12)).foregroundStyle(Theme.pink)
            }
        case .saved: Text("Nayi yaad").font(.sora(12)).foregroundStyle(Theme.pink)
        case .answer: Text("Aapne poochha").font(.sora(12)).foregroundStyle(Theme.mute)
        }
    }

    @ViewBuilder private var greeting: some View {
        switch screen {
        case .home:
            (Text(hello + "\n").font(.sora(38, .extraLight)) + Text("Kya yaad rakhein?").font(.sora(38, .medium)))
                .foregroundStyle(Theme.ink).tracking(-1.4).lineSpacing(-4)
        case .listen:
            if heard.isEmpty {
                Text("Boliye… jaise “Ramesh ko do hazaar diye, Diwali tak”").font(.sora(23, .extraLight)).foregroundStyle(Theme.mute)
            } else {
                Text("“\(heard)”").font(.sora(25, .extraLight)).foregroundStyle(Theme.ink).tracking(-0.7)
            }
        case .saved(let m):
            Text("“\(m.raw)”").font(.sora(25, .extraLight)).foregroundStyle(Theme.ink).tracking(-0.7)
        case .answer(let q, _):
            Text(q.hasSuffix("?") ? q : q + "?").font(.sora(30, .extraLight)).foregroundStyle(Theme.ink).tracking(-1)
        }
    }

    private var hello: String {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 12 ? "Suprabhat." : h < 17 ? "Namaste." : h < 21 ? "Shubh sandhya." : "Shubh ratri."
    }

    private var heard: String { demoTranscript ?? voice.transcript }

    private var capLeft: String {
        switch screen {
        case .home: "Titli ki udaan"
        case .listen: "Titli sun rahi hai…"
        case .saved: "Titli ne yaad rakh liya"
        case .answer(_, let a): a.kind == .none ? "Titli ko nahi mila" : "Titli dhoondh laayi"
        }
    }
    private var capRight: String {
        switch screen {
        case .listen: ""
        case .answer(_, let a): a.entries.isEmpty ? "" : "\(a.entries.count) yaad\(a.entries.count > 1 ? "ein" : "") mili"
        default: "\(store.memories.count) yaadein"
        }
    }
    private var focusMemory: Memory? { if case .answer(_, let a) = screen { a.focus } else { nil } }

    // MARK: tiles

    private var tilesKey: String {
        switch screen {
        case .home: "home-\(store.memories.count)"
        case .listen: "listen-\(Brain.loose(heard).count / 12)"
        case .saved(let m): "saved-\(m.id)"
        case .answer(let q, _): "answer-\(q)"
        }
    }

    @ViewBuilder private var tiles: some View {
        switch screen {
        case .home: HomeTiles(memories: store.memories, open: openMemory, ask: { handle($0) })
        case .listen:
            if !heard.isEmpty, case .memory(let m) = Brain.understand(heard) { MemoryTiles(memory: m) } else { Color.clear.frame(height: 1) }
        case .saved(let m): MemoryTiles(memory: m)
        case .answer(_, let a): AnswerTiles(answer: a) { speak(a.say) }
        }
    }

    // MARK: dock

    private var dock: some View {
        HStack(spacing: 10) {
            Button { typing.toggle(); typerFocused = typing } label: {
                Text("Aa").font(.sora(17, .medium)).foregroundStyle(Theme.ink)
                    .frame(width: 64, height: 64)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(Circle().fill(.white.opacity(0.6)))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1))
                    .shadow(color: Theme.shadow.opacity(0.3), radius: 15, y: 12)
            }
            .accessibilityLabel("Likh kar batayein")
            Button(action: pillAction) {
                HStack(spacing: 0) {
                    if screen == .listen { Waveform(levels: voice.levels, demo: demoTranscript != nil).padding(.trailing, 12) }
                    Text(pill.label).font(.sora(16)).foregroundStyle(Color(hex: 0xFAF9F6)).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    ZStack {
                        Circle().fill(Theme.aurora)
                        pill.icon
                    }
                    .frame(width: 48, height: 48)
                    .shadow(color: (screen == .listen ? Theme.pink : Theme.violet).opacity(0.6), radius: 11)
                    .phaseAnimator(screen == .listen ? [false, true] : [false]) { v, on in v.scaleEffect(on ? 1.08 : 1) } animation: { _ in .easeInOut(duration: 0.7) }
                }
                .padding(.leading, screen == .listen ? 20 : 24).padding(.trailing, 8)
                .frame(height: 64)
                .background(Theme.ink, in: Capsule())
                .shadow(color: Theme.ink.opacity(0.45), radius: 20, y: 16)
            }
            .buttonStyle(PressStyle())
        }
    }

    private struct PillContent { var label: String; var icon: AnyView }
    private var pill: PillContent {
        switch screen {
        case .listen: PillContent(label: "Bas, ho gaya", icon: AnyView(RoundedRectangle(cornerRadius: 3).fill(.white).frame(width: 12, height: 12)))
        case .saved: PillContent(label: "Galat hai? Hata dein", icon: AnyView(Image(systemName: "arrow.uturn.backward").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)))
        case .answer(_, let a) where a.kind == .money && a.net > 0:
            PillContent(label: "WhatsApp pe bhejein", icon: AnyView(Image(systemName: "paperplane.fill").font(.system(size: 18)).foregroundStyle(.white)))
        default: PillContent(label: "Chhuo aur bolo", icon: AnyView(Image(systemName: "mic.fill").font(.system(size: 20)).foregroundStyle(.white)))
        }
    }

    private func pillAction() {
        switch screen {
        case .listen: voice.finish()
        case .saved(let m): store.remove(m); show("Hata diya"); goHome()
        case .answer(_, let a) where a.kind == .money && a.net > 0:
            let msg = "Namaste \(a.person ?? ""), ek chhoti si yaad: \(Format.inr(a.net)) baaki hain. Dhanyavaad!"
            var c = URLComponents(string: "https://wa.me/")!; c.queryItems = [URLQueryItem(name: "text", value: msg)]
            if let u = c.url { openURL(u) }
        default: listen()
        }
    }

    private var typer: some View {
        HStack(spacing: 8) {
            TextField("Jaise: Ramesh ko 2000 diye, Diwali tak", text: $typed)
                .font(.sora(15)).padding(.leading, 14)
                .focused($typerFocused)
                .submitLabel(.send)
                .onSubmit(submitTyped)
            Button(action: submitTyped) {
                Image(systemName: "arrow.up").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Theme.aurora, in: Circle())
            }
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.3), radius: 20, y: 16)
    }

    // MARK: actions

    private func listen() {
        typing = false
        demoTranscript = nil
        voice.start { heard in
            if heard.isEmpty { goHome() } else { handle(heard) }
        } onProblem: { p in
            show(p == .denied ? "Mic ki ijaazat chahiye. Ya likh kar batayein." : "Abhi sun nahi pa rahi. Likh kar batayein.")
            typing = true; typerFocused = true
            goHome()
        }
        screen = .listen
    }

    private func submitTyped() {
        let v = typed.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        typed = ""; typing = false; typerFocused = false
        handle(v)
    }

    private func handle(_ text: String) {
        switch Brain.understand(text) {
        case .question(let q):
            let a = Brain.answer(q, store.memories)
            screen = .answer(text, a)
            speak(a.say)
        case .memory(let m):
            store.add(m)
            savedCount += 1
            screen = .saved(m)
            show("Yaad rakh liya ✓")
            speak("Theek hai, yaad rakh liya.")
        }
    }

    private func openMemory(_ m: Memory) {
        let say = m.kind == .doc ? Brain.docSay(m) : "\(m.title): \(m.sub)."
        let a = Answer(kind: m.kind == .doc ? .doc : .when, entries: [m], focus: m, say: say)
        screen = .answer(m.title, a)
        speak(say)
    }

    private func goHome() { screen = .home }

    private func speak(_ s: String) { if !quiet { voice.speak(s) } }

    private func show(_ t: String) {
        toast = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { if toast == t { toast = nil } }
    }

    /// Launch arguments used by the CI screenshots: -screen listen|saved|answer|doc
    private func demo() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return }
        switch args[i + 1] {
        case "listen": demoTranscript = "Maine Ramesh bhaiya ko do hazaar diye, Diwali tak lautayenge"; screen = .listen
        case "saved": handle("Maine Sunita didi ko 500 diye, Holi tak")
        case "answer": handle("Ramesh ko kitna diya tha?")
        case "doc": handle("आधार कार्ड कहाँ रखा है?")
        default: break
        }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1).animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct Waveform: View {
    var levels: [Float]
    var demo = false
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(levels.indices, id: \.self) { k in
                    let live = CGFloat(levels[k]), fake = abs(sin(t * 6 + Double(k) * 1.3))
                    Capsule().fill(Color(hex: 0xFAF9F6))
                        .frame(width: 3, height: 5 + (demo ? fake * 22 : live * 24))
                }
            }
            .frame(height: 30)
        }
    }
}
