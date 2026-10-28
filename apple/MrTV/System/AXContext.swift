import AppKit
import ApplicationServices

/// Đọc chữ ngay trước con trỏ qua Trợ năng, cho đường B (gõ đè): con trỏ vừa đổi chỗ thì lấy từ
/// trước con trỏ làm từ đang gõ. Gọi được từ luồng của event tap; chờ tối đa 50 ms mỗi lần hỏi.
enum AXContext {
    private static let timeout: Float = 0.05

    /// Chữ trước con trỏ (tối đa `length` ký tự). nil khi đang bôi đen, con trỏ ở giữa một từ,
    /// hay ứng dụng không cho đọc.
    static func textBeforeCaret(length: Int = 32) -> String? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, timeout)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, timeout)
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range), range.length == 0, range.location > 0 else { return nil }
        if let after = string(element, CFRange(location: range.location, length: 1)),
           let next = after.unicodeScalars.first, CharacterSet.alphanumerics.contains(next) {
            return nil
        }
        let start = max(0, range.location - length)
        return string(element, CFRange(location: start, length: range.location - start))
    }

    /// Số đơn vị UTF-16 đang bôi đen trong ô đang gõ (0 là không bôi đen); nil khi ứng dụng không cho đọc.
    /// Gọi được từ luồng của event tap.
    static func selectionLength() -> Int? {
        guard let element = focusedElement() else { return nil }
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else { return nil }
        return range.length
    }

    /// Khung con trỏ chữ trên màn hình (toạ độ AppKit), để nhãn Việt/Anh hiện ngay dưới chỗ đang gõ.
    /// nil khi chưa có quyền Trợ năng hay ứng dụng không cho đọc vị trí chữ.
    @MainActor
    static func caretRect() -> CGRect? {
        guard Permissions.accessibility, let element = focusedElement() else { return nil }
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else { return nil }
        // Khung của ký tự ngay trước con trỏ (con trỏ ở đầu ô thì ký tự sau nó).
        let before = range.location > 0
        let probe = CFRange(location: before ? range.location - 1 : range.location, length: 1)
        guard let glyph = bounds(element, probe) ?? bounds(element, CFRange(location: range.location, length: 0)),
              glyph.height > 0 else { return nil }
        return appKit(CGRect(x: before ? glyph.maxX : glyph.minX, y: glyph.minY, width: 1, height: glyph.height))
    }

    /// Khung cửa sổ đang dùng (toạ độ AppKit).
    @MainActor
    static func focusedWindowFrame() -> CGRect? {
        guard Permissions.accessibility else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, timeout)
        var app: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &app) == .success,
              let app, CFGetTypeID(app) == AXUIElementGetTypeID() else { return nil }
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        let w = window as! AXUIElement
        var pos: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &pos) == .success,
              AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &size) == .success,
              let pos, let size else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(pos as! AXValue, .cgPoint, &origin), AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        return appKit(CGRect(origin: origin, size: extent))
    }

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, timeout)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, timeout)
        return element
    }

    private static func bounds(_ element: AXUIElement, _ range: CFRange) -> CGRect? {
        var r = range
        guard let value = AXValueCreate(.cfRange, &r) else { return nil }
        var out: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, value, &out) == .success,
              let out, CFGetTypeID(out) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(out as! AXValue, .cgRect, &rect), rect.width < 10_000 else { return nil }
        return rect
    }

    /// Trợ năng tính từ góc trên bên trái màn hình chính; AppKit tính từ góc dưới.
    @MainActor
    private static func appKit(_ r: CGRect) -> CGRect {
        let height = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: r.minX, y: height - r.maxY, width: r.width, height: r.height)
    }

    private static func string(_ element: AXUIElement, _ range: CFRange) -> String? {
        var r = range
        guard let value = AXValueCreate(.cfRange, &r) else { return nil }
        var out: CFTypeRef?
        if AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, value, &out) == .success,
           let s = out as? String {
            return s
        }
        // Ứng dụng không hỗ trợ đọc theo khoảng: đọc cả giá trị rồi cắt (chỉ với ô ngắn).
        var whole: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &whole) == .success,
              let text = whole as? String else { return nil }
        let utf16 = Array(text.utf16)
        guard utf16.count < 200_000, range.location >= 0, range.location + range.length <= utf16.count else { return nil }
        return String(utf16CodeUnits: Array(utf16[range.location..<range.location + range.length]), count: range.length)
    }
}
