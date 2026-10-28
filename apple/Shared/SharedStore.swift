import Foundation
import os

/// Nhật ký của Mr TV. Không bao giờ ghi chữ người dùng gõ.
enum Log {
    static let input = Logger(subsystem: "dev.mrtung.mrtv", category: "input")
    static let app = Logger(subsystem: "dev.mrtung.mrtv", category: "app")
}

/// Việt hay Anh.
enum InputMode: String, Codable {
    case vietnamese, english
    var toggled: InputMode { self == .vietnamese ? .english : .vietnamese }
}

/// Cách đưa chữ vào một ứng dụng.
enum TypingPath: String, Codable, CaseIterable {
    /// Đường A · gõ ngay rồi sửa dấu bằng replacementRange: không gạch chân.
    case direct
    /// Đường A · chữ đang soạn (marked text): không bao giờ mất chữ, có thể có gạch chân.
    case composing
    /// Đường B · event tap trong MrTV.app: gõ đè / xoá rồi gõ lại.
    case tap

    /// Gọi theo điều người dùng nhìn thấy: chữ đang soạn hiện ra có gạch chân.
    var title: String {
        switch self {
        case .direct: return "Gõ chuẩn"
        case .composing: return "Chữ gạch chân"
        case .tap: return "Gõ đè"
        }
    }
}

/// Hồ sơ ứng dụng: cách Mr TV gõ trong một ứng dụng cụ thể.
struct AppProfile: Codable, Equatable {
    var bundleID: String
    var name: String
    var path: TypingPath
    /// Độ trễ giữa các phím tổng hợp của đường B, mili giây.
    var delayMs: Int?
    /// Ô có gợi ý tự điền (thanh địa chỉ trình duyệt, ô Excel): gõ một ký tự giả trước khi xoá,
    /// để phím xoá không ăn mất phần gợi ý đang bôi đen.
    var fixAutocomplete: Bool?
}

/// Lưu trữ dùng chung giữa MrTV.app và bộ gõ MrTVInput (cùng người dùng, không sandbox).
enum SharedStore {
    static let suiteName = "dev.mrtung.mrtv.shared"
    // UserDefaults an toàn khi dùng từ nhiều luồng.
    nonisolated(unsafe) static let defaults = UserDefaults(suiteName: suiteName) ?? .standard

    private enum Key {
        static let engine = "engine"
        static let modes = "modesByApp"
        static let globalMode = "globalMode"
        static let rememberPerApp = "rememberModePerApp"
        static let overrides = "profileOverrides"
        static let activeClient = "activeClient"
        static let exceptions = "englishExceptions"
        static let englishOff = "englishOff"
        static let macros = "macros"
    }

