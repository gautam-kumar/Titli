import Foundation
import Observation
import TitliCore

/// The person's memories, newest first, kept in a JSON file on the phone.
@Observable final class Store {
    private(set) var memories: [Memory] = []
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("memories.json")
        if ProcessInfo.processInfo.arguments.contains("-reset") { try? FileManager.default.removeItem(at: url) }
        if let data = try? Data(contentsOf: url), let saved = try? Self.decoder.decode([Memory].self, from: data) {
            memories = saved
        } else {
            memories = Self.seed()
        }
    }

    func add(_ m: Memory) { memories.insert(m, at: 0); save() }
    func remove(_ m: Memory) { memories.removeAll { $0.id == m.id }; save() }

    private func save() {
        guard let data = try? Self.encoder.encode(memories) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private static let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
    private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()

    /// A few examples so the first screen isn't empty.
    static func seed() -> [Memory] {
        [("Kal 10 baje gas cylinder book karna yaad dilana", 0),
         ("Imran se 1200 liye", 4),
         ("Maine Ramesh bhaiya ko do hazaar diye, Diwali tak lautayenge", 10),
         ("Aadhaar card almari ke drawer mein rakha hai", 20),
         ("Maine Ramesh bhaiya ko 1500 diye bacche ki fees ke liye", 49)].compactMap { raw, ago in
            guard case .memory(var m) = Brain.understand(raw) else { return nil }
            m.created = Date().addingTimeInterval(-Double(ago) * 86400)
            return Brain.describe(m)
        }
    }
}
