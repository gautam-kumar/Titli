import Foundation

// Understanding Hindi / Hinglish: turn what someone said into a memory, or answer a question from memories.
// Devanagari is transliterated to a loose Latin form first, so "दो हज़ार" and "do hazaar" match the same rules.

// MARK: - Regex helpers (JS-style, so the rules read like the web version)

private var cache: [String: NSRegularExpression] = [:]
private let cacheLock = NSLock()
private func rx(_ p: String, _ i: Bool = false) -> NSRegularExpression {
    let key = (i ? "i:" : "") + p
    cacheLock.lock(); defer { cacheLock.unlock() }
    if let r = cache[key] { return r }
    let r = try! NSRegularExpression(pattern: p, options: i ? [.caseInsensitive] : [])
    cache[key] = r
    return r
}

extension String {
    var ns: NSRange { NSRange(startIndex..., in: self) }
    func test(_ p: String, _ i: Bool = false) -> Bool { rx(p, i).firstMatch(in: self, range: ns) != nil }
    /// Groups of the first match; index 0 is the whole match. nil groups are "".
    func match(_ p: String, _ i: Bool = false) -> [String]? {
        guard let m = rx(p, i).firstMatch(in: self, range: ns) else { return nil }
        return (0..<m.numberOfRanges).map { k in
            let r = m.range(at: k)
            guard r.location != NSNotFound, let rr = Range(r, in: self) else { return "" }
            return String(self[rr])
        }
    }
    func rep(_ p: String, _ t: String, _ i: Bool = false) -> String {
        rx(p, i).stringByReplacingMatches(in: self, range: ns, withTemplate: t)
    }
    var titled: String { split(separator: " ", omittingEmptySubsequences: false).map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ") }
}

// MARK: - Transliteration

private let CONS: [Character: String] = ["क": "k", "ख": "kh", "ग": "g", "घ": "gh", "ङ": "n", "च": "ch", "छ": "chh", "ज": "j", "झ": "jh", "ञ": "n", "ट": "t", "ठ": "th", "ड": "d", "ढ": "dh", "ण": "n", "त": "t", "थ": "th", "द": "d", "ध": "dh", "न": "n", "प": "p", "फ": "ph", "ब": "b", "भ": "bh", "म": "m", "य": "y", "र": "r", "ल": "l", "व": "v", "श": "sh", "ष": "sh", "स": "s", "ह": "h"]
private let NUKTA: [Character: String] = ["ज": "z", "फ": "f", "ड": "r", "ढ": "rh", "क": "q", "ख": "kh", "ग": "g"]
private let VOW: [Character: String] = ["अ": "a", "आ": "aa", "इ": "i", "ई": "ee", "उ": "u", "ऊ": "oo", "ए": "e", "ऐ": "ai", "ओ": "o", "औ": "au", "ऋ": "ri"]
private let MATRA: [Character: String] = ["ा": "aa", "ि": "i", "ी": "ee", "ु": "u", "ू": "oo", "े": "e", "ै": "ai", "ो": "o", "ौ": "au", "ृ": "ri", "ॉ": "o"]
private let DIGITS = Array("०१२३४५६७८९")

public enum Brain {
    public static func translit(_ input: String) -> String {
        // work on unicode scalars: a Swift Character would glue a consonant and its matra together
        let chars: [Character] = input.decomposedStringWithCanonicalMapping.unicodeScalars.map { s in
            let c = Character(s)
            if let d = DIGITS.firstIndex(of: c) { return Character(String(d)) }
            return c
        }
        // a word is a list of units: v == nil means the inherent schwa, "" means none (virama)
        struct U { var c: String; var v: String?; var n: String = "" }
        var out = "", word: [U] = []
        func flush() {
            for i in word.indices where word[i].v == nil {
                let next = i + 1 < word.count ? word[i + 1] : nil
                if next == nil { word[i].v = "" }
                else if i > 0, word[i - 1].v != "", let nv = next?.v, nv != "", word[i].n.isEmpty { word[i].v = "" }
                else { word[i].v = "a" }
            }
            out += word.map { $0.c + ($0.v ?? "") + $0.n }.joined()
            word = []
        }
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if var base = CONS[c] {
                if i + 1 < chars.count, chars[i + 1] == "\u{093C}" { base = NUKTA[c] ?? base; i += 1 }
                let nx: Character? = i + 1 < chars.count ? chars[i + 1] : nil
                if let nx, let m = MATRA[nx] { word.append(U(c: base, v: m)); i += 1 }
                else if nx == "्" { word.append(U(c: base, v: "")); i += 1 }
                else { word.append(U(c: base, v: nil)) }
            } else if let v = VOW[c] { word.append(U(c: "", v: v)) }
            else if (c == "ं" || c == "ँ"), !word.isEmpty { word[word.count - 1].n = "n" }
            else if c == "ः", !word.isEmpty { word[word.count - 1].n = "h" }
            else { flush(); out += c == "।" ? "." : String(c) }
            i += 1
        }
        flush()
        return out
    }

