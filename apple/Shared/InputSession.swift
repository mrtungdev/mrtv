import Foundation

/// Ô nhập chữ mà bộ gõ đang gõ vào. Bộ gõ thật dùng `IMKTextInput`; bài thử dùng ô giả.
protocol TextClient: AnyObject {
    func selectedRange() -> NSRange
    /// Chữ trong một khoảng (đơn vị UTF-16), để đọc từ ngay trước con trỏ. nil nếu ứng dụng không cho đọc.
    func string(in range: NSRange) -> String?
    func insertText(_ text: String, replacementRange: NSRange)
    func setMarkedText(_ text: String, selectionRange: NSRange, replacementRange: NSRange)
}

/// Một phím, đã quy về những gì bộ gõ cần biết.
enum InputKey: Equatable {
    case char(Unicode.Scalar)
    case backspace
    case escape
    /// Phím di chuyển, Return, Tab… : chốt từ đang gõ rồi để phím đi tiếp.
    case navigation
    /// Có ⌘, ⌃ hoặc ⌥: chốt từ đang gõ rồi để phím đi tiếp.
    case shortcut
}

/// Logic gõ của đường A cho một ô nhập chữ: chọn giữa "gõ ngay" và "chữ đang soạn".
/// Tách khỏi InputMethodKit để thử được bằng XCTest.
final class InputSession {
    let engine: TypingEngine
    var path: TypingPath = .composing
    private(set) var marked = ""
    /// Vị trí con trỏ dự kiến sau phím vừa xử lý (gõ ngay). Lệch là người dùng đã bấm chuột đi chỗ khác.
    private var expectedCaret: Int?
    /// Đã đọc chữ quanh con trỏ từ lần con trỏ đổi chỗ gần nhất chưa.
    private var contextKnown = false
    /// Số ký tự đọc ngược từ con trỏ, đủ cho một từ dài và dấu câu trước nó.
    private static let contextLength = 32

    static let notFound = NSRange(location: NSNotFound, length: 0)

    init(engine: TypingEngine = TypingEngine()) {
        self.engine = engine
    }

    /// Trả về true nếu bộ gõ đã xử lý phím (nuốt phím).
    func handle(_ key: InputKey, client: TextClient) -> Bool {
        switch key {
        case .navigation, .shortcut:
            commit(client)
            return false
        case .backspace:
            return backspace(client)
        case .escape:
            return escape(client)
        case .char(let scalar):
            // Hỏi vị trí con trỏ một lần cho mỗi phím: mỗi lần hỏi là một lượt gọi sang ứng dụng.
            let sel = path == .direct ? client.selectedRange() : Self.notFound
            if path == .direct {
                checkCaret(sel)
                resumeIfNeeded(sel, scalar, client)
            }
            let edit = engine.key(scalar)
            return path == .direct ? applyDirect(edit, client, sel) : applyComposing(edit, scalar, client)
        }
    }

    /// Chốt chữ đang soạn (nếu có) và bỏ từ đang gõ.
    func commit(_ client: TextClient?) {
        if !marked.isEmpty, let client {
            client.insertText(marked, replacementRange: Self.notFound)
        }
        marked = ""
        engine.reset()
        expectedCaret = nil
        contextKnown = false
    }

    private func checkCaret(_ sel: NSRange) {
        if let expected = expectedCaret, sel.location != expected || sel.length != 0 {
            engine.reset()
            contextKnown = false
        }
    }

    /// Con trỏ vừa đổi chỗ (bấm chuột, phím mũi tên, mở ô nhập) và người dùng gõ một chữ:
    /// đọc từ ngay trước con trỏ để sửa hay gõ nối tiếp nó ("Viêt" rồi `j` ra "Việt").
    /// Con trỏ ở giữa một từ thì thôi, gõ như từ mới.
    private func resumeIfNeeded(_ sel: NSRange, _ scalar: Unicode.Scalar, _ client: TextClient) {
        guard !contextKnown else { return }
        contextKnown = true
        guard sel.location != NSNotFound, sel.length == 0, sel.location > 0,
              CharacterSet.alphanumerics.contains(scalar) else { return }
        if let after = client.string(in: NSRange(location: sel.location, length: 1)),
           let next = after.unicodeScalars.first, CharacterSet.alphanumerics.contains(next) {
            return
        }
        let start = max(0, sel.location - Self.contextLength)
        guard let before = client.string(in: NSRange(location: start, length: sel.location - start)), !before.isEmpty else { return }
        engine.resume(before)
    }

