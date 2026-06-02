import SwiftUI
import UIKit

// MARK: - Public API

@MainActor
func generateGamePDF(game: Game) -> Data {
    let bounds = CGRect(x: 0, y: 0, width: 842, height: 595)
    let renderer = UIGraphicsPDFRenderer(bounds: bounds)
    let selfQuarters = Set(game.shots.filter { !$0.isOpponent }.map { $0.quarter }).sorted()
    let oppQuarters  = Set(game.shots.filter { $0.isOpponent  }.map { $0.quarter }).sorted()
    return renderer.pdfData { ctx in
        ctx.beginPage()
        drawPage(PDFCourtPage(game: game, isOpponent: false, quarter: nil), in: bounds)
        for q in selfQuarters {
            ctx.beginPage()
            drawPage(PDFCourtPage(game: game, isOpponent: false, quarter: q), in: bounds)
        }
        ctx.beginPage()
        drawPage(PDFCourtPage(game: game, isOpponent: true, quarter: nil), in: bounds)
        for q in oppQuarters {
            ctx.beginPage()
            drawPage(PDFCourtPage(game: game, isOpponent: true, quarter: q), in: bounds)
        }
        ctx.beginPage()
        drawPage(PDFStatsPage(game: game), in: bounds)
    }
}

@MainActor
private func drawPage<V: View>(_ view: V, in bounds: CGRect) {
    let r = ImageRenderer(content: view.frame(width: bounds.width, height: bounds.height))
    r.scale = 2.0
    r.uiImage?.draw(in: bounds)
}

// MARK: - Court Page

private struct PDFCourtPage: View {
    let game: Game
    let isOpponent: Bool
    let quarter: Int?

