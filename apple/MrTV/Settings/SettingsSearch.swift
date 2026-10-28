import Foundation

/// Tìm trong Cài đặt: theo tên từng cài đặt và vài từ hay dùng để gọi nó, không chỉ tên mục.
/// Gõ không dấu cũng được ("gach chan" ra "Ứng dụng › Cách gõ").
enum SettingsSearch {
    struct Entry: Identifiable {
        let pane: SettingsPane
        let title: String
        /// Từ khác người dùng hay gõ khi tìm cài đặt này.
        let keywords: String
        var id: String { pane.rawValue + "/" + title }
    }

    static let entries: [Entry] = [
        .init(pane: .typing, title: "Kiểu gõ", keywords: "telex vni telex đơn giản cách bỏ dấu"),
        .init(pane: .typing, title: "Đặt dấu", keywords: "hoà hòa mới cũ oa oe uy thuỷ thủy"),
        .init(pane: .typing, title: "Giữ nguyên từ tiếng Anh", keywords: "english restore khôi phục esc"),
        .init(pane: .typing, title: "Danh sách từ tiếng Anh", keywords: "thêm từ tắt từ có sẵn xoá"),
        .init(pane: .typing, title: "Gõ thông minh", keywords: "vietje dấu muộn ươ uow xoá lùi sửa dấu"),
        .init(pane: .macros, title: "Bật gõ tắt", keywords: "macro viết tắt chữ tắt"),
        .init(pane: .macros, title: "Gõ tắt của bạn", keywords: "macro thêm sửa xoá mẫu"),
        .init(pane: .apps, title: "Nhớ Việt/Anh theo ứng dụng", keywords: "chế độ từng app"),
        .init(pane: .apps, title: "Cách gõ theo ứng dụng", keywords: "gõ chuẩn gõ đè chữ gạch chân khung chrome claude tự động"),
        .init(pane: .keys, title: "Phím Đổi Việt ⇄ Anh", keywords: "fn 🌐 chuyển ngôn ngữ phím tắt hotkey"),
        .init(pane: .keys, title: "Phím Mr TV", keywords: "option ⌥⌥ bảng lệnh phím tắt"),
        .init(pane: .keys, title: "Tự đặt tổ hợp phím", keywords: "ghi phím đổi phím trùng phím"),
        .init(pane: .keys, title: "Phím fn của macOS", keywords: "🌐 địa cầu biểu tượng cảm xúc emoji bàn phím"),
        .init(pane: .general, title: "Mở Mr TV khi bật máy", keywords: "khởi động đăng nhập login"),
        .init(pane: .general, title: "Hiện biểu tượng trên thanh menu", keywords: "ẩn menu bar icon"),
        .init(pane: .general, title: "Nhãn Việt/Anh cạnh con trỏ", keywords: "hud báo chế độ"),
        .init(pane: .general, title: "Bộ gõ Mr TV", keywords: "nguồn nhập input source cài bật dùng không gõ được không ra dấu"),
        .init(pane: .general, title: "Trợ năng", keywords: "accessibility quyền cấp quyền"),
        .init(pane: .general, title: "Giám sát đầu vào", keywords: "input monitoring quyền"),
        .init(pane: .general, title: "Riêng tư", keywords: "gửi dữ liệu không lưu mã nguồn"),
    ]

    private static func fold(_ s: String) -> String {
        (TextTool.strip.run(s.lowercased()) ?? s.lowercased())
    }

    /// nil khi ô tìm trống; mảng rỗng khi không thấy gì.
    static func find(_ query: String) -> [Entry]? {
        let words = fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }
        let scored: [(Entry, Int)] = entries.compactMap { e in
            let title = fold(e.title)
            let hay = title + " " + fold(e.keywords) + " " + fold(e.pane.title)
            guard words.allSatisfy({ hay.contains($0) }) else { return nil }
            // Khớp ở tên cài đặt xếp trên, khớp ở đầu tên xếp trên nữa.
            let score = (title.hasPrefix(words[0]) ? 2 : 0) + (words.allSatisfy { title.contains($0) } ? 1 : 0)
            return (e, score)
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }
}
