import Foundation

/// Năm luật kiểm tra trước khi hiện một mẹo (xem trang Hướng dẫn trên canvas).
/// Logic thuần, không đụng giao diện, để thử được dễ.
struct TipContext {
    var level: AppModel.TipLevel
    var secondsSinceLastKey: TimeInterval
    var screenSharingOrFocus: Bool
    var shownToday: Int
    var dismissed: Set<String>
    var mastered: Set<String>
    var snoozedUntil: Date?
    var now = Date()
}

enum TipEngine {
    static func dailyLimit(_ level: AppModel.TipLevel) -> Int {
        switch level {
        case .off, .few: return 0
        case .normal: return 1
        case .many: return 3
        }
    }

    static func canShow(_ tipID: String, _ c: TipContext) -> Bool {
        // 1. Không chen giữa câu đang gõ.
        guard c.secondsSinceLastKey >= 1.5 else { return false }
        // 2. Không khi chia sẻ màn hình, Tập trung, xem video hay trình chiếu.
        guard !c.screenSharingOrFocus else { return false }
        // 3. Chưa quá số mẹo của mức đang chọn.
        guard c.shownToday < dailyLimit(c.level) else { return false }
        // 4. Mẹo chưa bị đóng, và người dùng chưa từng làm được cách đó.
        guard !c.dismissed.contains(tipID), !c.mastered.contains(tipID) else { return false }
        // 5. Không đang tạm im lặng.
        if let until = c.snoozedUntil, until > c.now { return false }
        return true
    }
}
