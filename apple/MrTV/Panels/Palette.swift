import AppKit
import SwiftUI

// MARK: Bảng lệnh (Phím Mr TV)

/// Bài hướng dẫn trong Bảng lệnh khi gõ "?". Phím trong bài luôn là phím người dùng đã đặt.
struct HelpArticle: Identifiable {
    enum Action { case useInputSource, settings(SettingsPane), accessibility }

    let id: String
    let title: String
    let intro: String
    var steps: [String] = []
    var actions: [(String, Action)] = []

    @MainActor
    static var all: [HelpArticle] {
        let toggle = ShortcutStore.shared.trigger(.toggle) == .off ? "menu Mr TV" : ShortcutStore.label(.toggle)
        let mrtv = ShortcutStore.shared.trigger(.mrtv) == .off ? "menu Mr TV › Bảng lệnh" : ShortcutStore.label(.mrtv)
        return [
            HelpArticle(id: "khong-go-duoc", title: "Không gõ được tiếng Việt",
                        intro: "Thường là do máy đang dùng bộ gõ khác, như ABC hay U.S.",
                        steps: ["Bấm \(toggle) để đổi sang tiếng Việt. Mr TV tự dùng bộ gõ Mr TV.",
                                "Biểu tượng trên thanh menu có viền đứt? Mở menu Mr TV để xem lý do.",
                                "Vẫn chưa được: kiểm tra Cài đặt › Chung › Quyền."],
                        actions: [("Dùng bộ gõ Mr TV", .useInputSource), ("Mở Cài đặt…", .settings(.general))]),
            HelpArticle(id: "doi-viet-anh", title: "Đổi Việt ⇄ Anh",
                        intro: "Bấm \(toggle). Mr TV nhớ riêng cho từng ứng dụng: Slack tiếng Việt, VS Code tiếng Anh.",
                        steps: ["Đổi phím ở Cài đặt › Phím.", "Không muốn nhớ theo ứng dụng: tắt ở Cài đặt › Ứng dụng."],
                        actions: [("Mở Cài đặt › Phím", .settings(.keys))]),
            HelpArticle(id: "bang-lenh", title: "Bảng lệnh và Phím Mr TV",
                        intro: "Bấm \(mrtv) để mở Bảng lệnh.",
                        steps: ["Đang bôi đen chữ: việc chạy trên đoạn đó và thay thẳng vào chữ. ⌘Z để hoàn tác.",
                                "Không bôi đen: việc chạy trên chữ vừa chép, kết quả được chép lại vào clipboard.",
                                "Gõ ? trong bảng để tìm hướng dẫn, không dấu cũng được."]),
            HelpArticle(id: "sua-tu", title: "Sửa dấu một từ đã gõ",
                        intro: "Đặt con trỏ ngay sau từ đó (bấm chuột hay phím mũi tên) rồi gõ dấu: “Viêt” thêm j thành “Việt”.",
                        steps: ["Xoá lùi qua dấu cách cũng sửa tiếp được từ trước."]),
            HelpArticle(id: "chuyen-nguoc", title: "Lỡ gõ khi đang ở tiếng Anh",
                        intro: "Bôi đen chữ như “tooi ddang”, bấm \(mrtv) rồi chọn Chuyển ngược."),
            HelpArticle(id: "tieng-anh", title: "Giữ nguyên từ tiếng Anh",
                        intro: "Từ không phải tiếng Việt (progress, keep) tự ra đúng phím khi bấm dấu cách. Từ vẫn bị đổi (test → tét) thì bấm esc ngay sau từ.",
                        steps: ["Từ hay dùng thì thêm vào Cài đặt › Gõ chữ › Sửa danh sách…",
                                "esc ngay sau một gõ tắt vừa bung cũng lấy lại chữ tắt."],
                        actions: [("Mở Cài đặt › Gõ chữ", .settings(.typing))]),
            HelpArticle(id: "mat-khau", title: "Ô mật khẩu chặn bộ gõ",
                        intro: "Khi đang nhập mật khẩu, macOS chặn mọi bộ gõ. Biểu tượng Mr TV có viền đứt; rời ô mật khẩu là gõ lại được."),
            HelpArticle(id: "mat-quyen", title: "Mất quyền sau khi cập nhật macOS",
                        intro: "Cập nhật macOS đôi khi tắt quyền Trợ năng mà không báo.",
                        steps: ["Mở Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Trợ năng.",
                                "Tìm Mr TV, tắt rồi bật lại.",
                                "Quay lại Mr TV: băng báo trong Cài đặt tự biến mất."],
                        actions: [("Mở Trợ năng…", .accessibility)]),
        ]
    }

