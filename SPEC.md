# ShootChart アプリ 仕様書

## 1. プロジェクト概要

**ShootChart** は、ミニバスケットボール（小学生）向けの iPad 専用ショットチャートアプリです。試合中のシュート・ターンオーバーをコート図上にリアルタイムで記録し、選手ごとの成績を集計・PDF出力します。

- **対象**: ミニバス指導者・コーチ
- **プラットフォーム**: iPadOS 17.0+（iPad専用、横向き固定）
- **技術スタック**: SwiftUI + SwiftData
- **データ保存**: 端末内ローカル（SwiftData）
- **出力**: PDF エクスポート（シェア機能経由）

---

## 2. データモデル

### 2.1 Game（試合）

| プロパティ | 型 | 説明 |
|---|---|---|
| `id` | UUID | |
| `date` | Date | 試合日時 |
| `opponent` | String | 対戦相手名 |
| `memo` | String | メモ（作戦等） |
| `rosterName` | String | 紐付けロスター名（表示用） |
| `shots` | [Shot] | ショット記録（cascade delete） |
| `gamePlayers` | [GamePlayer] | 試合時メンバースナップショット（cascade delete） |

### 2.2 Shot（ショット記録）

| プロパティ | 型 | 説明 |
|---|---|---|
| `id` | UUID | |
| `playerId` | UUID | 選手ID（センチネル値あり） |
| `playerNumber` | String | 選手番号（非正規化） |
| `playerName` | String | 選手名（非正規化） |
| `quarter` | Int | クォーター（1-4=Q1-Q4, 5=OT1, 6=OT2） |
| `x` / `y` | Double | コート上の正規化座標（0.0〜1.0） |
| `isMade` | Bool | シュート成功フラグ |
| `shotType` | String | ShotType の rawValue |
| `createdAt` | Date | 記録日時（Undo 用） |

**ShotType enum**（`Shot.swift`）:

| rawValue | 意味 |
|---|---|
| `"field"` | フィールドゴール（通常シュート） |
| `"freeThrow"` | フリースロー |
| `"turnOver"` | ターンオーバー（その他） |
| `"traveling"` | トラベリング |

**Quarter enum**（`Shot.swift`）:

| rawValue | ラベル |
|---|---|
| 1 | 1Q |
| 2 | 2Q |
| 3 | 3Q |
| 4 | 4Q |
| 5 | OT1 |
| 6 | OT2 |

**センチネル UUID**（実在しない選手を表す特殊な playerId）:

| UUID | 定数名 | 用途 |
|---|---|---|
| `00000000-0000-0000-0000-000000000000` | `opponentPlayerId` | 相手チームのシュート |
| `00000000-0000-0000-0000-000000000001` | `ownTeamFilterId` | 自チーム全体フィルタ（UI用・Shot保存には不使用） |
| `00000000-0000-0000-0000-000000000002` | `ownTeamTurnoverPlayerId` | チームターンオーバー |

**計算プロパティ**:
- `isOpponent`: `playerId == opponentPlayerId`
- `isTeamTurnover`: `playerId == ownTeamTurnoverPlayerId`

### 2.3 Player（選手）

| プロパティ | 型 | 説明 |
|---|---|---|
| `id` | UUID | |
| `number` | String | 背番号 |
| `name` | String | 選手名 |
| `grade` | String? | 学年（オプション） |
| `roster` | Roster? | 所属ロスター |

### 2.4 GamePlayer（試合時スナップショット）

Player の試合時コピー。`id` は対応する `Player.id` と同値を保持。  
ロスター変更後も試合当時のメンバー構成を保持するための設計。

| プロパティ | 型 | 説明 |
|---|---|---|
| `id` | UUID | Player.id と同値 |
| `number` | String | |
| `name` | String | |
| `grade` | String? | |
| `game` | Game? | 所属試合 |

### 2.5 Roster（ロスター）

| プロパティ | 型 | 説明 |
|---|---|---|
| `id` | UUID | |
| `name` | String | ロスター名 |
| `createdAt` | Date | |
| `players` | [Player] | 所属選手（cascade delete） |

---

## 3. 画面構成・機能

### 3.1 HomeView（試合一覧）

- 試合を新しい順に一覧表示
- 各行：対戦相手名、日付、シュート成功数/試行数（自チーム）
- ナビゲーション先：ショットチャート画面、集計画面、試合編集画面
- 試合の削除（スワイプ）
- ロスター管理画面へのリンク
- 「＋」ボタンで新規試合作成

