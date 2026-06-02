# ShootChart バックエンド仕様書

データ永続化・モデル定義・CSV インポートロジックの仕様。

---

## 技術スタック

| 項目 | 内容 |
|---|---|
| 永続化フレームワーク | SwiftData（iOS 17.0+） |
| ストレージ | オンデバイス SQLite（iCloud 同期なし） |
| データアクセス | `@Environment(\.modelContext)` / `@Query` |
| 最低 OS | iOS 17.0（Xcode 15+ 必須） |

---

## ModelContainer 設定

エントリポイント（`ShootChartApp.swift`）で 3 モデルを登録する。

```swift
// ShootChart/ShootChartApp.swift
WindowGroup {
    HomeView()
}
.modelContainer(for: [Player.self, Game.self, Shot.self])
```

- `Player` は `Game` / `Shot` と SwiftData のリレーション**なし**（独立した別テーブル）
- `Game` → `Shot` は `@Relationship(deleteRule: .cascade)` で連結

---

## データモデル

### Player

グローバルなメンバーロスター。どの試合にも紐付かない独立したエンティティ。

```swift
// ShootChart/Models/Player.swift
@Model final class Player {
    var id: UUID          // 主キー（自動生成）
    var number: String    // 背番号（upsert キー）
    var name: String      // 選手名
    var grade: String?    // 学年（任意・画面非表示）
    var createdAt: Date   // 登録日時
}
```

**計算プロパティ:**

```swift
var displayName: String { "#\(number) \(name)" }
```

**設計意図:**
- `number` を upsert キーとして使用するため、`UUID` ではなく `String` で管理
- `grade` はCSVからインポートされるが UI には表示しない（将来利用の余地あり）

---

### Game

1試合を表すエンティティ。所有する `Shot` を cascade 削除する。

```swift
// ShootChart/Models/Game.swift
@Model final class Game {
    var id: UUID          // 主キー（自動生成）
    var date: Date        // 試合日
    var opponent: String  // 対戦相手名
    var memo: String      // メモ（空文字可）
    var createdAt: Date   // 作成日時

    @Relationship(deleteRule: .cascade, inverse: \Shot.game)
    var shots: [Shot]     // 所有するショット一覧（初期値 []）
}
```

**計算プロパティ:**

```swift
var dateFormatted: String  // "2024年4月1日"（ja_JP ロケール）
```

---

### Shot

コート上の1本のショットを表すエンティティ。

```swift
// ShootChart/Models/Shot.swift
@Model final class Shot {
    var id: UUID             // 主キー（自動生成）
    var playerId: UUID       // 記録時点の Player.id（参照用）
    var playerNumber: String // 記録時点の背番号（非正規化）
    var playerName: String   // 記録時点の選手名（非正規化）
    var quarter: Int         // クォーター（後述の Quarter enum 参照）
    var x: Double            // コート上の横位置（0.0–1.0）
    var y: Double            // コート上の縦位置（0.0–1.0）
    var isMade: Bool         // 成功 = true / 失敗 = false
    var shotType: String = ShotType.field.rawValue  // ショット種別（後述の ShotType enum 参照）
    var createdAt: Date      // 記録日時
    var game: Game?          // 所属する試合（@Relationship の inverse）
}
```

**座標系:**
- `x = 0.0`: 左ベースライン、`x = 1.0`: 右ベースライン
- `y = 0.0`: 上サイドライン、`y = 1.0`: 下サイドライン
- 画面サイズ・デバイスに依存しない正規化座標で保存

**非正規化の設計意図:**
- `playerNumber` / `playerName` を Shot 側にコピーすることで、選手情報が後から編集・削除されても過去のショット履歴の表示が維持される
- `playerId` は集計時の同一選手グルーピングに使用するが、存在しなくなった Player を指す場合も許容する

---

### Quarter enum

`Shot.swift` 内に定義。アプリ全体で唯一の Quarter 定義。

```swift
enum Quarter: Int, CaseIterable, Identifiable {
    case q1 = 1, q2 = 2, q3 = 3, q4 = 4, ot1 = 5, ot2 = 6

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .q1:  return "1Q"
        case .q2:  return "2Q"
        case .q3:  return "3Q"
        case .q4:  return "4Q"
        case .ot1: return "OT1"
        case .ot2: return "OT2"
        }
    }
}
```

| rawValue | 意味 |
|---|---|
| 1 | 第1クォーター |
| 2 | 第2クォーター |
| 3 | 第3クォーター |
| 4 | 第4クォーター |
| 5 | 延長第1ピリオド |
| 6 | 延長第2ピリオド |

Shot モデルでは `Int` として保存し、表示時に `Quarter(rawValue:)` で変換する。

---

### ShotType enum

`Shot.swift` 内に定義。ショットの種別を表す。

