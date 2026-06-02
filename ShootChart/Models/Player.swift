import Foundation
import SwiftData

@Model
final class Player {
    var id: UUID
    var number: String
    var name: String
    var grade: String?
    var createdAt: Date
    var roster: Roster? = nil

    init(number: String, name: String, grade: String? = nil) {
        self.id = UUID()
        self.number = number
        self.name = name
        self.grade = grade
        self.createdAt = Date()
    }

    var displayName: String {
        "#\(number) \(name)"
    }
}