    static var engine: EngineSettings {
        get {
            guard let data = defaults.data(forKey: Key.engine),
                  let s = try? JSONDecoder().decode(EngineSettings.self, from: data) else { return EngineSettings() }
            return s
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.engine)
            DarwinNotice.settingsChanged.post()
        }
    }

    static var rememberModePerApp: Bool {
        get { defaults.object(forKey: Key.rememberPerApp) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.rememberPerApp) }
    }

    static func mode(for bundleID: String?) -> InputMode {
        if rememberModePerApp, let id = bundleID,
           let raw = (defaults.dictionary(forKey: Key.modes) as? [String: String])?[id],
           let m = InputMode(rawValue: raw) {
            return m
        }
        return InputMode(rawValue: defaults.string(forKey: Key.globalMode) ?? "") ?? .vietnamese
    }

    static func setMode(_ mode: InputMode, for bundleID: String?) {
        defaults.set(mode.rawValue, forKey: Key.globalMode)
        if rememberModePerApp, let id = bundleID {
            var all = defaults.dictionary(forKey: Key.modes) as? [String: String] ?? [:]
            all[id] = mode.rawValue
            defaults.set(all, forKey: Key.modes)
        }
        DarwinNotice.modeChanged.post()
    }

    /// Hồ sơ mặc định đi kèm ứng dụng, cộng với lựa chọn riêng của người dùng.
    /// Ứng dụng lạ dùng gõ đè: không gạch chân, không khung quanh chữ đang gõ (như OpenKey, EVKey).
    /// Khi chưa có quyền Trợ năng, bộ gõ tự lùi về chữ đang soạn để vẫn gõ được.
    static func profile(for bundleID: String?) -> AppProfile {
        let id = bundleID ?? ""
        var p = bundledProfiles[id] ?? AppProfile(bundleID: id, name: id, path: .tap, delayMs: 1)
        if let raw = (defaults.dictionary(forKey: Key.overrides) as? [String: String])?[id],
           let path = TypingPath(rawValue: raw) {
            p.path = path
        }
        return p
    }

    /// Cách gõ người dùng tự chọn cho ứng dụng; nil là để Mr TV tự chọn.
    static func pathOverride(for bundleID: String) -> TypingPath? {
        (defaults.dictionary(forKey: Key.overrides) as? [String: String])?[bundleID].flatMap(TypingPath.init(rawValue:))
    }

    /// Ứng dụng người dùng đã tự chọn cách gõ.
    static var overriddenApps: [String] {
        Array((defaults.dictionary(forKey: Key.overrides) as? [String: String] ?? [:]).keys)
    }

    /// Chế độ Việt/Anh đã nhớ cho ứng dụng, không tính chế độ chung.
    static func rememberedMode(for bundleID: String) -> InputMode? {
        (defaults.dictionary(forKey: Key.modes) as? [String: String])?[bundleID].flatMap(InputMode.init(rawValue:))
    }

    /// Đặt chế độ nhớ cho một ứng dụng từ Cài đặt: không đổi chế độ đang gõ.
    static func setRememberedMode(_ mode: InputMode, for bundleID: String) {
        var all = defaults.dictionary(forKey: Key.modes) as? [String: String] ?? [:]
        all[bundleID] = mode.rawValue
        defaults.set(all, forKey: Key.modes)
    }

    static func setPath(_ path: TypingPath?, for bundleID: String) {
        var all = defaults.dictionary(forKey: Key.overrides) as? [String: String] ?? [:]
        all[bundleID] = path?.rawValue
        defaults.set(all, forKey: Key.overrides)
        DarwinNotice.settingsChanged.post()
    }

    /// Từ tiếng Anh người dùng thêm: bấm dấu cách là trả lại đúng phím đã gõ.
    static var exceptions: [String] {
        get { defaults.stringArray(forKey: Key.exceptions) ?? [] }
        set {
            defaults.set(newValue, forKey: Key.exceptions)
            DarwinNotice.settingsChanged.post()
        }
    }

    /// Từ trong danh sách tiếng Anh có sẵn mà người dùng đã tắt (gõ thành tiếng Việt như thường).
    static var englishOff: [String] {
        get { defaults.stringArray(forKey: Key.englishOff) ?? [] }
        set {
            defaults.set(newValue, forKey: Key.englishOff)
            DarwinNotice.settingsChanged.post()
        }
    }

    /// Gõ tắt, lưu ngay trong cài đặt chung: sửa trong Cài đặt là bộ gõ dùng được luôn, không cần tệp hay nạp lại.
    static var macros: [Macro] {
        get {
            if let data = defaults.data(forKey: Key.macros), let list = try? JSONDecoder().decode([Macro].self, from: data) {
                return list
            }
            return importLegacyMacros()
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.macros)
            DarwinNotice.settingsChanged.post()
        }
    }

    /// Bản cũ để gõ tắt trong tệp macros.tsv: chuyển sang một lần.
    private static func importLegacyMacros() -> [Macro] {
        guard let text = try? String(contentsOf: macrosURL, encoding: .utf8) else { return [] }
        let list = Macro.parse(tsv: text)
        defaults.set(try? JSONEncoder().encode(list), forKey: Key.macros)
        return list
    }

    static let bundledProfiles: [String: AppProfile] = {
        guard let url = Bundle.main.url(forResource: "app-profiles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([AppProfile].self, from: data) else { return [:] }
        return Dictionary(list.map { ($0.bundleID, $0) }, uniquingKeysWith: { a, _ in a })
    }()

    /// Ứng dụng có ô đang nhận chữ, do bộ gõ báo. Chính xác hơn "ứng dụng đứng trước" với các ô nổi
    /// như Spotlight, Raycast, Alfred (chúng không thành ứng dụng đứng trước).
    static var activeClient: String? {
        defaults.synchronize()
        return defaults.string(forKey: Key.activeClient)
    }

    static func reportClient(_ bundleID: String?) {
        guard let bundleID, defaults.string(forKey: Key.activeClient) != bundleID else { return }
        defaults.set(bundleID, forKey: Key.activeClient)
        DarwinNotice.clientChanged.post()
    }

    /// Tệp gõ tắt của bản cũ, chỉ đọc một lần để chuyển sang `macros`.
    static var macrosURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Mr TV", isDirectory: true).appendingPathComponent("macros.tsv")
    }

    /// Gõ tắt dạng TSV cho lõi gõ.
    static func loadMacros() -> String {
        macros.map { "\($0.key)\t\($0.text)" }.joined(separator: "\n")
    }
}

