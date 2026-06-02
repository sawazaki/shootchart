import Foundation
import SwiftData

struct ParsedPlayer {
    let number: String
    let name: String
    let grade: String?
}

enum CSVImportError: LocalizedError {
    case invalidEncoding
    case missingRequiredColumns
    case noValidRows

    var errorDescription: String? {
        switch self {
        case .invalidEncoding: return "CSVファイルの文字コードが読み取れません（UTF-8で保存してください）"
        case .missingRequiredColumns: return "CSVにnumberまたはname列がありません"
        case .noValidRows: return "有効なデータ行が見つかりませんでした"
        }
    }
}

func parseCSV(from url: URL) throws -> [ParsedPlayer] {
    guard url.startAccessingSecurityScopedResource() else {
        throw CSVImportError.invalidEncoding
    }
    defer { url.stopAccessingSecurityScopedResource() }

    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        throw CSVImportError.invalidEncoding
    }

    var lines = text.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    guard !lines.isEmpty else { throw CSVImportError.noValidRows }

    let header = lines.removeFirst()
        .components(separatedBy: ",")
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

    guard let numberIdx = header.firstIndex(of: "number"),
          let nameIdx = header.firstIndex(of: "name") else {
        throw CSVImportError.missingRequiredColumns
    }
    let gradeIdx = header.firstIndex(of: "grade")

    var players: [ParsedPlayer] = []
    for line in lines {
        let cols = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard cols.count > max(numberIdx, nameIdx) else { continue }
        let number = cols[numberIdx]
        let name = cols[nameIdx]
        guard !number.isEmpty, !name.isEmpty else { continue }
        let grade: String? = gradeIdx.flatMap { cols.count > $0 ? cols[$0] : nil }
            .flatMap { $0.isEmpty ? nil : $0 }
        players.append(ParsedPlayer(number: number, name: name, grade: grade))
    }

    guard !players.isEmpty else { throw CSVImportError.noValidRows }
    return players
}

func replaceRosterPlayers(_ parsed: [ParsedPlayer], roster: Roster, context: ModelContext) {
    for player in roster.players { context.delete(player) }
    for p in parsed {
        let player = Player(number: p.number, name: p.name, grade: p.grade)
        player.roster = roster
        context.insert(player)
    }
    try? context.save()
}

func upsertPlayers(_ parsed: [ParsedPlayer], context: ModelContext) {
    let existing = (try? context.fetch(FetchDescriptor<Player>())) ?? []
    var byNumber: [String: Player] = Dictionary(uniqueKeysWithValues: existing.map { ($0.number, $0) })

    for p in parsed {
        if let player = byNumber[p.number] {
            player.name = p.name
            player.grade = p.grade
        } else {
            let player = Player(number: p.number, name: p.name, grade: p.grade)
            context.insert(player)
            byNumber[p.number] = player
        }
    }
    try? context.save()
}
