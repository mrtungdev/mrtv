import XCTest

/// Ô nhập chữ giả: giữ chữ đã chốt, con trỏ và chữ đang soạn, giống cách ứng dụng thật cư xử.
private final class FakeClient: TextClient {
    var text: [UInt16] = []
    var caret = 0
    var marked: [UInt16] = []
    var markedStart = 0

    var visible: String {
        var all = text
        all.insert(contentsOf: marked, at: markedStart)
        return String(utf16CodeUnits: all, count: all.count)
    }

    func selectedRange() -> NSRange {
        NSRange(location: marked.isEmpty ? caret : markedStart + marked.count, length: 0)
    }

    func string(in range: NSRange) -> String? {
        guard range.location >= 0, range.location + range.length <= text.count else { return nil }
        let slice = Array(text[range.location..<range.location + range.length])
        return String(utf16CodeUnits: slice, count: slice.count)
    }

    /// Ô nhập có sẵn chữ, con trỏ ở `caret` (mặc định ở cuối).
    convenience init(_ existing: String, caret: Int? = nil) {
        self.init()
        text = Array(existing.utf16)
        self.caret = caret ?? text.count
    }

    func insertText(_ s: String, replacementRange: NSRange) {
        let u = Array(s.utf16)
        if replacementRange.location == NSNotFound {
            if !marked.isEmpty {
                caret = markedStart
                marked = []
            }
            text.insert(contentsOf: u, at: caret)
            caret += u.count
        } else {
            text.replaceSubrange(replacementRange.location..<replacementRange.location + replacementRange.length, with: u)
            caret = replacementRange.location + u.count
        }
    }

    func setMarkedText(_ s: String, selectionRange: NSRange, replacementRange: NSRange) {
        if marked.isEmpty { markedStart = caret }
        marked = Array(s.utf16)
    }

    /// Phím không được bộ gõ xử lý thì ứng dụng tự xử lý.
    func passThrough(_ key: InputKey) {
        switch key {
        case .char(let c):
            insertText(String(c), replacementRange: NSRange(location: NSNotFound, length: 0))
        case .backspace:
            if caret > 0 {
                text.remove(at: caret - 1)
                caret -= 1
            }
        default:
            break
        }
    }
}

final class InputSessionTests: XCTestCase {
    private func type(_ input: String, path: TypingPath, client: FakeClient = FakeClient(), session: InputSession? = nil) -> String {
        let s = session ?? InputSession()
        s.path = path
        for c in input.unicodeScalars {
            let key: InputKey
            switch c {
            case "\u{8}": key = .backspace
            case "\u{1b}": key = .escape
            default: key = .char(c)
            }
            if !s.handle(key, client: client) {
                client.passThrough(key)
            }
        }
        return client.visible
    }

    func testDirectTyping() {
        XCTAssertEqual(type("tieesng Vieejt ", path: .direct), "tiếng Việt ")
        XCTAssertEqual(type("dduowcj nguowif ", path: .direct), "được người ")
    }

    func testComposingTyping() {
        XCTAssertEqual(type("tieesng Vieejt ", path: .composing), "tiếng Việt ")
        XCTAssertEqual(type("hoaf ", path: .composing), "hoà ")
    }

    func testBackspaceKeepsWordState() {
        XCTAssertEqual(type("tieesng\u{8}\u{8}t", path: .direct), "tiết")
        XCTAssertEqual(type("tieesng\u{8}\u{8}t", path: .composing), "tiết")
    }

    func testBackspaceIntoPreviousWord() {
        XCTAssertEqual(type("Tieeng \u{8}s", path: .direct), "Tiếng")
        XCTAssertEqual(type("Tieeng abc\u{8}\u{8}\u{8}\u{8}s", path: .direct), "Tiếng")
    }

    func testCaretJumpForgetsPreviousWords() {
        let client = FakeClient()
        let session = InputSession()
        _ = type("Tieeng abc", path: .direct, client: client, session: session)
        // Người dùng bấm chuột ra sau chữ "a" rồi xoá "a" và dấu cách: không được sửa nhầm thành "Tiếng".
        client.caret = 7
        XCTAssertEqual(type("\u{8}\u{8}s", path: .direct, client: client, session: session), "Tiêngsbc")
    }

    func testResumeWordBeforeCaret() {
        // Con trỏ ở cuối "Viêt" có sẵn (vừa bấm chuột tới), gõ j ra "Việt".
        XCTAssertEqual(type("j", path: .direct, client: FakeClient("Tôi ở Viêt")), "Tôi ở Việt")
        XCTAssertEqual(type("f", path: .direct, client: FakeClient("hoa")), "hoà")
        // Con trỏ giữa từ: gõ như từ mới.
        XCTAssertEqual(type("s", path: .direct, client: FakeClient("hoa", caret: 2)), "hosa")
        // Sau dấu cách: từ mới; xoá lùi thì nối về từ trước.
        XCTAssertEqual(type("\u{8}f", path: .direct, client: FakeClient("hoa ")), "hoà")
    }

    func testEscapeRestoresKeys() {
        XCTAssertEqual(type("tieesng\u{1b}", path: .direct), "tieesng")
        XCTAssertEqual(type("tieesng\u{1b}", path: .composing), "tieesng")
    }

