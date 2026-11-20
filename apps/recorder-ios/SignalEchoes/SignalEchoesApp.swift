import SwiftUI

@main
struct SignalEchoesApp: App {
    var body: some Scene {
        WindowGroup {
            RecorderView()
                .preferredColorScheme(.dark)
        }
    }
}