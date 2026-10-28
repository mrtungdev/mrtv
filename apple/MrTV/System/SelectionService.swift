import AppKit
import ApplicationServices

/// Đọc chữ đang bôi đen và vị trí của nó qua Trợ năng (AX), thay chữ sau khi chạy một việc.
///
/// Chromium/Electron đọc qua AX không chắc chắn: khi cần (⌥⌥) thì chép bằng ⌘C rồi trả lại clipboard như cũ.
@MainActor
final class SelectionService {
    struct Picked {
        var text: String
        var rect: CGRect?
    }

    /// Ô chứa chữ đang bôi đen, ghi lại lúc mở bảng lệnh để lát nữa thay đúng ô đó. Spotlight và các bảng
    /// nổi nhận phím trong khi ứng dụng khác vẫn đứng trước, nên không suy ra được từ ứng dụng đứng trước.
    struct Target {
        let element: AXUIElement
        let pid: pid_t
    }

    /// Kết quả đọc vùng chọn qua Trợ năng.
    enum Read {
        case text(Picked)
        /// Đọc được, nhưng không có chữ nào đang bôi đen.
        case empty
        /// Không đọc được (thiếu quyền, hoặc ứng dụng không cho đọc qua Trợ năng).
        case unknown
    }

    /// Có chữ được bôi đen sau khi thả chuột hoặc chọn bằng Shift + mũi tên.
    var onSelection: ((String, CGRect?) -> Void)?
    private var monitor: Any?
    private var pending: DispatchWorkItem?

    func start(delay: TimeInterval) {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .keyUp]) { [weak self] event in
            let isSelectionKey = event.type == .keyUp && event.modifierFlags.contains(.shift)
            guard event.type == .leftMouseUp || isSelectionKey else { return }
            MainActor.assumeIsolated { self?.schedule(after: delay) }
        }
    }

    private func schedule(after delay: TimeInterval, retry: Bool = true) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch self.read() {
                case .text(let picked) where picked.text.count >= 2:
                    self.onSelection?(picked.text, picked.rect)
                case .unknown where retry:
                    // Electron, Chromium dựng cây trợ năng sau khi được nhờ: đọc lại một lần nữa.
                    self.schedule(after: 0.3, retry: false)
                default:
                    break
                }
            }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func focusedElement() -> AXUIElement? {
        systemFocused()
    }

    /// Electron (Claude, Slack, VS Code…) và Chromium chỉ mở cây trợ năng khi được nhờ.
    /// Nhờ một lần cho mỗi tiến trình; lần đọc sau sẽ được.
    private func enableAccessibilityForFrontApp() {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier, !enabledPIDs.contains(pid) else { return }
        enabledPIDs.insert(pid)
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }

    private var enabledPIDs = Set<pid_t>()

    private func systemFocused() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    /// Ô đang có focus (và tiến trình của nó), nil khi không có quyền hay ứng dụng không cho đọc.
    func target() -> Target? {
        guard Permissions.accessibility, let el = focusedElement() else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(el, &pid) == .success else { return nil }
        return Target(element: el, pid: pid)
    }

    func currentSelection() -> Picked? {
        if case .text(let picked) = read() { return picked }
        return nil
    }

    func read() -> Read {
        guard Permissions.accessibility else { return .unknown }
        guard let el = focusedElement() else {
            enableAccessibilityForFrontApp()
            return .unknown
        }
        var text: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextAttribute as CFString, &text) == .success,
              let s = text as? String else {
            enableAccessibilityForFrontApp()
            return .unknown
        }
        return s.isEmpty ? .empty : .text(Picked(text: s, rect: selectionRect(el)))
    }

    /// Khung của vùng chọn, đổi sang toạ độ AppKit. Mép trái lấy theo chữ đầu tiên, mép dưới theo dòng cuối,
    /// để thanh gợi ý nằm ngay dưới đoạn chọn, thẳng hàng với chỗ bắt đầu bôi đen.
    private func selectionRect(_ el: AXUIElement) -> CGRect? {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range), let all = bounds(el, range) else { return nil }
        let first = bounds(el, CFRange(location: range.location, length: min(range.length, 1))) ?? all
        // AX tính từ góc trên bên trái màn hình chính; AppKit tính từ góc dưới.
        let height = NSScreen.screens.first?.frame.height ?? 0
        let union = all.union(first)
        guard union.width > 0 || union.height > 0 else { return nil }
        return CGRect(x: first.minX, y: height - union.maxY, width: max(union.maxX - first.minX, 1), height: union.height)
    }

    private func bounds(_ el: AXUIElement, _ range: CFRange) -> CGRect? {
        var r = range
        guard let value = AXValueCreate(.cfRange, &r) else { return nil }
        var out: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, value, &out) == .success,
              let out, CFGetTypeID(out) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(out as! AXValue, .cgRect, &rect), rect.width < 10_000 else { return nil }
        return rect
    }

    /// Thay chữ đang bôi đen. Thử AX trước, không được thì dán.
    /// Có `target` thì chỉ thay trong đúng ô đó: ô đã đóng (Spotlight tự đóng khi mất focus) hay focus đã sang
    /// ô khác thì không dán bừa, mà chép kết quả vào clipboard để người dùng tự dán.
    func replaceSelection(with text: String, in target: Target? = nil) {
        guard let target else {
            if let el = focusedElement(),
               AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success {
                return
            }
            return paste(text)
        }
        if AXUIElementSetAttributeValue(target.element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success {
            return
        }
        if let now = focusedElement(), CFEqual(now, target.element) {
            return paste(text)
        }
        Log.app.info("Ô đã bôi đen không còn focus: chép kết quả vào clipboard thay vì dán")
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
    }

    /// Dán chữ rồi trả lại clipboard như cũ.
    func paste(_ text: String) {
        let board = NSPasteboard.general
        let saved = PasteboardSnapshot(board)
        board.clearContents()
        board.setString(text, forType: .string)
        let ours = board.changeCount
        sendKey(9, command: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // Trong lúc chờ mà có ai chép cái mới thì giữ cái mới, không đè lại bằng bản cũ.
            guard board.changeCount == ours else { return }
            saved.restore(to: board)
        }
    }

    /// Dự phòng cho ứng dụng không cho đọc vùng chọn qua AX: chép bằng ⌘C.
    func copySelection(_ done: @escaping @MainActor (String?) -> Void) {
        let board = NSPasteboard.general
        let saved = PasteboardSnapshot(board)
        let before = board.changeCount
        sendKey(8, command: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            MainActor.assumeIsolated {
                let copied = board.changeCount != before ? board.string(forType: .string) : nil
                if copied != nil { saved.restore(to: board) }
                done(copied)
            }
        }
    }

    private func sendKey(_ code: CGKeyCode, command: Bool) {
        let src = CGEventSource(stateID: .privateState)
        src?.userData = TapTypist.marker
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down)
            if command { e?.flags = .maskCommand }
            e?.post(tap: .cgSessionEventTap)
        }
    }
}
