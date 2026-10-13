import SwiftUI
import SwiftData

struct PlayerListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Player.number) private var players: [Player]

    @State private var showFilePicker = false
    @State private var importError: String?
    @State private var showError = false
    @State private var successMessage = ""
    @State private var showSuccess = false

    var body: some View {
        List {
            ForEach(players) { player in
                HStack(spacing: 16) {
                    Text("#\(player.number)")
                        .font(.title2.bold())
                        .frame(width: 70, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name).font(.title3)
                        if let grade = player.grade, !grade.isEmpty {
                            Text(grade).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deletePlayers)
        }
        .navigationTitle("メンバー管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilePicker = true
                } label: {
                    Label("CSVインポート", systemImage: "square.and.arrow.down")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("インポートエラー", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .alert("インポート完了", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage)
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let parsed = try parseCSV(from: url)
                try upsertPlayers(parsed.players, context: context)
                if parsed.skippedRows > 0 {
                    successMessage = "\(parsed.players.count)件の選手データをインポートしました\n（\(parsed.skippedRows)行は背番号または氏名が未入力のため取り込みませんでした）"
                } else {
                    successMessage = "\(parsed.players.count)件の選手データをインポートしました"
                }
                showSuccess = true
            } catch {
                importError = error.localizedDescription
                showError = true
            }
        case .failure(let error):
            importError = error.localizedDescription
            showError = true
        }
    }

    private func deletePlayers(at offsets: IndexSet) {
        for i in offsets {
            context.delete(players[i])
        }
        try? context.save()
    }
}
