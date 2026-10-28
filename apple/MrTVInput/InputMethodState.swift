import AppKit

/// Trạng thái chung của tiến trình bộ gõ: cài đặt đã nạp, bộ điều khiển đang hoạt động.
/// Mọi thứ chạy trên luồng chính (IMK gọi bộ gõ trên luồng chính).
@MainActor
final class InputMethodState {
    static let shared = InputMethodState()
    /// MrTV.app, nơi chạy đường B.
    nonisolated static let companionID = "dev.mrtung.mrtv"

    private(set) var settings = SharedStore.engine
    private(set) var macros = SharedStore.loadMacros()
    private(set) var exceptions = SharedStore.exceptions
    private(set) var englishOff = SharedStore.englishOff
    /// Tăng mỗi lần cài đặt đổi; bộ điều khiển so số này để biết khi nào nạp lại.
    private(set) var version = 0
    /// MrTV.app đang chạy đường B (event tap) và đã có quyền.
    private(set) var tapActive = false

    weak var active: InputController?

    private init() {}

    func start() {
        reload()
        DarwinNotice.settingsChanged.observe { Task { @MainActor in InputMethodState.shared.reload() } }
        DarwinNotice.modeChanged.observe { Task { @MainActor in InputMethodState.shared.active?.refreshContext() } }
        DarwinNotice.toggleMode.observe { Task { @MainActor in InputMethodState.shared.active?.toggleMode() } }
        // MrTV.app văng hay bị tắt thì không kịp báo tapActive = false. Tự nhận ra để bộ gõ gõ lại bằng
        // chữ đang soạn, thay vì để phím đi thẳng mà không còn ai gõ.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == InputMethodState.companionID else { return }
            MainActor.assumeIsolated { InputMethodState.shared.companionExited() }
        }
    }

    private func companionExited() {
        tapActive = false
        active?.refreshContext()
    }

    func reload() {
        SharedStore.defaults.synchronize()
        settings = SharedStore.engine
        macros = SharedStore.loadMacros()
        exceptions = SharedStore.exceptions
        englishOff = SharedStore.englishOff
        tapActive = SharedStore.defaults.bool(forKey: "tapActive")
        version += 1
        active?.refreshContext()
    }
}
