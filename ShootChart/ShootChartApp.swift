import SwiftUI
import SwiftData

@main
struct ShootChartApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [Player.self, Game.self, Shot.self, Roster.self, GamePlayer.self])
    }
}
