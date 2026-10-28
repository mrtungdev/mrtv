import AppKit
import Carbon.HIToolbox

/// Phần riêng của ứng dụng cho `Modifier` (kiểu chung nằm ở Shared/Gestures.swift).
extension Modifier {
    var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .control: return .control
        case .option: return .option
        case .shift: return .shift
        case .command: return .command
        }
    }

    var carbon: UInt32 {
        switch self {
        case .control: return UInt32(controlKey)
        case .option: return UInt32(optionKey)
        case .shift: return UInt32(shiftKey)
        case .command: return UInt32(cmdKey)
        }
    }

    static func from(_ flags: NSEvent.ModifierFlags) -> [Modifier] {
        allCases.filter { flags.contains($0.eventFlag) }
    }
}

/// Hai phím của Mr TV. Bảng phím (giữ ⌥) đã gộp vào Bảng lệnh: mở bảng khi chưa có chữ là thấy mọi phím.
enum ShortcutAction: String, CaseIterable, Codable {
    case toggle, mrtv

    var title: String {
        switch self {
        case .toggle: return "Đổi Việt ⇄ Anh"
        case .mrtv: return "Phím Mr TV"
        }
    }

    var defaultTrigger: Trigger {
        switch self {
        case .toggle: return .fn
        case .mrtv: return .double(.option)
        }
    }

    /// Lựa chọn có sẵn, hay dùng nhất trước.
    var presets: [Trigger] {
        switch self {
        case .toggle: return [.fn, .chord([.control, .shift]), .chord([.command, .shift]), .double(.shift)]
        case .mrtv: return [.double(.option), .double(.control), .double(.command), .double(.shift)]
        }
    }
}

/// Phím của Mr TV, lưu trong cài đặt của ứng dụng.
@MainActor
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()
    private let key = "shortcuts"

    @Published private(set) var triggers: [ShortcutAction: Trigger]

    /// Gọi khi đổi phím, để dịch vụ phím nạp lại.
    var onChange: (() -> Void)?

    private init() {
        var t: [ShortcutAction: Trigger] = [:]
        for a in ShortcutAction.allCases { t[a] = a.defaultTrigger }
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([String: Trigger].self, from: data) {
            for (k, v) in saved { if let a = ShortcutAction(rawValue: k) { t[a] = v } }
        }
        triggers = t
    }

    func trigger(_ action: ShortcutAction) -> Trigger {
        triggers[action] ?? action.defaultTrigger
    }

    /// Phím đang dùng, để chèn vào câu chữ ("Bấm fn để đổi nhanh").
    static func label(_ action: ShortcutAction) -> String {
        shared.trigger(action).label
    }

    /// Đặt phím mới. Trả về lời báo nếu không đặt được (trùng phím khác, trùng phím hệ thống).
    @discardableResult
    func set(_ trigger: Trigger, for action: ShortcutAction) -> String? {
        if trigger != .off, let other = ShortcutAction.allCases.first(where: { $0 != action && self.trigger($0) == trigger }) {
            return "Trùng với phím của “\(other.title)”."
        }
        if case .combo(let code, let mods, let key) = trigger, let reason = Self.systemConflict(code: code, modifiers: mods, key: key) {
            return reason
        }
        triggers[action] = trigger
        let raw = Dictionary(uniqueKeysWithValues: triggers.map { ($0.key.rawValue, $0.value) })
        UserDefaults.standard.set(try? JSONEncoder().encode(raw), forKey: key)
        onChange?()
        return nil
    }

    /// Lưu ý (không chặn) cho vài lựa chọn dễ va với ứng dụng khác. Phím fn có nhóm riêng trong Cài đặt › Phím.
    static func note(_ trigger: Trigger) -> String? {
        switch trigger {
        case .double(.shift): return "IDE của JetBrains cũng dùng phím này"
        case .double(.command): return "Một số ứng dụng ghi màn hình dùng phím này"
        default: return nil
        }
    }

    /// Tổ hợp mà macOS hay mọi ứng dụng đã dùng.
    static func systemConflict(code: UInt16, modifiers: [Modifier], key: String) -> String? {
        let mods = Set(modifiers)
        if mods.isEmpty || mods == [.shift] {
            return "Cần thêm ⌘, ⌃ hoặc ⌥, không thì phím này sẽ gõ ra chữ."
        }
        let taken: [(Set<Modifier>, String, String)] = [
            ([.command], "Space", "Spotlight"), ([.control], "Space", "đổi nguồn nhập của macOS"),
            ([.control, .option], "Space", "đổi nguồn nhập của macOS"),
            ([.command], "Tab", "chuyển ứng dụng"), ([.command], "Q", "thoát ứng dụng"), ([.command], "W", "đóng cửa sổ"),
            ([.command], "C", "chép"), ([.command], "V", "dán"), ([.command], "X", "cắt"), ([.command], "Z", "hoàn tác"),
            ([.command], "A", "chọn hết"), ([.command], "S", "lưu"), ([.command], "F", "tìm"), ([.command], "H", "ẩn ứng dụng"),
            ([.command], "M", "thu nhỏ cửa sổ"), ([.command], ",", "cài đặt của ứng dụng"), ([.command], "N", "tạo mới"),
            ([.command], "T", "tab mới"), ([.command], "P", "in"), ([.command], "O", "mở"),
            ([.command, .shift], "3", "chụp màn hình"), ([.command, .shift], "4", "chụp màn hình"),
            ([.command, .shift], "5", "chụp màn hình"), ([.control, .command], "Q", "khoá màn hình"),
            ([.control, .command], "F", "toàn màn hình"), ([.control, .command], "Space", "bảng biểu tượng cảm xúc"),
        ]
        if let hit = taken.first(where: { $0.0 == mods && $0.1 == key }) {
            return "\(modifiers.sorted().map(\.symbol).joined())\(key) là phím \(hit.2), chọn phím khác nhé."
        }
        return nil
    }
}

/// Tổ hợp có phím thường đăng ký bằng Carbon `RegisterEventHotKey`: macOS nuốt phím cho Mr TV,
/// không cần quyền gì thêm.
@MainActor
final class ComboHotkeys {
    static let shared = ComboHotkeys()
    private var refs: [UInt32: EventHotKeyRef] = [:]
    fileprivate var handlers: [UInt32: () -> Void] = [:]
    private var installed = false

    @discardableResult
    func register(id: UInt32, keyCode: UInt16, modifiers: [Modifier], handler: @escaping () -> Void) -> Bool {
        install()
        unregister(id)
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D52_5456), id: id)
        let flags = modifiers.reduce(UInt32(0)) { $0 | $1.carbon }
        let status = RegisterEventHotKey(UInt32(keyCode), flags, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs[id] = ref
        handlers[id] = handler
        return true
    }

    func unregister(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        handlers[id] = nil
    }

    private func install() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKey = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            let id = hotKey.id
            MainActor.assumeIsolated { ComboHotkeys.shared.handlers[id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

/// Tên hiện cho một phím thường khi ghi tổ hợp.
enum KeyNames {
    static func name(keyCode: UInt16, characters: String?) -> String {
        let special: [UInt16: String] = [
            49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦", 53: "esc", 123: "←", 124: "→", 125: "↓", 126: "↑",
            115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
            109: "F10", 103: "F11", 111: "F12",
        ]
        if let s = special[keyCode] { return s }
        return (characters ?? "?").uppercased()
    }

    static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111].contains(keyCode)
    }
}
