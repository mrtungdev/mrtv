import AppKit
import SwiftUI

/// Bảng nổi không cướp focus của ứng dụng đang gõ (thanh gợi ý, HUD, bảng phím).
/// `focusable` = true cho bảng lệnh, vì cần ô gõ tìm kiếm.
/// Bóng đổ do SwiftUI vẽ (đúng thông số canvas), nên nội dung có lề trong suốt `insets` quanh bảng.
@MainActor
final class FloatingPanel: NSPanel {
    private let focusable: Bool
    private let insets: NSEdgeInsets

    init<Content: View>(_ content: Content, focusable: Bool = false, insets: NSEdgeInsets = NSEdgeInsets()) {
        self.focusable = focusable
        self.insets = insets
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = !focusable
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let host = NSHostingView(rootView: content)
        contentView = host
        setContentSize(host.fittingSize)
    }

    override var canBecomeKey: Bool { focusable }
    override var canBecomeMain: Bool { false }

    func setContent<Content: View>(_ content: Content) {
        let host = NSHostingView(rootView: content)
        contentView = host
        setContentSize(host.fittingSize)
    }

    /// Đặt bảng cạnh vùng chọn (hoặc cạnh chuột), không tràn khỏi màn hình.
    /// `below`: ưu tiên ngay dưới dòng chữ (thanh gợi ý), hết chỗ thì lên trên; không thì ngược lại.
    /// `animated`: hiện dần và trượt nhẹ 6 pt.
    func show(near rect: CGRect?, gap: CGFloat = 8, below: Bool = false, animated: Bool = false) {
        let anchor = rect ?? CGRect(origin: NSEvent.mouseLocation, size: .zero)
        let screen = NSScreen.screens.first { $0.frame.insetBy(dx: -1, dy: -1).contains(anchor.origin) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let size = frame.size
        let aboveY = anchor.maxY + gap - insets.bottom
        let belowY = anchor.minY - gap - size.height + insets.top
        let fitsAbove = aboveY + size.height - insets.top <= visible.maxY
        let fitsBelow = belowY + insets.bottom >= visible.minY
        var origin = CGPoint(x: anchor.minX - insets.left, y: below ? (fitsBelow ? belowY : aboveY) : (fitsAbove ? aboveY : belowY))
        origin.x = min(max(origin.x, visible.minX + 8 - insets.left), visible.maxX - size.width + insets.right - 8)
        origin.y = min(max(origin.y, visible.minY + 8 - insets.bottom), visible.maxY - size.height + insets.top - 8)
        let wentBelow = origin.y == belowY
        if animated {
            alphaValue = 0
            setFrameOrigin(CGPoint(x: origin.x, y: origin.y + (wentBelow ? 6 : -6)))
        } else {
            alphaValue = 1
            setFrameOrigin(origin)
        }
        if focusable {
            makeKeyAndOrderFront(nil)
        } else {
            orderFrontRegardless()
        }
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.14
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().alphaValue = 1
                animator().setFrameOrigin(origin)
            }
        }
    }

    /// Ẩn dần trong 0,1 giây.
    func fadeOut() {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.alphaValue == 0 else { return }
                self.orderOut(nil)
                self.alphaValue = 1
            }
        })
    }

    /// Đặt giữa màn hình theo chiều ngang; `height` là vị trí tâm theo chiều dọc (0 = đáy, 1 = đỉnh).
    func showCentered(height: CGFloat = 0.62) {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        setFrameOrigin(CGPoint(x: f.midX - frame.width / 2, y: f.minY + f.height * height - frame.height / 2))
        if focusable {
            makeKeyAndOrderFront(nil)
        } else {
            orderFrontRegardless()
        }
    }
}

// MARK: Thanh gợi ý

@MainActor
final class QuickBarModel: ObservableObject {
    /// Bản gọn tự hiện khi bôi đen, hoặc danh sách đầy đủ khi bấm Phím Mr TV.
    enum Mode { case peek, list }

    @Published var mode: Mode = .peek
    @Published var text = ""
    @Published var suggestions: [ActionCard] = []
    /// Kết quả xem trước của từng việc trong danh sách.
    @Published var previews: [String] = []
    @Published var selected = 0
    @Published var status: String?
    @Published var showTip = false
}

