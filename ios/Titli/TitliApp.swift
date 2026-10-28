import SwiftUI

@main
struct TitliApp: App {
    init() { AIService.configure() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}
