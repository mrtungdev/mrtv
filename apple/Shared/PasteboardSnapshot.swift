import AppKit

/// Bản sao mọi thứ trong clipboard (chữ, chữ định dạng, ảnh, tệp…), giữ đúng thứ tự từng loại,
/// để mượn clipboard xong trả lại nguyên vẹn.
struct PasteboardSnapshot: @unchecked Sendable {
    private let items: [[(NSPasteboard.PasteboardType, Data)]]

    init(_ board: NSPasteboard) {
        items = (board.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
    }

    func restore(to board: NSPasteboard) {
        board.clearContents()
        let restored = items.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { board.writeObjects(restored) }
    }
}
