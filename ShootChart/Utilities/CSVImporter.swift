import Foundation
import SwiftData

struct ParsedPlayer {
    let number: String
    let name: String
    let grade: String?
}

struct CSVImportResult {
    /// 同一 number は後勝ちで解決済みの選手一覧
    let players: [ParsedPlayer]
    /// number / name が欠落していて無視したデータ行数
    let skippedRows: Int
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

func parseCSV(from url: URL) throws -> CSVImportResult {
    guard url.startAccessingSecurityScopedResource() else {
        throw CSVImportError.invalidEncoding
    }
    defer { url.stopAccessingSecurityScopedResource() }

    guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
        throw CSVImportError.invalidEncoding
    }

    // 先頭の BOM を除去（Excel「CSV UTF-8」対策）
    let text = raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw

    let rows = parseCSVRows(text)
    guard let headerRow = rows.first else { throw CSVImportError.noValidRows }

    let header = headerRow.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
    guard let numberIdx = header.firstIndex(of: "number"),
          let nameIdx = header.firstIndex(of: "name") else {
        throw CSVImportError.missingRequiredColumns
    }
    let gradeIdx = header.firstIndex(of: "grade")

    var ordered: [String] = []
    var byNumber: [String: ParsedPlayer] = [:]
    var skipped = 0

    for cols in rows.dropFirst() {
        // 完全な空行はスキップ扱いにしない
        if cols.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }

        guard cols.count > max(numberIdx, nameIdx) else { skipped += 1; continue }
        let number = cols[numberIdx].trimmingCharacters(in: .whitespaces)
        let name = cols[nameIdx].trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty, !name.isEmpty else { skipped += 1; continue }

        let grade: String? = gradeIdx
            .flatMap { cols.count > $0 ? cols[$0].trimmingCharacters(in: .whitespaces) : nil }
            .flatMap { $0.isEmpty ? nil : $0 }

        let player = ParsedPlayer(number: number, name: name, grade: grade)
        if byNumber[number] == nil { ordered.append(number) }
        byNumber[number] = player  // 同一 number は後勝ち
    }

    let players = ordered.compactMap { byNumber[$0] }
    guard !players.isEmpty else { throw CSVImportError.noValidRows }
    return CSVImportResult(players: players, skippedRows: skipped)
}

/// RFC 4180 準拠の簡易パーサ。引用符付きフィールド・フィールド内カンマ・フィールド内改行に対応。
/// 走査は `Unicode.Scalar` 単位で行う。`Character` 単位だと "\r\n" が1書記素クラスタになり
/// CRLF 改行の CSV で行区切りを認識できなくなるため。
private func parseCSVRows(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var field = ""
    var row: [String] = []
    var inQuotes = false

    let scalars = Array(text.unicodeScalars)
    var i = 0

    func endField() { row.append(field); field = "" }
    func endRow() { endField(); rows.append(row); row = [] }

    while i < scalars.count {
        let s = scalars[i]
        if inQuotes {
            if s == "\"" {
                if i + 1 < scalars.count && scalars[i + 1] == "\"" {
                    field.unicodeScalars.append("\"")
                    i += 1
                } else {
                    inQuotes = false
                }
            } else {
                field.unicodeScalars.append(s)
            }
        } else {
            switch s {
            case "\"":
                inQuotes = true
            case ",":
                endField()
            case "\r":
                if i + 1 < scalars.count && scalars[i + 1] == "\n" { i += 1 }
                endRow()
            case "\n":
                endRow()
            case "\u{FEFF}":
                break  // 念のため途中の BOM は読み飛ばす
            default:
                field.unicodeScalars.append(s)
            }
        }
        i += 1
    }
    // 末尾フィールド/行の取りこぼし防止
    if !field.isEmpty || !row.isEmpty {
        endRow()
    }

    // 完全な空行（1列かつ空）は除去
    return rows.filter { !($0.count == 1 && $0[0].trimmingCharacters(in: .whitespaces).isEmpty) }
}

func replaceRosterPlayers(_ parsed: [ParsedPlayer], roster: Roster, context: ModelContext) throws {
    for player in Array(roster.players) { context.delete(player) }
    for p in parsed {
        let player = Player(number: p.number, name: p.name, grade: p.grade)
        context.insert(player)
        player.roster = roster
    }
    try context.save()
}

func upsertPlayers(_ parsed: [ParsedPlayer], context: ModelContext) throws {
    let existing = (try? context.fetch(FetchDescriptor<Player>())) ?? []
    var byNumber: [String: Player] = Dictionary(existing.map { ($0.number, $0) },
                                                uniquingKeysWith: { _, last in last })

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
    try context.save()
}
