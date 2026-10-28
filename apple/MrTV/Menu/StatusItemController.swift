import AppKit

/// Biểu tượng V / E / tạm dừng trên thanh menu và menu thả xuống.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private(set) static weak var shared: StatusItemController?

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let model: AppModel
    private weak var actions: AppDelegate?

    /// Cột phím bên phải của menu (vị trí tab căn phải).
    private static let hintColumn: CGFloat = 250

    init(model: AppModel, actions: AppDelegate) {
        self.model = model
        self.actions = actions
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        StatusItemController.shared = self
        refresh()
    }

    func setVisible(_ visible: Bool) {
        item.isVisible = visible
    }

    func refresh() {
        let mode = model.currentMode
        // Bộ gõ đang dùng không phải Mr TV thì bộ gõ không nhận phím: hiện viền đứt như lúc tạm dừng.
        let notSelected = mode == .vietnamese && model.frontProfile.path != .tap && !InputSourceInstaller.isSelected
        let paused = Permissions.secureInputApp != nil || notSelected
        item.button?.image = Self.icon(letter: mode == .vietnamese ? "V" : "E", filled: mode == .vietnamese, paused: paused)
        item.button?.toolTip = paused ? "Mr TV đang tạm dừng" : (mode == .vietnamese ? "Tiếng Việt" : "Tiếng Anh")
    }

    /// Vẽ biểu tượng dạng ảnh mẫu để macOS tự đổi màu theo thanh menu sáng/tối.
    static func icon(letter: String, filled: Bool, paused: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            let box = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 4, yRadius: 4)
            let font = NSFont.systemFont(ofSize: 11, weight: .heavy)
            if filled && !paused {
                NSColor.black.setFill()
                box.fill()
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
                let str = NSAttributedString(string: letter, attributes: attrs)
                let sz = str.size()
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                str.draw(at: NSPoint(x: (rect.width - sz.width) / 2, y: (rect.height - sz.height) / 2))
            } else {
                NSColor.black.setStroke()
                box.lineWidth = 1.5
                if paused { box.setLineDash([2, 1.5], count: 2, phase: 0) }
                box.stroke()
                let str = NSAttributedString(string: letter, attributes: [.font: font, .foregroundColor: NSColor.black])
                let sz = str.size()
                str.draw(at: NSPoint(x: (rect.width - sz.width) / 2, y: (rect.height - sz.height) / 2))
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let mode = model.currentMode
        let engine = model.engine
        let toggleKey = ShortcutStore.shared.trigger(.toggle) == .off ? nil : ShortcutStore.label(.toggle)
        let mrtvKey = ShortcutStore.shared.trigger(.mrtv) == .off ? nil : ShortcutStore.label(.mrtv)

        menu.addItem(header("Mr TV · \(mode == .vietnamese ? "Tiếng Việt" : "Tiếng Anh") · \(engine.method.title)"))
        addProblem(to: menu)

        let viet = item("Tiếng Việt", hint: toggleKey) { $0.setMode(.vietnamese) }
        viet.state = mode == .vietnamese ? .on : .off
        let eng = item("Tiếng Anh", hint: toggleKey) { $0.setMode(.english) }
        eng.state = mode == .english ? .on : .off
        menu.addItem(viet)
        menu.addItem(eng)
        menu.addItem(.separator())

        let methods = NSMenu()
        for (m, title) in methodOptions {
            let mi = item(title) { _ in AppModel.shared.engine.method = m }
            mi.state = engine.method == m ? .on : .off
            methods.addItem(mi)
        }
        menu.addItem(submenu("Kiểu gõ", detail: engine.method.title, methods))

        if let app = model.frontApp, let id = app.bundleIdentifier {
            let name = app.localizedName ?? id
            let override = SharedStore.pathOverride(for: id)
            let auto = SharedStore.bundledProfiles[id]?.path ?? .tap
            let paths = NSMenu()
            paths.addItem(header("Cách gõ trong \(name)"))
            let automatic = item("Tự động", hint: auto.title) { _ in SharedStore.setPath(nil, for: id) }
            automatic.state = override == nil ? .on : .off
            paths.addItem(automatic)
            paths.addItem(.separator())
            for p in [TypingPath.direct, .tap, .composing] {
                let mi = item(p.title) { _ in SharedStore.setPath(p, for: id) }
                mi.state = override == p ? .on : .off
                paths.addItem(mi)
            }
            paths.addItem(.separator())
            paths.addItem(note("Chỉ đổi khi \(name) gõ sai dấu. Xem thêm ở Cài đặt › Ứng dụng."))
            menu.addItem(submenu("Cách gõ trong \(name)", detail: override?.title ?? "Tự động", paths))
        }

        menu.addItem(.separator())
        menu.addItem(item("Bảng lệnh…", hint: mrtvKey) { $0.openPalette() })
        menu.addItem(item("Gõ tắt…") { $0.openSettings(.macros) })
        menu.addItem(item("Hướng dẫn", hint: mrtvKey.map { "\($0) ?" }) { $0.openHelp() })

        menu.addItem(.separator())
        menu.addItem(item("Cài đặt…", key: ",") { $0.openSettings() })
        menu.addItem(item("Về Mr TV") { $0.showAbout() })
        if Updater.isAvailable {
            menu.addItem(item("Kiểm tra bản mới…") { $0.checkForUpdates() })
        }
        menu.addItem(.separator())
        menu.addItem(item("Thoát Mr TV", key: "q") { _ in NSApp.terminate(nil) })
    }

    /// Khi Mr TV đang không gõ được: một dòng báo lý do và đúng một việc để sửa.
    private func addProblem(to menu: NSMenu) {
        if let blocker = Permissions.secureInputApp {
            menu.addItem(warning("\(blocker) đang chặn bộ gõ", detail: "Rời ô mật khẩu là gõ lại được."))
            menu.addItem(item("Xem hướng dẫn") { $0.openHelp("mat khau") })
        } else if InputSourceInstaller.status != .ready && model.frontProfile.path != .tap {
            menu.addItem(warning(InputSourceInstaller.status.problem, detail: "Gõ phím nào cũng ra chữ không dấu."))
            menu.addItem(item("Dùng bộ gõ Mr TV") { $0.useInputSource() })
        } else if !Permissions.accessibility {
            menu.addItem(warning("Mr TV chưa có quyền Trợ năng", detail: "Chưa gõ được ở Chrome, VS Code, Terminal."))
            menu.addItem(item("Cấp quyền…") { _ in Permissions.askAccessibility() })
        } else {
            return
        }
        menu.addItem(.separator())
    }

    // MARK: Mục menu

    private static let paragraph: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.tabStops = [NSTextTab(textAlignment: .right, location: hintColumn)]
        return p
    }()

    /// Dòng tiêu đề nhỏ, màu phụ, không bấm được.
    private func header(_ title: String) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        mi.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor,
        ])
        mi.isEnabled = false
        return mi
    }

    /// Chú thích nhỏ trong menu con.
    private func note(_ text: String) -> NSMenuItem {
        let mi = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        mi.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor,
        ])
        mi.isEnabled = false
        return mi
    }

    /// Dòng báo lỗi: biểu tượng cảnh báo, tiêu đề đậm, một dòng giải thích.
    private func warning(_ title: String, detail: String) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let text = NSMutableAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor,
        ])
        text.append(NSAttributedString(string: "\n\(detail)", attributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        mi.attributedTitle = text
        mi.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Cảnh báo")
        mi.isEnabled = false
        return mi
    }

    private func submenu(_ title: String, detail: String, _ menu: NSMenu) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        mi.attributedTitle = withHint(title, detail)
        mi.submenu = menu
        return mi
    }

    /// Tên mục và phím (hay chi tiết) căn phải bằng cột thật, không chèn dấu cách.
    private func withHint(_ title: String, _ hint: String?) -> NSAttributedString {
        let text = NSMutableAttributedString(string: title, attributes: [.font: NSFont.menuFont(ofSize: 0), .paragraphStyle: Self.paragraph])
        if let hint {
            text.append(NSAttributedString(string: "\t\(hint)", attributes: [
                .font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: Self.paragraph,
            ]))
        }
        return text
    }

    private func item(_ title: String, key: String = "", hint: String? = nil,
                      _ run: @escaping @MainActor (AppDelegate) -> Void) -> NSMenuItem {
        let mi = ClosureMenuItem(title: title, key: key) { [weak self] in
            if let actions = self?.actions { run(actions) }
        }
        if hint != nil { mi.attributedTitle = withHint(title, hint) }
        return mi
    }
}

/// Mục menu chạy một closure.
@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let run: () -> Void

    init(title: String, key: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }

    @objc private func fire() {
        run()
    }
}
