# リファクタリング計画（関数責務ごとのファイル分割）

## 目的
現在 `README.md` に 1 ファイルで集約されている SwiftUI + UIKit + PencilKit の実装を、**責務単位**で分割し、可読性・保守性・テスト容易性を向上させる。

---

## 現状の責務整理（主要関数単位）

### 1) ノートデータ管理
- 対象: `Note`, `NoteStore`
- 関数:
  - `loadNotes()`
  - `createNote(name:)`
  - `deleteNote(_:)`
- 責務: ノート一覧の永続化ディレクトリ走査・作成・削除

### 2) ノート描画画面制御（ViewController）
- 対象: `NoteViewController`
- サブ責務:
  - 罫線描画: `drawLines()`
  - ページ表示: `setupPageLabel()`, `updatePageLabel()`, `pageCount()`
  - 保存/読込: `pageURL()`, `savePage()`, `loadPage()`
  - ページ遷移: `setupGestures()`, `nextPage()`, `prevPage()`
  - ツール操作: `updatePen()`
  - UI構築: `setupToolBar()`

### 3) SwiftUI ブリッジ
- 対象: `NoteView`
- 関数:
  - `makeUIViewController(context:)`
  - `updateUIViewController(_:context:)`
- 責務: UIKit の `NoteViewController` を SwiftUI に接続

### 4) ノート一覧 UI
- 対象: `NoteListView`
- 責務: 一覧表示、削除、作成ダイアログ、遷移

### 5) アプリエントリ
- 対象: `SimpleNoteApp`
- 責務: ルート画面起動

---

## 分割後の推奨ディレクトリ構成

```text
Sources/
  App/
    SimpleNoteApp.swift
  Models/
    Note.swift
  Stores/
    NoteStore.swift
  Features/NoteList/
    NoteListView.swift
  Features/NoteEditor/
    NoteViewController.swift
    NoteView.swift
    Components/
      EditorToolbarBuilder.swift
      PageIndicatorView.swift
    Services/
      NotePageRepository.swift
      NotePagingService.swift
      RuledLineRenderer.swift
```

> 既存プロジェクト構成に合わせ、`SimpleNoteApp.swift` 等に統合してもよい。

---

## 関数責務に基づく具体的な分割計画

### Step 1: モデルとストアを分離
1. `Note` を `Models/Note.swift` へ移動。
2. `NoteStore` を `Stores/NoteStore.swift` へ移動。
3. `baseURL` 解決処理を小関数化（例: `notesRootURL()`）し重複を抑制。

**効果**: 一覧 UI から永続化ロジックを切り離し。

---

### Step 2: ページ永続化責務を `NotePageRepository` に抽出
`NoteViewController` の以下を移管:
- `pageURL()`
- `savePage()`
- `loadPage()`
- `pageCount()`

新規:
- `Features/NoteEditor/Services/NotePageRepository.swift`
- API 例:
  - `func pageURL(noteID: String, index: Int) -> URL`
  - `func loadDrawing(noteID: String, index: Int) -> PKDrawing?`
  - `func saveDrawing(_ drawing: PKDrawing, noteID: String, index: Int)`
  - `func pageCount(noteID: String) -> Int`

**効果**: ファイル I/O を UI から分離し、テストしやすくする。

---

### Step 3: ページ遷移責務を `NotePagingService` へ抽出
`NoteViewController` の以下を移管/委譲:
- `nextPage()`
- `prevPage()`
- `updatePageLabel()` の計算部分

新規:
- `Features/NoteEditor/Services/NotePagingService.swift`
- API 例:
  - `func next(current: Int) -> Int`
  - `func previous(current: Int) -> Int`
  - `func pageIndicatorText(current: Int, total: Int) -> String`

**効果**: ページングルールを単体テスト可能に。

---

### Step 4: 罫線描画責務を `RuledLineRenderer` へ抽出
`drawLines()` の `UIBezierPath` 組み立てを外出し。

新規:
- `Features/NoteEditor/Services/RuledLineRenderer.swift`
- API 例:
  - `func makePath(bounds: CGRect, spacing: CGFloat) -> CGPath`

`NoteViewController` は `lineLayer.path = renderer.makePath(...)` のみ担当。

**効果**: 表示ロジックを独立させ、将来の方眼紙/ドット罫線拡張に対応。

---

### Step 5: ツールバー構築責務を `EditorToolbarBuilder` へ抽出
`setupToolBar()` のボタン生成を分離。

新規:
- `Features/NoteEditor/Components/EditorToolbarBuilder.swift`
- 役割:
  - 太さボタン生成
  - 色ボタン生成
  - 消しゴムボタン生成
  - アクションをクロージャで受け取り `NoteViewController` に通知

**効果**: UI構築コードの肥大化を抑制。

---

### Step 6: ページ表示ラベル責務を簡素化
`setupPageLabel()` は `NoteViewController` に残しつつ、文言生成は `NotePagingService` へ委譲。

任意で:
- `Components/PageIndicatorView.swift` を作成し UIKit/SwiftUI どちらでも再利用可能に。

---

### Step 7: SwiftUI 側を Feature 単位に整理
- `NoteView` → `Features/NoteEditor/NoteView.swift`
- `NoteListView` → `Features/NoteList/NoteListView.swift`
- `SimpleNoteApp` → `App/SimpleNoteApp.swift`

**効果**: 画面ごとの依存が明確になり、変更影響範囲を局所化。

---

## 依存関係の目標
- `NoteListView` → `NoteStore`, `NoteView`
- `NoteView` → `NoteViewController`
- `NoteViewController` → `NotePageRepository`, `NotePagingService`, `RuledLineRenderer`, `EditorToolbarBuilder`
- `Services` は UIKit/SwiftUI に依存しない（可能な範囲で）

---

## 実施順（安全な移行手順）
1. **ファイル分割のみ**（挙動変更なし）
2. `NotePageRepository` 抽出
3. `NotePagingService` 抽出
4. `RuledLineRenderer` 抽出
5. `EditorToolbarBuilder` 抽出
6. 画面動作確認（保存、ページ移動、色/太さ変更、消しゴム、削除/作成）

---

## 完了条件
- 1ファイルあたりの責務が単一（目安: 200行前後以内）
- `NoteViewController` が「画面ライフサイクルとイベント配線」に集中
- 永続化・ページング・描画パス生成・ツールバー生成が独立ファイル化
- 既存機能（ノート作成/削除、ページ保存/遷移、描画ツール）が維持される