    private func applyDirect(_ edit: TypingEngine.Edit, _ client: TextClient, _ sel: NSRange? = nil) -> Bool {
        let sel = sel ?? client.selectedRange()
        guard sel.location != NSNotFound else {
            engine.reset()
            expectedCaret = nil
            return false
        }
        var caret = sel.location
        if edit.hasEdit {
            // NSRange tính theo UTF-16: dùng số đơn vị UTF-16 cần xoá, không phải số ký tự.
            guard sel.location >= edit.deletedUTF16 else {
                engine.reset()
                expectedCaret = nil
                return false
            }
            let range = NSRange(location: sel.location - edit.deletedUTF16, length: edit.deletedUTF16 + sel.length)
            client.insertText(edit.text, replacementRange: range)
            caret = range.location + (edit.text as NSString).length
        }
        // Theo dõi con trỏ cả sau dấu cách: lõi nhớ các từ vừa gõ để xoá lùi về sửa tiếp,
        // nên con trỏ nhảy chỗ khác thì phải quên chúng.
        expectedCaret = caret + (edit.consumed ? 0 : 1)
        return edit.consumed
    }

    private func applyComposing(_ edit: TypingEngine.Edit, _ scalar: Unicode.Scalar, _ client: TextClient) -> Bool {
        let isLetter = scalar.isASCII && CharacterSet.alphanumerics.contains(scalar)
        guard isLetter else {
            // Kết thúc từ: áp chỉnh sửa (gõ tắt, trả lại phím gốc) lên chữ đang soạn rồi chốt.
            var word = marked
            if edit.hasEdit {
                word = String(String.UnicodeScalarView(word.unicodeScalars.dropLast(edit.backspaces))) + edit.text
            }
            if !word.isEmpty {
                client.insertText(word, replacementRange: Self.notFound)
            }
            marked = ""
            return false
        }
        setMarked(engine.composingWord, client)
        return true
    }

    private func setMarked(_ word: String, _ client: TextClient) {
        marked = word
        client.setMarkedText(word, selectionRange: NSRange(location: (word as NSString).length, length: 0),
                             replacementRange: Self.notFound)
    }

    private func backspace(_ client: TextClient) -> Bool {
        guard path == .composing else {
            let sel = client.selectedRange()
            checkCaret(sel)
            guard sel.location != NSNotFound, sel.length == 0 else {
                // Xoá một vùng đang bôi đen: chữ quanh con trỏ đã khác, bắt đầu lại.
                engine.reset()
                contextKnown = false
                expectedCaret = sel.location == NSNotFound ? nil : sel.location
                return false
            }
            _ = engine.backspace()
            expectedCaret = sel.location == 0 ? nil : sel.location - 1
            return false
        }
        guard !marked.isEmpty else {
            engine.reset()
            return false
        }
        _ = engine.backspace()
        setMarked(engine.composingWord, client)
        return true
    }

    private func escape(_ client: TextClient) -> Bool {
        // Gõ ngay: con trỏ đã đổi chỗ thì từ vừa gõ không còn ở đó, esc không được sửa chữ ở chỗ mới.
        let sel = path == .direct ? client.selectedRange() : Self.notFound
        if path == .direct { checkCaret(sel) }
        let edit = engine.escape()
        guard edit.consumed else {
            commit(client)
            return false
        }
        if path == .composing {
            // Chữ đã chốt (gõ tắt vừa bung) thì chữ đang soạn không sửa ngược được.
            guard !marked.isEmpty else {
                engine.reset()
                return false
            }
            setMarked(engine.composingWord, client)
            return true
        }
        return applyDirect(edit, client, sel)
    }
}
