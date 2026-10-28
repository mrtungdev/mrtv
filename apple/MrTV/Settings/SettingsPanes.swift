import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PaneContent: View {
    var pane: SettingsPane
    @ObservedObject var model: AppModel
    @ObservedObject var router: SettingsRouter
    var setup: SetupState
    var refresh: () -> Void

    var body: some View {
        switch pane {
        case .typing: TypingPane(model: model, router: router)
        case .macros: MacrosPane(model: model)
        case .apps: AppsPane(model: model)
        case .keys: KeysPane()
        case .general: GeneralPane(model: model, setup: setup, refresh: refresh)
        }
    }
}

/// Thứ tự kiểu gõ ở mọi nơi (Cài đặt, menu, Bắt đầu).
let methodOptions: [(EngineSettings.Method, String)] = [(.telex, "Telex"), (.simpleTelex, "Telex đơn giản"), (.vni, "VNI")]

extension EngineSettings.Method {
    var title: String {
        switch self {
        case .telex: return "Telex"
        case .simpleTelex: return "Telex đơn giản"
        case .vni: return "VNI"
        }
    }

    /// Ví dụ phím gõ → chữ hiện ra.
    var example: String {
        switch self {
        case .telex: return "tieesng Vieejt → tiếng Việt · dduowcj → được"
        case .simpleTelex: return "tieesng → tiếng · w đứng một mình vẫn là w"
        case .vni: return "tie61ng Vie65t → tiếng Việt · d9u7o7c5 → được"
        }
    }
}

/// Đoạn "Xem hướng dẫn" cuối trang: mở Bảng lệnh ở bài hướng dẫn hợp chủ đề.
private struct HelpLink: View {
    var topic: String

    var body: some View {
        InlineLink(title: "Xem hướng dẫn") { AppDelegate.current?.openHelp(topic) }
            .font(Fonts.text(11))
            .padding(.horizontal, 2)
    }
}

/// Hộp bảng: nền nhóm, viền mảnh, bo 10.
private extension View {
    func tableBox() -> some View {
        background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.surface))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
    }
}

/// Dòng tiêu đề cột của bảng.
private struct TableHeader: View {
    var columns: [(String, CGFloat?)]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(columns.indices, id: \.self) { i in
                if let width = columns[i].1 {
                    Text(columns[i].0).frame(width: width, alignment: .leading)
                } else {
                    Text(columns[i].0).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(Fonts.text(11, .semibold)).foregroundColor(Palette.ink2)
        .padding(.horizontal, 12).frame(height: 26)
        .overlay(FormDivider(), alignment: .bottom)
    }
}

/// Nút + và − dính nhau dưới bảng, như bảng của macOS.
private struct AddRemoveButtons: View {
    var addHelp: String
    var removeHelp: String
    var canRemove: Bool
    var add: () -> Void
    var remove: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: add) { Image(systemName: "plus").frame(width: 24, height: 20) }.help(addHelp)
            Rectangle().fill(Palette.stroke).frame(width: 0.5, height: 14)
            Button(action: remove) { Image(systemName: "minus").frame(width: 24, height: 20) }
                .help(removeHelp).disabled(!canRemove)
        }
        .buttonStyle(.borderless)
        .font(.system(size: 11, weight: .semibold))
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Palette.raised))
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 0.5))
    }
}

/// Dòng "Đã xoá … · Hoàn tác" sau khi xoá.
private struct UndoNote: View {
    var text: String
    var undo: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text).foregroundColor(Palette.ink2)
            InlineLink(title: "Hoàn tác", action: undo)
        }
        .font(Fonts.text(11))
    }
}

// MARK: Gõ chữ

