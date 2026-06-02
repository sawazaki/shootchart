import SwiftUI
import SwiftData

struct GameEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Roster.createdAt) private var rosters: [Roster]

    var game: Game?

    @State private var date: Date
    @State private var opponent: String
    @State private var memo: String
    @State private var selectedRoster: Roster?

    init(game: Game? = nil) {
        self.game = game
        _date = State(initialValue: game?.date ?? Date())
        _opponent = State(initialValue: game?.opponent ?? "")
        _memo = State(initialValue: game?.memo ?? "")
        _selectedRoster = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("試合情報") {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    HStack {
                        Text("対戦相手")
                        TextField("チーム名", text: $opponent)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("メモ") {
                    TextEditor(text: $memo)
                        .frame(minHeight: 80)
                }

                memberSection
            }
            .navigationTitle(game == nil ? "試合を作成" : "試合を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(opponent.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if selectedRoster == nil {
                    if let game = game {
                        selectedRoster = rosters.first(where: { $0.name == game.rosterName })
                        if selectedRoster == nil && game.gamePlayers.isEmpty {
                            selectedRoster = rosters.first
                        }
                    } else {
                        selectedRoster = rosters.first
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var memberSection: some View {
        Section {
            if rosters.isEmpty {
                NavigationLink(destination: RosterListView()) {
                    Label("ロスターを作成する", systemImage: "plus.circle")
                        .foregroundColor(.accentColor)
                }
            } else {
                Picker("ロスター", selection: $selectedRoster) {
                    Text("未選択").tag(Optional<Roster>.none)
                    ForEach(rosters) { roster in
                        Text(roster.name).tag(Optional(roster))
                    }
                }
                if let roster = selectedRoster {
                    ForEach(roster.players.sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }) { player in
                        HStack(spacing: 12) {
                            Text("#\(player.number)")
                                .font(.headline)
                                .frame(width: 48, alignment: .leading)
                                .foregroundStyle(.secondary)
                            Text(player.name)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("メンバー")
        } footer: {
            if let existingGame = game, !existingGame.gamePlayers.isEmpty, selectedRoster != nil {
                Text("保存するとメンバーが選択したロスターの内容に更新されます")
            } else if selectedRoster == nil && !rosters.isEmpty {
                Text("ロスターを選択すると試合に選手を登録できます")
            }
        }
    }

    private func save() {
        if let game {
            game.date = date
            game.opponent = opponent.trimmingCharacters(in: .whitespaces)
            game.memo = memo
            if selectedRoster != nil {
                for gp in game.gamePlayers { context.delete(gp) }
                game.gamePlayers.removeAll()
                snapshotRoster(into: game)
            }
        } else {
            let g = Game(date: date,
                         opponent: opponent.trimmingCharacters(in: .whitespaces),
                         memo: memo)
            context.insert(g)
            snapshotRoster(into: g)
        }
        try? context.save()
        dismiss()
    }

    private func snapshotRoster(into game: Game) {
        guard let roster = selectedRoster else { return }
        game.rosterName = roster.name
        for player in roster.players {
            let gp = GamePlayer(id: player.id, number: player.number,
                                name: player.name, grade: player.grade)
            game.gamePlayers.append(gp)
            context.insert(gp)
        }
        let numberToId = Dictionary(game.gamePlayers.map { ($0.number, $0.id) },
                                    uniquingKeysWith: { _, last in last })
        for shot in game.shots where !shot.isOpponent {
            if let newId = numberToId[shot.playerNumber] {
                shot.playerId = newId
            }
        }
    }
}
