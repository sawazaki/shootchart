import Foundation
import SwiftData

@Model
final class Game {
    var id: UUID
    var date: Date
    var opponent: String
    var memo: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Shot.game)
    var shots: [Shot] = []
    var rosterName: String = ""
    @Relationship(deleteRule: .cascade, inverse: \GamePlayer.game)
    var gamePlayers: [GamePlayer] = []

    init(date: Date, opponent: String, memo: String = "") {
        self.id = UUID()
        self.date = date
        self.opponent = opponent
        self.memo = memo
        self.createdAt = Date()
        self.shots = []
    }

    var dateFormatted: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