---

### 3.2 ShotChartView（ショット記録）

メインの記録画面。

**レイアウト**:
- 左：バスケットボールコート（残幅すべて）
- 右：コントロールパネル（幅 280pt 固定）

#### コントロールパネル（上から順）

1. **ステータスバー**  
   現在の選択選手名（または「相手チーム」「チームTO」）、記録クォーター、成功/失敗表示

2. **ショットタイプ選択**  
   `2P` / `FT` / `TO` の3択ボタン

3. **成功/失敗ボタン**（TO 以外のとき表示）  
   `○ 成功`（緑）/ `× 失敗`（赤）

4. **TO モード UI**（TO 選択時のみ表示）  
   - サブタイプ選択：`トラベリング` / `その他`  
   - `TO を記録` ボタン  
   - 記録済み TO の削除バッジ一覧（Q ラベル + タイプ + ×）

5. **記録Q選択**  
   `1Q` / `2Q` / `3Q` / `4Q` / `OT1` / `OT2`

6. **表示Qフィルター**（横スクロール）  
   `全Q` / `1Q` / `2Q` / `3Q` / `4Q` / `OT1` / `OT2`

7. **プレイヤーリスト**（横スクロール）  
   `相手チーム` / `チームTO` / 選手ボタン（番号順）  
   TOが記録されている選手にはオレンジのドットを表示

8. **アクションボタン**（下部）  
   `直前取消`（最新 Shot を削除）/ `削除`（選択中の Shot を削除）

#### コート上のUI

- **スコアバッジ**（コート上部中央）  
  `相 N - 自 N`。表示Qフィルターに連動。
- **TOバッジ**（スコアバッジ下）  
  `TV N  TO N  合計 N`（合計 0 のときは非表示）
- **プレイヤーフィルターバー**（コート下部）  
  横スクロールチップ。Shotを持つ選手のみ表示。

#### コートマーカーの色

| 対象 | 成功 | 失敗 |
|---|---|---|
| 自チーム 2P | 緑 ○ | 赤 × |
| 自チーム FT | 青 ○ | オレンジ × |
| 相手チーム 2P | 紫 ○ | グレー × |
| 相手チーム FT | ティール ○ | 茶色 × |
| TO（TV/その他） | — | オレンジ × |
| 選択中 | 黄色（40pt） | 黄色（40pt） |

通常マーカーサイズ: 32pt。選択時: 40pt。中央に背番号を表示。

#### 主要ロジック

**ショット記録** (`recordShot`):
- コートをタップすると正規化座標 (x, y) を取得して Shot を保存
- TO モード中のコートタップは無効（TO は `recordTurnover` で記録）

**TO 記録** (`recordTurnover`):
- 座標は固定値 `(x: 0.5, y: -0.05)`（コート外・上部）
- 相手チームモード → `opponentPlayerId`
- チームTO選択時 → `ownTeamTurnoverPlayerId`
- 個人選択時 → その選手の `playerId`

**Undo** (`undoLastShot`):
- `createdAt` が最新の Shot を1件削除

**ロスター適用** (`linkRoster`):
1. 既存 `gamePlayers` を全削除
2. 選択ロスターの Player から GamePlayer を新規作成（同一 id）
3. `reassociateShots()` で既存 Shot の `playerId` を背番号で再マッピング

---

### 3.3 SummaryView（集計）

ショット成績と TO を一覧する統計画面。

**クォーターフィルター**: `全Q` / `1Q`〜`4Q` / `OT1` / `OT2`（横スクロール）

**表の行（上から順）**:
1. 個人選手行（番号昇順）→ タップで ShotChartView へ（その選手フィルタ付き）
2. チームTO行（チームTO が 1件以上のとき表示）
3. 合計行（チームTO を含む総計）
4. 相手チーム行（記録があるとき表示）

**列構成**:

| 列 | 幅 | 色 | 内容 |
|---|---|---|---|
| `#` | 36 | — | 背番号 |
| `名前` | max | — | 選手名 |
| `2P成` | 52 | 緑 | FG 成功数 |
| `2P試` | 52 | 緑 | FG 試行数 |
| `2P%` | 56 | 緑 | FG 成功率 |
| `FT成` | 52 | 青 | FT 成功数 |
| `FT試` | 52 | 青 | FT 試行数 |
| `FT%` | 56 | 青 | FT 成功率 |
| `TV` | 44 | オレンジ | トラベリング数 |
| `その他` | 44 | オレンジ | その他 TO 数 |
| `合計` | 52 | オレンジ | TV + その他 |
| `TO%` | 52 | オレンジ | TO 率（下記式） |