    /// Chữ để tìm: tên bài, nội dung và mã bài ("mat-quyen" khớp "mat quyen").
    var haystack: String {
        ([title, intro, id.replacingOccurrences(of: "-", with: " ")] + steps).joined(separator: " ")
    }
}

@MainActor
final class PaletteModel: ObservableObject {
    @Published var query = "" { didSet { if query != oldValue { selected = 0 } } }
    @Published var selected = 0
    @Published var note: String?
    /// Chữ mà các việc chạy trên đó: chữ đang bôi đen (mở bằng Phím Mr TV), hoặc chữ trong clipboard.
    @Published var clip = ""
    /// Mở khi đang bôi đen: kết quả thay thẳng vào chữ đó.
    @Published var fromSelection = false
    /// Ứng dụng và chế độ lúc mở bảng, hiện ở góc trên khi chưa có chữ.
    var appName: String?
    var mode: InputMode = .vietnamese
    var method: EngineSettings.Method = .telex

    var isHelp: Bool { query.hasPrefix("?") }

    /// Gợi ý cho chữ đang có (tối đa 2), rồi mọi việc khác theo nhóm.
    var suggested: [ActionCard] {
        guard query.isEmpty, !clip.isEmpty else { return [] }
        return Array(ActionRegistry.shared.suggestions(for: clip, limit: 2))
    }

    var others: [ActionCard] {
        let picked = Set(suggested.map(\.id))
        let order = ActionGroup.allCases
        let list = ActionRegistry.shared.search(query).filter { !picked.contains($0.id) }
        return list.enumerated().sorted {
            let a = order.firstIndex(of: $0.element.group) ?? 0, b = order.firstIndex(of: $1.element.group) ?? 0
            return a == b ? $0.offset < $1.offset : a < b
        }.map(\.element)
    }

    var actions: [ActionCard] { suggested + others }

    var articles: [HelpArticle] {
        let q = fold(String(query.dropFirst()).trimmingCharacters(in: .whitespaces))
        let words = q.split(separator: " ").map(String.init)
        return HelpArticle.all.filter { a in
            let hay = fold(a.haystack)
            return words.allSatisfy { hay.contains($0) }
        }
    }

    private func fold(_ s: String) -> String { TextTool.strip.run(s.lowercased()) ?? s.lowercased() }

    var count: Int { isHelp ? articles.count : actions.count }

    func move(_ delta: Int) {
        guard count > 0 else { return }
        selected = (selected + delta + count) % count
    }

    var current: ActionCard? {
        let list = actions
        return !isHelp && selected < list.count ? list[selected] : nil
    }

    var article: HelpArticle? {
        let list = articles
        return isHelp && selected < list.count ? list[selected] : nil
    }

    /// Kết quả xem trước của việc đang chọn.
    var preview: String? {
        guard let card = current, !clip.isEmpty else { return nil }
        let out = ActionRegistry.shared.preview(card, on: clip)
        return out.isEmpty ? nil : out
    }
}

struct PaletteView: View {
    @ObservedObject var model: PaletteModel
    var run: (ActionCard) -> Void
    var help: (HelpArticle.Action) -> Void
    var close: () -> Void

    static let size = CGSize(width: 680, height: 480)
    static let insets = NSEdgeInsets(top: 16, left: 30, bottom: 44, right: 30)

    var body: some View {
        VStack(spacing: 0) {
            header
            FormDivider()
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        if model.isHelp { helpList } else { actionList }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                }
                .frame(width: 300)
                Rectangle().fill(Palette.line).frame(width: 0.5)
                Group {
                    if let article = model.article {
                        articleView(article)
                    } else if model.isHelp {
                        Text("Không thấy bài nào khớp. Thử từ khác, không dấu cũng được.")
                            .font(Fonts.text(13)).foregroundColor(Palette.ink2)
                    } else if model.clip.isEmpty {
                        emptyView
                    } else {
                        previewView
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            FormDivider()
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(GlassBackground(material: .popover, cornerRadius: 14, tint: Palette.window.opacity(0.72)))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.28), radius: 30, y: 20)
        .padding(EdgeInsets(top: Self.insets.top, leading: Self.insets.left, bottom: Self.insets.bottom, trailing: Self.insets.right))
        .foregroundColor(Palette.ink)
        .onExitCommand(perform: close)
    }

