import SwiftUI
import SwiftData

struct ShotChartView: View {
    @Environment(\.modelContext) private var context
    let game: Game

    @Query private var players: [Player]
    @Query(sort: \Roster.createdAt) private var rosters: [Roster]

    @State private var selectedPlayerId: UUID?
    @State private var selectedQuarter: Quarter = .q1
    @State private var isMade: Bool = true
    @State private var shotType: ShotType = .field
    @State private var filterQuarter: Int? = nil
    @State private var filterPlayerId: UUID?
    @State private var selectedShot: Shot?
    @State private var isOpponentMode: Bool = false
    @State private var toSubType: ShotType = .traveling
    @State private var shareURL: IdentifiableURL? = nil
    @State private var showRosterPicker = false

    init(game: Game, initialFilterPlayerId: UUID? = nil) {
        self.game = game
        self._filterPlayerId = State(initialValue: initialFilterPlayerId)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                CourtView(
                    shots: game.shots,
                    selectedShotId: selectedShot?.id,
                    filterQuarter: filterQuarter,
                    filterPlayerId: filterPlayerId,
                    onTap: { norm in recordShot(at: norm) },
                    onShotTap: { shot in
                        selectedShot = (selectedShot?.id == shot.id) ? nil : shot
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    VStack(spacing: 4) {
                        scoreBadge
                        toBadge
                    }
                    .padding(.top, 10)
                }

                if !game.shots.isEmpty {
                    Divider()
                    playerFilterBar
                }
            }

            controlPanel
                .frame(width: 280)
                .background(Color(UIColor.secondarySystemBackground))
        }
        .navigationTitle("\(game.opponent)  \(game.dateFormatted)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SummaryView(game: game)
                } label: {
                    Label("集計", systemImage: "chart.bar")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let data = generateGamePDF(game: game)
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(game.opponent)_report.pdf")
                    try? data.write(to: url)
                    shareURL = IdentifiableURL(url: url)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $shareURL) { item in
            ShareSheetView(items: [item.url])
        }
        .sheet(isPresented: $showRosterPicker) {
            NavigationStack {
                List(rosters) { roster in
                    Button(roster.name) {
                        linkRoster(roster)
                        showRosterPicker = false
                    }
                    .foregroundColor(.primary)
                }
                .navigationTitle("ロスターを選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { showRosterPicker = false }
                    }
                }
            }
        }
        .onAppear {
            if selectedPlayerId == nil {
                selectedPlayerId = sortedPlayers.first?.playerId
            }
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 0) {
            statusBar
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.tertiarySystemBackground))

            Divider()

            // Shot type: 2P / FT / TO
            HStack(spacing: 4) {
                shotTypeButton(label: "2P", type: .field)
                shotTypeButton(label: "FT", type: .freeThrow)
                shotTypeButton(label: "TO", type: .turnOver)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)

            if shotType == .turnOver {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        toSubTypeButton(label: "トラベリング", type: .traveling)
                        toSubTypeButton(label: "その他", type: .turnOver)
                    }
                    Button {
                        recordTurnover(type: toSubType)
                    } label: {
                        Text("TO を記録")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    let toShots = toShotsForCurrentTarget
                    if !toShots.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("記録済みTO").font(.caption).foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(toShots, id: \.id) { shot in
                                        Button {
                                            deleteTurnover(shot)
                                        } label: {
                                            let qLabel = Quarter(rawValue: shot.quarter)?.label ?? "\(shot.quarter)Q"
                                            let typeLabel = shot.shotType == ShotType.traveling.rawValue ? "TV" : "TO"
                                            HStack(spacing: 3) {
                                                Text("\(qLabel) \(typeLabel)")
                                                    .font(.system(size: 12, weight: .bold))
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(Color.orange)
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                // Made / Missed — most prominent control
                HStack(spacing: 8) {
                    resultButton(label: "○  成功", isMadeValue: true, color: .green)
                    resultButton(label: "×  失敗", isMadeValue: false, color: .red)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            Divider()

            // 記録Q + 表示Q (adjacent block)
            quarterSection

            Divider()

            // Player list (fills remaining space)
            playerSection

            Divider()

            // Action buttons — always visible at bottom
            actionButtons
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 6) {
            if isOpponentMode {
                Text("相手チーム")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.purple)
            } else if selectedPlayerId == Shot.ownTeamTurnoverPlayerId {
                Text("チームTO")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.orange)
            } else if let player = sortedPlayers.first(where: { $0.playerId == selectedPlayerId }) {
                Text("#\(player.number)")
                    .font(.system(size: 15, weight: .bold))
                Text(player.name)
                    .font(.system(size: 14))
                    .lineLimit(1)
            } else {
                Text("選手未選択").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(selectedQuarter.label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.accentColor)
            Text("|").foregroundStyle(.secondary)
            Text(isMade ? "○" : "×")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(isMade ? .green : .red)
        }
    }

    // MARK: - Shot Type Buttons

    private func shotTypeButton(label: String, type: ShotType) -> some View {
        Button {
            shotType = type
            selectedShot = nil
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .background(shotType == type ? Color.accentColor : Color(UIColor.tertiarySystemBackground))
        .foregroundColor(shotType == type ? .white : .primary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(shotType == type ? 0 : 0.4), lineWidth: 1.5)
        )
    }

    // MARK: - Result Buttons

    private func resultButton(label: String, isMadeValue: Bool, color: Color) -> some View {
        Button {
            isMade = isMadeValue
            selectedShot = nil
        } label: {
            Text(label)
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 72)
        }
        .background(isMade == isMadeValue ? color : Color(UIColor.tertiarySystemBackground))
        .foregroundColor(isMade == isMadeValue ? .white : color)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(isMade == isMadeValue ? 0 : 0.5), lineWidth: 2)
        )
    }

    private func toSubTypeButton(label: String, type: ShotType) -> some View {
        Button {
            toSubType = type
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .background(toSubType == type ? Color.orange : Color(UIColor.tertiarySystemBackground))
        .foregroundColor(toSubType == type ? .white : .orange)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(toSubType == type ? 0 : 0.5), lineWidth: 1.5)
        )
    }

    // MARK: - Quarter Section (記録Q + 表示Q)

    private var quarterSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("記録Q").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(Quarter.allCases) { q in
                    Button(q.label) {
                        selectedQuarter = q
                        selectedShot = nil
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(selectedQuarter == q ? Color.accentColor : Color(UIColor.tertiarySystemBackground))
                    .foregroundColor(selectedQuarter == q ? .white : .primary)
                    .cornerRadius(6)
                }
            }

            Text("表示Q").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    filterChip(label: "全Q", value: nil)
                    ForEach(Quarter.allCases) { q in
                        filterChip(label: q.label, value: q.rawValue)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func filterChip(label: String, value: Int?) -> some View {
        Button(label) { filterQuarter = value }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(filterQuarter == value ? Color.orange.opacity(0.85) : Color(UIColor.tertiarySystemBackground))
            .foregroundColor(filterQuarter == value ? .white : .primary)
            .cornerRadius(6)
    }

    // MARK: - Player Filter Bar (below court)

    private var playerFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                playerFilterChip(label: "両チーム", value: nil)
                playerFilterChip(label: "相手チーム", value: Shot.opponentPlayerId)
                playerFilterChip(label: "自チーム", value: Shot.ownTeamFilterId)
                ForEach(playersInShots, id: \.id) { p in
                    playerFilterChip(label: "#\(p.number)", value: p.id)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 52)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func playerFilterChip(label: String, value: UUID?) -> some View {
        Button(label) { filterPlayerId = value }
            .font(.system(size: 17, weight: .semibold))
            .frame(minWidth: 54, minHeight: 44)
            .padding(.horizontal, 14)
            .background(filterPlayerId == value ? Color.orange.opacity(0.85) : Color(UIColor.tertiarySystemBackground))
            .foregroundColor(filterPlayerId == value ? .white : .primary)
            .cornerRadius(8)
    }

    private var playersInShots: [(id: UUID, number: String)] {
        var seen = Set<UUID>()
        return game.shots
            .filter { !$0.isOpponent && !$0.isTeamTurnover && seen.insert($0.playerId).inserted }
            .map { (id: $0.playerId, number: $0.playerNumber) }
            .sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
    }

    // MARK: - Player Section

    private struct PlayerEntry: Identifiable {
        let id: PersistentIdentifier
        let playerId: UUID
        let number: String
        let name: String
    }

    private var sortedPlayers: [PlayerEntry] {
        if !game.gamePlayers.isEmpty {
            return game.gamePlayers
                .sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
                .map { PlayerEntry(id: $0.persistentModelID, playerId: $0.id, number: $0.number, name: $0.name) }
        }
        return players
            .sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
            .map { PlayerEntry(id: $0.persistentModelID, playerId: $0.id, number: $0.number, name: $0.name) }
    }

    private func toCountsForPlayer(_ playerId: UUID) -> (tv: Int, other: Int) {
        let shots = game.shots.filter { $0.playerId == playerId }
        let tv = shots.filter { $0.shotType == ShotType.traveling.rawValue }.count
        let other = shots.filter { $0.shotType == ShotType.turnOver.rawValue }.count
        return (tv, other)
    }

    private var playerSection: some View {
        VStack(spacing: 0) {
            Button {
                isOpponentMode = true
                selectedPlayerId = nil
                selectedShot = nil
            } label: {
                HStack(spacing: 10) {
                    Text("相手チーム")
                        .font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if isOpponentMode {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 18))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isOpponentMode ? Color.purple.opacity(0.15) : Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
            }
            .foregroundColor(isOpponentMode ? .purple : .primary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider().padding(.horizontal, 12)

            let teamToC = toCountsForPlayer(Shot.ownTeamTurnoverPlayerId)
            Button {
                selectedPlayerId = Shot.ownTeamTurnoverPlayerId
                isOpponentMode = false
                selectedShot = nil
            } label: {
                HStack(spacing: 10) {
                    Text("チームTO")
                        .font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if teamToC.tv + teamToC.other > 0 {
                        Circle().fill(Color.orange).frame(width: 10, height: 10)
                    }
                    if selectedPlayerId == Shot.ownTeamTurnoverPlayerId {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 18))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    selectedPlayerId == Shot.ownTeamTurnoverPlayerId
                        ? Color.orange.opacity(0.15)
                        : Color(UIColor.tertiarySystemBackground)
                )
                .cornerRadius(8)
            }
            .foregroundColor(selectedPlayerId == Shot.ownTeamTurnoverPlayerId ? .orange : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider().padding(.horizontal, 12)

            HStack {
                Text("選手").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if game.gamePlayers.isEmpty && !rosters.isEmpty {
                    Button {
                        showRosterPicker = true
                    } label: {
                        Label("ロスターを設定", systemImage: "person.2.badge.plus")
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if sortedPlayers.isEmpty {
                Text("メンバー未登録")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(sortedPlayers) { player in
                            Button {
                                selectedPlayerId = player.playerId
                                isOpponentMode = false
                                selectedShot = nil
                            } label: {
                                HStack(spacing: 10) {
                                    Text("#\(player.number)")
                                        .font(.system(size: 22, weight: .bold))
                                        .frame(width: 54, alignment: .leading)
                                    Text(player.name)
                                        .font(.system(size: 16))
                                        .lineLimit(1)
                                    Spacer()
                                    let toC = toCountsForPlayer(player.playerId)
                                    if toC.tv + toC.other > 0 {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 10, height: 10)
                                    }
                                    if selectedPlayerId == player.playerId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accentColor)
                                            .font(.system(size: 18))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    selectedPlayerId == player.playerId
                                        ? Color.accentColor.opacity(0.15)
                                        : Color(UIColor.tertiarySystemBackground)
                                )
                                .cornerRadius(8)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - Score

    private var currentScore: Int {
        let shots = (filterQuarter == nil ? game.shots : game.shots.filter { $0.quarter == filterQuarter })
            .filter { !$0.isOpponent }
        return shots.filter(\.isMade).reduce(0) { sum, shot in
            sum + (shot.shotType == ShotType.freeThrow.rawValue ? 1 : 2)
        }
    }

    private var opponentScore: Int {
        let shots = (filterQuarter == nil ? game.shots : game.shots.filter { $0.quarter == filterQuarter })
            .filter { $0.isOpponent }
        return shots.filter(\.isMade).reduce(0) { sum, shot in
            sum + (shot.shotType == ShotType.freeThrow.rawValue ? 1 : 2)
        }
    }

    private var toCountsForBadge: (tv: Int, other: Int) {
        var shots = game.shots.filter {
            filterQuarter == nil || $0.quarter == filterQuarter
        }
        if let pid = filterPlayerId {
            if pid == Shot.ownTeamFilterId {
                shots = shots.filter { !$0.isOpponent }
            } else if pid == Shot.opponentPlayerId {
                shots = shots.filter { $0.isOpponent }
            } else {
                shots = shots.filter { $0.playerId == pid }
            }
        } else {
            shots = shots.filter { !$0.isOpponent }
        }
        let tv = shots.filter { $0.shotType == ShotType.traveling.rawValue }.count
        let other = shots.filter { $0.shotType == ShotType.turnOver.rawValue }.count
        return (tv, other)
    }

    private var scoreBadge: some View {
        Text("相 \(opponentScore) - 自 \(currentScore)")
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(.black.opacity(0.45))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var toBadge: some View {
        let counts = toCountsForBadge
        let total = counts.tv + counts.other
        if total > 0 {
            Text("TV \(counts.tv)  TO \(counts.other)  合計 \(total)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.8))
                .clipShape(Capsule())
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                undoLastShot()
            } label: {
                Label("直前取消", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(game.shots.isEmpty)

            Button(role: .destructive) {
                deleteSelectedShot()
            } label: {
                Label("削除", systemImage: "trash")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(selectedShot == nil)
        }
    }

    // MARK: - Data Actions

    private func recordShot(at norm: CGPoint) {
        guard shotType != .turnOver else { return }
        if isOpponentMode {
            let shot = Shot(
                playerId: Shot.opponentPlayerId,
                playerNumber: "相",
                playerName: "相手チーム",
                quarter: selectedQuarter.rawValue,
                x: norm.x, y: norm.y,
                isMade: isMade,
                shotType: shotType.rawValue
            )
            shot.game = game
            game.shots.append(shot)
            context.insert(shot)
            try? context.save()
            return
        }
        guard let pid = selectedPlayerId,
              let entry = sortedPlayers.first(where: { $0.playerId == pid }) else { return }
        let shot = Shot(
            playerId: entry.playerId,
            playerNumber: entry.number,
            playerName: entry.name,
            quarter: selectedQuarter.rawValue,
            x: norm.x,
            y: norm.y,
            isMade: isMade,
            shotType: shotType.rawValue
        )
        shot.game = game
        game.shots.append(shot)
        context.insert(shot)
        try? context.save()
    }

    private func deleteSelectedShot() {
        guard let shot = selectedShot else { return }
        game.shots.removeAll { $0.id == shot.id }
        context.delete(shot)
        try? context.save()
        selectedShot = nil
    }

    private func undoLastShot() {
        guard let last = game.shots.sorted(by: { $0.createdAt < $1.createdAt }).last else { return }
        if selectedShot?.id == last.id { selectedShot = nil }
        game.shots.removeAll { $0.id == last.id }
        context.delete(last)
        try? context.save()
    }

    private var toShotsForCurrentTarget: [Shot] {
        let shots = game.shots.filter {
            $0.shotType == ShotType.traveling.rawValue ||
            $0.shotType == ShotType.turnOver.rawValue
        }
        if isOpponentMode {
            return shots.filter { $0.isOpponent }
                .sorted { $0.createdAt < $1.createdAt }
        }
        if selectedPlayerId == Shot.ownTeamTurnoverPlayerId {
            return shots.filter { $0.isTeamTurnover }
                .sorted { $0.createdAt < $1.createdAt }
        }
        guard let pid = selectedPlayerId else { return [] }
        return shots.filter { $0.playerId == pid }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func deleteTurnover(_ shot: Shot) {
        game.shots.removeAll { $0.id == shot.id }
        context.delete(shot)
        try? context.save()
    }

    private func recordTurnover(type: ShotType) {
        if isOpponentMode {
            let shot = Shot(playerId: Shot.opponentPlayerId,
                            playerNumber: "相", playerName: "相手チーム",
                            quarter: selectedQuarter.rawValue,
                            x: 0.5, y: -0.05, isMade: false,
                            shotType: type.rawValue)
            shot.game = game; game.shots.append(shot)
            context.insert(shot); try? context.save()
            return
        }
        if selectedPlayerId == Shot.ownTeamTurnoverPlayerId {
            let shot = Shot(playerId: Shot.ownTeamTurnoverPlayerId,
                            playerNumber: "チ", playerName: "チームTO",
                            quarter: selectedQuarter.rawValue,
                            x: 0.5, y: -0.05, isMade: false,
                            shotType: type.rawValue)
            shot.game = game; game.shots.append(shot)
            context.insert(shot); try? context.save()
            return
        }
        guard let pid = selectedPlayerId,
              let entry = sortedPlayers.first(where: { $0.playerId == pid }) else { return }
        let shot = Shot(playerId: entry.playerId,
                        playerNumber: entry.number, playerName: entry.name,
                        quarter: selectedQuarter.rawValue,
                        x: 0.5, y: -0.05, isMade: false,
                        shotType: type.rawValue)
        shot.game = game; game.shots.append(shot)
        context.insert(shot); try? context.save()
    }

    private func linkRoster(_ roster: Roster) {
        for gp in game.gamePlayers { context.delete(gp) }
        game.gamePlayers.removeAll()
        game.rosterName = roster.name
        for player in roster.players {
            let gp = GamePlayer(id: player.id, number: player.number,
                                name: player.name, grade: player.grade)
            gp.game = game
            game.gamePlayers.append(gp)
            context.insert(gp)
        }
        reassociateShots()
        try? context.save()
    }

    private func reassociateShots() {
        let numberToId = Dictionary(game.gamePlayers.map { ($0.number, $0.id) },
                                    uniquingKeysWith: { _, last in last })
        for shot in game.shots where !shot.isOpponent {
            if let newId = numberToId[shot.playerNumber] {
                shot.playerId = newId
            }
        }
    }
}

// MARK: - Share Sheet

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = vc.popoverPresentationController,
           let window = UIApplication.shared.connectedScenes
               .compactMap({ $0 as? UIWindowScene }).first?.keyWindow {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.width - 56, y: 44, width: 0, height: 0)
        }
        return vc
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
