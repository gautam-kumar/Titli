import FirebaseAILogic
import FirebaseAppCheck
import FirebaseCore
import Foundation
import TitliCore

/// Gemini (free tier) through Firebase AI Logic. Only what was said and the memories' text details are sent;
/// files and photos stay on the phone. If Firebase isn't set up, the call fails or it's too slow,
/// callers fall back to the on-phone parser in TitliCore.
enum AIService {
    private(set) static var ready = false
    private static var model: GenerativeModel?
    private static var modelDay = ""

    /// Call once at launch. Does nothing when GoogleService-Info.plist isn't in the app.
    static func configure() {
        guard !ProcessInfo.processInfo.arguments.contains("-offline"),
              Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        AppCheck.setAppCheckProviderFactory(AppCheckFactory())
        FirebaseApp.configure()
        ready = true
    }

    static func understand(_ said: String, memories: [Memory], timeout: Double = 6) async -> AIResult? {
        guard ready else { return nil }
        let prompt = AI.request(said: said, memories: memories)
        let text: String? = await withTaskGroup(of: String?.self) { group in
            group.addTask {
                do { return try await currentModel().generateContent(prompt).text } catch { print("Titli AI:", error); return nil }
            }
            group.addTask { try? await Task.sleep(for: .seconds(timeout)); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard let text, let reply = AI.decode(text) else { return nil }
        return AI.interpret(reply, said: said, memories: memories)
    }

    /// The model carries today's date in its instructions, so it's rebuilt when the day changes.
    @MainActor private static func currentModel() -> GenerativeModel {
        let day = Format.short(Date())
        if let model, day == modelDay { return model }
        let config = GenerationConfig(temperature: 0.2, responseMIMEType: "application/json", responseSchema: schema)
        let m = FirebaseAI.firebaseAI(backend: .googleAI())
            .generativeModel(modelName: AI.model, generationConfig: config, systemInstruction: ModelContent(role: "system", parts: AI.instructions()))
        model = m; modelDay = day
        return m
    }

    private static let schema = Schema.object(
        properties: [
            "intent": .enumeration(values: ["save", "ask"]),
            "kind": .enumeration(values: ["give", "take", "doc", "remind", "note"]),
            "amount": .integer(),
            "person": .string(),
            "due": .string(),
            "dueDate": .string(),
            "time": .string(),
            "doc": .string(),
            "place": .string(),
            "what": .string(),
            "why": .string(),
            "answerKind": .enumeration(values: ["money", "doc", "when", "note", "none"]),
            "matches": .array(items: .integer()),
            "say": .string(),
        ],
        optionalProperties: ["kind", "amount", "person", "due", "dueDate", "time", "doc", "place", "what", "why", "answerKind", "matches", "say"]
    )
}

/// App Attest on a real iPhone proves requests come from this app, so nobody can use the Firebase key elsewhere.
private final class AppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        AppCheckDebugProvider(app: app)
        #else
        AppAttestProvider(app: app)
        #endif
    }
}