    // MARK: Đầu và chân bảng

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: model.isHelp ? "questionmark.circle" : "magnifyingglass")
                .font(.system(size: 17, weight: .regular)).foregroundColor(model.isHelp ? Palette.accent : Palette.ink2)
            PlainField(placeholder: "Tìm việc… (gõ ? để xem hướng dẫn)", text: $model.query, font: Fonts.text(17)) { submit() }
            Text(context).font(Fonts.text(11)).foregroundColor(Palette.ink2).lineLimit(1)
                .padding(.horizontal, 9).frame(height: 22)
                .background(Capsule().fill(Palette.fill))
                .fixedSize()
            KeyCap(label: "esc")
        }
        .padding(.horizontal, 16).frame(height: 54)
    }

    private var context: String {
        if model.isHelp { return "Hướng dẫn · hỏi không dấu cũng được" }
        if model.fromSelection { return "Chữ đang bôi đen" }
        if !model.clip.isEmpty { return "Chữ vừa chép" }
        let mode = model.mode == .vietnamese ? "Tiếng Việt · \(model.method.title)" : "Tiếng Anh"
        return [model.appName, mode].compactMap { $0 }.joined(separator: " · ")
    }

    private var footer: some View {
        HStack(spacing: 14) {
            hint(["↑↓"], model.isHelp ? "chọn bài" : "chọn")
            hint(["↩"], model.isHelp ? "làm theo" : "chạy")
            if model.isHelp {
                hint(["⌫"], "xoá ? để về danh sách việc")
            } else {
                hint(["?"], "hướng dẫn")
            }
            Spacer()
            Text(model.isHelp ? "\(HelpArticle.all.count) bài" : "\(ActionRegistry.shared.available.count) việc · tìm không dấu cũng được")
                .font(Fonts.text(11)).foregroundColor(Palette.ink2)
        }
        .padding(.horizontal, 16).frame(height: 34)
    }

    private func hint(_ keys: [String], _ text: String) -> some View {
        HStack(spacing: 5) {
            KeyCaps(caps: keys)
            Text(text).font(Fonts.text(11)).foregroundColor(Palette.ink2)
        }
    }

    // MARK: Danh sách bên trái

    @ViewBuilder private var actionList: some View {
        if !model.suggested.isEmpty {
            sectionTitle(model.fromSelection ? "Gợi ý cho chữ đang bôi đen" : "Gợi ý cho chữ vừa chép")
            ForEach(Array(model.suggested.enumerated()), id: \.element.id) { i, card in
                Button { run(card) } label: { bigRow(card, on: i == model.selected) }.buttonStyle(.plain)
            }
        }
        let offset = model.suggested.count
        let others = model.others
        ForEach(Array(others.enumerated()), id: \.element.id) { i, card in
            if i == 0 || others[i - 1].group != card.group {
                sectionTitle(model.query.isEmpty ? card.group.title : (i == 0 ? "Kết quả" : nil))
            }
            Button { run(card) } label: { row(card, on: offset + i == model.selected) }.buttonStyle(.plain)
        }
        if others.isEmpty && model.suggested.isEmpty {
            Text("Không thấy việc nào. Gõ ? để tìm trong hướng dẫn.").font(Fonts.text(12)).foregroundColor(Palette.ink2)
                .padding(8)
        }
    }

    @ViewBuilder private func sectionTitle(_ title: String?) -> some View {
        if let title {
            Text(title).font(Fonts.text(11, .semibold)).foregroundColor(Palette.ink2)
                .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 3)
        }
    }

    private func bigRow(_ card: ActionCard, on: Bool) -> some View {
        HStack(spacing: 10) {
            IconTile(symbol: card.symbol, color: card.group.color, size: 26)
                .overlay(RoundedRectangle(cornerRadius: 6.5, style: .continuous).strokeBorder(Color.white.opacity(on ? 0.5 : 0), lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(card.name).font(Fonts.text(13, .semibold))
                if !card.tip.isEmpty {
                    Text(card.tip).font(Fonts.text(11)).foregroundColor(on ? .white.opacity(0.88) : Palette.ink2).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if on { Text("↩").font(Fonts.text(13)) }
        }
        .foregroundColor(on ? .white : Palette.ink)
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(on ? Palette.accent : .clear))
        .contentShape(Rectangle())
    }

    private func row(_ card: ActionCard, on: Bool) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(card.group.color).frame(width: 16, height: 16)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.white.opacity(on ? 0.5 : 0), lineWidth: 0.5))
            Text(card.name).font(Fonts.text(13))
            Spacer(minLength: 8)
            if let reason = card.unavailableReason {
                Text(reason).font(Fonts.text(11)).foregroundColor(on ? .white.opacity(0.85) : Palette.ink2).lineLimit(1)
            }
        }
        .foregroundColor(on ? .white : Palette.ink)
        .padding(.horizontal, 8).frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(on ? Palette.accent : .clear))
        .opacity(card.isAvailable ? 1 : 0.6)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var helpList: some View {
        sectionTitle("Hướng dẫn")
        ForEach(Array(model.articles.enumerated()), id: \.element.id) { i, a in
            let on = i == model.selected
            Button { model.selected = i } label: {
                Text(a.title).font(Fonts.text(13, on ? .semibold : .regular))
                    .foregroundColor(on ? .white : Palette.ink)
                    .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(on ? Palette.accent : .clear))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Bên phải

    private func articleView(_ a: HelpArticle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(a.title).font(Fonts.text(20, .semibold)).fixedSize(horizontal: false, vertical: true)
            Text(a.intro).font(Fonts.text(13)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            if !a.steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(a.steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(i + 1).").font(Fonts.text(13)).foregroundColor(Palette.ink2).frame(width: 16, alignment: .trailing)
                            Text(step).font(Fonts.text(13)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            if !a.actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(a.actions.enumerated()), id: \.offset) { i, item in
                        if i == 0 {
                            Button(item.0) { help(item.1) }.buttonStyle(PrimaryButtonStyle(size: .medium))
                        } else {
                            Button(item.0) { help(item.1) }.buttonStyle(SecondaryButtonStyle(size: .medium))
                        }
                    }
                }
            }
        }
    }

    /// Chưa có chữ để chạy: hiện mọi phím đang dùng và vài gõ tắt (thay cho Bảng phím của bản cũ).
    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chưa có chữ để chạy").font(Fonts.text(13, .semibold))
                Text("Bôi đen chữ rồi bấm \(ShortcutStore.label(.mrtv)), hoặc chép (⌘C) một đoạn rồi mở lại bảng này.")
                    .font(Fonts.text(12)).foregroundColor(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Phím đang dùng").font(Fonts.text(11, .semibold)).foregroundColor(Palette.ink2)
                VStack(spacing: 0) {
                    keyRow(ShortcutStore.shared.trigger(.toggle).caps, model.mode == .vietnamese ? "Đổi sang tiếng Anh" : "Đổi sang tiếng Việt")
                    FormDivider()
                    keyRow(ShortcutStore.shared.trigger(.mrtv).caps, "Mở Bảng lệnh")
                    FormDivider()
                    keyRow(["esc"], "Lấy lại phím vừa gõ, bỏ gõ tắt vừa bung")
                    FormDivider()
                    keyRow(["⌘", "Z"], "Hoàn tác việc vừa chạy")
                }
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
            }
            let macros = SharedStore.macros.sorted { $0.key < $1.key }.prefix(3)
            if !macros.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gõ tắt của bạn").font(Fonts.text(11, .semibold)).foregroundColor(Palette.ink2)
                    ForEach(Array(macros), id: \.id) { m in
                        HStack(spacing: 10) {
                            Text(m.key).font(Fonts.mono(12)).foregroundColor(Palette.link).frame(width: 52, alignment: .leading)
                            Text(m.text).font(Fonts.text(12)).lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func keyRow(_ caps: [String], _ text: String) -> some View {
        HStack(spacing: 10) {
            Group {
                if caps.isEmpty { Text("Tắt").font(Fonts.text(11)).foregroundColor(Palette.ink2) } else { KeyCaps(caps: caps) }
            }
            .fixedSize()
            .frame(minWidth: 92, alignment: .leading)
            Text(text).font(Fonts.text(13))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }

    private var previewView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.fromSelection ? "Chữ đang bôi đen" : "Đang có trong clipboard").font(Fonts.text(11, .semibold)).foregroundColor(Palette.ink2)
            Text(model.clip).font(Fonts.text(13)).lineSpacing(2).lineLimit(4)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.fill))
            if let card = model.current {
                Image(systemName: "arrow.down").font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.ink2)
                    .frame(maxWidth: .infinity)
                Text("Sau khi \(card.name.lowercased())").font(Fonts.text(11, .semibold)).foregroundColor(Palette.ink2)
                Text(model.preview ?? card.unavailableReason ?? "Không làm được với chữ này")
                    .font(Fonts.text(15, .semibold)).lineSpacing(2).lineLimit(4)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.accent, lineWidth: 1.5))
            }
            Text(model.note ?? (model.fromSelection ? "Kết quả thay thẳng vào chữ đang bôi đen. ⌘Z để hoàn tác."
                                                    : "Kết quả được chép vào clipboard. Dán (⌘V) vào chỗ bạn cần."))
                .font(Fonts.text(11, model.note == nil ? .regular : .semibold))
                .foregroundColor(model.note == nil ? Palette.ink2 : Palette.ink)
                .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { submit() } label: {
                HStack(spacing: 8) { Text(model.fromSelection ? "Thay chữ đang bôi đen" : "Chép kết quả"); Text("↩").opacity(0.8) }
            }
            .buttonStyle(PrimaryButtonStyle(size: .large, fill: true))
            .disabled(model.preview == nil)
        }
    }

    private func submit() {
        if let card = model.current {
            run(card)
        } else if let first = model.article?.actions.first {
            help(first.1)
        }
    }
}