struct TypingPane: View {
    @ObservedObject var model: AppModel
    @ObservedObject var router: SettingsRouter
    @State private var counts = WordCounts.current

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FormSection {
                FormRow(title: "Kiểu gõ", detail: model.engine.method.example, monoDetail: true) {
                    Picker("Kiểu gõ", selection: $model.engine.method) {
                        ForEach(methodOptions, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .pickerStyle(.menu).labelsHidden().fixedSize()
                }
                FormDivider()
                FormRow(title: "Đặt dấu", detail: "Chỉ khác ở oa, oe, uy khi không có âm cuối") {
                    Picker("Đặt dấu", selection: $model.engine.toneStyle) {
                        Text("hoà · mới").tag(EngineSettings.ToneStyle.new)
                        Text("hòa · cũ").tag(EngineSettings.ToneStyle.old)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
            }

            FormSection(title: "Từ tiếng Anh") {
                FormRow(title: "Giữ nguyên từ tiếng Anh", detail: "Từ không phải tiếng Việt (progress, class, keep) ra đúng phím đã gõ khi bấm dấu cách.") {
                    FormSwitch(label: "Giữ nguyên từ tiếng Anh", isOn: $model.engine.restoreEnglish)
                }
                FormDivider()
                FormRow(title: "Danh sách từ", detail: "\(counts.builtIn) từ có sẵn · \(counts.mine) từ bạn thêm") {
                    Button("Sửa danh sách…") { router.englishSheet = true }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                (Text("Gõ thông minh luôn bật: gõ dấu ở đâu trong từ cũng được (vietje → việt), uow ra ươ, xoá lùi về từ trước vẫn sửa được dấu. Lỡ thành tiếng Việt? Bấm ")
                    + Text("esc").fontWeight(.semibold) + Text(" ngay sau từ."))
                    .font(Fonts.text(11)).foregroundColor(Palette.ink2).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 2)
                HelpLink(topic: "tieng anh")
            }
        }
        .sheet(isPresented: $router.englishSheet, onDismiss: { counts = WordCounts.current }) {
            EnglishWordsSheet()
        }
    }
}

/// Số từ trong danh sách giữ nguyên tiếng Anh.
private struct WordCounts {
    var builtIn: Int
    var mine: Int

    static var current: WordCounts {
        let off = Set(SharedStore.englishOff)
        return WordCounts(builtIn: TypingEngine.englishWords.filter { !off.contains($0) }.count, mine: SharedStore.exceptions.count)
    }
}

/// Sheet Từ tiếng Anh: từ có sẵn và từ bạn thêm trong một bảng. Xoá từ bạn thêm thì mất hẳn,
/// từ có sẵn thì chỉ tắt; luôn hoàn tác được ngay.
struct EnglishWordsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mine = Set(SharedStore.exceptions)
    @State private var off = Set(SharedStore.englishOff)
    @State private var newWord = ""
    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var selected = Set<String>()
    @State private var undo: (mine: Set<String>, off: Set<String>, note: String)?
    @FocusState private var addFocused: Bool

    enum Filter: Hashable { case all, mine, builtIn, off }

    private struct Row: Hashable {
        var word: String
        var isMine: Bool
        var isOn: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Từ tiếng Anh giữ nguyên").font(Fonts.text(13, .semibold))
                Text("Gõ các từ này rồi bấm dấu cách là ra đúng phím đã gõ. Từ nào Mr TV vẫn đổi thành tiếng Việt (test → tét) thì thêm vào đây.")
                    .font(Fonts.text(11)).foregroundColor(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                TextField("Thêm từ, cách nhau bằng dấu phẩy", text: $newWord)
                    .textFieldStyle(.roundedBorder).focused($addFocused).onSubmit(add)
                Button("Thêm", action: add).disabled(parsed.isEmpty)
            }
            HStack(spacing: 10) {
                Picker("Lọc", selection: $filter) {
                    Text("Tất cả \(allRows.count)").tag(Filter.all)
                    Text("Bạn thêm \(mine.count)").tag(Filter.mine)
                    Text("Có sẵn \(TypingEngine.englishWords.count - off.count)").tag(Filter.builtIn)
                    Text("Đã tắt \(off.count)").tag(Filter.off)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                SearchField(placeholder: "Tìm từ", text: $query, small: true).frame(height: 22)
            }
            list
            HStack(spacing: 10) {
                AddRemoveButtons(addHelp: "Thêm từ", removeHelp: "Xoá từ đã chọn", canRemove: !removable.isEmpty,
                                 add: { addFocused = true }, remove: { remove(removable) })
                if !restorable.isEmpty {
                    Button("Bật lại \(restorable.count)") { restore(restorable) }.controlSize(.small)
                }
                Text("Từ bạn thêm bị xoá. Từ có sẵn chỉ bị tắt, bật lại được.")
                    .font(Fonts.text(11)).foregroundColor(Palette.ink2).lineLimit(1)
            }
            HStack {
                if let undo {
                    UndoNote(text: undo.note) { save(mine: undo.mine, off: undo.off); self.undo = nil }
                }
                Spacer()
                Button("Xong") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 540)
        .onChange(of: filter) { _ in selected.removeAll() }
    }

    private var list: some View {
        VStack(spacing: 0) {
            TableHeader(columns: [("Từ", nil), ("Nguồn", 110)])
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.word) { i, row in
                        let on = selected.contains(row.word)
                        Button { toggle(row.word) } label: {
                            HStack(spacing: 10) {
                                Text(row.word).font(Fonts.mono(12)).strikethrough(!row.isOn)
                                    .foregroundColor(on ? .white : row.isOn ? Palette.ink : Palette.ink2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(row.isMine ? "Bạn thêm" : row.isOn ? "Có sẵn" : "Đã tắt").font(Fonts.text(12))
                                    .foregroundColor(on ? .white : Palette.ink2)
                                    .frame(width: 110, alignment: .leading)
                            }
                            .padding(.horizontal, 12).frame(height: 24)
                            .background(on ? Palette.accent : i % 2 == 1 ? Palette.fill : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if rows.isEmpty {
                        Text(query.isEmpty ? "Không có từ nào ở đây." : "Không có từ nào khớp “\(query)”.")
                            .font(Fonts.text(12)).foregroundColor(Palette.ink2).padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .tableBox()
    }

    private var allRows: [Row] {
        let builtIn = TypingEngine.englishWords.filter { !mine.contains($0) }
            .map { Row(word: $0, isMine: false, isOn: !off.contains($0)) }
        let added = mine.map { Row(word: $0, isMine: true, isOn: true) }
        return (added + builtIn).sorted { $0.word < $1.word }
    }

    private var rows: [Row] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return allRows.filter { row in
            let fits: Bool
            switch filter {
            case .all: fits = true
            case .mine: fits = row.isMine
            case .builtIn: fits = !row.isMine && row.isOn
            case .off: fits = !row.isOn
            }
            return fits && (q.isEmpty || row.word.contains(q))
        }
    }

    private var picked: [Row] { allRows.filter { selected.contains($0.word) } }
    private var removable: [Row] { picked.filter { $0.isMine || $0.isOn } }
    private var restorable: [Row] { picked.filter { !$0.isMine && !$0.isOn } }

    private var parsed: [String] {
        newWord.lowercased().split(whereSeparator: { $0 == "," || $0 == " " || $0 == ";" }).map(String.init)
            .filter { w in !w.isEmpty && w.unicodeScalars.allSatisfy { $0.isASCII && CharacterSet.alphanumerics.contains($0) } }
    }

    private func toggle(_ word: String) {
        if selected.contains(word) { selected.remove(word) } else { selected.insert(word) }
    }

    private func add() {
        let words = parsed
        guard !words.isEmpty else { return }
        // Thêm lại một từ có sẵn đang tắt thì bật nó lên.
        save(mine: mine.union(words.filter { !TypingEngine.englishWords.contains($0) }), off: off.subtracting(words))
        newWord = ""
    }

    private func remove(_ list: [Row]) {
        guard !list.isEmpty else { return }
        undo = (mine, off, list.count == 1 ? "Đã \(list[0].isMine ? "xoá" : "tắt") “\(list[0].word)”." : "Đã xoá hoặc tắt \(list.count) từ.")
        save(mine: mine.subtracting(list.filter(\.isMine).map(\.word)), off: off.union(list.filter { !$0.isMine }.map(\.word)))
        selected.removeAll()
    }

    private func restore(_ list: [Row]) {
        save(mine: mine, off: off.subtracting(list.map(\.word)))
        selected.removeAll()
    }

    private func save(mine newMine: Set<String>, off newOff: Set<String>) {
        if newMine != mine {
            mine = newMine
            SharedStore.exceptions = newMine.sorted()
        }
        if newOff != off {
            off = newOff
            SharedStore.englishOff = newOff.sorted()
        }
    }
}

// MARK: Gõ tắt

struct MacrosPane: View {
    @ObservedObject var model: AppModel
    @State private var macros = SharedStore.macros
    @State private var newKey = ""
    @State private var newText = ""
    @State private var query = ""
    @State private var selected: String?
    @State private var editing: String?
    @State private var editKey = ""
    @State private var editText = ""
    @State private var undo: (list: [Macro], note: String)?
    @FocusState private var keyFocused: Bool

    private static let samples = [
        Macro(key: "ksao", text: "Không sao đâu anh/chị ạ, em xử lý ngay."),
        Macro(key: "ty", text: "Cảm ơn anh/chị nhiều ạ!"),
        Macro(key: "dc", text: "được"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FormSection {
                FormRow(title: "Bật gõ tắt",
                        detail: "Gõ chữ tắt rồi bấm dấu cách hoặc dấu câu là ra cả câu. Viết hoa chữ tắt thì câu viết hoa theo: Ksao → Không sao…") {
                    FormSwitch(label: "Bật gõ tắt", isOn: $model.engine.macrosEnabled)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    SectionTitle("Gõ tắt của bạn · \(macros.count)")
                    Spacer()
                    SearchField(placeholder: "Tìm, không dấu cũng được", text: $query, small: true)
                        .frame(width: 190, height: 22)
                }
                VStack(spacing: 0) {
                    if macros.isEmpty {
                        emptyState
                    } else {
                        TableHeader(columns: [("Chữ tắt", 110), ("Câu đầy đủ", nil)])
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, m in
                            if editing == m.id { editRow(m) } else { row(m, zebra: i % 2 == 1) }
                        }
                        if filtered.isEmpty {
                            Text("Không có gõ tắt nào khớp “\(query)”.").font(Fonts.text(12)).foregroundColor(Palette.ink2)
                                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    addRow
                }
                .tableBox()
                HStack(spacing: 10) {
                    AddRemoveButtons(addHelp: "Thêm gõ tắt", removeHelp: "Xoá gõ tắt đã chọn", canRemove: selected != nil,
                                     add: { keyFocused = true }, remove: removeSelected)
                    if let undo {
                        UndoNote(text: undo.note) { save(undo.list); self.undo = nil }
                    } else {
                        Text(addHint).font(Fonts.text(11)).foregroundColor(addProblem == nil ? Palette.ink2 : Palette.bad).lineLimit(1)
                    }
                }
                FormNote("Chữ tắt chỉ gồm chữ không dấu và số, tối đa 20 ký tự. Lỡ bung chữ? Bấm esc ngay sau đó để lấy lại chữ tắt.")
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chưa có gõ tắt nào.").font(Fonts.text(13, .medium))
            Text("Thêm ở dòng dưới, hoặc bắt đầu bằng vài mẫu rồi sửa lại cho hợp với bạn.")
                .font(Fonts.text(11)).foregroundColor(Palette.ink2)
            Button("Thêm 3 mẫu") { save(Self.samples) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(FormDivider(), alignment: .bottom)
    }

    private func row(_ m: Macro, zebra: Bool) -> some View {
        let on = selected == m.id
        return HStack(spacing: 10) {
            Text(m.key).font(Fonts.mono(12)).frame(width: 110, alignment: .leading)
            Text(m.text).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(Fonts.text(13))
        .foregroundColor(on ? .white : Palette.ink)
        .padding(.horizontal, 12).frame(height: 28)
        .background(on ? Palette.accent : zebra ? Palette.fill : .clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { startEditing(m) }
        .onTapGesture { selected = on ? nil : m.id }
        .help("Bấm đúp để sửa")
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func editRow(_ m: Macro) -> some View {
        let clash = editKey.lowercased() != m.id && existing(editKey) != nil
        let issue = problem(key: editKey) ?? (clash ? "Đã có chữ tắt này." : nil)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("chữ tắt", text: $editKey).font(Fonts.mono(12)).textFieldStyle(.roundedBorder).frame(width: 110)
                TextField("Câu đầy đủ", text: $editText).textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 8) {
                if let issue { Text(issue).font(Fonts.text(11)).foregroundColor(Palette.bad) }
                Spacer()
                Button("Huỷ") { editing = nil }
                Button("Lưu") {
                    var list = macros.filter { $0.id != m.id }
                    list.append(Macro(key: editKey.trimmingCharacters(in: .whitespaces).lowercased(),
                                      text: editText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    save(list)
                    editing = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(issue != nil || editKey.isEmpty || editText.isEmpty)
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 8).padding(.vertical, 8)
        .background(Palette.selection)
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("chữ tắt", text: $newKey).font(Fonts.mono(12)).textFieldStyle(.roundedBorder).frame(width: 110)
                .focused($keyFocused).onSubmit(add)
            TextField("Câu đầy đủ", text: $newText).textFieldStyle(.roundedBorder).onSubmit(add)
            Button(existing(newKey) == nil ? "Thêm" : "Thay", action: add)
                .disabled(addProblem != nil || newKey.isEmpty || newText.isEmpty)
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(Palette.fill)
        .overlay(FormDivider(), alignment: .top)
    }

    private var filtered: [Macro] {
        let q = (TextTool.strip.run(query.lowercased()) ?? query).trimmingCharacters(in: .whitespaces)
        let sorted = macros.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
        guard !q.isEmpty else { return sorted }
        return sorted.filter { (TextTool.strip.run(($0.key + " " + $0.text).lowercased()) ?? "").contains(q) }
    }

    private func existing(_ key: String) -> Macro? {
        let k = key.trimmingCharacters(in: .whitespaces).lowercased()
        return macros.first { $0.id == k }
    }

    /// Chữ tắt chỉ gồm chữ cái và số, không dấu cách: lõi gõ coi dấu cách là hết từ.
    private func problem(key: String) -> String? {
        let k = key.trimmingCharacters(in: .whitespaces)
        if k.isEmpty { return nil }
        if !k.unicodeScalars.allSatisfy({ $0.isASCII && CharacterSet.alphanumerics.contains($0) }) {
            return "Chữ tắt chỉ gồm chữ cái không dấu và số, không có dấu cách."
        }
        if k.count > 20 { return "Chữ tắt dài quá, tối đa 20 ký tự." }
        return nil
    }

    private var addProblem: String? { problem(key: newKey) }

    private var addHint: String {
        if let p = addProblem { return p }
        if let m = existing(newKey) { return "Đã có “\(m.key)” → \(m.text). Bấm Thay để đổi." }
        return "Bấm đúp một dòng để sửa."
    }

    private func startEditing(_ m: Macro) {
        selected = m.id
        editing = m.id
        editKey = m.key
        editText = m.text
    }

    private func add() {
        let key = newKey.trimmingCharacters(in: .whitespaces).lowercased()
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !text.isEmpty, problem(key: key) == nil else { return }
        var list = macros.filter { $0.id != key }
        list.append(Macro(key: key, text: text))
        save(list)
        newKey = ""
        newText = ""
        undo = nil
    }

    private func removeSelected() {
        guard let id = selected, let m = macros.first(where: { $0.id == id }) else { return }
        undo = (macros, "Đã xoá “\(m.key)”.")
        save(macros.filter { $0.id != id })
        selected = nil
    }

    private func save(_ list: [Macro]) {
        macros = list
        SharedStore.macros = list
    }
}

// MARK: Ứng dụng

struct AppsPane: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var selected: String?
    @State private var version = 0

    private struct AppRow: Identifiable {
        var id: String
        var name: String
        var recent: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FormSection {
                FormRow(title: "Nhớ Việt/Anh theo ứng dụng", detail: "Mỗi ứng dụng giữ chế độ riêng: Slack tiếng Việt, VS Code tiếng Anh.") {
                    FormSwitch(label: "Nhớ Việt/Anh theo ứng dụng", isOn: $model.rememberModePerApp)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    SectionTitle("Cách gõ")
                    Spacer()
                    SearchField(placeholder: "Tìm ứng dụng", text: $query, small: true).frame(width: 170, height: 22)
                }
                (Text("Để Tự động là đủ: Mr TV chọn sẵn cho \(SharedStore.bundledProfiles.count) ứng dụng quen thuộc. Chỉ đổi khi một ứng dụng gõ sai dấu. ")
                    + Text("Gõ chuẩn").fontWeight(.semibold).foregroundColor(Palette.ink) + Text(" cho ứng dụng của Apple · ")
                    + Text("Gõ đè").fontWeight(.semibold).foregroundColor(Palette.ink) + Text(" xoá rồi gõ lại, cần quyền Trợ năng · ")
                    + Text("Chữ gạch chân").fontWeight(.semibold).foregroundColor(Palette.ink) + Text(" khi chưa có quyền."))
                    .font(Fonts.text(11)).foregroundColor(Palette.ink2).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 2)
                VStack(spacing: 0) {
                    TableHeader(columns: [("Ứng dụng", nil), ("Việt/Anh", 112), ("Cách gõ", 172)])
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, app in
                        row(app, zebra: i % 2 == 1)
                    }
                    if rows.isEmpty {
                        Text(query.isEmpty ? "Chưa có ứng dụng nào. Bấm + để thêm." : "Không thấy ứng dụng nào khớp “\(query)”.")
                            .font(Fonts.text(12)).foregroundColor(Palette.ink2).padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .tableBox()
                .id(version)
                HStack(spacing: 10) {
                    AddRemoveButtons(addHelp: "Thêm ứng dụng", removeHelp: "Bỏ ứng dụng đã chọn khỏi danh sách",
                                     canRemove: selected.map(model.listedApps.contains) ?? false, add: addApp, remove: removeSelected)
                    Text("Ứng dụng khác: Tự động dùng Gõ đè.")
                        .font(Fonts.text(11)).foregroundColor(Palette.ink2).lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Về Tự động") {
                        if let id = selected { SharedStore.setPath(nil, for: id); version += 1 }
                    }
                    .disabled(selected.flatMap(SharedStore.pathOverride(for:)) == nil)
                }
            }
        }
    }

    private var rows: [AppRow] {
        let front = model.frontApp?.bundleIdentifier
        let q = fold(query.trimmingCharacters(in: .whitespaces))
        var ids: [String] = []
        if let front { ids.append(front) }
        ids += model.listedApps + SharedStore.overriddenApps.sorted()
        if !q.isEmpty {
            ids += SharedStore.bundledProfiles.values.sorted { $0.name < $1.name }.map(\.bundleID)
        }
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
            .map { AppRow(id: $0, name: Self.name(of: $0), recent: $0 == front) }
            .filter { q.isEmpty || fold($0.name).contains(q) }
    }

    private func fold(_ s: String) -> String { TextTool.strip.run(s.lowercased()) ?? s.lowercased() }

    static func name(of id: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first, let name = app.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return SharedStore.bundledProfiles[id]?.name ?? id
    }

    private func row(_ app: AppRow, zebra: Bool) -> some View {
        let on = selected == app.id
        let override = SharedStore.pathOverride(for: app.id)
        let auto = SharedStore.bundledProfiles[app.id]?.path ?? .tap
        return HStack(spacing: 10) {
            HStack(spacing: 8) {
                AppIcon(bundleID: app.id, name: app.name)
                Text(app.name).lineLimit(1)
                if app.recent { Text("· vừa dùng").font(Fonts.text(11)).foregroundColor(Palette.ink2) }
                if override != nil {
                    HStack(spacing: 4) {
                        Circle().fill(Palette.accent).frame(width: 6, height: 6)
                        Text("đã đổi").font(Fonts.text(11)).foregroundColor(Palette.ink2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { selected = on ? nil : app.id }
            Picker("Việt/Anh trong \(app.name)", selection: Binding(
                get: { SharedStore.rememberedMode(for: app.id) ?? SharedStore.mode(for: nil) },
                set: { SharedStore.setRememberedMode($0, for: app.id); version += 1 })) {
                Text("Tiếng Việt").tag(InputMode.vietnamese)
                Text("Tiếng Anh").tag(InputMode.english)
            }
            .labelsHidden().pickerStyle(.menu).fixedSize().frame(width: 112, alignment: .leading)
            .disabled(!model.rememberModePerApp)
            Picker("Cách gõ trong \(app.name)", selection: Binding(
                get: { override },
                set: { SharedStore.setPath($0, for: app.id); version += 1 })) {
                Text("Tự động · \(auto.title)").tag(TypingPath?.none)
                Divider()
                ForEach([TypingPath.direct, .tap, .composing], id: \.self) { p in
                    Text(p.title).tag(TypingPath?.some(p))
                }
            }
            .labelsHidden().pickerStyle(.menu).fixedSize().frame(width: 172, alignment: .leading)
        }
        .font(Fonts.text(13))
        .controlSize(.small)
        .padding(.horizontal, 12).frame(height: 32)
        .background(on ? Palette.selection : zebra ? Palette.fill : .clear)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Thêm"
        panel.message = "Chọn ứng dụng muốn chỉnh cách gõ"
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        if !model.listedApps.contains(id) { model.listedApps.append(id) }
        selected = id
    }

    private func removeSelected() {
        guard let id = selected else { return }
        model.listedApps.removeAll { $0 == id }
        SharedStore.setPath(nil, for: id)
        selected = nil
        version += 1
    }
}

/// Biểu tượng thật của ứng dụng; chưa cài thì là ô chữ cái đầu.
private struct AppIcon: View {
    var bundleID: String
    var name: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 18, height: 18)
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Palette.fill2).frame(width: 18, height: 18)
                .overlay(Text(String(name.prefix(1))).font(Fonts.text(10, .semibold)).foregroundColor(Palette.ink2))
        }
    }
}

// MARK: Phím

struct KeysPane: View {
    @ObservedObject private var store = ShortcutStore.shared
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                FormSection {
                    FormRow(title: ShortcutAction.toggle.title, detail: store.trigger(.toggle).spoken) {
                        ShortcutField(action: .toggle, store: store, message: $message)
                    }
                    FormDivider()
                    FormRow(title: ShortcutAction.mrtv.title, detail: mrtvDetail) {
                        ShortcutField(action: .mrtv, store: store, message: $message)
                    }
                }
                if let message {
                    Text(message).font(Fonts.text(11, .medium)).foregroundColor(Palette.bad).padding(.horizontal, 2)
                }
                FormNote("Đổi phím ở đây thì mọi chữ hướng dẫn trong Mr TV đổi theo. Mr TV báo ngay nếu phím trùng với phím của ứng dụng khác.")
            }

            if store.trigger(.toggle) == .fn {
                FormSection(title: "Phím fn của macOS") {
                    HStack(spacing: 12) {
                        Image(systemName: "globe").font(.system(size: 18)).foregroundColor(Palette.ink2)
                        Text("macOS cũng dùng fn để mở bảng biểu tượng. Để fn chỉ đổi Việt ⇄ Anh, đặt “Nhấn phím 🌐 để” thành “Không làm gì”.")
                            .font(Fonts.text(12)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Mở cài đặt Bàn phím…") { InputSourceInstaller.openKeyboardSettings() }
                    }
                    .padding(12)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                (Text("Khi đang gõ, ") + Text("esc").fontWeight(.semibold) + Text(" lấy lại phím vừa gõ và ")
                    + Text("⌘Z").fontWeight(.semibold) + Text(" hoàn tác như thường."))
                    .font(Fonts.text(11)).foregroundColor(Palette.ink2).padding(.horizontal, 2)
                HelpLink(topic: "")
            }
        }
    }

    private var mrtvDetail: String {
        let t = store.trigger(.mrtv)
        return t == .off ? "Không dùng phím; mở Bảng lệnh từ menu Mr TV" : "\(t.spoken) để mở Bảng lệnh"
    }
}

// MARK: Chung

struct GeneralPane: View {
    @ObservedObject var model: AppModel
    var setup: SetupState
    var refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FormSection {
                FormRow(title: "Mở Mr TV khi bật máy", detail: "Chạy nền, không mở cửa sổ") {
                    FormSwitch(label: "Mở Mr TV khi bật máy", isOn: $model.launchAtLogin)
                }
                FormDivider()
                FormRow(title: "Hiện biểu tượng trên thanh menu", detail: "Tắt đi thì mở Mr TV từ Launchpad để vào Cài đặt") {
                    FormSwitch(label: "Hiện biểu tượng trên thanh menu", isOn: menuBar)
                }
                FormDivider()
                FormRow(title: "Nhãn Việt/Anh cạnh con trỏ", detail: "Hiện thoáng qua mỗi khi đổi") {
                    FormSwitch(label: "Nhãn Việt/Anh cạnh con trỏ", isOn: $model.cursorLabel)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                FormSection(title: "Quyền") {
                    FormRow(title: "Bộ gõ Mr TV", detail: setup.source.detail) {
                        InputSourceButton(status: setup.source, onChange: refresh)
                    }
                    FormDivider()
                    FormRow(title: "Trợ năng", detail: "Để gõ ở Chrome, VS Code, Terminal và đọc chữ đang bôi đen") {
                        if setup.accessibility {
                            StatusLabel(kind: .ok, text: "Đã cấp")
                        } else {
                            Button("Cấp quyền…") { Permissions.askAccessibility() }.buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    FormDivider()
                    FormRow(title: "Giám sát đầu vào",
                            detail: "Chỉ cần khi chưa có Trợ năng, để nghe phím \(ShortcutStore.label(.toggle)) và \(ShortcutStore.label(.mrtv))") {
                        if setup.accessibility {
                            StatusLabel(kind: .muted, text: "Không cần")
                        } else if setup.inputMonitoring {
                            StatusLabel(kind: .ok, text: "Đã cấp")
                        } else {
                            Button("Cấp quyền…") { Permissions.askInputMonitoring() }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    FormNote("Cập nhật macOS đôi khi tắt quyền mà không báo. Khi đó Mr TV báo ở đầu Cài đặt và trong menu.")
                    InlineLink(title: "Mất quyền thì làm gì?") { AppDelegate.current?.openHelp("mat quyen") }
                        .font(Fonts.text(11)).padding(.horizontal, 2)
                }
            }

            FormSection(title: "Riêng tư") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock").font(.system(size: 15)).foregroundColor(Palette.ink2)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Chữ bạn gõ ở lại trên máy này. Mr TV không gửi đi, không lưu phím đã bấm. Gõ tắt và danh sách từ nằm trong cài đặt macOS của bạn.")
                            .font(Fonts.text(12)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        InlineLink(title: "Mã nguồn mở trên GitHub") { NSWorkspace.shared.open(Links.source) }
                            .font(Fonts.text(12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
            }
        }
    }

    /// Biểu tượng trên thanh menu bật/tắt; ai đã chọn hiện ở Dock thì vẫn giữ Dock.
    private var menuBar: Binding<Bool> {
        Binding(get: { model.showIn == .menuBar || model.showIn == .both },
                set: { on in
                    let dock = model.showIn == .dock || model.showIn == .both
                    model.showIn = on ? (dock ? .both : .menuBar) : (dock ? .dock : .none)
                })
    }
}

/// Địa chỉ của dự án.
enum Links {
    static let source = URL(string: "https://github.com/mrtungdev/mrtv")!
    static let releases = URL(string: "https://github.com/mrtungdev/mrtv/releases")!
}
