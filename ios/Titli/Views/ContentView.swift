import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers
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
    @State private var themeID = Palette.active.id
    @State private var showThemes = false
    /// A photo or file waiting to be told what it is.
    @State private var pending: Attachment?
    @State private var showAttach = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var previewURL: URL?
    @FocusState private var typerFocused: Bool
    @Environment(\.openURL) private var openURL

    private let quiet = ProcessInfo.processInfo.arguments.contains("-quiet")

    var body: some View {
        ZStack(alignment: .bottom) {
            Aura().id(themeID)
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
            .id(themeID)
            VStack(spacing: 8) {
                if let pending, screen != .listen { pendingBanner(pending).transition(.move(edge: .bottom).combined(with: .opacity)) }
                if typing { typer.transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .padding(.horizontal, 12).padding(.bottom, 82)
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
        .animation(.easeOut(duration: 0.25), value: pending)
        .animation(.easeOut(duration: 0.3), value: toast)
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.impact(weight: .medium), trigger: voice.listening)
        .onAppear(perform: demo)
        .sheet(isPresented: $showThemes) {
            ThemePicker(current: themeID, pick: pickTheme)
                .presentationDetents([.height(300)])
                .presentationCornerRadius(28)
                .presentationBackground(.regularMaterial)
        }
        .confirmationDialog("Kya jodna hai?", isPresented: $showAttach, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Photo kheenchein") { showCamera = true } }
            Button("Gallery se photo") { showPhotos = true }
            Button("File chunein (PDF ya koi bhi)") { showFiles = true }
            Button("Rehne dein", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                if let data, let img = UIImage(data: data) { attached(Files.save(img)) } else { show("Photo nahi khul payi") }
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .image, .item]) { result in
            if case .success(let url) = result { attached(Files.copy(url)) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { img in
                showCamera = false
                if let img { attached(Files.save(img)) }
            }
            .ignoresSafeArea()
        }
        .quickLookPreview($previewURL)
        .environment(\.openAttachment, { (a: Attachment) in previewURL = Files.url(a) })
    }

    private func attached(_ a: Attachment?) {
        guard let a else { return show("Yeh file save nahi ho payi") }
        if let old = pending { Files.delete(old) }
        pending = a
        goHome()
        speak("Yeh kya hai? Bataiye.")
    }

    private func pendingBanner(_ a: Attachment) -> some View {
        HStack(spacing: 12) {
            Group {
                if let t = Files.thumbnail(a, size: 120) { Image(uiImage: t).resizable().scaledToFill() }
                else { Image(systemName: "doc.fill").font(.system(size: 20)).foregroundStyle(Theme.violet) }
            }
            .frame(width: 46, height: 46).background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Yeh kya hai?").font(.jakarta(15, .extraBold)).foregroundStyle(Theme.ink)
                Text("Boliye ya likhiye, jaise “Ramesh ka bijli bill”").font(.jakarta(12, .medium)).foregroundStyle(Theme.mute).lineLimit(2)
            }
            Spacer(minLength: 4)
            Button { Files.delete(a); pending = nil } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.mute)
                    .frame(width: 32, height: 32).background(.white.opacity(0.8), in: Circle())
            }
            .accessibilityLabel("Hata dein")
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.25), radius: 18, y: 12)
    }

    private func pickTheme(_ p: Palette) {
        Palette.active = p
        UserDefaults.standard.set(p.id, forKey: Palette.storageKey)
        showThemes = false
        withAnimation(.easeInOut(duration: 0.35)) { themeID = p.id }
        show("\(p.name) rang laga diya")
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                metaLeft
                Spacer()
                if screen == .home || screen == .listen {
                    Text("Hindi · Hinglish").font(.sora(12)).foregroundStyle(Theme.mute)
                    if screen == .home {
                        Button { showThemes = true } label: { Swatch(palette: Palette.active, size: 20).overlay(Circle().strokeBorder(.white, lineWidth: 2)) }
                            .accessibilityLabel("Rang badlein")
                    }
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
        case .home where pending != nil:
            (Text((pending?.kind == .image ? "Photo" : "File") + " mil gayi.\n").font(.sora(38, .extraLight)) + Text("Yeh kya hai?").font(.sora(38, .medium)))
                .foregroundStyle(Theme.ink).tracking(-1.4).lineSpacing(-4)
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
            if screen == .home {
                Button { showAttach = true } label: {
                    Image(systemName: "paperclip").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.ink)
                        .frame(width: 56, height: 64)
                        .background(.ultraThinMaterial, in: Capsule())
                        .background(Capsule().fill(.white.opacity(0.6)))
                        .overlay(Capsule().strokeBorder(.white, lineWidth: 1))
                        .shadow(color: Theme.shadow.opacity(0.3), radius: 15, y: 12)
                }
                .accessibilityLabel("Photo ya file jodein")
            }
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
        if let a = pending {
            pending = nil
            let m = Brain.attach(a, to: Brain.understand(text))
            store.add(m)
            savedCount += 1
            screen = .saved(m)
            show("Yaad rakh liya ✓")
            speak("Theek hai, \(m.title) phone mein rakh liya.")
            return
        }
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

    /// Launch arguments used by the CI screenshots: -screen listen|saved|answer|doc|themes, -theme neel|kesar|mor|gulaal
    private func demo() {
        let args = ProcessInfo.processInfo.arguments
        if let t = args.firstIndex(of: "-theme"), t + 1 < args.count {
            Palette.active = Palette.named(args[t + 1]); themeID = Palette.active.id
        }
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return }
        switch args[i + 1] {
        case "listen": demoTranscript = "Maine Ramesh bhaiya ko do hazaar diye, Diwali tak lautayenge"; screen = .listen
        case "saved": handle("Maine Sunita didi ko 500 diye, Holi tak")
        case "answer": handle("Ramesh ko kitna diya tha?")
        case "doc": handle("आधार कार्ड कहाँ रखा है?")
        case "themes": showThemes = true
        case "attach": pending = Files.sample()
        case "attached": pending = Files.sample(); handle("Ramesh ka bijli bill")
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

/// A little ball of the theme's four colours.
struct Swatch: View {
    var palette: Palette
    var size: CGFloat
    var body: some View {
        Circle()
            .fill(AngularGradient(colors: [palette.c1, palette.c2, palette.c3, palette.c4, palette.c1].map { Color(hex: $0) }, center: .center, angle: .degrees(200)))
            .overlay(Circle().fill(RadialGradient(colors: [.white.opacity(0.45), .clear], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.6)))
            .frame(width: size, height: size)
            .shadow(color: Color(hex: palette.shadow).opacity(0.35), radius: 4, y: 2)
    }
}

struct ThemePicker: View {
    var current: String
    var pick: (Palette) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Titli ka rang").font(.sora(20, .medium)).tracking(-0.4).foregroundStyle(Theme.ink)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Palette.all) { p in
                    Button { pick(p) } label: {
                        HStack(spacing: 12) {
                            Swatch(palette: p, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.jakarta(15, .bold)).foregroundStyle(Theme.ink)
                                Text(p.mood).font(.jakarta(11.5, .semibold)).foregroundStyle(Theme.mute).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(p.id == current ? Theme.ink : Theme.line, lineWidth: p.id == current ? 2 : 1))
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 24)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
