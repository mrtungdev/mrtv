import Foundation

/// Chữ gửi đi bằng phím tổng hợp: mỗi sự kiện phím chỉ mang được một đoạn UTF-16 ngắn.
enum SyntheticText {
    /// Chia `text` thành các đoạn tối đa `size` đơn vị UTF-16, không cắt đôi cặp surrogate
    /// (emoji): mỗi đoạn tự nó là UTF-16 hợp lệ.
    static func chunks(_ text: String, size: Int = 20) -> [[UInt16]] {
        let units = Array(text.utf16)
        var out: [[UInt16]] = []
        var i = 0
        while i < units.count {
            var end = min(i + size, units.count)
            if end < units.count, end - i > 1, UTF16.isLeadSurrogate(units[end - 1]) { end -= 1 }
            out.append(Array(units[i..<end]))
            i = end
        }
        return out
    }
}
