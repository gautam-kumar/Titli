import Foundation

// Gemini does the understanding when it can; this file is everything around that call that doesn't
// need the network: the instructions, what we send (text and memory details only, never files),
// and turning Gemini's JSON back into a Memory or an Answer. Money totals are always added up here,
// on the phone, from the matched memories, never taken from the model.

/// The JSON Gemini is asked to return.
public struct AIReply: Codable, Equatable {
    /// "save" when the person is telling Titli something, "ask" when they want something back.
    public var intent: String
    // save
    public var kind: String?
    public var amount: Int?
    public var person: String?
    public var due: String?
    public var dueDate: String?
    public var time: String?
    public var doc: String?
    public var place: String?
    public var what: String?
    public var why: String?
    // ask
    public var answerKind: String?
    public var matches: [Int]?
    public var say: String?

    public init(intent: String, kind: String? = nil, amount: Int? = nil, person: String? = nil, due: String? = nil, dueDate: String? = nil, time: String? = nil,
                doc: String? = nil, place: String? = nil, what: String? = nil, why: String? = nil, answerKind: String? = nil, matches: [Int]? = nil, say: String? = nil) {
        self.intent = intent; self.kind = kind; self.amount = amount; self.person = person; self.due = due; self.dueDate = dueDate; self.time = time
        self.doc = doc; self.place = place; self.what = what; self.why = why; self.answerKind = answerKind; self.matches = matches; self.say = say
    }
}

public enum AIResult: Equatable {
    case memory(Memory)
    case answer(Answer)
}

public enum AI {
    public static let model = "gemini-3.1-flash-lite"
    /// How many recent memories go along with a question.
    public static let contextLimit = 60

    public static func instructions(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = Brain.calendar.timeZone; f.dateFormat = "yyyy-MM-dd EEEE"
        return """
        You are Titli, a memory helper for Indian families who are not comfortable with technology. People speak in Hindi, \
        Hinglish or English, in Devanagari or Roman script. Today is \(f.string(from: now)) (India time).

        Decide if the person is telling you something to remember (intent "save") or asking for something back (intent "ask").

        For "save", fill:
        - kind: "give" (they gave or lent money to someone, or someone owes them), "take" (they took or borrowed money, or they owe someone), \
        "doc" (where an important paper or document is kept), "remind" (something to do at a time), or "note" (anything else).
        - amount in rupees as a whole number ("do hazaar" = 2000, "dhai hazaar" = 2500, "sadhe teen sau" = 350).
        - person exactly as said, keeping words like bhaiya, didi, ji, chacha.
        - due: when money is to come back or the reminder is, as a short Hinglish label ("Diwali", "Kal", "Agle hafte", "5 Nov"); \
        dueDate as yyyy-MM-dd if you can work it out; time as HH:mm (24 hour) if a time was said.
        - doc: the document's common name in English ("Aadhaar card", "PAN card", "Ration card", "Passport", "Insurance policy"); \
        place: where it is kept, in the person's words ("Almari ke drawer").
        - what: for a reminder, the task in a few Hinglish words ("Gas cylinder book karna"). why: the purpose of money, if said.

        For "ask", you get their saved memories as a numbered list. Fill:
        - answerKind: "money" (how much is owed or was given), "doc" (where something is), "when" (when something is due), \
        "note" (some other memory) or "none" (nothing matches).
        - matches: the numbers of the memories that answer the question, most relevant first. For money, every memory about that person.
        - person: for money questions, the person as written in the memories.
        - say: a short, warm answer in simple Hinglish (Roman script), one or two sentences, that an elderly person would understand.

        Never invent memories. If nothing matches, use answerKind "none".
        """
    }

