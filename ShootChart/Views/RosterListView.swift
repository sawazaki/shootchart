import SwiftUI
import SwiftData

struct RosterListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Roster.createdAt) private var rosters: [Roster]

    @State private var showAddRoster = false
    @State private var newRosterName = ""

    var body: some View {
        List {
            ForEach(rosters) { roster in
                NavigationLink(destination: RosterDetailView(roster: roster)) {
                    HStack {
                        Text(roster.name)
                            .font(.body)
                        Spacer()
                        Text("\(roster.players.count)名")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .onDelete(perform: deleteRosters)
        }
        .navigationTitle("ロスター管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newRosterName = ""
                    showAddRoster = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddRoster) {
            NavigationStack {
                Form {
                    Section("ロスター名") {
                        TextField("例：女子チーム", text: $newRosterName)
                    }
                }
                .navigationTitle("新規ロスター")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { showAddRoster = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("作成") {
                            let roster = Roster(name: newRosterName.trimmingCharacters(in: .whitespaces))
                            context.insert(roster)
                            try? context.save()
                            showAddRoster = false
                        }
                        .disabled(newRosterName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func deleteRosters(at offsets: IndexSet) {
        for i in offsets { context.delete(rosters[i]) }
        try? context.save()
    }
}
