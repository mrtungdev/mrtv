import Foundation
import ServiceManagement

/// Mở Mr TV khi bật máy: SMAppService trên macOS 13 trở lên, LaunchAgent trên macOS 12.
enum LoginItem {
    private static let label = "dev.mrtung.mrtv.login"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: agentURL.path)
    }

    static func set(_ on: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                Log.app.error("Không đổi được mục mở khi bật máy: \(error.localizedDescription)")
            }
            return
        }
        if on {
            guard let exe = Bundle.main.executablePath else { return }
            let plist: [String: Any] = ["Label": label, "ProgramArguments": [exe], "RunAtLoad": true, "ProcessType": "Interactive"]
            try? FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            (plist as NSDictionary).write(to: agentURL, atomically: true)
        } else {
            try? FileManager.default.removeItem(at: agentURL)
        }
    }
}