/// Bản gọn: tối đa 3 việc nhỏ ngay dưới chữ đang bôi đen, như phần xem trước trong Cài đặt.
struct QuickBarView: View {
    @ObservedObject var model: QuickBarModel
    var choose: (Int) -> Void
    var expand: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                MrTVLogo(size: 22, round: true, background: Palette.fixed(0x0D0F1C), ink: Palette.fixed(0xF6F7FB),
                         accent: Palette.fixed(0xFF5C8A))
                    .padding(.leading, 3).padding(.trailing, 3)
                ForEach(Array(model.suggestions.prefix(3).enumerated()), id: \.element.id) { i, card in
                    Button { choose(i) } label: {
                        QuickChip(index: i, title: card.name, group: card.group, selected: false, symbol: card.symbol, compact: true)
                    }
                    .buttonStyle(HoverChipStyle())
                }
                Button(action: expand) {
                    HStack(spacing: 3) {
                        ForEach(Array(ShortcutStore.shared.trigger(.mrtv).caps.enumerated()), id: \.offset) { _, c in
                            Text(c).font(Fonts.text(11, .bold))
                        }
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .heavy))
                    }
                    .foregroundColor(Palette.ink2)
                    .padding(.horizontal, 9).frame(minHeight: 32)
                    .contentShape(Capsule())
                }
                .buttonStyle(HoverChipStyle())
                .help("Xem mọi việc làm được với đoạn này")
            }
            .padding(4)
            .background(GlassBackground(material: .popover, cornerRadius: 22).clipShape(Capsule()))
            .overlay(Capsule().stroke(scheme == .dark ? Color.white.opacity(0.12) : Palette.fixed(0x0D0F1C, 0.16), lineWidth: 0.5))
            .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.18), radius: 16, y: 10)

            if let status = model.status {
                DarkNote(text: status)
            } else if model.showTip {
                DarkNote(text: "Bấm 1, 2, 3 để chọn · \(ShortcutStore.label(.mrtv)) xem thêm · esc đóng")
            }
        }
        .padding(EdgeInsets(top: Self.insets.top, leading: Self.insets.left, bottom: Self.insets.bottom, trailing: Self.insets.right))
    }

    /// Lề trong suốt cho bóng đổ.
    static let insets = NSEdgeInsets(top: 8, left: 24, bottom: 36, right: 24)
}

/// Nền mờ khi rê chuột lên một việc.
struct HoverChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverChip(configuration: configuration)
    }

    private struct HoverChip: View {
        let configuration: ButtonStyleConfiguration
        @State private var hover = false

        var body: some View {
            configuration.label
                .background(Capsule().fill(hover || configuration.isPressed ? Palette.fill2 : .clear))
                .onHover { hover = $0 }
        }
    }
}

/// Danh sách đầy đủ (Phím Mr TV khi đang bôi đen): mọi việc hợp với đoạn đã chọn, kèm kết quả xem trước.
struct QuickListView: View {
    @ObservedObject var model: QuickBarModel
    var choose: (Int) -> Void
    var palette: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Với đoạn đã chọn").font(Fonts.text(11.5, .heavy)).foregroundColor(Palette.ink2)
                Text(model.text.replacingOccurrences(of: "\n", with: " ")).font(Fonts.text(13)).foregroundColor(Palette.ink)
                    .lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            Rectangle().fill(Palette.line).frame(height: 1)
            VStack(spacing: 2) {
                ForEach(Array(model.suggestions.enumerated()), id: \.element.id) { i, card in
                    Button { choose(i) } label: { row(i, card) }.buttonStyle(.plain)
                }
            }
            .padding(6)
            if let status = model.status {
                Text(status).font(Fonts.text(12, .semibold)).foregroundColor(Palette.bad).padding(.horizontal, 16).padding(.bottom, 8)
            }
            Rectangle().fill(Palette.line).frame(height: 1)
            HStack(spacing: 10) {
                hint("1–\(model.suggestions.count)", "chọn")
                hint("↑↓", "")
                hint("↩", "dùng")
                hint("esc", "đóng")
                Spacer()
                Button("Bảng lệnh…", action: palette).buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 14).frame(height: 46)
        }
        .frame(width: 420)
        .background(GlassBackground(material: .popover, cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(scheme == .dark ? Color.white.opacity(0.12) : Palette.fixed(0x0D0F1C, 0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.22), radius: 24, y: 16)
        .padding(EdgeInsets(top: Self.insets.top, leading: Self.insets.left, bottom: Self.insets.bottom, trailing: Self.insets.right))
    }

    static let insets = NSEdgeInsets(top: 10, left: 30, bottom: 48, right: 30)

    private func row(_ i: Int, _ card: ActionCard) -> some View {
        let on = i == model.selected
        let preview = i < model.previews.count ? model.previews[i] : ""
        return HStack(spacing: 10) {
            Text("\(i + 1)").font(Fonts.text(11, .bold))
                .foregroundColor(on ? Palette.fixed(0xF6F7FB) : Palette.ink2)
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(on ? Color.white.opacity(0.18) : Palette.fill))
            IconTile(symbol: card.symbol, color: card.group.color, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(card.name).font(Fonts.text(13.5, .bold))
                if !preview.isEmpty {
                    Text(preview.replacingOccurrences(of: "\n", with: " ")).font(Fonts.text(12))
                        .foregroundColor(on ? Palette.fixed(0xDDE2FF) : Palette.ink2).lineLimit(1).truncationMode(.tail)
                }
            }
            Spacer(minLength: 0)
            if on { Text("↩").font(Fonts.text(13)).opacity(0.8) }
        }
        .foregroundColor(on ? Palette.fixed(0xF6F7FB) : Palette.ink)
        .padding(.horizontal, 10).frame(minHeight: 50)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Palette.fixed(0x3B5BFF) : .clear))
        .contentShape(Rectangle())
    }

    private func hint(_ key: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Text(key).font(Fonts.text(11, .bold)).foregroundColor(Palette.ink)
            if !text.isEmpty { Text(text).font(Fonts.text(11.5)).foregroundColor(Palette.ink2) }
        }
    }
}

