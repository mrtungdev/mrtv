import AppKit

@main
enum MrTVMain {
    static func main() {
        runSelfTestIfAsked("Mr TV")
        MainActor.assumeIsolated {
            Snapshot.runIfAsked()
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { app.run() }
        }
    }
}

/// Nối mọi phần của ứng dụng trên thanh menu.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel.shared
    private var status: StatusItemController?
    let hotkeys = HotkeyService()
    private let frontmost = FrontmostAppObserver()
    private let selection = SelectionService()
    lazy var quickBar = QuickBarController(selection: selection)
    private let palette = CommandPaletteController()
    private let hud = HUDController()
    private let updater = Updater()

    private var watchdog: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainMenu.install()
        InputSourceInstaller.syncInstalledCopy()
        status = StatusItemController(model: model, actions: self)
        DockPolicy.apply(model.showIn)

        frontmost.onChange = { [weak self] app in
            guard let self else { return }
            self.model.frontApp = app
            TapTypist.shared.frontAppChanged(bundleID: app?.bundleIdentifier)
            self.status?.refresh()
        }
        frontmost.start()

        hotkeys.onAction = { [weak self] action, began in
            guard let self, began else { return }
            switch action {
            case .toggle: self.toggleMode()
            case .mrtv: self.mrTVKey()
            }
        }
        ShortcutStore.shared.onChange = { [weak self] in
            self?.hotkeys.reload()
            self?.status?.refresh()
        }
        hotkeys.start()

        if Features.quickBar {
            selection.onSelection = { [weak self] text, rect in
                guard let self, self.model.quickBarAuto else { return }
                self.quickBar.show(text: text, near: rect)
            }
            selection.start(delay: 0.25)
        }

        TapTypist.shared.start()
        DarwinNotice.modeChanged.observe { Task { @MainActor in AppDelegate.current?.modeChanged() } }
        DarwinNotice.clientChanged.observe {
            Task { @MainActor in TapTypist.shared.frontAppChanged(bundleID: SharedStore.activeClient) }
        }

        if !model.onboardingDone {
            OnboardingWindowController.shared.show()
        } else if CommandLine.arguments.contains("--settings") {
            // Mở từ menu của bộ gõ ("Cài đặt Mr TV…") khi Mr TV chưa chạy.
            openSettings()
        }
        updater.start()

        // Quyền thường được cấp khi Mr TV đang chạy: cứ vài giây xem lại, có quyền là bật
        // phím toàn cục và đường B ngay, không bắt người dùng mở lại ứng dụng.
        watchdog = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            MainActor.assumeIsolated {
                guard let me = AppDelegate.current else { return }
                if !me.hotkeys.isRunning { me.hotkeys.start() }
                if !TapTypist.shared.isRunning { TapTypist.shared.start() }
                me.status?.refresh()
            }
        }
    }

    static var current: AppDelegate? { NSApp.delegate as? AppDelegate }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Khi đã ẩn biểu tượng trên thanh menu, mở lại ứng dụng là vào Cài đặt.
        openSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        TapTypist.shared.stop()
    }

    // MARK: Việc dùng chung cho menu, phím và bảng nổi

    func toggleMode() {
        setMode(SharedStore.mode(for: model.typingClient).toggled)
    }

    /// Đổi Việt/Anh cho ô đang gõ (cả Spotlight, dù ứng dụng khác vẫn đứng trước).
    /// Sang tiếng Việt thì dùng luôn bộ gõ Mr TV, vì nếu máy đang dùng U.S./ABC
    /// thì bộ gõ không nhận được phím nào.
    func setMode(_ mode: InputMode) {
        if mode == .vietnamese && !InputSourceInstaller.isSelected {
            useInputSource()
        }
        SharedStore.setMode(mode, for: model.typingClient)
    }

    /// Dùng bộ gõ Mr TV: cài và bật trước nếu cần (macOS sẽ hỏi một lần).
    func useInputSource() {
        switch InputSourceInstaller.status {
        case .ready: return
        case .notSelected: InputSourceInstaller.select()
        case .notEnabled, .notInstalled:
            do {
                try InputSourceInstaller.installAndSelect()
            } catch {
                Log.app.error("Không cài được bộ gõ: \(error.localizedDescription)")
                openSettings(.general)
            }
        }
        status?.refresh()
    }

    func modeChanged() {
        status?.refresh()
        let id = model.typingClient
        let name = id.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first?.localizedName }
        hud.show(mode: SharedStore.mode(for: id), appName: name ?? model.frontApp?.localizedName)
    }

    /// Phím Mr TV: có chữ đang bôi đen thì Bảng lệnh chạy trên đoạn đó, không thì trên chữ vừa chép.
    /// Ứng dụng không cho đọc vùng chọn qua Trợ năng thì chép bằng ⌘C (rồi trả clipboard như cũ).
    func mrTVKey() {
        // Ghi lại ô đang bôi đen trước khi bảng lệnh lấy focus, để thay chữ đúng ô đó (kể cả Spotlight).
        let target = selection.target()
        let open: (String, CGRect?) -> Void = { [weak self] text, rect in
            guard let self else { return }
            if Features.quickBar {
                self.quickBar.showList(text: text, near: rect)
            } else {
                self.openPalette(selection: text, target: target)
            }
        }
        switch selection.read() {
        case .text(let picked):
            open(picked.text, picked.rect)
        case .empty:
            palette.show()
        case .unknown:
            selection.copySelection { [weak self] text in
                if let text, !text.isEmpty {
                    open(text, nil)
                } else {
                    self?.palette.show()
                }
            }
        }
    }

    func openPalette() {
        palette.show()
    }

    /// Hướng dẫn: Bảng lệnh với "?" và chủ đề cần tìm (không dấu cũng được).
    func openHelp(_ topic: String = "") {
        palette.show(query: topic.isEmpty ? "?" : "?\(topic)")
    }

    /// Bảng lệnh chạy trên chữ đang bôi đen.
    func openPalette(selection text: String, target: SelectionService.Target? = nil) {
        palette.replaceSelection = { [weak self] out in self?.selection.replaceSelection(with: out, in: target) }
        palette.show(selection: text, owner: target?.pid)
    }

    func openSettings(_ pane: SettingsPane? = nil) {
        SettingsWindowController.shared.show(pane)
    }

    func openOnboarding() {
        OnboardingWindowController.shared.show()
    }

    func checkForUpdates() {
        updater.checkNow()
    }

    /// Cửa sổ Về Mr TV chuẩn của macOS: icon, phiên bản, lời cảm ơn và liên kết.
    func showAbout() {
        let center = NSMutableParagraphStyle()
        center.alignment = .center
        center.paragraphSpacing = 6
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: center,
        ]
        let credits = NSMutableAttributedString(string: "Tiếng Việt, gõ là đúng.\n", attributes: base.merging([
            .font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.labelColor,
        ]) { $1 })
        credits.append(NSAttributedString(string: "Học từ những bộ gõ đã mở đường: Unikey, OpenKey, EVKey, Gõ Nhanh và cộng đồng người gõ tiếng Việt trên Mac.\n", attributes: base))
        for (i, (title, url)) in [("Mã nguồn", Links.source), ("Có gì mới", Links.releases),
                                  ("Liên hệ", URL(string: "mailto:hi@mrtung.dev")!)].enumerated() {
            if i > 0 { credits.append(NSAttributedString(string: "  ·  ", attributes: base)) }
            credits.append(NSAttributedString(string: title, attributes: base.merging([.link: url]) { $1 }))
        }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Mr TV",
            .applicationVersion: "Phiên bản \(Bundle.main.shortVersion) · lõi gõ \(TypingEngine.coreVersion)",
            .version: Bundle.main.buildNumber,
            .credits: credits,
        ])
    }
}