**TO% 計算式**:
```
TO% = toTotal / (fgTotal + 0.44 × ftTotal + toTotal) × 100
```
- チームTO行のTO%は「—」（possession 計算が適用できないため）

---

### 3.4 GameEditView（試合作成・編集）

- 試合日付（DatePicker, 日本語）
- 対戦相手名（TextField）
- メモ（TextEditor）
- ロスター選択（Picker）
- 選択ロスターの選手一覧（読み取り専用）

保存時にロスターが選択されている場合、GamePlayer スナップショットを生成し、既存 Shot の `playerId` を再マッピング（`reassociateShots()`）。

---

### 3.5 RosterListView / RosterDetailView（ロスター管理）

**RosterListView**: ロスター一覧・新規作成・削除

**RosterDetailView**:
- ロスター名の編集
- CSV ファイルインポートによるプレイヤー一括登録（既存プレイヤー全置換）

**CSV フォーマット**:
```
number,name,grade
10,山田太郎,6年
11,鈴木花子,5年
```
- 文字コード: UTF-8
- ヘッダー行必須（`number`, `name` は必須。`grade` は省略可）
- 同番号の選手は上書き更新

---

## 4. PDF エクスポート

`ShotChartView` の Share ボタンから生成。A4 横向き（842×595pt）。

**ページ構成**:

| ページ | 内容 |
|---|---|
| 1 | 自チーム 全Q ショットチャート |
| 2〜N | 自チーム Q別 ショットチャート（記録があるQのみ） |
| N+1 | 相手チーム 全Q ショットチャート |
| N+2〜M | 相手チーム Q別 ショットチャート |
| 最終 | 統計集計表（SummaryView と同内容・全Q集計） |

統計表の列構成は SummaryView と同じ（TO%含む）。チームTO行のTO%は「—」。

---

## 5. CourtView の座標系

`Components/CourtView.swift`

- SVG 画像サイズ: 942×540（viewBox）
- コート境界（Shot 配置・タップ判定に使用）:
  - x: 40〜906（942中）
  - y: 39〜504（540中）
- `imageRect(in:)`: 942:540 のアスペクト比でレターボックス表示
- `courtRect(in:)`: コート境界 rect（Shot 描画・タップ判定の基準）
- タップ判定: 最寄りマーカーの中心から **22pt 以内** でショット選択、それ以外はコート内新規記録

**Shot 座標の変換**:
```
screen.x = courtRect.minX + shot.x × courtRect.width
screen.y = courtRect.minY + shot.y × courtRect.height
```

---

## 6. ファイル構成

```
ShootChart/
├── ShootChartApp.swift            # エントリポイント・SwiftData container
├── Models/
│   ├── Game.swift
│   ├── Shot.swift                 # ShotType / Quarter enum もここに定義
│   ├── Player.swift
│   ├── GamePlayer.swift
│   └── Roster.swift
├── Views/
│   ├── HomeView.swift
│   ├── ShotChartView.swift        # メイン記録画面
│   ├── SummaryView.swift          # 集計画面
│   ├── GameEditView.swift
│   ├── RosterListView.swift
│   └── RosterDetailView.swift
├── Components/
│   └── CourtView.swift            # コート描画・タップ判定
└── Utilities/
    ├── CSVImporter.swift
    └── PDFExporter.swift
```

---

## 7. 設計上の注意点

- **スキーマ変更ルール**: `@Model` に非オプションプロパティを追加するときは必ずストアドデフォルト値を付与すること（例: `var x: T = defaultValue`）。付与しない場合 SwiftData が起動時に既存ストアを削除する。
- **Shot の非正規化**: `playerNumber` / `playerName` を Shot に保持することで、選手情報を変更・削除しても過去の記録が壊れない。
- **チームTO の座標**: `(x: 0.5, y: -0.05)` はコート外（上部）に固定。CourtView の `visibleShots` フィルタを外したことで橙マーカーがコート外に表示される。
- **ownTeamFilterId の用途**: Shot の保存には使用しない。CourtView の `filterPlayerId` に渡して自チーム全体を表示するためのUIフィルタ専用値。