/// Một việc: vòng màu, tên việc, phím số. Việc đang chọn có viền đậm.
struct QuickChip: View {
    var index: Int
    var title: String
    var group: ActionGroup
    var selected: Bool
    /// Biểu tượng riêng (việc tự tạo); không có thì theo nhóm.
    var symbol: String? = nil
    /// Bản nhỏ cho thanh gợi ý gọn và phần xem trước trong Cài đặt.
    var compact = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        HStack(spacing: compact ? 6 : 9) {
            Circle().fill(group.color).frame(width: compact ? 22 : 30, height: compact ? 22 : 30)
                .overlay(Image(systemName: symbol ?? group.symbol).font(.system(size: compact ? 10 : 13, weight: .bold)).foregroundColor(.white))
            Text(title).font(Fonts.text(compact ? 12.5 : 14, .bold)).foregroundColor(Palette.ink).lineLimit(1).fixedSize()
            Text("\(index + 1)")
                .font(Fonts.text(compact ? 10 : 11, .bold)).foregroundColor(dark ? Palette.fixed(0xECEFF5) : Palette.fixed(0x0D0F1C))
                .frame(minWidth: compact ? 17 : 20, minHeight: compact ? 17 : 20)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(dark ? Color.white.opacity(0.12) : .white))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(dark ? Color.white.opacity(0.18) : Palette.fixed(0x0D0F1C, 0.16), lineWidth: 1))
        }
        .padding(.leading, compact ? 4 : 6).padding(.trailing, compact ? 8 : 12)
        .frame(minHeight: compact ? 32 : 44)
        .background(Capsule().fill(selected ? (dark ? Color.white.opacity(0.14) : Color.white) : .clear)
            .shadow(color: Palette.fixed(0x0D0F1C, selected && !dark ? 0.16 : 0), radius: 8, y: 6))
        .overlay(Capsule().stroke(selected ? (dark ? Palette.fixed(0xECEFF5) : Palette.fixed(0x0D0F1C)) : .clear, lineWidth: 2))
        .contentShape(Capsule())
    }
}

/// Viên báo tối, như "Đã thay · ⌘Z để hoàn tác" trên canvas.
struct DarkNote: View {
    var text: String

    var body: some View {
        Text(text).font(Fonts.text(12.5, .semibold)).foregroundColor(Palette.fixed(0xF6F7FB))
            .padding(.horizontal, 14).frame(minHeight: 32)
            .background(Capsule().fill(Palette.fixed(0x0D0F1C, 0.9)))
            .shadow(color: .black.opacity(0.3), radius: 17, y: 14)
    }
}

@MainActor
final class QuickBarController {
    private let selection: SelectionService
    private let model = QuickBarModel()
    private lazy var peekPanel = FloatingPanel(peekView, insets: QuickBarView.insets)
    private lazy var listPanel = FloatingPanel(listView, insets: QuickListView.insets)
    private var hideWork: DispatchWorkItem?
    private var monitor: Any?
    private var anchor: CGRect?

    private var peekView: QuickBarView {
        QuickBarView(model: model, choose: { [weak self] in self?.choose($0) },
                     expand: { [weak self] in self?.expand() })
    }

    private var listView: QuickListView {
        QuickListView(model: model, choose: { [weak self] in self?.choose($0) }, palette: { [weak self] in self?.openPalette() })
    }

