import SwiftUI

@main
struct SchlaglaengeApp: App {
    @StateObject private var store = ShotStore()
    @StateObject private var gps = LocationEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(gps)
        }
    }
}

extension Color {
    /// Navy der Homepage zulugolf.de (#1b2233)
    static let zuluNavy = Color(red: 27 / 255, green: 34 / 255, blue: 51 / 255)
    /// Gelb aus dem ZG-Logo (#ffc20a)
    static let zuluYellow = Color(red: 255 / 255, green: 194 / 255, blue: 10 / 255)
}