@MainActor
final class CommandPaletteController {
    private let model = PaletteModel()
    private lazy var panel = FloatingPanel(view, focusable: true, insets: PaletteView.insets)
    private var monitor: Any?
    private var resign: NSObjectProtocol?
    /// Ứng dụng đang dùng trước khi mở bảng, để trả focus về và thay chữ đang bôi đen.
    private var previousApp: NSRunningApplication?
    /// Thay chữ đang bôi đen ở ứng dụng đó (do AppDelegate đưa vào).
    var replaceSelection: ((String) -> Void)?

    private var view: PaletteView {
        PaletteView(model: model, run: { [weak self] in self?.run($0) },
                    help: { [weak self] in self?.perform($0) }, close: { [weak self] in self?.hide() })
    }

    /// `owner`: tiến trình của ô đang bôi đen, để trả focus về đúng nó (Spotlight không phải ứng dụng đứng trước).
    func show(query: String = "", selection: String? = nil, owner: pid_t? = nil) {
        let app = AppModel.shared
        previousApp = owner.flatMap { NSRunningApplication(processIdentifier: $0) } ?? NSWorkspace.shared.frontmostApplication
        model.fromSelection = selection != nil
        model.clip = selection ?? NSPasteboard.general.string(forType: .string) ?? ""
        model.appName = app.frontApp?.localizedName
        model.mode = app.currentMode
        model.method = app.engine.method
        model.query = query
        model.selected = 0
        model.note = nil
        panel.setContent(view)
        panel.showCentered()
        NSApp.activate(ignoringOtherApps: true)
        // Ô tìm đang giữ phím mũi tên và esc, nên bắt ở đây để chọn dòng và đóng bảng.
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let code = event.keyCode
                // NSEvent không Sendable: chỉ đưa mã phím vào, nhận lại là đã dùng phím hay chưa.
                let used = MainActor.assumeIsolated { () -> Bool in
                    guard let self, self.panel.isKeyWindow else { return false }
                    switch code {
                    case 125: self.model.move(1)
                    case 126: self.model.move(-1)
                    case 53: self.hide()
                    default: return false
                    }
                    return true
                }
                return used ? nil : event
            }
        }
        // Bấm ra ngoài (sang ứng dụng khác, cửa sổ khác) là đóng bảng.
        if resign == nil {
            resign = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.hide() }
            }
        }
    }

    func hide() {
        panel.orderOut(nil)
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let resign { NotificationCenter.default.removeObserver(resign) }
        resign = nil
    }

    private func perform(_ action: HelpArticle.Action) {
        hide()
        switch action {
        case .useInputSource: AppDelegate.current?.useInputSource()
        case .settings(let pane): AppDelegate.current?.openSettings(pane)
        case .accessibility: Permissions.open(.accessibility)
        }
    }

    private func run(_ card: ActionCard) {
        let board = NSPasteboard.general
        guard !model.clip.isEmpty else {
            model.note = "Chưa có chữ. Bôi đen chữ rồi bấm \(ShortcutStore.label(.mrtv)) để chạy việc trên đoạn đó."
            return
        }
        if card.custom?.runsExternally == true { model.note = "Đang chạy “\(card.name)”…" }
        ActionRegistry.shared.perform(card, on: model.clip) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .replace(let out) where self.model.fromSelection:
                self.hide()
                self.previousApp?.activate(options: [])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    MainActor.assumeIsolated { self?.replaceSelection?(out) }
                }
            case .replace(let out), .copy(let out):
                board.clearContents()
                board.setString(out, forType: .string)
                self.model.clip = out
                self.model.note = "Đã chép vào clipboard. Dán (⌘V) để dùng."
            case .opened:
                self.hide()
            case .failed(let why):
                self.model.note = why
            }
        }
    }
}

