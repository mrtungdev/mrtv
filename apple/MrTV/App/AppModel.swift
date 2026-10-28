import AppKit
import Combine

/// Cài đặt và trạng thái của ứng dụng trên thanh menu. Cài đặt bộ máy gõ nằm ở `SharedStore`
/// để bộ gõ cũng đọc được; phần còn lại chỉ MrTV.app dùng.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum ShowIn: String, CaseIterable { case menuBar, dock, both, none }
    /// Mức mẹo cho `TipEngine` (mẹo đang tạm ẩn).
    enum TipLevel: String, CaseIterable { case off, few, normal, many }

    private let defaults = UserDefaults.standard

    @Published var engine: EngineSettings { didSet { SharedStore.engine = engine } }
    @Published var launchAtLogin: Bool { didSet { LoginItem.set(launchAtLogin) } }
    @Published var showIn: ShowIn { didSet { save(showIn.rawValue, "showIn"); DockPolicy.apply(showIn) } }
    @Published var cursorLabel: Bool { didSet { save(cursorLabel, "cursorLabel") } }
    @Published var autoUpdate: Bool { didSet { save(autoUpdate, "autoUpdate") } }
    /// Ứng dụng người dùng tự thêm vào bảng Cài đặt › Ứng dụng.
    @Published var listedApps: [String] { didSet { save(listedApps, "listedApps") } }
    /// Tự hiện bản gọn của thanh gợi ý khi bôi đen. Danh sách đầy đủ luôn mở được bằng Phím Mr TV.
    @Published var quickBarAuto: Bool { didSet { save(quickBarAuto, "quickBarAuto") } }
    /// Việc được hiện trên thanh gợi ý, theo thứ tự người dùng xếp.
    @Published var quickBarActions: [String] { didSet { save(quickBarActions, "quickBarActions") } }
    /// Việc người dùng tự tạo cho thanh gợi ý và bảng lệnh.
    @Published private(set) var customActions: [CustomAction] {
        didSet { defaults.set(try? JSONEncoder().encode(customActions), forKey: "customActions") }
    }
    /// Tự xếp: việc hợp nhất với chữ đang bôi đen và hay dùng lên trước.
    @Published var quickBarSmartOrder: Bool { didSet { save(quickBarSmartOrder, "quickBarSmartOrder") } }
    @Published var onboardingDone: Bool { didSet { save(onboardingDone, "onboardingDone") } }
    @Published var rememberModePerApp: Bool { didSet { SharedStore.rememberModePerApp = rememberModePerApp } }

    /// Ứng dụng đang dùng (không tính chính Mr TV).
    @Published var frontApp: NSRunningApplication?

    private init() {
        func get<T>(_ key: String, _ fallback: T) -> T { UserDefaults.standard.object(forKey: key) as? T ?? fallback }
        func pick<E: RawRepresentable>(_ key: String, _ fallback: E) -> E where E.RawValue == String {
            E(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? fallback
        }
        engine = SharedStore.engine
        launchAtLogin = LoginItem.isEnabled
        showIn = pick("showIn", .menuBar)
        cursorLabel = get("cursorLabel", true)
        autoUpdate = get("autoUpdate", true)
        listedApps = get("listedApps", [])
        quickBarAuto = get("quickBarAuto", UserDefaults.standard.string(forKey: "quickBarTrigger") != "hotkeyOnly")
        quickBarActions = get("quickBarActions", ActionRegistry.shared.defaultQuickBar)
        quickBarSmartOrder = get("quickBarSmartOrder", true)
        customActions = (UserDefaults.standard.data(forKey: "customActions"))
            .flatMap { try? JSONDecoder().decode([CustomAction].self, from: $0) } ?? []
        onboardingDone = get("onboardingDone", false)
        rememberModePerApp = SharedStore.rememberModePerApp
        // Giao diện luôn theo macOS; bỏ cài đặt Màu của bản cũ.
        defaults.removeObject(forKey: "theme")
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }

    /// Thêm hoặc sửa một việc tự tạo. Việc mới được hiện luôn trên thanh gợi ý, ở đầu.
    func save(_ action: CustomAction) {
        if let i = customActions.firstIndex(where: { $0.id == action.id }) {
            customActions[i] = action
        } else {
            customActions.append(action)
            quickBarActions.insert(action.id, at: 0)
        }
    }

    func delete(_ action: CustomAction) {
        customActions.removeAll { $0.id == action.id }
        quickBarActions.removeAll { $0 == action.id }
    }

    var frontProfile: AppProfile {
        SharedStore.profile(for: frontApp?.bundleIdentifier)
    }

    /// Ứng dụng có ô đang gõ, để đọc và đổi chế độ Việt/Anh cho đúng chỗ (Spotlight, không phải ứng dụng bên dưới).
    var typingClient: String? {
        TapTypist.shared.client ?? frontApp?.bundleIdentifier
    }

    var currentMode: InputMode {
        SharedStore.mode(for: typingClient)
    }
}

/// Tính năng đang tạm ngừng; bật lại khi đã ổn.
enum Features {
    /// Thanh gợi ý khi bôi đen: đang tạm ngừng. Phím Mr TV mở bảng lệnh thay cho nó.
    static let quickBar = false
}

/// Hiện biểu tượng ở thanh menu, Dock, cả hai hay ẩn cả hai.
@MainActor
enum DockPolicy {
    static func apply(_ showIn: AppModel.ShowIn) {
        let dock = showIn == .dock || showIn == .both
        NSApp.setActivationPolicy(dock ? .regular : .accessory)
        StatusItemController.shared?.setVisible(showIn == .menuBar || showIn == .both)
    }
}

/// Theo dõi ứng dụng đang dùng để chọn hồ sơ gõ và chế độ Việt/Anh.
@MainActor
final class FrontmostAppObserver {
    var onChange: ((NSRunningApplication?) -> Void)?
    private var token: NSObjectProtocol?

    func start() {
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard app?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
                self.onChange?(app)
            }
        }
        onChange?(NSWorkspace.shared.frontmostApplication)
    }
}