    /// Loose form for matching: lower case, doubled vowels collapsed, common spelling variants folded.
    public static func loose(_ s: String) -> String {
        translit(s).lowercased()
            .replacingOccurrences(of: "aa", with: "a").replacingOccurrences(of: "ee", with: "i").replacingOccurrences(of: "oo", with: "u")
            .rep("[’'`]", "").replacingOccurrences(of: "w", with: "v").rep("\\bkard\\b", "card")
            .replacingOccurrences(of: "z", with: "j").replacingOccurrences(of: "ph", with: "f")
            .rep("[^a-z0-9₹.,?\\s-]", " ").rep("\\s+", " ").trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Amounts

    static let NUM: [String: Double] = ["ek": 1, "do": 2, "tin": 3, "char": 4, "panch": 5, "pach": 5, "chhah": 6, "chhe": 6, "chhai": 6, "che": 6, "sat": 7, "ath": 8, "nau": 9, "das": 10, "gyarah": 11, "barah": 12, "pandrah": 15, "bis": 20, "pachis": 25, "tis": 30, "chalis": 40, "pachas": 50, "sath": 60, "sattar": 70, "assi": 80, "nabbe": 90, "dedh": 1.5, "derh": 1.5, "dhai": 2.5, "sadhe": 0.5,
                                        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "twenty": 20, "fifty": 50]
    static let MULT: [String: Double] = ["sau": 100, "hundred": 100, "hajar": 1000, "thousand": 1000, "k": 1000, "lakh": 100000, "lac": 100000, "karod": 10000000, "crore": 10000000]

    public static func parseAmount(_ l: String) -> Int {
        // digits, optionally followed by a multiplier word: "2000", "2,000", "2 hajar", "1.5 lakh"
        if let m = l.match("(?:₹|rs\\.?|rupaye?\\s)?\\s*(\\d[\\d,]*(?:\\.\\d+)?)\\s*(sau|hajar|thousand|k\\b|lakh|lac|karod|crore)?") {
            var v = Double(m[1].replacingOccurrences(of: ",", with: "")) ?? 0
            if !m[2].isEmpty { v *= MULT[m[2]] ?? 1 }
            if v >= 1 { return Int(v.rounded()) }
        }
        // words: "do hajar", "dhai hajar", "panch sau", "sadhe tin hajar"
        let w = l.split(separator: " ").map(String.init)
        var best = 0.0
        for i in w.indices where i > 0 {
            guard let mult = MULT[w[i]], var n = NUM[w[i - 1]] else { continue }
            if i >= 2, w[i - 2] == "sadhe" { n += 0.5 }
            var v = n * mult
            // "do hajar panch sau"
            if i + 2 < w.count, w[i + 2] == "sau", let h = NUM[w[i + 1]], mult > 100 { v += h * 100 }
            best = max(best, v)
        }
        return Int(best.rounded())
    }

    // MARK: - Dates

    public struct When: Equatable { public var label = ""; public var date: Date?; public var time: String? }
    static let FEST: [(String, String, String)] = [("divali", "Diwali", "2026-11-08"), ("holi", "Holi", "2027-03-22"), ("rakhi", "Rakhi", "2027-08-17"), ("id", "Eid", "2027-03-10"), ("navratri", "Navratri", "2026-10-11"), ("chhath", "Chhath", "2026-11-15")]
    static let DAYS: [(String, Int)] = [("somvar", 2), ("mangalvar", 3), ("budhvar", 4), ("guruvar", 5), ("brihaspativar", 5), ("shukravar", 6), ("shanivar", 7), ("ravivar", 1), ("itvar", 1), ("monday", 2), ("tuesday", 3), ("wednesday", 4), ("thursday", 5), ("friday", 6), ("saturday", 7), ("sunday", 1)]
    public static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return c
    }()

