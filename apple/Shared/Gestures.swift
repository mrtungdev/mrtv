import CoreGraphics
import Foundation

/// Phím bổ trợ dùng để chạm hai lần, giữ, hoặc nhấn cùng nhau.
enum Modifier: String, Codable, CaseIterable, Comparable {
    case control, option, shift, command

    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .shift: return .maskShift
        case .command: return .maskCommand
        }
    }

    /// Thứ tự hiện theo quy ước của macOS: ⌃ ⌥ ⇧ ⌘.
    static func < (a: Modifier, b: Modifier) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }

    static func from(_ flags: CGEventFlags) -> Set<Modifier> {
        Set(allCases.filter { flags.contains($0.flag) })
    }
}

/// Cách bấm để gọi một việc của Mr TV.
enum Trigger: Codable, Hashable {
    case off
    /// Phím 🌐 (fn) bấm rồi thả, không kèm phím nào.
    case fn
    /// Chạm phím bổ trợ hai lần thật nhanh, ví dụ ⌥⌥.
    case double(Modifier)
    /// Giữ phím bổ trợ một mình.
    case hold(Modifier)
    /// Nhấn vài phím bổ trợ cùng lúc rồi thả, không kèm phím nào, ví dụ ⌃⇧.
    case chord([Modifier])
    /// Tổ hợp có một phím thường, ví dụ ⌃⌥V.
    case combo(keyCode: UInt16, modifiers: [Modifier], key: String)

    /// Các phím để vẽ thành phím bấm.
    var caps: [String] {
        switch self {
        case .off: return []
        case .fn: return ["fn"]
        case .double(let m): return [m.symbol, m.symbol]
        case .hold(let m): return [m.symbol]
        case .chord(let ms): return ms.sorted().map(\.symbol)
        case .combo(_, let ms, let key): return ms.sorted().map(\.symbol) + [key]
        }
    }

    /// Chữ ngắn để chèn vào câu: "fn", "⌥⌥", "giữ ⌥", "⌃⌥V".
    var label: String {
        switch self {
        case .off: return "Tắt"
        case .hold(let m): return "giữ \(m.symbol)"
        default: return caps.joined()
        }
    }

    /// Cách bấm, nói thành lời.
    var spoken: String {
        switch self {
        case .off: return "Không dùng phím"
        case .fn: return "Bấm rồi thả phím 🌐 fn"
        case .double(let m): return "Chạm \(m.symbol) hai lần thật nhanh"
        case .hold(let m): return "Giữ \(m.symbol) một lúc"
        case .chord(let ms): return "Nhấn \(ms.sorted().map(\.symbol).joined()) cùng lúc rồi thả"
        case .combo: return "Nhấn tổ hợp \(label)"
        }
    }
}

/// Nhận ra fn, chạm hai lần, giữ và nhấn cùng lúc từ chuỗi thay đổi phím bổ trợ.
/// Không tự hẹn giờ: nơi dùng gọi `holdCheck(at:)` sau `holdAfter` giây để biết có đang giữ không.
/// Tách khỏi event tap để thử được bằng XCTest.
struct GestureDetector {
    enum Event: Equatable {
        case fired(Trigger)
        case holdBegan(Modifier)
        case holdEnded(Modifier)
    }

    static let doubleTapWindow: TimeInterval = 0.4
    static let tapMax: TimeInterval = 0.3
    static let chordMax: TimeInterval = 1.0
    static let holdAfter: TimeInterval = 0.6

    private(set) var down: Set<Modifier> = []
    private var peak: Set<Modifier> = []
    private var dirty = false
    private var pressedAt: TimeInterval = 0
    private var lastTap: (Modifier, TimeInterval)?
    private var holding: Modifier?
    private var fnDown = false
    private var fnDirty = false

    /// Đang giữ đúng một phím bổ trợ, chưa xen phím nào: nơi dùng nên hẹn `holdCheck`.
    var holdCandidate: Modifier? {
        guard down.count == 1, !dirty, holding == nil else { return nil }
        return down.first
    }

    /// Có phím thường hay cú bấm chuột xen vào: không còn là chạm, giữ hay nhấn cùng lúc nữa.
    mutating func otherInput() -> [Event] {
        fnDirty = fnDown
        if !down.isEmpty { dirty = true }
        lastTap = nil
        return endHold()
    }

    mutating func fn(down isDown: Bool) -> [Event] {
        if isDown {
            fnDown = true
            fnDirty = !down.isEmpty
            return []
        }
        guard fnDown else { return [] }
        fnDown = false
        return !fnDirty && down.isEmpty ? [.fired(.fn)] : []
    }

    mutating func modifiers(_ new: Set<Modifier>, at now: TimeInterval) -> [Event] {
        let old = down
        down = new
        var events: [Event] = []
        if old.isEmpty && !new.isEmpty {
            peak = new
            dirty = fnDown
            pressedAt = now
        } else {
            peak.formUnion(new)
        }
        if let h = holding, new != [h] {
            events += endHold()
            if new.isEmpty { return events }
            dirty = true
        }
        guard new.isEmpty, !old.isEmpty, !dirty else { return events }
        let held = now - pressedAt
        if peak.count == 1, let m = peak.first, held < Self.tapMax {
            if let (last, at) = lastTap, last == m, now - at < Self.doubleTapWindow {
                lastTap = nil
                events.append(.fired(.double(m)))
            } else {
                lastTap = (m, now)
            }
        } else if peak.count >= 2, held < Self.chordMax {
            lastTap = nil
            events.append(.fired(.chord(peak.sorted())))
        } else {
            lastTap = nil
        }
        return events
    }

    /// Gọi sau `holdAfter` giây kể từ lúc nhấn: vẫn giữ đúng một phím thì bắt đầu "giữ".
    mutating func holdCheck(at now: TimeInterval) -> [Event] {
        guard let m = holdCandidate, now - pressedAt >= Self.holdAfter - 0.01 else { return [] }
        holding = m
        lastTap = nil
        return [.holdBegan(m)]
    }

    private mutating func endHold() -> [Event] {
        guard let m = holding else { return [] }
        holding = nil
        dirty = true
        return [.holdEnded(m)]
    }
}