```swift
enum ShotType: String, CaseIterable {
    case field     = "field"       // フィールドゴール（2P）
    case freeThrow = "freeThrow"   // フリースロー（FT）
}
```

| rawValue | 意味 |
|---|---|
| `"field"` | フィールドゴール（2P）。デフォルト |
| `"freeThrow"` | フリースロー（FT） |

Shot モデルでは `String` として保存。コートマーカーの色分けと集計の FG/FT 分離に使用する。

---

## モデル間のリレーション

```
Player          Game ─── Shot
（独立）         1   ─── *

Game.shots: [Shot]
  @Relationship(deleteRule: .cascade, inverse: \Shot.game)

Shot.game: Game?
  （Game 削除時に Shot も自動削除される）
```

- **Player ↔ Game/Shot**: SwiftData のリレーション**なし**。Player を削除しても Shot は残る（`playerNumber` / `playerName` が非正規化で保持されるため表示可能）
- **Game → Shot**: cascade 削除。Game を削除すると所属する全 Shot が削除される

---

## CSV インポートロジック

### ParsedPlayer（中間構造体）

```swift
// ShootChart/Utilities/CSVImporter.swift
struct ParsedPlayer {
    let number: String
    let name: String
    let grade: String?
}
```

### parseCSV(from:)

```swift
func parseCSV(from url: URL) throws -> [ParsedPlayer]
```

**処理フロー:**

1. `url.startAccessingSecurityScopedResource()` でファイルアクセス権取得（Files アプリ経由の URL に必要）
2. `String(contentsOf: url, encoding: .utf8)` で読み込み（UTF-8 固定）
3. 改行で分割・空行除去
4. 1行目をヘッダーとして解析（小文字に正規化してカンマ分割）
5. `number` 列・`name` 列のインデックスを確認（なければ `missingRequiredColumns` エラー）
6. 2行目以降を各行パース（列不足・必須値空行はスキップ）
7. 有効行が0件なら `noValidRows` エラー

**CSVImportError:**

| ケース | ユーザー向けメッセージ |
|---|---|
| `invalidEncoding` | CSVファイルの文字コードが読み取れません（UTF-8で保存してください） |
| `missingRequiredColumns` | CSVにnumberまたはname列がありません |
| `noValidRows` | 有効なデータ行が見つかりませんでした |

### upsertPlayers(_:context:)

```swift
func upsertPlayers(_ parsed: [ParsedPlayer], context: ModelContext)
```

**処理フロー:**

1. 全 Player を `context.fetch` で取得し、`number → Player` の辞書を作成
2. 各 `ParsedPlayer` について:
   - 同じ `number` の Player が存在 → `name` / `grade` を上書き
   - 存在しない → 新規 `Player` を `context.insert`
3. `context.save()` で確定

**upsert キーは `number`（背番号）**。同じ番号の選手を再インポートすると名前・学年が更新される。

---

## データ永続化フロー

### ショット記録（ShotChartView.recordShot）

```
1. Shot インスタンス生成（playerNumber/playerName/shotType をコピー）
2. shot.game = game（所属関係を設定）
3. game.shots.append(shot)
4. context.insert(shot)
5. context.save()
```

### ショット削除（ShotChartView.deleteSelectedShot）

```
1. game.shots.removeAll { $0.id == shot.id }
2. context.delete(shot)
3. context.save()
4. selectedShot = nil
```

### undo（直前のショット取消）

```
1. game.shots を createdAt 昇順ソートし last を取得
2. 選択中のショットが last と一致する場合 selectedShot = nil
3. game.shots.removeAll { $0.id == last.id }
4. context.delete(last)
5. context.save()
```

### 試合削除（HomeView.deleteGames）

```
context.delete(game)
// Game の @Relationship(deleteRule: .cascade) により
// 所属する全 Shot が自動削除される
context.save()
```

---

## 設計上の制約と判断

| 事項 | 内容 |
|---|---|
| Player と Shot の独立性 | Player を削除しても Shot 履歴は残る。過去の記録を保全するための意図的な設計 |
| iCloud 同期なし | `modelContainer` に `isStoredInMemoryOnly` / CloudKit オプションなし。完全ローカル保存 |
| エラーハンドリング | `context.save()` は `try?` で呼び出し（失敗を無視）。SwiftData の自動マージに依存 |
| OT の上限 | OT1・OT2 の 2 ピリオドのみ対応。OT3 以降は現仕様では記録不可 |
| 背番号の型 | `number` は `String`。数値ソートが必要な箇所では `Int($0.number) ?? 0` で変換 |
| スキーマ変更ルール | SwiftData で非オプショナルフィールドを追加する際は、プロパティ宣言にストアドデフォルト値を必ず付与すること（例: `var x: T = defaultValue`）。デフォルト値がない場合、SwiftData は既存ストアを丸ごと削除してデータが消失する |