    func testEscapeUndoesMacro() {
        let session = InputSession()
        session.engine.setMacros(tsv: "ksao\tKhông sao đâu")
        XCTAssertEqual(type("ksao ", path: .direct, session: session), "Không sao đâu ")
        let again = InputSession()
        again.engine.setMacros(tsv: "ksao\tKhông sao đâu")
        XCTAssertEqual(type("ksao \u{1b}", path: .direct, session: again), "ksao ")
    }

    func testEscapeUndoesEmojiMacro() {
        // 😀 chiếm 2 đơn vị UTF-16: esc phải xoá trọn nó, không cắt đôi.
        let typed = InputSession()
        typed.engine.setMacros(tsv: "cuoi\t😀")
        XCTAssertEqual(type("cuoi ", path: .direct, session: typed), "😀 ")
        let undone = InputSession()
        undone.engine.setMacros(tsv: "cuoi\t😀")
        XCTAssertEqual(type("cuoi \u{1b}", path: .direct, session: undone), "cuoi ")
    }

    func testEscapeAfterCaretJumpLeavesTextAlone() {
        let client = FakeClient("xin chào ")
        let session = InputSession()
        _ = type("tieesng", path: .direct, client: client, session: session)
        XCTAssertEqual(client.visible, "xin chào tiếng")
        client.caret = 3
        XCTAssertEqual(type("\u{1b}", path: .direct, client: client, session: session), "xin chào tiếng")
    }

    func testEnglishWordsStay() {
        XCTAssertEqual(type("good book user ", path: .direct), "good book user ")
        // Phím lặp không làm mất chữ, và chữ biến đổi được trả lại đúng phím khi bấm dấu cách.
        XCTAssertEqual(type("progress class keep pass ", path: .direct), "progress class keep pass ")
        XCTAssertEqual(type("progress class keep pass ", path: .composing), "progress class keep pass ")
    }

    func testCaretJumpStartsNewWord() {
        let client = FakeClient()
        let session = InputSession()
        _ = type("tie", path: .direct, client: client, session: session)
        client.caret = 0
        XCTAssertEqual(type("e", path: .direct, client: client, session: session), "etie")
    }

    func testTextTools() {
        XCTAssertEqual(TextTool.strip.run("Tiếng Việt"), "Tieng Viet")
        XCTAssertEqual(TextTool.fromTCVN3.run("ViÖt Nam"), "Việt Nam")
        XCTAssertEqual(TextTool.numberWords.run("1500"), "một nghìn năm trăm")
        XCTAssertFalse(TypingEngine.coreVersion.isEmpty)
    }
}

final class GestureDetectorTests: XCTestCase {
    func testDoubleTapOption() {
        var d = GestureDetector()
        XCTAssertEqual(d.modifiers([.option], at: 0), [])
        XCTAssertEqual(d.modifiers([], at: 0.1), [])
        XCTAssertEqual(d.modifiers([.option], at: 0.2), [])
        XCTAssertEqual(d.modifiers([], at: 0.3), [.fired(.double(.option))])
    }

    func testSlowTapsAreNotDouble() {
        var d = GestureDetector()
        _ = d.modifiers([.option], at: 0)
        _ = d.modifiers([], at: 0.1)
        _ = d.modifiers([.option], at: 0.9)
        XCTAssertEqual(d.modifiers([], at: 1.0), [])
    }

    func testTypingBetweenTapsCancels() {
        var d = GestureDetector()
        _ = d.modifiers([.option], at: 0)
        _ = d.modifiers([], at: 0.1)
        _ = d.otherInput()
        _ = d.modifiers([.option], at: 0.2)
        XCTAssertEqual(d.modifiers([], at: 0.3), [])
    }

    func testOptionWithKeyIsNotTap() {
        var d = GestureDetector()
        _ = d.modifiers([.option], at: 0)
        _ = d.otherInput()
        _ = d.modifiers([], at: 0.1)
        _ = d.modifiers([.option], at: 0.2)
        XCTAssertEqual(d.modifiers([], at: 0.3), [])
    }

    func testChord() {
        var d = GestureDetector()
        _ = d.modifiers([.control], at: 0)
        _ = d.modifiers([.control, .shift], at: 0.05)
        _ = d.modifiers([.shift], at: 0.2)
        XCTAssertEqual(d.modifiers([], at: 0.25), [.fired(.chord([.control, .shift]))])
    }

    func testHold() {
        var d = GestureDetector()
        _ = d.modifiers([.option], at: 0)
        XCTAssertEqual(d.holdCheck(at: 0.6), [.holdBegan(.option)])
        XCTAssertEqual(d.modifiers([], at: 1.5), [.holdEnded(.option)])
        // Vừa giữ xong thì lần chạm sau không tính thành chạm hai lần.
        _ = d.modifiers([.option], at: 1.6)
        XCTAssertEqual(d.modifiers([], at: 1.7), [])
    }

    func testFn() {
        var d = GestureDetector()
        XCTAssertEqual(d.fn(down: true), [])
        XCTAssertEqual(d.fn(down: false), [.fired(.fn)])
        _ = d.fn(down: true)
        _ = d.otherInput()
        XCTAssertEqual(d.fn(down: false), [])
    }
}
