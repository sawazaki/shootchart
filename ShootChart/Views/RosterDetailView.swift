import SwiftUI
import SwiftData

struct RosterDetailView: View {
    @Environment(\.modelContext) private var context
    let roster: Roster

    @State private var rosterName: String = ""
    @State private var showFilePicker = false
    @State private var importError: String?
    @State private var showError = false
    @State private var successMessage = ""
    @State private var showSuccess = false

    private var sortedPlayers: [Player] {
        roster.players.sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
    }

    var body: some View {
        List {
            Section("ロスター名") {
                TextField("ロスター名", text: $rosterName)
            }

            Section {
                Button {
                    showFilePicker = true
                } label: {
                    Label("CSVファイルを選択", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                HStack {
                    Text("メンバー")
                    Spacer()
                    if !roster.players.isEmpty {
                        Text("登録済み \(roster.players.count)名")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                if roster.players.isEmpty {
                    Text("CSV形式：1行目をヘッダー(number,name,grade)にして保存してください")
                }
            }

            if !sortedPlayers.isEmpty {
                Section {
                    ForEach(sortedPlayers) { player in
                        HStack(spacing: 12) {
                            Text("#\(player.number)")
                                .font(.headline)
                                .frame(width: 48, alignment: .leading)
                            Text(player.name)
                            if let grade = player.grade, !grade.isEmpty {
                                Spacer()
                                Text(grade)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: deletePlayers)
                }
            }
        }
        .navigationTitle(roster.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rosterName = roster.name
        }
        .onDisappear {
            let trimmed = rosterName.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                roster.name = trimmed
                try? context.save()
            }
        }
        .toolbar {
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
                try replaceRosterPlayers(parsed.players, roster: roster, context: context)
                if parsed.skippedRows > 0 {
                    successMessage = "\(parsed.players.count)名のメンバーをインポートしました\n（\(parsed.skippedRows)行は背番号または氏名が未入力のため取り込みませんでした）"
                } else {
                    successMessage = "\(parsed.players.count)名のメンバーをインポートしました"
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
        let sorted = sortedPlayers
        for i in offsets { context.delete(sorted[i]) }
        try? context.save()
    }
}