/// Một mục gõ tắt: gõ `key` rồi bấm dấu cách là ra `text`.
struct Macro: Codable, Equatable, Identifiable {
    var key: String
    var text: String

    var id: String { key.lowercased() }

    /// Đọc dạng "chữ tắt<TAB>câu đầy đủ", mỗi dòng một mục; bỏ dòng bắt đầu bằng #.
    static func parse(tsv: String) -> [Macro] {
        tsv.split(whereSeparator: \.isNewline).compactMap { line in
            guard !line.hasPrefix("#") else { return nil }
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let text = String(parts[1])
            return key.isEmpty || text.isEmpty ? nil : Macro(key: key, text: text)
        }
    }
}

/// Thông báo giữa hai tiến trình qua Darwin notify (không mang dữ liệu, chỉ báo "có đổi").
enum DarwinNotice: String {
    case settingsChanged = "dev.mrtung.mrtv.settings-changed"
    case modeChanged = "dev.mrtung.mrtv.mode-changed"
    /// MrTV.app nhận phím fn và nhờ bộ gõ đổi Việt/Anh cho ứng dụng đang dùng.
    case toggleMode = "dev.mrtung.mrtv.toggle-mode"
    /// Bộ gõ vừa chuyển sang một ô nhập chữ của ứng dụng khác (xem `SharedStore.activeClient`).
    case clientChanged = "dev.mrtung.mrtv.client-changed"

    func post() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(rawValue as CFString), nil, nil, true)
    }

    /// Gọi `handler` trên luồng chính mỗi khi có thông báo, kể cả từ tiến trình khác.
    func observe(_ handler: @escaping @Sendable () -> Void) {
        DarwinCenter.shared.observe(rawValue, handler)
    }
}

private final class DarwinCenter: @unchecked Sendable {
    static let shared = DarwinCenter()
    private let handlers = Locked<[String: [@Sendable () -> Void]]>([:])

    func observe(_ name: String, _ handler: @escaping @Sendable () -> Void) {
        let first = handlers.withLock { all -> Bool in
            let isFirst = all[name] == nil
            all[name, default: []].append(handler)
            return isFirst
        }
        guard first else { return }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(),
                                        { _, observer, name, _, _ in
            guard let observer, let name else { return }
            Unmanaged<DarwinCenter>.fromOpaque(observer).takeUnretainedValue().fire(name.rawValue as String)
        }, name as CFString, nil, .deliverImmediately)
    }

    private func fire(_ name: String) {
        let list = handlers.withLock { $0[name] ?? [] }
        DispatchQueue.main.async { list.forEach { $0() } }
    }
}

/// Khoá nhỏ cho dữ liệu dùng chung giữa các luồng. Dùng os_unfair_lock vì
/// `Mutex` cần macOS 15 và `OSAllocatedUnfairLock` cần macOS 13.
final class Locked<Value>: @unchecked Sendable {
    private let lock: UnsafeMutablePointer<os_unfair_lock>
    private var value: Value

    init(_ value: Value) {
        self.value = value
        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    func withLock<R>(_ body: (inout Value) -> R) -> R {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return body(&value)
    }

    var current: Value { withLock { $0 } }
}