// MARK: Nhãn Việt/Anh cạnh con trỏ chữ

/// Viên nhỏ hiện thoáng qua dưới con trỏ chữ khi đổi Việt/Anh. Chữ V/E giống biểu tượng trên thanh menu.
struct HUDView: View {
    var mode: InputMode
    var appName: String?

    static let insets = NSEdgeInsets(top: 4, left: 12, bottom: 18, right: 12)

    var body: some View {
        let viet = mode == .vietnamese
        HStack(spacing: 7) {
            Text(viet ? "V" : "E")
                .font(Fonts.text(10, .heavy))
                .foregroundColor(viet ? .white : Palette.ink)
                .frame(width: 19, height: 14)
                .background(RoundedRectangle(cornerRadius: 3.5, style: .continuous).fill(viet ? Palette.accent : .clear))
                .overlay(RoundedRectangle(cornerRadius: 3.5, style: .continuous).strokeBorder(viet ? .clear : Palette.ink, lineWidth: 1.3))
            (Text(viet ? "Tiếng Việt" : "Tiếng Anh").font(Fonts.text(12, .semibold))
                + Text(appName.map { " · \($0)" } ?? "").font(Fonts.text(12)).foregroundColor(Palette.ink2))
                .lineLimit(1)
        }
        .foregroundColor(Palette.ink)
        .padding(.leading, 6).padding(.trailing, 11).frame(height: 26)
        .background(Capsule().fill(Palette.raised))
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.16), radius: 9, y: 6)
        .padding(EdgeInsets(top: Self.insets.top, leading: Self.insets.left, bottom: Self.insets.bottom, trailing: Self.insets.right))
        .accessibilityElement(children: .combine)
    }
}

@MainActor
final class HUDController {
    private var panel: FloatingPanel?
    private var work: DispatchWorkItem?

    func show(mode: InputMode, appName: String?) {
        guard AppModel.shared.cursorLabel else { return }
        let view = HUDView(mode: mode, appName: appName)
        let p = panel ?? FloatingPanel(view, insets: HUDView.insets)
        panel = p
        p.setContent(view)
        // Ngay dưới con trỏ chữ; không đọc được thì giữa cửa sổ đang dùng, cuối cùng mới là cạnh chuột.
        if let caret = AXContext.caretRect() {
            p.show(near: caret, gap: 6, below: true)
        } else if let window = AXContext.focusedWindowFrame() {
            p.show(near: CGRect(x: window.midX - p.frame.width / 2, y: window.midY, width: 0, height: 0), gap: 0, below: true)
        } else {
            p.show(near: nil, gap: 18)
        }
        work?.cancel()
        let w = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.panel?.fadeOut() } }
        work = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: w)
    }
}