    static func day(_ iso: String) -> Date {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 10))!
    }

    public static func parseWhen(_ l: String, now: Date = Date()) -> When {
        var r = When()
        let cal = calendar
        if let f = FEST.first(where: { l.contains($0.0) }) { r.label = f.1; r.date = day(f.2) }
        var d = cal.date(bySettingHour: 10, minute: 0, second: 0, of: now)!
        func add(_ c: Calendar.Component, _ n: Int) { d = cal.date(byAdding: c, value: n, to: d)! }
        if r.label.isEmpty {
            if l.test("\\bparson\\b") { add(.day, 2); r.label = "Parson"; r.date = d }
            else if l.test("\\bkal\\b") && !l.test("(kal\\s+(maine|diye|diya|liye|liya|die|lie))") { add(.day, 1); r.label = "Kal"; r.date = d }
            else if l.test("\\baj\\b") { r.label = "Aaj"; r.date = d }
            else if l.test("agle\\s+hafte|next week") { add(.day, 7); r.label = "Agle hafte"; r.date = d }
            else if l.test("agle\\s+mahine|next month") { add(.month, 1); r.label = "Agle mahine"; r.date = d }
            else {
                if let (k, wd) = DAYS.first(where: { l.contains($0.0) }) {
                    let a = (wd - cal.component(.weekday, from: d) + 7) % 7
                    add(.day, a == 0 ? 7 : a); r.label = k.titled; r.date = d
                }
                if r.label.isEmpty, let t = l.match("(\\d{1,2})\\s*(tarikh|tarik|date)"), let dd = Int(t[1]) {
                    if dd < cal.component(.day, from: d) { add(.month, 1) }
                    var comps = cal.dateComponents([.year, .month, .hour], from: d); comps.day = dd
                    d = cal.date(from: comps) ?? d
                    r.label = Format.short(d); r.date = d
                }
            }
        }
        if let tm = l.match("(\\d{1,2})(?::(\\d{2}))?\\s*baje") ?? l.match("(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)") {
            var h = Int(tm[1]) ?? 0
            if l.test("shaam|sham|raat|rat|pm") && h < 12 { h += 12 }
            if l.test("dopahar") && h < 12 { h += 12 }
            let mm = Int(tm[2]) ?? 0
            r.time = String(format: "%02d:%@", h, tm[2].isEmpty ? "00" : tm[2])
            if r.date == nil {
                d = cal.date(bySettingHour: h % 24, minute: mm, second: 0, of: d)!
                if d < now { add(.day, 1) }
                if r.label.isEmpty { r.label = "Aaj" }
                r.date = d
            }
        }
        return r
    }

    // MARK: - Understanding

    static let STOP: Set<String> = ["maine", "mene", "mainne", "main", "mai", "ne", "aj", "abhi", "kal", "to", "ki", "ka", "ke", "hai", "hain", "tha", "the", "ek", "apne", "apni", "mera", "meri", "mere", "humne", "hamne", "i", "gave", "ji", "mujhe", "muje", "hamein", "humein"]
    static let DOCS: [(String, String)] = [("adhar", "Aadhaar card"), ("adhaar", "Aadhaar card"), ("aadhar", "Aadhaar card"), ("pan card", "PAN card"), ("pan", "PAN card"), ("passport", "Passport"), ("rashan", "Ration card"), ("ration", "Ration card"), ("licens", "Driving licence"), ("voter", "Voter ID"), ("marksheet", "Marksheet"), ("certificate", "Certificate"), ("policy", "Insurance policy"), ("bima", "Insurance policy"), ("registry", "Registry"), ("ragistri", "Registry"), ("fd", "FD papers"), ("chekbuk", "Cheque book"), ("cheque", "Cheque book"), ("passbuk", "Passbook"), ("passbook", "Passbook"), ("kagaj", "Kaagaz"), ("dastavej", "Kaagaz"), ("vasiyat", "Will")]

    static func findDoc(_ l: String) -> (String, String)? { DOCS.first { l.test("\\b" + $0.0) } }

    static func personBefore(_ words: [String], _ idx: Int) -> String {
        var out: [String] = []
        var i = idx - 1
        while i >= 0 && out.count < 2 {
            let w = words[i]
            if STOP.contains(w) || w.test("^\\d") || MULT[w] != nil || NUM[w] != nil || w.test("^(rupaye?|rs|₹)$") {
                if !out.isEmpty { break }
            } else { out.insert(w, at: 0) }
            i -= 1
        }
        guard !out.isEmpty else { return "" }
        return out.joined(separator: " ").titled.rep("\\bBhaiy?a\\b", "bhaiya").rep("\\bDidi\\b", "didi").rep("\\bJi\\b", "ji")
    }

    static func words(_ l: String) -> [String] { l.rep("[?.,]", " ").split(whereSeparator: { $0 == " " }).map(String.init) }

    public static func understand(_ raw: String, now: Date = Date()) -> Heard {
        let l = loose(raw), words = words(l)
        let isQ = raw.trimmingCharacters(in: .whitespaces).hasSuffix("?")
            || (l.test("\\b(kitna|kitne|kitni|kahan|kaha|kidhar|kab|kaun|kya|batao|bata|bataiye|dikhao|how much|where|when)\\b") && !l.test("\\b(yad dilana|yad dila|remind)\\b"))
        if isQ { return .question(Question(raw: raw, l: l, words: words)) }
        let amount = parseAmount(l), when = parseWhen(l, now: now)
        var m = Memory(raw: raw, created: now)
        let ko = words.firstIndex(of: "ko") ?? -1, se = words.firstIndex(of: "se") ?? -1
        let give = l.test("\\b(diye|diya|die|dia|de diye|de diya|udhar diya|lene hain|lene hai|lena hai|gave|lent)\\b")
        let take = l.rep("\\bke li(y)?e\\b", "").test("\\b(liye|liya|lie|lia|le liye|udhar liya|dene hain|dene hai|dena hai|borrowed|owe)\\b")
        let doc = findDoc(l)
        let remind = l.test("\\b(yad dilana|yad dila|yad dilaiye|remind|book karna|bharna|bharni|jama karna|lena hai|karna hai|jana hai)\\b") || (when.time != nil && amount == 0)
        if amount > 0 && (give || take) {
            m.kind = take && !l.test("lene ha|lena ha") ? .take : .give
            m.amount = amount
            let first = m.kind == .give ? ko : se, second = m.kind == .give ? se : ko
            m.person = first > 0 ? personBefore(words, first) : second > 0 ? personBefore(words, second) : ""
            if let tak = words.firstIndex(of: "tak"), tak > 0 {
                m.due = when.label.isEmpty ? words[max(0, tak - 2)..<tak].joined(separator: " ").titled : when.label
                m.dueDate = when.date
            }
            if let why = raw.match("([^\\s,।]+\\s+(?:ki|ke|ka|की|के|का)\\s+[^\\s,।]+|[^\\s,।]+)\\s+(?:ke\\s+liye|के\\s+लिए)", true) { m.why = why[1] }
        } else if let doc {
            m.kind = .doc; m.doc = doc.1
            let soft = raw.test("[\\u0900-\\u097F]")
                ? translit(raw).lowercased().replacingOccurrences(of: "aa", with: "a").replacingOccurrences(of: "ee", with: "i").replacingOccurrences(of: "oo", with: "u").rep("\\bkard\\b", "card")
                : raw.lowercased()
            if let pm = soft.match("(?:(?:aa?dhaa?r|pan|ration|voter)\\s+card|card|aa?dhaa?r|passport|pan|ration|licen[cs]e|policy|registry|marksheet|certificate|passbook|cheque\\s*book|papers?|kaagaz|kagaz)\\s+(?:ko\\s+|maine\\s+|mene\\s+)?(.{3,40}?)\\s+(?:mein|me|men|par|pe|andar)\\b") {
                let p = pm[1].trimmingCharacters(in: .whitespaces)
                m.place = p.prefix(1).uppercased() + p.dropFirst()
            }
        } else if remind {
            m.kind = .remind
            m.what = raw.rep("(yaad\\s*dila(na|iye|\\s*dena)?|remind\\s*me|kal|parson|subah|shaam|\\d{1,2}\\s*baje)", "", true).rep("\\s+", " ").trimmingCharacters(in: .whitespaces)
            m.when = when.label; m.time = when.time; m.dueDate = when.date
        }
        if amount > 0 && m.kind == .note { m.amount = amount }
        return .memory(describe(m))
    }

    public static func describe(_ m0: Memory) -> Memory {
        var m = m0
        let c = Format.short(m.created)
        let join = { (xs: [String?]) in xs.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ") }
        let who = (m.person ?? "").isEmpty ? "Kisi" : m.person!
        switch m.kind {
        case .give: m.title = "\(who) ko \(Format.inr(m.amount ?? 0))"; m.sub = join([c, m.due.map { "\($0) tak" }])
        case .take: m.title = "\(who) ke \(Format.inr(m.amount ?? 0)) dene"; m.sub = join([c, m.due.map { "\($0) tak" }])
        case .doc: m.title = m.doc ?? "Kaagaz"; m.sub = m.place ?? c
        case .remind:
            let w = (m.what ?? "").isEmpty ? m.raw : m.what!
            m.title = String(w.prefix(34)); m.sub = join([m.when, m.time]); if m.sub.isEmpty { m.sub = c }
        case .note: m.title = m.raw.count > 30 ? m.raw.prefix(30) + "…" : m.raw; m.sub = c
        }
        return m
    }

    // MARK: - Answering

    static func matchPerson(_ mems: [Memory], _ words: [String]) -> String? {
        var seen: [String] = []
        for m in mems { if let p = m.person, !p.isEmpty, !seen.contains(p) { seen.append(p) } }
        var best: String?, score = 0
        for p in seen {
            var s = 0
            for w in loose(p).split(separator: " ").map(String.init) {
                let hit = words.contains { (x: String) -> Bool in
                    x.count > 2 && (x.hasPrefix(String(w.prefix(4))) || w.hasPrefix(String(x.prefix(4))))
                }
                if hit { s += 1 }
            }
            if s > score { score = s; best = p }
        }
        return best
    }

    public static func answer(_ q: Question, _ mems: [Memory]) -> Answer {
        let l = q.l, words = q.words
        if let person = matchPerson(mems, words) {
            let es = mems.filter { $0.person == person && ($0.kind == .give || $0.kind == .take) }
            if !es.isEmpty {
                let net = es.reduce(0) { $0 + ($1.kind == .give ? ($1.amount ?? 0) : -($1.amount ?? 0)) }
                return Answer(kind: .money, person: person, net: net, entries: es, focus: es[0],
                              say: net >= 0 ? "\(person) se \(Format.number(net)) rupaye lene baaki hain." : "Aapko \(person) ko \(Format.number(-net)) rupaye dene hain.")
            }
        }
        if l.test("\\b(kahan|kaha|kidhar|where|rakha|rakhi|rakhe)\\b") {
            let doc = findDoc(l)
            let docs = mems.filter { $0.kind == .doc && (doc == nil || $0.doc == doc!.1) }
            // with no known document name, pick the one sharing the most words with the question
            let overlap = { (m: Memory) -> Int in words.filter { $0.count > 2 && !STOP.contains($0) && loose(m.raw + " " + (m.doc ?? "")).contains($0) }.count }
            if let hit = doc == nil ? docs.max(by: { overlap($0) < overlap($1) }).flatMap({ overlap($0) > 0 ? $0 : docs.first }) : docs.first {
                return Answer(kind: .doc, entries: [hit], focus: hit, say: docSay(hit))
            }
        }
        if l.test("\\b(kab|when)\\b") || l.test("\\b(yad|reminder)\\b") {
            let rs = mems.filter { $0.kind == .remind || $0.due != nil }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            let scored = rs.map { m in (m, words.filter { $0.count > 2 && loose(m.raw).contains($0) }.count) }
            if let hit = scored.max(by: { $0.1 < $1.1 })?.0 ?? rs.first {
                return Answer(kind: .when, entries: [hit], focus: hit, say: "\(hit.title): \(hit.sub).")
            }
        }
        // fall back to the memory sharing the most words with the question
        let scored = mems.map { m in (m, words.filter { $0.count > 2 && !STOP.contains($0) && loose(m.raw).contains($0) }.count) }
        if let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0 {
            return Answer(kind: .note, entries: [best.0], focus: best.0, say: best.0.raw)
        }
        return Answer(kind: .none, say: "Iske baare mein mujhe abhi kuch yaad nahi hai.")
    }

    /// Attach a photo or file to what was said about it. A bare label ("Ramesh ka bijli bill") becomes a document kept on the phone;
    /// money or reminders keep their meaning and carry the file along (a receipt, a bill).
    public static func attach(_ a: Attachment, to heard: Heard, now: Date = Date()) -> Memory {
        var m: Memory
        switch heard {
        case .memory(let x): m = x
        case .question(let q): m = Memory(raw: q.raw, created: now)
        }
        m.attachment = a
        if m.kind == .note {
            m.kind = .doc
            let label = m.raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .rep("^(ye|yeh|yah|is|isko|ise|this is)\\s+", "", true)
                .rep("\\s+(hai|he|h)[.!]*$", "", true)
                .rep("\\s+(ki|ka|ke)\\s+(photo|foto|fotu|tasveer|tasvir|file|scan|copy|pdf)$", "", true)
                .rep("[.!?।]+$", "")
            m.doc = label.isEmpty ? (a.kind == .image ? "Photo" : a.name) : label.prefix(1).uppercased() + label.dropFirst()
        }
        if m.kind == .doc && m.place == nil { m.place = "Phone" }
        return describe(m)
    }

    public static func docSay(_ m: Memory) -> String {
        "\(m.doc ?? "Kaagaz") \(m.place.map { $0.lowercased() + " mein " } ?? "")rakha hai."
    }
}
