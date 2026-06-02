import Foundation
import SwiftData

@Model
final class GamePlayer {
    var id: UUID
    var number: String
    var name: String
    var grade: String?
    var game: Game?

    init(id: UUID, number: String, name: String, grade: String? = nil) {
        self.id = id
        self.number = number
        self.name = name
        self.grade = grade
    }
}