    private var quarterLabel: String {
        guard let q = quarter else { return "全Q" }
        return Quarter(rawValue: q)?.label ?? "\(q)Q"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("vs \(game.opponent)")
                    .font(.system(size: 18, weight: .bold))
                Text("\(game.dateFormatted)　\(isOpponent ? "相手チーム" : "自チーム")　\(quarterLabel)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)
            .padding(.bottom, 8)

            CourtView(
                shots: game.shots,
                selectedShotId: nil,
                filterQuarter: quarter,
                filterPlayerId: isOpponent ? Shot.opponentPlayerId : Shot.ownTeamFilterId,
                onTap: { _ in },
                onShotTap: { _ in }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .background(Color.white)
    }
}

// MARK: - Stats Page

private struct PDFStatsPage: View {
    let game: Game

    private struct Stat {
        let number: String
        let name: String
        let fgMade: Int
        let fgTotal: Int
        let ftMade: Int
        let ftTotal: Int
        let travelingCount: Int
        let toOtherCount: Int
        var toTotal: Int { travelingCount + toOtherCount }
        var fgRate: String { fgTotal > 0 ? String(format: "%.0f%%", Double(fgMade) / Double(fgTotal) * 100) : "—" }
        var ftRate: String { ftTotal > 0 ? String(format: "%.0f%%", Double(ftMade) / Double(ftTotal) * 100) : "—" }
        var toRate: String {
            let poss = Double(fgTotal) + 0.44 * Double(ftTotal) + Double(toTotal)
            guard poss > 0, toTotal > 0 else { return "—" }
            return String(format: "%.1f%%", Double(toTotal) / poss * 100)
        }
    }

    private var playerStats: [Stat] {
        if !game.gamePlayers.isEmpty {
            return game.gamePlayers
                .sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
                .map { gp in
                    var fgMade = 0, fgTotal = 0, ftMade = 0, ftTotal = 0
                    var travelingCount = 0, toOtherCount = 0
                    for shot in game.shots where !shot.isOpponent && shot.playerId == gp.id {
                        if shot.shotType == ShotType.freeThrow.rawValue {
                            ftTotal += 1; if shot.isMade { ftMade += 1 }
                        } else if shot.shotType == ShotType.traveling.rawValue {
                            travelingCount += 1
                        } else if shot.shotType == ShotType.turnOver.rawValue {
                            toOtherCount += 1
                        } else {
                            fgTotal += 1; if shot.isMade { fgMade += 1 }
                        }
                    }
                    return Stat(number: gp.number, name: gp.name,
                                fgMade: fgMade, fgTotal: fgTotal,
                                ftMade: ftMade, ftTotal: ftTotal,
                                travelingCount: travelingCount, toOtherCount: toOtherCount)
                }
        }
        var map: [UUID: (number: String, name: String, fgMade: Int, fgTotal: Int, ftMade: Int, ftTotal: Int, travelingCount: Int, toOtherCount: Int)] = [:]
        for shot in game.shots where !shot.isOpponent {
            guard !shot.isTeamTurnover else { continue }
            var e = map[shot.playerId] ?? (shot.playerNumber, shot.playerName, 0, 0, 0, 0, 0, 0)
            if shot.shotType == ShotType.freeThrow.rawValue {
                e.ftTotal += 1; if shot.isMade { e.ftMade += 1 }
            } else if shot.shotType == ShotType.traveling.rawValue {
                e.travelingCount += 1
            } else if shot.shotType == ShotType.turnOver.rawValue {
                e.toOtherCount += 1
            } else {
                e.fgTotal += 1; if shot.isMade { e.fgMade += 1 }
            }
            map[shot.playerId] = e
        }
        return map.map { _, v in
            Stat(number: v.number, name: v.name,
                 fgMade: v.fgMade, fgTotal: v.fgTotal,
                 ftMade: v.ftMade, ftTotal: v.ftTotal,
                 travelingCount: v.travelingCount, toOtherCount: v.toOtherCount)
        }
        .sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
    }

    private var teamTurnoverStat: (travelingCount: Int, toOtherCount: Int)? {
        var tv = 0, other = 0
        for shot in game.shots where shot.isTeamTurnover {
            if shot.shotType == ShotType.traveling.rawValue { tv += 1 }
            else if shot.shotType == ShotType.turnOver.rawValue { other += 1 }
        }
        guard tv > 0 || other > 0 else { return nil }
        return (tv, other)
    }

    private var opponentStat: Stat? {
        var fgMade = 0, fgTotal = 0, ftMade = 0, ftTotal = 0
        var travelingCount = 0, toOtherCount = 0
        for shot in game.shots where shot.isOpponent {
            if shot.shotType == ShotType.freeThrow.rawValue {
                ftTotal += 1; if shot.isMade { ftMade += 1 }
            } else if shot.shotType == ShotType.traveling.rawValue {
                travelingCount += 1
            } else if shot.shotType == ShotType.turnOver.rawValue {
                toOtherCount += 1
            } else {
                fgTotal += 1; if shot.isMade { fgMade += 1 }
            }
        }
        guard fgTotal > 0 || ftTotal > 0 || travelingCount > 0 || toOtherCount > 0 else { return nil }
        return Stat(number: "相", name: "相手チーム",
                    fgMade: fgMade, fgTotal: fgTotal,
                    ftMade: ftMade, ftTotal: ftTotal,
                    travelingCount: travelingCount, toOtherCount: toOtherCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("vs \(game.opponent)")
                    .font(.system(size: 18, weight: .bold))
                Text("\(game.dateFormatted)　集計")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)
            .padding(.bottom, 10)

            columnHeader

            Divider()

            ForEach(Array(playerStats.enumerated()), id: \.offset) { _, stat in
                statRow(
                    number: stat.number, name: stat.name,
                    fg1: stat.fgTotal > 0 ? "\(stat.fgMade)" : "—",
                    fg2: stat.fgTotal > 0 ? "\(stat.fgTotal)" : "—",
                    fg3: stat.fgRate,
                    ft1: stat.ftTotal > 0 ? "\(stat.ftMade)" : "—",
                    ft2: stat.ftTotal > 0 ? "\(stat.ftTotal)" : "—",
                    ft3: stat.ftRate,
                    to1: stat.travelingCount > 0 ? "\(stat.travelingCount)" : "—",
                    to2: stat.toOtherCount > 0 ? "\(stat.toOtherCount)" : "—",
                    to3: stat.toTotal > 0 ? "\(stat.toTotal)" : "—",
                    to4: "—",
                    fgColor: .green, ftColor: .blue
                )
            }

            Divider()

            if let team = teamTurnoverStat {
                statRow(
                    number: "チ", name: "チームTO",
                    fg1: "—", fg2: "—", fg3: "—",
                    ft1: "—", ft2: "—", ft3: "—",
                    to1: team.travelingCount > 0 ? "\(team.travelingCount)" : "—",
                    to2: team.toOtherCount > 0 ? "\(team.toOtherCount)" : "—",
                    to3: team.travelingCount + team.toOtherCount > 0 ? "\(team.travelingCount + team.toOtherCount)" : "—",
                    to4: "—",
                    fgColor: .green, ftColor: .blue, toColor: .orange, isBold: true
                )
            }

            Divider().padding(.top, 2)

            totalRow

            if let opp = opponentStat {
                Divider().padding(.top, 6)
                statRow(
                    number: "相", name: "相手チーム",
                    fg1: opp.fgTotal > 0 ? "\(opp.fgMade)" : "—",
                    fg2: opp.fgTotal > 0 ? "\(opp.fgTotal)" : "—",
                    fg3: opp.fgRate,
                    ft1: opp.ftTotal > 0 ? "\(opp.ftMade)" : "—",
                    ft2: opp.ftTotal > 0 ? "\(opp.ftTotal)" : "—",
                    ft3: opp.ftRate,
                    to1: opp.travelingCount > 0 ? "\(opp.travelingCount)" : "—",
                    to2: opp.toOtherCount > 0 ? "\(opp.toOtherCount)" : "—",
                    to3: opp.toTotal > 0 ? "\(opp.toTotal)" : "—",
                    to4: opp.toRate,
                    fgColor: .purple, ftColor: .teal, isBold: true
                )
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color.white)
    }

    private var columnHeader: some View {
        statRow(
            number: "#", name: "名前",
            fg1: "2P成", fg2: "2P試", fg3: "2P%",
            ft1: "FT成", ft2: "FT試", ft3: "FT%",
            to1: "TV", to2: "その他", to3: "合計", to4: "TO%",
            fgColor: .green, ftColor: .blue, isBold: true
        )
        .foregroundColor(.secondary)
    }

    private var totalRow: some View {
        let fgM = playerStats.reduce(0) { $0 + $1.fgMade }
        let fgT = playerStats.reduce(0) { $0 + $1.fgTotal }
        let ftM = playerStats.reduce(0) { $0 + $1.ftMade }
        let ftT = playerStats.reduce(0) { $0 + $1.ftTotal }
        let teamTvC = teamTurnoverStat?.travelingCount ?? 0
        let teamToOC = teamTurnoverStat?.toOtherCount ?? 0
        let tvC = playerStats.reduce(0) { $0 + $1.travelingCount } + teamTvC
        let toOC = playerStats.reduce(0) { $0 + $1.toOtherCount } + teamToOC
        let toTotal = tvC + toOC
        let toPoss = Double(fgT) + 0.44 * Double(ftT) + Double(toTotal)
        return statRow(
            number: "", name: "全員",
            fg1: fgT > 0 ? "\(fgM)" : "—",
            fg2: fgT > 0 ? "\(fgT)" : "—",
            fg3: fgT > 0 ? String(format: "%.0f%%", Double(fgM) / Double(fgT) * 100) : "—",
            ft1: ftT > 0 ? "\(ftM)" : "—",
            ft2: ftT > 0 ? "\(ftT)" : "—",
            ft3: ftT > 0 ? String(format: "%.0f%%", Double(ftM) / Double(ftT) * 100) : "—",
            to1: tvC > 0 ? "\(tvC)" : "—",
            to2: toOC > 0 ? "\(toOC)" : "—",
            to3: toTotal > 0 ? "\(toTotal)" : "—",
            to4: toPoss > 0 && toTotal > 0 ? String(format: "%.1f%%", Double(toTotal) / toPoss * 100) : "—",
            fgColor: .green, ftColor: .blue, isBold: true
        )
    }

    private func statRow(number: String, name: String,
                         fg1: String, fg2: String, fg3: String,
                         ft1: String, ft2: String, ft3: String,
                         to1: String, to2: String, to3: String, to4: String,
                         fgColor: Color, ftColor: Color, toColor: Color = .orange,
                         isBold: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(number)
                .frame(width: 36, alignment: .leading)
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(fg1).frame(width: 52, alignment: .trailing).foregroundColor(fgColor)
            Text(fg2).frame(width: 52, alignment: .trailing).foregroundColor(fgColor)
            Text(fg3).frame(width: 56, alignment: .trailing).foregroundColor(fgColor)
            Text(ft1).frame(width: 52, alignment: .trailing).foregroundColor(ftColor)
            Text(ft2).frame(width: 52, alignment: .trailing).foregroundColor(ftColor)
            Text(ft3).frame(width: 56, alignment: .trailing).foregroundColor(ftColor)
            Text(to1).frame(width: 44, alignment: .trailing).foregroundColor(toColor)
            Text(to2).frame(width: 44, alignment: .trailing).foregroundColor(toColor)
            Text(to3).frame(width: 48, alignment: .trailing).foregroundColor(toColor)
            Text(to4).frame(width: 48, alignment: .trailing).foregroundColor(toColor)
        }
        .font(isBold ? .system(size: 13, weight: .bold) : .system(size: 13))
        .padding(.vertical, 5)
    }
}