/// Main menu chuẩn. Mr TV chạy trên thanh menu nên không hiện thanh menu riêng, nhưng nhờ đây
/// ⌘C, ⌘V, ⌘Z, ⌘W… chạy được trong cửa sổ Cài đặt, Bắt đầu và ô tìm của Bảng lệnh.
@MainActor
enum MainMenu {
    static func install() {
        let main = NSMenu()

        let app = NSMenu(title: "Mr TV")
        app.addItem(ClosureMenuItem(title: "Về Mr TV", key: "") { AppDelegate.current?.showAbout() })
        app.addItem(.separator())
        app.addItem(ClosureMenuItem(title: "Cài đặt…", key: ",") { AppDelegate.current?.openSettings() })
        app.addItem(.separator())
        app.addItem(withTitle: "Ẩn Mr TV", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Thoát Mr TV", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(app, to: main)

        let edit = NSMenu(title: "Sửa")
        edit.addItem(withTitle: "Hoàn tác", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Làm lại", action: Selector(("redo:")), keyEquivalent: "z").keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cắt", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Chép", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Dán", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Chọn tất cả", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        add(edit, to: main)

        let window = NSMenu(title: "Cửa sổ")
        window.addItem(withTitle: "Thu nhỏ", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Đóng", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        add(window, to: main)

        NSApp.mainMenu = main
        NSApp.windowsMenu = window
    }

    private static func add(_ menu: NSMenu, to main: NSMenu) {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        main.addItem(item)
    }
}
