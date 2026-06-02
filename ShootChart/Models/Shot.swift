import Foundation
import SwiftData

@Model
final class Shot {
    var id: UUID
    var playerId: UUID
    var playerNumber: String
    var playerName: String
    var quarter: Int
    var x: Double
    var y: Double
    var isMade: Bool
    var shotType: String = ShotType.field.rawValue
    var createdAt: Date
    var game: Game?

    init(playerId: UUID, playerNumber: String, playerName: String,
         quarter: Int, x: Double, y: Double, isMade: Bool,
         shotType: String = ShotType.field.rawValue) {
        self.id = UUID()
        self.playerId = playerId
        self.playerNumber = playerNumber
        self.playerName = playerName
        self.quarter = quarter
        self.x = x
        self.y = y
        self.isMade = isMade
        self.shotType = shotType
        self.createdAt = Date()
    }
}

enum ShotType: String, CaseIterable {
    case field     = "field"
    case freeThrow = "freeThrow"
    case turnOver  = "turnOver"   // その他TO
    case traveling = "traveling"  // トラベリング
}

extension Shot {
    static let opponentPlayerId        = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let ownTeamFilterId         = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let ownTeamTurnoverPlayerId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    var isOpponent:     Bool { playerId == Shot.opponentPlayerId }
    var isTeamTurnover: Bool { playerId == Shot.ownTeamTurnoverPlayerId }
}

enum Quarter: Int, CaseIterable, Identifiable {
    case q1 = 1, q2 = 2, q3 = 3, q4 = 4, ot1 = 5, ot2 = 6

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .q1: return "1Q"
        case .q2: return "2Q"
        case .q3: return "3Q"
        case .q4: return "4Q"
        case .ot1: return "OT1"
        case .ot2: return "OT2"
        }
    }
}
