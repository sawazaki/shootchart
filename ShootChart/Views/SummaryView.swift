import SwiftUI

struct SummaryView: View {
    let game: Game

    @State private var filterQuarter: Int? = nil

    private struct PlayerStat: Identifiable {
        let id: UUID
        let number: String
        let name: String
        let fgMade: Int
        let fgTotal: Int
        let ftMade: Int
        let ftTotal: Int
        let travelingCount: Int
        let toOtherCount: Int
        var toTotal: Int { travelingCount + toOtherCount }
        var fgRate: String {
            guard fgTotal > 0 else { return "—" }
            return String(format: "%.0f%%", Double(fgMade) / Double(fgTotal) * 100)
        }
        var ftRate: String {
            guard ftTotal > 0 else { return "—" }
            return String(format: "%.0f%%", Double(ftMade) / Double(ftTotal) * 100)
        }
        var toRate: String {
            let poss = Double(fgTotal) + 0.44 * Double(ftTotal) + Double(toTotal)
            guard poss > 0, toTotal > 0 else { return "—" }
            return String(format: "%.1f%%", Double(toTotal) / poss * 100)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
                .padding()
                .background(Color(UIColor.secondarySystemBackground))

            List {
                Section {
                    HStack {
                        Text("#").frame(width: 36, alignment: .leading).bold()
                        Text("名前").frame(maxWidth: .infinity, alignment: .leading).bold()
                        Text("2P成").frame(width: 52, alignment: .trailing).bold().foregroundColor(.green)
                        Text("2P試").frame(width: 52, alignment: .trailing).bold().foregroundColor(.green)
                        Text("2P%").frame(width: 56, alignment: .trailing).bold().foregroundColor(.green)
                        Text("FT成").frame(width: 52, alignment: .trailing).bold().foregroundColor(.blue)
                        Text("FT試").frame(width: 52, alignment: .trailing).bold().foregroundColor(.blue)
                        Text("FT%").frame(width: 56, alignment: .trailing).bold().foregroundColor(.blue)
                        Text("TV").frame(width: 44, alignment: .trailing).bold().foregroundColor(.orange)
                        Text("その他").frame(width: 44, alignment: .trailing).bold().foregroundColor(.orange)
                        Text("合計").frame(width: 52, alignment: .trailing).bold().foregroundColor(.orange)
                        Text("TO%").frame(width: 52, alignment: .trailing).bold().foregroundColor(.orange)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                ForEach(stats) { stat in
                    NavigationLink(destination: ShotChartView(game: game, initialFilterPlayerId: stat.id)) {
                        HStack {
                            Text(stat.number).frame(width: 36, alignment: .leading).font(.headline)
                            Text(stat.name).frame(maxWidth: .infinity, alignment: .leading)
                            Text(stat.fgTotal > 0 ? "\(stat.fgMade)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.green)
                            Text(stat.fgTotal > 0 ? "\(stat.fgTotal)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.green)
                            Text(stat.fgRate).frame(width: 56, alignment: .trailing).foregroundColor(.green)
                            Text(stat.ftTotal > 0 ? "\(stat.ftMade)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.blue)
                            Text(stat.ftTotal > 0 ? "\(stat.ftTotal)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.blue)
                            Text(stat.ftRate).frame(width: 56, alignment: .trailing).foregroundColor(.blue)
                            Text(stat.travelingCount > 0 ? "\(stat.travelingCount)" : "—").frame(width: 44, alignment: .trailing).foregroundColor(.orange)
                            Text(stat.toOtherCount > 0 ? "\(stat.toOtherCount)" : "—").frame(width: 44, alignment: .trailing).foregroundColor(.orange)
                            Text(stat.toTotal > 0 ? "\(stat.toTotal)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.orange)
                            Text("—").frame(width: 52, alignment: .trailing).foregroundColor(.orange)
                        }
                        .font(.body)
                    }
                }

                if let team = teamTurnoverStat {
                    Section("チームTO") {
                        HStack {
                            Text("チ").frame(width: 36, alignment: .leading).font(.headline).foregroundColor(.orange)
                            Text("チームTO").frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.orange)
                            Text("—").frame(width: 52, alignment: .trailing).foregroundColor(.green).bold()
                            Text("—").frame(width: 52, alignment: .trailing).foregroundColor(.green).bold()
                            Text("—").frame(width: 56, alignment: .trailing).foregroundColor(.green).bold()
                            Text("—").frame(width: 52, alignment: .trailing).foregroundColor(.blue).bold()
                            Text("—").frame(width: 52, alignment: .trailing).foregroundColor(.blue).bold()
                            Text("—").frame(width: 56, alignment: .trailing).foregroundColor(.blue).bold()
                            Text(team.travelingCount > 0 ? "\(team.travelingCount)" : "—").frame(width: 44, alignment: .trailing).foregroundColor(.orange).bold()
                            Text(team.toOtherCount > 0 ? "\(team.toOtherCount)" : "—").frame(width: 44, alignment: .trailing).foregroundColor(.orange).bold()
                            let teamTotal = team.travelingCount + team.toOtherCount
                            Text(teamTotal > 0 ? "\(teamTotal)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.orange).bold()
                            Text("—").frame(width: 52, alignment: .trailing).foregroundColor(.orange).bold()
                        }
                        .font(.body)
                    }
                }

                Section("合計") {
                    HStack {
                        Text("全員").frame(width: 36, alignment: .leading).font(.headline)
                        Spacer()
                        let fgM = stats.reduce(0) { $0 + $1.fgMade }
                        let fgT = stats.reduce(0) { $0 + $1.fgTotal }
                        let ftM = stats.reduce(0) { $0 + $1.ftMade }
                        let ftT = stats.reduce(0) { $0 + $1.ftTotal }
                        let teamTvC = teamTurnoverStat?.travelingCount ?? 0
                        let teamToC = teamTurnoverStat?.toOtherCount ?? 0
                        let tvC = stats.reduce(0) { $0 + $1.travelingCount } + teamTvC
                        let toC = stats.reduce(0) { $0 + $1.toOtherCount } + teamToC
                        let toTotal = tvC + toC
                        Text(fgT > 0 ? "\(fgM)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.green).bold()
                        Text(fgT > 0 ? "\(fgT)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.green).bold()
                        Text(fgT > 0 ? String(format: "%.0f%%", Double(fgM) / Double(fgT) * 100) : "—").frame(width: 56, alignment: .trailing).foregroundColor(.green).bold()
                        Text(ftT > 0 ? "\(ftM)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.blue).bold()
                        Text(ftT > 0 ? "\(ftT)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.blue).bold()
                        Text(ftT > 0 ? String(format: "%.0f%%", Double(ftM) / Double(ftT) * 100) : "—").frame(width: 56, alignment: .trailing).foregroundColor(.blue).bold()
                        Text(tvC > 0 ? "\(tvC)" : "—").frame(width: 44, alignment: .trailing).foregroundColor(.orange).bold()
                        Text(toC > 0 ? "\(toC)" : "—").frame(width: 44, alignment: .trailing).foregroundColor(.orange).bold()
                        Text(toTotal > 0 ? "\(toTotal)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.orange).bold()
                        let toPoss = Double(fgT) + 0.44 * Double(ftT) + Double(toTotal)
                        Text(toPoss > 0 && toTotal > 0 ? String(format: "%.1f%%", Double(toTotal) / toPoss * 100) : "—").frame(width: 52, alignment: .trailing).foregroundColor(.orange).bold()
                    }
                    .font(.body)
                }

                let opp = opponentStats
                if opp.fgTotal > 0 || opp.ftTotal > 0 || opp.travelingCount > 0 || opp.toOtherCount > 0 {
                    Section("相手チーム") {
                        HStack {
                            Text("相手").frame(width: 36, alignment: .leading).font(.headline).foregroundColor(.purple)
                            Text("相手チーム").frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.purple)
                            Text(opp.fgTotal > 0 ? "\(opp.fgMade)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.purple).bold()
                            Text(opp.fgTotal > 0 ? "\(opp.fgTotal)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.purple).bold()
                            Text(opp.fgTotal > 0 ? String(format: "%.0f%%", Double(opp.fgMade) / Double(opp.fgTotal) * 100) : "—").frame(width: 56, alignment: .trailing).foregroundColor(.purple).bold()
                            Text(opp.ftTotal > 0 ? "\(opp.ftMade)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.teal).bold()
                            Text(opp.ftTotal > 0 ? "\(opp.ftTotal)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.teal).bold()
                            Text(opp.ftTotal > 0 ? String(format: "%.0f%%", Double(opp.ftMade) / Double(opp.ftTotal) * 100) : "—").frame(width: 56, alignment: .trailing).foregroundColor(.teal).bold()
                            Text(opp.travelingCount > 0 ? "\(opp.travelingCount)" : "—").frame(width: 44, alignment: .trailing).foregroundColor(.orange).bold()
                            Text(opp.toOtherCount > 0 ? "\(opp.toOtherCount)" : "—").frame(width: 44, alignment: .trailing).foregroundColor(.orange).bold()
                            let oppToTotal = opp.travelingCount + opp.toOtherCount
                            Text(oppToTotal > 0 ? "\(oppToTotal)" : "—").frame(width: 52, alignment: .trailing).foregroundColor(.orange).bold()
                            let oppPoss = Double(opp.fgTotal) + 0.44 * Double(opp.ftTotal) + Double(oppToTotal)
                            Text(oppPoss > 0 && oppToTotal > 0 ? String(format: "%.1f%%", Double(oppToTotal) / oppPoss * 100) : "—").frame(width: 52, alignment: .trailing).foregroundColor(.orange).bold()
                        }
                        .font(.body)
                    }
                }
            }
        }
        .navigationTitle("集計：\(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "全Q", value: nil)
                ForEach(Quarter.allCases) { q in
                    filterChip(label: q.label, value: q.rawValue)
                }
            }
        }
    }

    private func filterChip(label: String, value: Int?) -> some View {
        Button(label) { filterQuarter = value }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(filterQuarter == value ? Color.accentColor : Color(UIColor.tertiarySystemBackground))
            .foregroundColor(filterQuarter == value ? .white : .primary)
            .cornerRadius(8)
            .font(.system(size: 15, weight: .medium))
    }

    private var filteredShots: [Shot] {
        let own = game.shots.filter { !$0.isOpponent }
        guard let q = filterQuarter else { return own }
        return own.filter { $0.quarter == q }
    }

    private var teamTurnoverStat: (travelingCount: Int, toOtherCount: Int)? {
        let shots = (filterQuarter == nil ? game.shots : game.shots.filter { $0.quarter == filterQuarter })
            .filter { $0.isTeamTurnover }
        var tv = 0, other = 0
        for shot in shots {
            if shot.shotType == ShotType.traveling.rawValue { tv += 1 }
            else if shot.shotType == ShotType.turnOver.rawValue { other += 1 }
        }
        guard tv > 0 || other > 0 else { return nil }
        return (tv, other)
    }

    private var opponentStats: (fgMade: Int, fgTotal: Int, ftMade: Int, ftTotal: Int, travelingCount: Int, toOtherCount: Int) {
        let shots = (filterQuarter == nil ? game.shots : game.shots.filter { $0.quarter == filterQuarter })
            .filter { $0.isOpponent }
        var fgMade = 0, fgTotal = 0, ftMade = 0, ftTotal = 0, travelingCount = 0, toOtherCount = 0
        for shot in shots {
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
        return (fgMade, fgTotal, ftMade, ftTotal, travelingCount, toOtherCount)
    }


    private var stats: [PlayerStat] {
        if !game.gamePlayers.isEmpty {
            return game.gamePlayers
                .sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
                .map { gp in
                    var fgMade = 0, fgTotal = 0, ftMade = 0, ftTotal = 0
                    var travelingCount = 0, toOtherCount = 0
                    for shot in filteredShots where shot.playerId == gp.id {
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
                    return PlayerStat(id: gp.id, number: gp.number, name: gp.name,
                                      fgMade: fgMade, fgTotal: fgTotal,
                                      ftMade: ftMade, ftTotal: ftTotal,
                                      travelingCount: travelingCount, toOtherCount: toOtherCount)
                }
        }
        var map: [UUID: (number: String, name: String, fgMade: Int, fgTotal: Int, ftMade: Int, ftTotal: Int, travelingCount: Int, toOtherCount: Int)] = [:]
        for shot in filteredShots {
            guard !shot.isTeamTurnover else { continue }
            var entry = map[shot.playerId] ?? (shot.playerNumber, shot.playerName, 0, 0, 0, 0, 0, 0)
            if shot.shotType == ShotType.freeThrow.rawValue {
                entry.ftTotal += 1
                if shot.isMade { entry.ftMade += 1 }
            } else if shot.shotType == ShotType.traveling.rawValue {
                entry.travelingCount += 1
            } else if shot.shotType == ShotType.turnOver.rawValue {
                entry.toOtherCount += 1
            } else {
                entry.fgTotal += 1
                if shot.isMade { entry.fgMade += 1 }
            }
            map[shot.playerId] = entry
        }
        return map.map { id, val in
            PlayerStat(id: id, number: val.number, name: val.name,
                       fgMade: val.fgMade, fgTotal: val.fgTotal,
                       ftMade: val.ftMade, ftTotal: val.ftTotal,
                       travelingCount: val.travelingCount, toOtherCount: val.toOtherCount)
        }
        .sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
    }
}
