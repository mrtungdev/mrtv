import AppKit
import SwiftUI

/// `MrTV --snapshot <thư mục> [tiền tố]`: vẽ mọi màn ra PNG ở chế độ sáng và tối, để so với canvas thiết kế
/// mà không cần mở cửa sổ hay cấp quyền chụp màn hình. Không đổi cài đặt nào của người dùng.
@MainActor
enum Snapshot {
    static func runIfAsked() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot") else { return }
        let dir = URL(fileURLWithPath: i + 1 < args.count ? args[i + 1] : "snapshots", isDirectory: true)
        let only = i + 2 < args.count ? args[i + 2] : nil
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        RenderMode.snapshot = true
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var count = 0
        for (name, view) in screens() where only.map({ name.hasPrefix($0) }) ?? true {
            for dark in [false, true] {
                let file = dir.appendingPathComponent("\(name)-\(dark ? "toi" : "sang").png")
                if render(view, dark: dark, to: file) { count += 1 }
            }
        }
        print("Đã chụp \(count) ảnh vào \(dir.path)")
        exit(0)
    }

    private static func screens() -> [(String, AnyView)] {
        let model = AppModel.shared
        // Một ứng dụng "vừa dùng" để bảng Cài đặt › Ứng dụng có dòng (không lưu vào cài đặt).
        model.frontApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        let size = SettingsLayout.size
        var list: [(String, AnyView)] = []
        for pane in SettingsPane.allCases {
            let router = SettingsRouter()
            router.go(pane)
            list.append(("caidat-\(pane.rawValue)", AnyView(SettingsView(router: router, model: model).frame(width: size.width, height: size.height))))
        }
        let searching = SettingsRouter()
        searching.go(.apps)
        searching.search = "gach chan"
        list.append(("caidat-timkiem", AnyView(SettingsView(router: searching, model: model).frame(width: size.width, height: size.height))))
        list.append(("caidat-tutienganh", AnyView(EnglishWordsSheet().background(Palette.window))))
        for step in 1...3 {
            list.append(("batdau-\(step)", AnyView(OnboardingView(model: model, step: step, trial: step == 1 ? "tieesng Vieejt, gox laf ddusng" : "") {})))
        }
        let picked = PaletteModel()
        picked.clip = "TiÕng ViÖt lµ ng«n ng÷ chÝnh thøc"
        picked.fromSelection = true
        list.append(("banglenh-boiden", AnyView(PaletteView(model: picked, run: { _ in }, help: { _ in }, close: {}))))
        let copied = PaletteModel()
        copied.clip = "1250000"
        list.append(("banglenh-chep", AnyView(PaletteView(model: copied, run: { _ in }, help: { _ in }, close: {}))))
        let empty = PaletteModel()
        empty.appName = "Ghi chú"
        list.append(("banglenh-trong", AnyView(PaletteView(model: empty, run: { _ in }, help: { _ in }, close: {}))))
        let help = PaletteModel()
        help.query = "?"
        list.append(("banglenh-huongdan", AnyView(PaletteView(model: help, run: { _ in }, help: { _ in }, close: {}))))
        list.append(("nhan-viet", AnyView(HUDView(mode: .vietnamese, appName: "Ghi chú"))))
        list.append(("nhan-anh", AnyView(HUDView(mode: .english, appName: "VS Code"))))
        return list
    }

    /// Vẽ qua NSHostingView trong một cửa sổ ngoài màn hình: control gốc của macOS (công tắc, nút chọn,
    /// ô tìm) là NSView nên ImageRenderer không vẽ được.
    private static func render(_ view: AnyView, dark: Bool, to url: URL) -> Bool {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        // Nền đặc như hình nền trên canvas, để bóng đổ và viền mờ hiện đúng như trên màn hình.
        let backdrop = Palette.fixed(dark ? 0x2B2E35 : 0xD5D9E0)
        let root = view.background(backdrop).environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: root)
        host.appearance = appearance
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: -20000, y: -20000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.backingType = .buffered
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        host.display()
        // SwiftUI vẽ xong sau một vòng chạy.
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return false }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        window.contentView = nil
        return (try? png.write(to: url)) != nil
    }
}
