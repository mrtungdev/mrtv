import Foundation
import Sparkle

/// Cập nhật qua Sparkle 2. Chỉ chạy khi Info.plist có SUFeedURL (hiện để trống cho tới khi có trang phát hành).
/// Mỗi lần cập nhật, bộ gõ đi kèm được cài lại ở lần mở kế tiếp (xem `InputSourceInstaller.needsUpdate`).
@MainActor
final class Updater {
    private var controller: SPUStandardUpdaterController?

    /// Đã có trang phát hành. Chưa có thì mọi chỗ nói về bản mới (Cài đặt, menu) đều ẩn.
    static var isAvailable: Bool {
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        return !feed.isEmpty
    }

    func start() {
        guard Self.isAvailable else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        controller?.updater.automaticallyChecksForUpdates = AppModel.shared.autoUpdate
    }

    func checkNow() {
        if let controller {
            controller.checkForUpdates(nil)
        } else {
            Log.app.info("Chưa có địa chỉ cập nhật (SUFeedURL)")
        }
    }
}
