import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Game.date, order: .reverse) private var games: [Game]

    @Environment(\.editMode) private var editMode

    @State private var showNewGame = false
    @State private var editingGame: Game?
    @State private var deletingGame: Game?
    @State private var chartGame: Game?
    @State private var summaryGame: Game?

    var body: some View {
        NavigationStack {
            List {
                if games.isEmpty {
                    ContentUnavailableView(
                        "試合がありません",
                        systemImage: "sportscourt",
                        description: Text("右上の「＋」から試合を登録してください")
                    )
                    .listRowBackground(Color.clear)
                }
                ForEach(games) { game in
                    gameRow(game: game)
                }
                .onDelete(perform: deleteGames)
            }
            .navigationTitle("ShootChart")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: RosterListView()) {
                        Text("ロスター表管理")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editMode?.wrappedValue.isEditing == true ? "完了" : "試合編集") {
                        withAnimation {
                            editMode?.wrappedValue = editMode?.wrappedValue.isEditing == true ? .inactive : .active
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewGame = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(item: $chartGame) { ShotChartView(game: $0) }
            .navigationDestination(item: $summaryGame) { SummaryView(game: $0) }
            .sheet(isPresented: $showNewGame) {
                GameEditView()
            }
            .sheet(item: $editingGame) { game in
                GameEditView(game: game)
            }
        }
    }

    @ViewBuilder
    private func gameRow(game: Game) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("vs \(game.opponent)")
                    .font(.title3.bold())
                HStack(spacing: 12) {
                    Text(game.dateFormatted)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    let madeCount = game.shots.filter { $0.isMade }.count
                    let total = game.shots.count
                    if total > 0 {
                        Text("🏀 \(madeCount)/\(total)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                if !game.memo.isEmpty {
                    Text(game.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)

            Spacer()

            Button { chartGame = game } label: {
                Label("ショットチャート", systemImage: "sportscourt.fill")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.bordered)

            Button { summaryGame = game } label: {
                Label("ショット率一覧", systemImage: "chart.bar.fill")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.orange)

            Button {
                editingGame = game
            } label: {
                Image(systemName: "pencil")
                    .font(.title3)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
    }

    private func deleteGames(at offsets: IndexSet) {
        for i in offsets {
            context.delete(games[i])
        }
        try? context.save()
    }
}