    /// The text sent with each request: what was said, plus memory details for questions.
    public static func request(said: String, memories: [Memory]) -> String {
        struct Item: Encodable { let n: Int; let kind: String; let said: String; let person: String?; let amount: Int?; let doc: String?; let place: String?; let due: String?; let on: String }
        struct Req: Encodable { let said: String; let memories: [Item] }
        let items = memories.prefix(contextLimit).enumerated().map { i, m in
            Item(n: i, kind: m.kind.rawValue, said: m.raw, person: m.person, amount: m.amount, doc: m.doc, place: m.place, due: m.due ?? m.when, on: Format.short(m.created))
        }
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? e.encode(Req(said: said, memories: items))) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    public static func decode(_ json: String) -> AIReply? {
        var s = json.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") { s = s.rep("^```(json)?\\s*", "").rep("\\s*```$", "") }
        return try? JSONDecoder().decode(AIReply.self, from: Data(s.utf8))
    }

    /// Turn Gemini's reply into a memory to save or an answer to show. nil means "use the on-phone parser instead".
    public static func interpret(_ r: AIReply, said: String, memories: [Memory], now: Date = Date()) -> AIResult? {
        let blank = { (s: String?) -> String? in
            guard let t = s?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
            return t
        }
        if r.intent == "save" {
            var m = Memory(raw: said, created: now)
            m.kind = Memory.Kind(rawValue: r.kind ?? "") ?? .note
            if (m.kind == .give || m.kind == .take) && (r.amount ?? 0) <= 0 { m.kind = .note }
            m.amount = (r.amount ?? 0) > 0 ? r.amount : nil
            m.person = blank(r.person)
            m.why = blank(r.why)
            let date = r.dueDate.flatMap(day)
            switch m.kind {
            case .give, .take:
                m.due = blank(r.due); m.dueDate = date
            case .doc:
                m.doc = blank(r.doc) ?? "Kaagaz"; m.place = blank(r.place).map { $0.prefix(1).uppercased() + $0.dropFirst() }
            case .remind:
                m.what = blank(r.what); m.when = blank(r.due); m.time = blank(r.time); m.dueDate = date
            case .note: break
            }
            return .memory(Brain.describe(m))
        }
        let picked = (r.matches ?? []).filter { memories.indices.contains($0) }.map { memories[$0] }
        switch r.answerKind {
        case "money":
            let person = blank(r.person) ?? picked.first(where: { $0.person != nil })?.person
            guard let person else { return nil }
            let key = Brain.loose(person)
            let es = memories.filter { ($0.kind == .give || $0.kind == .take) && $0.person.map { Brain.loose($0) == key || Brain.loose($0).hasPrefix(key) || key.hasPrefix(Brain.loose($0)) } == true }
            guard let first = es.first else { return nil }
            let name = first.person ?? person
            let net = es.reduce(0) { $0 + ($1.kind == .give ? ($1.amount ?? 0) : -($1.amount ?? 0)) }
            return .answer(Answer(kind: .money, person: name, net: net, entries: es, focus: first,
                                  say: net >= 0 ? "\(name) se \(Format.number(net)) rupaye lene baaki hain." : "Aapko \(name) ko \(Format.number(-net)) rupaye dene hain."))
        case "doc":
            guard let hit = picked.first(where: { $0.kind == .doc }) ?? picked.first else { return nil }
            return .answer(Answer(kind: .doc, entries: [hit], focus: hit, say: hit.kind == .doc ? Brain.docSay(hit) : (blank(r.say) ?? hit.raw)))
        case "when":
            guard let hit = picked.first else { return nil }
            return .answer(Answer(kind: .when, entries: [hit], focus: hit, say: blank(r.say) ?? "\(hit.title): \(hit.sub)."))
        case "note":
            guard let hit = picked.first else { return nil }
            return .answer(Answer(kind: .note, entries: picked, focus: hit, say: blank(r.say) ?? hit.raw))
        default:
            return .answer(Answer(kind: .none, say: "Iske baare mein mujhe abhi kuch yaad nahi hai."))
        }
    }

    private static func day(_ s: String) -> Date? {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return Brain.calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 10))
    }
}
