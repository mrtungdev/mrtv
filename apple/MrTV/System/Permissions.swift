import AppKit
import ApplicationServices
import Carbon

/// Quyền Mr TV cần, và chế độ nhập bảo mật.
enum Permissions {
    /// Trợ năng: đọc vùng chọn, gõ đè / xoá rồi gõ lại (đường B), thay chữ của thanh gợi ý.
    static var accessibility: Bool { AXIsProcessTrusted() }

    /// Giám sát đầu vào: nghe phím fn, ⌥⌥ khi chưa có Trợ năng.
    static var inputMonitoring: Bool { CGPreflightListenEventAccess() }

    /// Phát phím tổng hợp (cùng quyền Trợ năng trên macOS mới).
    static var postEvents: Bool { CGPreflightPostEventAccess() }

    static func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }

    /// Nút "Cấp quyền…": macOS hỏi, và mở sẵn đúng chỗ trong Cài đặt hệ thống.
    static func askAccessibility() {
        requestAccessibility()
        open(.accessibility)
    }

    static func askInputMonitoring() {
        requestInputMonitoring()
        open(.inputMonitoring)
    }

    enum Pane: String {
        case accessibility = "Privacy_Accessibility"
        case inputMonitoring = "Privacy_ListenEvent"
    }

    static func open(_ pane: Pane) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Tên ứng dụng đang bật chế độ nhập bảo mật (macOS chặn mọi bộ gõ), nếu có.
    static var secureInputApp: String? {
        guard IsSecureEventInputEnabled() else { return nil }
        let dict = CGSessionCopyCurrentDictionary() as? [String: Any]
        if let pid = dict?["kCGSSessionSecureInputPID"] as? pid_t,
           let app = NSRunningApplication(processIdentifier: pid) {
            return app.localizedName
        }
        return "Một ứng dụng"
    }
}

/// Cài, đăng ký, bật và chọn bộ gõ Mr TV.
///
/// `TISRegisterInputSource` chỉ nhận bundle trong `~/Library/Input Methods` hoặc `/Library/Input Methods`,
/// nên bản bộ gõ đi kèm MrTV.app được chép sang đó. Từ macOS 12, hệ thống bắt người dùng tự cho phép
/// bộ gõ trong Cài đặt hệ thống; trạng thái "đã bật" đôi khi không đúng, nên luôn đọc lại sau mỗi bước.
enum InputSourceInstaller {
    static let bundleID = "dev.mrtung.inputmethod.mrtv"
    static let bundleName = "MrTVInput.app"

    static var embeddedURL: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Library/Input Methods/\(bundleName)")
    }

    static var installedURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Input Methods/\(bundleName)")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installedURL.path)
    }

    /// Bản đã cài khác bản đi kèm (sau khi cập nhật Mr TV) thì cần cài lại.
    /// So cả số build lẫn file chạy: bản build bằng Xcode có thể trùng số build mà khác mã.
    static var needsUpdate: Bool {
        let installed = Bundle(url: installedURL)?.infoDictionary?["CFBundleVersion"] as? String
        let embedded = Bundle(url: embeddedURL)?.infoDictionary?["CFBundleVersion"] as? String
        if installed != embedded { return true }
        let exe = "Contents/MacOS/MrTVInput"
        return !FileManager.default.contentsEqual(atPath: installedURL.appendingPathComponent(exe).path,
                                                  andPath: embeddedURL.appendingPathComponent(exe).path)
    }

    static func install() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: installedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            app.forceTerminate()
        }
        if fm.fileExists(atPath: installedURL.path) {
            try fm.removeItem(at: installedURL)
        }
        try fm.copyItem(at: embeddedURL, to: installedURL)
        let status = TISRegisterInputSource(installedURL as CFURL)
        Log.app.info("Đăng ký bộ gõ: \(status)")
    }

    private static func source() -> TISInputSource? {
        let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] else { return nil }
        return list.first
    }

    private static func bool(_ src: TISInputSource, _ key: CFString) -> Bool {
        guard let raw = TISGetInputSourceProperty(src, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(raw).takeUnretainedValue())
    }

    static var isEnabled: Bool {
        source().map { bool($0, kTISPropertyInputSourceIsEnabled) } ?? false
    }

    /// Mr TV đang là nguồn nhập được chọn. "Đã bật" chưa đủ: nếu nguồn nhập đang chọn là
    /// U.S. hay ABC thì bộ gõ không nhận được phím nào.
    static var isSelected: Bool {
        source().map { bool($0, kTISPropertyInputSourceIsSelected) } ?? false
    }

    enum Status {
        case notInstalled, notEnabled, notSelected, ready

        /// Mô tả ngắn cho dòng Bộ gõ Mr TV ở Cài đặt › Chung.
        var detail: String {
            switch self {
            case .notInstalled: return "Chưa có trong máy"
            case .notEnabled: return "macOS chưa cho phép, sẽ hỏi bạn một lần"
            case .notSelected: return "Máy đang dùng bộ gõ khác"
            case .ready: return "Đang là bộ gõ của máy"
            }
        }

        /// Tiêu đề băng báo khi chưa gõ được.
        var problem: String {
            switch self {
            case .notInstalled: return "Bộ gõ Mr TV chưa có trong máy"
            case .notEnabled: return "macOS chưa cho phép bộ gõ Mr TV"
            case .notSelected: return "Máy đang dùng bộ gõ khác"
            case .ready: return ""
            }
        }
    }

    static var status: Status {
        if !isInstalled || source() == nil { return .notInstalled }
        if !isEnabled { return .notEnabled }
        return isSelected ? .ready : .notSelected
    }

    /// Bật bộ gõ. Trên macOS 12 trở lên, hệ thống sẽ hỏi người dùng.
    static func enable() {
        if let s = source() { TISEnableInputSource(s) }
    }

    /// Chọn Mr TV làm nguồn nhập. Trả về true nếu sau đó Mr TV thật sự đang được chọn.
    @discardableResult
    static func select() -> Bool {
        guard let s = source() else { return false }
        if !bool(s, kTISPropertyInputSourceIsEnabled) { TISEnableInputSource(s) }
        TISSelectInputSource(s)
        return isSelected
    }

    /// Cài, bật và chọn trong một bước (nút ở màn Bắt đầu và mục Quyền).
    static func installAndSelect() throws {
        if !isInstalled || needsUpdate { try install() }
        enable()
        select()
    }

    /// Mỗi lần mở Mr TV: bộ gõ đã cài mà khác phiên bản đi kèm thì cài lại,
    /// để bộ gõ và ứng dụng luôn cùng một bản.
    static func syncInstalledCopy() {
        guard isInstalled, needsUpdate else { return }
        let wasSelected = isSelected
        do {
            try install()
            if wasSelected { select() }
            Log.app.info("Đã cài lại bộ gõ cho khớp phiên bản")
        } catch {
            Log.app.error("Không cài lại được bộ gõ: \(error.localizedDescription)")
        }
    }

    static func openKeyboardSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
            ?? URL(fileURLWithPath: "/System/Library/PreferencePanes/Keyboard.prefPane")
        NSWorkspace.shared.open(url)
    }
}
