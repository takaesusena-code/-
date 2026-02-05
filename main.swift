import SwiftUI
import PencilKit

// =====================
// MARK: - ノートモデル
// =====================
struct Note: Identifiable {
    let id: String
    let name: String
}

// =====================
// MARK: - ノート管理
// =====================
final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []

    private let baseURL =
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    init() { loadNotes() }

    func loadNotes() {
        notes = []
        let dirs = (try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: nil
        )) ?? []

        for dir in dirs where dir.hasDirectoryPath {
            let id = dir.lastPathComponent
            let nameURL = dir.appendingPathComponent("name.txt")
            let name = (try? String(contentsOf: nameURL)) ?? "ノート"
            notes.append(Note(id: id, name: name))
        }
    }

    func createNote(name: String) {
        let id = UUID().uuidString
        let dir = baseURL.appendingPathComponent(id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? name.write(to: dir.appendingPathComponent("name.txt"),
                        atomically: true,
                        encoding: .utf8)
        loadNotes()
    }

    func deleteNote(_ note: Note) {
        let dir = baseURL.appendingPathComponent(note.id)
        try? FileManager.default.removeItem(at: dir)
        loadNotes()
    }
}

// =====================
// MARK: - ノート本体
// =====================
final class NoteViewController: UIViewController {

    private let canvas = PKCanvasView()
    private let lineLayer = CAShapeLayer()
    private let pageLabel = UILabel()

    private let noteID: String
    private var pageIndex = 0

    private var penColor: UIColor = .black
    private var penWidth: CGFloat = 6

    init(noteID: String) {
        self.noteID = noteID
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        canvas.drawingPolicy = .pencilOnly
        canvas.backgroundColor = .clear
        canvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvas)

        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        lineLayer.strokeColor = UIColor.lightGray.cgColor
        lineLayer.lineWidth = 1
        view.layer.insertSublayer(lineLayer, at: 0)

        setupPageLabel()
        setupToolBar()
        setupGestures()

        loadPage()
        updatePen()
        updatePageLabel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        drawLines()
    }

    // =====================
    // MARK: - 罫線
    // =====================
    private func drawLines() {
        let path = UIBezierPath()
        let spacing: CGFloat = 32
        var y: CGFloat = 0
        while y < view.bounds.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: view.bounds.width, y: y))
            y += spacing
        }
        lineLayer.frame = view.bounds
        lineLayer.path = path.cgPath
    }

    // =====================
    // MARK: - ページ表示
    // =====================
    private func setupPageLabel() {
        pageLabel.font = .systemFont(ofSize: 14)
        pageLabel.textColor = .darkGray
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageLabel)

        NSLayoutConstraint.activate([
            pageLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            pageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
    }

    private func updatePageLabel() {
        let total = pageCount()
        pageLabel.text = "\(pageIndex + 1) / \(max(total, pageIndex + 1))"
    }

    private func pageCount() -> Int {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(noteID)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.filter { $0.hasPrefix("page_") }.count
    }

    // =====================
    // MARK: - 保存
    // =====================
    private func pageURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(noteID)
            .appendingPathComponent("page_\(pageIndex).data")
    }

    private func savePage() {
        try? canvas.drawing.dataRepresentation().write(to: pageURL())
    }

    private func loadPage() {
        if let data = try? Data(contentsOf: pageURL()),
           let d = try? PKDrawing(data: data) {
            canvas.drawing = d
        } else {
            canvas.drawing = PKDrawing()
        }
    }

    // =====================
    // MARK: - ページ操作
    // =====================
    private func setupGestures() {
        let left = UISwipeGestureRecognizer(target: self, action: #selector(nextPage))
        left.direction = .left
        view.addGestureRecognizer(left)

        let right = UISwipeGestureRecognizer(target: self, action: #selector(prevPage))
        right.direction = .right
        view.addGestureRecognizer(right)
    }

    @objc private func nextPage() {
        savePage()
        pageIndex += 1
        loadPage()
        updatePageLabel()
    }

    @objc private func prevPage() {
        guard pageIndex > 0 else { return }
        savePage()
        pageIndex -= 1
        loadPage()
        updatePageLabel()
    }

    // =====================
    // MARK: - ペン / 消しゴム
    // =====================
    private func updatePen() {
        canvas.tool = PKInkingTool(.pen, color: penColor, width: penWidth)
    }

    // =====================
    // MARK: - UI
    // =====================
    private func setupToolBar() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])

        [2, 6, 10].forEach { w in
            let b = UIButton(type: .system)
            b.setTitle("●", for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: CGFloat(w))
            b.addAction(UIAction { _ in
                self.penWidth = CGFloat(w)
                self.updatePen()
            }, for: .touchUpInside)
            stack.addArrangedSubview(b)
        }

        [(UIColor.black, "⚫︎"), (.red, "🔴"), (.blue, "🔵")].forEach { c, t in
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal)
            b.addAction(UIAction { _ in
                self.penColor = c
                self.updatePen()
            }, for: .touchUpInside)
            stack.addArrangedSubview(b)
        }

        let eraser = UIButton(type: .system)
        eraser.setTitle("消", for: .normal)
        eraser.addAction(UIAction { _ in
            self.canvas.tool = PKEraserTool(.vector)
        }, for: .touchUpInside)
        stack.addArrangedSubview(eraser)
    }
}

// =====================
// MARK: - SwiftUI ブリッジ
// =====================
struct NoteView: UIViewControllerRepresentable {
    let noteID: String
    func makeUIViewController(context: Context) -> NoteViewController {
        NoteViewController(noteID: noteID)
    }
    func updateUIViewController(_ uiViewController: NoteViewController, context: Context) {}
}

// =====================
// MARK: - ノート一覧
// =====================
struct NoteListView: View {
    @StateObject var store = NoteStore()
    @State private var showNew = false
    @State private var newName = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(store.notes) { note in
                    NavigationLink(note.name,
                        destination: NoteView(noteID: note.id))
                }
                .onDelete { indexSet in
                    indexSet.map { store.notes[$0] }
                        .forEach { store.deleteNote($0) }
                }
            }
            .navigationTitle("ノート")
            .toolbar {
                EditButton()
                Button("＋") { showNew = true }
            }
            .alert("新しいノート", isPresented: $showNew) {
                TextField("ノート名", text: $newName)
                Button("作成") {
                    store.createNote(name: newName.isEmpty ? "ノート" : newName)
                    newName = ""
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}

// =====================
// MARK: - App
// =====================
@main
struct SimpleNoteApp: App {
    var body: some Scene {
        WindowGroup {
            NoteListView()
        }
    }
}