    /// Phím số 1–9 trên hàng phím số.
    nonisolated private static let digitCodes: [Int64] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    init(selection: SelectionService) {
        self.selection = selection
        TapTypist.shared.quickBarKeys = { code, isList in
            let digit = Self.digitCodes.firstIndex(of: code)
            let handled: Bool
            if isList {
                handled = digit != nil || [53, 125, 126, 36, 76].contains(code)
            } else {
                handled = (digit ?? 9) < 3 || code == 53
            }
            guard handled else { return false }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { AppDelegate.current?.quickBar.key(code, digit: digit) }
            }
            return true
        }
    }

    var isVisible: Bool { peekPanel.isVisible || listPanel.isVisible }

    /// Bản gọn, tự hiện khi bôi đen.
    func show(text: String, near rect: CGRect?) {
        let picks = ActionRegistry.shared.suggestions(for: text)
        guard !picks.isEmpty else { return }
        listPanel.orderOut(nil)
        model.mode = .peek
        model.text = text
        model.suggestions = picks
        model.previews = []
        model.status = nil
        let seenKey = "quickBarSeen"
        // Mẹo tạm tắt (mục Hướng dẫn & mẹo đang ẩn); chỉ nhắc phím một lần đầu.
        model.showTip = !UserDefaults.standard.bool(forKey: seenKey)
        UserDefaults.standard.set(true, forKey: seenKey)
        anchor = rect
        peekPanel.setContent(peekView)
        // Ngay dưới dòng chữ đang bôi đen, như trên canvas; hết chỗ thì lên trên.
        peekPanel.show(near: rect, gap: 6, below: true, animated: true)
        TapTypist.shared.setQuickBarOpen(true)
        watchOutside()
        scheduleHide(after: 8)
    }

    /// Danh sách đầy đủ, khi bấm Phím Mr TV lúc đang bôi đen.
    func showList(text: String, near rect: CGRect?) {
        let picks = ActionRegistry.shared.listSuggestions(for: text)
        guard !picks.isEmpty else {
            AppDelegate.current?.openPalette(selection: text)
            return
        }
        peekPanel.orderOut(nil)
        model.mode = .list
        model.text = text
        model.suggestions = picks
        model.previews = picks.map { ActionRegistry.shared.preview($0, on: text) }
        model.selected = 0
        model.status = nil
        anchor = rect ?? anchor
        listPanel.setContent(listView)
        listPanel.show(near: anchor, gap: 6, below: true, animated: true)
        TapTypist.shared.setQuickBarOpen(true, list: true)
        watchOutside()
        hideWork?.cancel()
    }

    /// Bấm nút ⌥⌥ trên bản gọn.
    private func expand() {
        showList(text: model.text, near: anchor)
    }

    fileprivate func key(_ code: Int64, digit: Int?) {
        if code == 53 { return hide() }
        if let digit { return choose(digit) }
        switch code {
        case 125: model.selected = min(model.selected + 1, model.suggestions.count - 1)
        case 126: model.selected = max(model.selected - 1, 0)
        default: choose(model.selected)
        }
    }

    func choose(_ index: Int) {
        guard index < model.suggestions.count else { return }
        let card = model.suggestions[index]
        if card.custom?.runsExternally == true { model.status = "Đang chạy “\(card.name)”…" }
        ActionRegistry.shared.perform(card, on: model.text) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .replace(let out):
                self.hide()
                self.selection.replaceSelection(with: out)
            case .copy(let out):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(out, forType: .string)
                self.model.status = "Đã chép kết quả · ⌘V để dán"
                self.scheduleHide(after: 1.6, force: true)
            case .opened:
                self.hide()
            case .failed(let why):
                self.model.status = why
                self.scheduleHide(after: 2.5, force: true)
            }
        }
    }

    private func openPalette() {
        let text = model.text
        hide()
        AppDelegate.current?.openPalette(selection: text)
    }

    func hide() {
        hideWork?.cancel()
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        peekPanel.fadeOut()
        listPanel.fadeOut()
        TapTypist.shared.setQuickBarOpen(false)
    }

    /// Bấm chuột ra ngoài, cuộn, hay gõ tiếp ở ứng dụng khác thì ẩn. Phím chọn việc đã được
    /// đường B nuốt nên không tới đây.
    private func watchOutside() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    private func scheduleHide(after seconds: TimeInterval, force: Bool = false) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                // Danh sách đầy đủ do người dùng gọi: không tự ẩn, trừ khi vừa báo kết quả.
                guard let self, force || self.model.mode == .peek else { return }
                self.hide()
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
