import AppKit
@preconcurrency import InputMethodKit

/// Đường A: bộ gõ chuẩn của macOS. Gọi lõi Rust ngay trong tiến trình, không IPC trên đường gõ phím.
/// Logic gõ nằm trong `InputSession`; lớp này chỉ nối InputMethodKit với nó.
/// Ứng dụng chọn đường B thì phím được để đi thẳng, MrTV.app lo phần gõ.
@objc(InputController)
final class InputController: IMKInputController {
    private let session = InputSession()
    private var appliedVersion = -1
    private var appliedSettings: EngineSettings?
    private var bundleID: String?
    private var mode: InputMode = .vietnamese
    private var passThrough = false

    // MARK: Vòng đời

    override func activateServer(_ sender: Any!) {
        MainActor.assumeIsolated {
            InputMethodState.shared.active = self
            bundleID = (sender as? IMKTextInput)?.bundleIdentifier()
            // Báo MrTV.app ô nào đang nhận chữ, để đường B chọn đúng hồ sơ (kể cả Spotlight, Raycast).
            SharedStore.reportClient(bundleID)
            refreshContext()
            session.commit(nil)
        }
    }

    override func deactivateServer(_ sender: Any!) {
        MainActor.assumeIsolated {
            session.commit(TextClientAdapter(sender))
            if InputMethodState.shared.active === self {
                InputMethodState.shared.active = nil
            }
        }
    }

    override func commitComposition(_ sender: Any!) {
        MainActor.assumeIsolated { session.commit(TextClientAdapter(sender)) }
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    @MainActor
    func refreshContext() {
        let state = InputMethodState.shared
        if appliedVersion != state.version {
            // Báo đổi cài đặt đến cả khi chỉ cờ tapActive đổi: chỉ nạp lại kiểu gõ khi nó thật sự đổi,
            // vì nạp lại làm lõi bỏ từ đang gõ. Có chữ đang soạn thì chốt trước, kẻo phím sau thay mất nó.
            if state.settings != appliedSettings {
                session.commit(TextClientAdapter(client()))
                session.engine.apply(state.settings)
                appliedSettings = state.settings
            }
            session.engine.loadWordLists(macros: state.macros, exceptions: state.exceptions, englishOff: state.englishOff)
            appliedVersion = state.version
        }
        let newMode = SharedStore.mode(for: bundleID)
        if newMode != mode { session.commit(TextClientAdapter(client())) }
        mode = newMode
        let profile = SharedStore.profile(for: bundleID)
        // Đường B cần MrTV.app đang chạy và có quyền; không thì bộ gõ tự gõ bằng chữ đang soạn.
        // Kiểm tra cả tiến trình, vì cờ tapActive có thể còn sót lại nếu MrTV.app bị tắt đột ngột.
        let appRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: InputMethodState.companionID).isEmpty
        let newPassThrough = profile.path == .tap && state.tapActive && appRunning
        let newPath: TypingPath = profile.path == .direct ? .direct : .composing
        if newPassThrough != passThrough || newPath != session.path {
            // Đổi cách gõ giữa chừng: chốt chữ đang soạn và bỏ từ đang gõ, kẻo cách mới sửa nhầm chữ của cách cũ.
            session.commit(TextClientAdapter(client()))
        }
        passThrough = newPassThrough
        session.path = newPath
    }

    @MainActor
    func toggleMode() {
        session.commit(TextClientAdapter(client()))
        mode = mode.toggled
        SharedStore.setMode(mode, for: bundleID)
    }

    // MARK: Phím

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        MainActor.assumeIsolated {
            guard let event, event.type == .keyDown, let client = TextClientAdapter(sender) else { return false }
            if appliedVersion != InputMethodState.shared.version { refreshContext() }
            if mode == .english || passThrough { return false }
            return session.handle(Self.key(for: event), client: client)
        }
    }

    private static func key(for event: NSEvent) -> InputKey {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !flags.isDisjoint(with: [.command, .control, .option]) { return .shortcut }
        switch event.keyCode {
        case 51: return .backspace
        case 53: return .escape
        case 36, 48, 76, 115, 116, 117, 119, 121, 123, 124, 125, 126: return .navigation
        default: break
        }
        guard let chars = event.characters, chars.unicodeScalars.count == 1, let s = chars.unicodeScalars.first else {
            return .navigation
        }
        return .char(s)
    }

    // MARK: Menu bộ gõ

    override func menu() -> NSMenu! {
        // NSMenu không Sendable nên không trả thẳng ra khỏi assumeIsolated được.
        final class Holder: @unchecked Sendable { var menu: NSMenu? }
        let holder = Holder()
        MainActor.assumeIsolated { holder.menu = buildMenu() }
        return holder.menu
    }

    @MainActor
    private func buildMenu() -> NSMenu {
        do {
            let menu = NSMenu()
            let toggle = NSMenuItem(title: mode == .vietnamese ? "Đổi sang tiếng Anh" : "Đổi sang tiếng Việt",
                                    action: #selector(menuToggle(_:)), keyEquivalent: "")
            toggle.target = self
            menu.addItem(toggle)
            let settings = NSMenuItem(title: "Cài đặt Mr TV…", action: #selector(openApp(_:)), keyEquivalent: "")
            settings.target = self
            menu.addItem(settings)
            return menu
        }
    }

    @objc private func menuToggle(_ sender: Any?) {
        MainActor.assumeIsolated { toggleMode() }
    }

    @objc private func openApp(_ sender: Any?) {
        MainActor.assumeIsolated {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: InputMethodState.companionID) {
                // Đang chạy thì macOS gửi "mở lại" và Mr TV mở Cài đặt; chưa chạy thì báo bằng tham số.
                let config = NSWorkspace.OpenConfiguration()
                config.arguments = ["--settings"]
                NSWorkspace.shared.openApplication(at: url, configuration: config)
            }
        }
    }
}

/// Nối `IMKTextInput` của ứng dụng đang gõ với `TextClient`.
private final class TextClientAdapter: TextClient {
    private let client: IMKTextInput

    init?(_ sender: Any?) {
        guard let c = sender as? IMKTextInput else { return nil }
        client = c
    }

    func selectedRange() -> NSRange {
        client.selectedRange()
    }

    func string(in range: NSRange) -> String? {
        client.attributedSubstring(from: range)?.string
    }

    func insertText(_ text: String, replacementRange: NSRange) {
        client.insertText(text, replacementRange: replacementRange)
    }

    func setMarkedText(_ text: String, selectionRange: NSRange, replacementRange: NSRange) {
        // Xin không gạch chân; ứng dụng AppKit làm theo, Chromium vẫn vẽ một nét mảnh.
        let attributed = NSAttributedString(string: text, attributes: [.underlineStyle: 0])
        client.setMarkedText(attributed, selectionRange: selectionRange, replacementRange: replacementRange)
    }
}
