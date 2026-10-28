import Foundation

/// One thing the person asked Titli to remember.
public struct Memory: Codable, Identifiable, Equatable, Hashable {
    public enum Kind: String, Codable { case give, take, doc, remind, note }

    public var id = UUID()
    public var raw: String
    public var created: Date
    public var kind: Kind = .note
    public var amount: Int?
    public var person: String?
    public var due: String?
    public var dueDate: Date?
    public var why: String?
    public var doc: String?
    public var place: String?
    public var what: String?
    public var when: String?
    public var time: String?
    public var title = ""
    public var sub = ""
    /// A photo or file kept on the phone alongside this memory.
    public var attachment: Attachment?

    public init(raw: String, created: Date = Date()) {
        self.raw = raw
        self.created = created
    }
}

/// A photo or document saved on the phone. Only its label ever leaves the device.
public struct Attachment: Codable, Equatable, Hashable {
    public enum Kind: String, Codable { case image, pdf, file }
    /// File name inside the app's files folder.
    public var file: String
    public var kind: Kind
    /// The original name, shown for documents.
    public var name: String

    public init(file: String, kind: Kind, name: String) {
        self.file = file; self.kind = kind; self.name = name
    }
}

/// What Titli found when asked a question.
public struct Answer: Equatable {
    public enum Kind: String { case money, doc, when, note, none }
    public var kind: Kind
    public var person: String?
    public var net: Int = 0
    public var entries: [Memory] = []
    public var focus: Memory?
    public var say: String

    public init(kind: Kind, person: String? = nil, net: Int = 0, entries: [Memory] = [], focus: Memory? = nil, say: String) {
        self.kind = kind; self.person = person; self.net = net; self.entries = entries; self.focus = focus; self.say = say
    }
}

public enum Heard: Equatable {
    case question(Question)
    case memory(Memory)
}

public struct Question: Equatable {
    public var raw: String
    public var l: String
    public var words: [String]
}

public enum Format {
    static let inLocale = Locale(identifier: "en_IN")

    /// "2,000", "1,00,000" in Indian grouping.
    public static func number(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = inLocale
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
    public static func inr(_ n: Int) -> String { "₹" + number(abs(n)) }

    /// "8 Nov"
    public static func short(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMM"
        return f.string(from: d)
    }
}
