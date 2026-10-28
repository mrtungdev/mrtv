import AppKit
import XCTest

final class PasteboardSnapshotTests: XCTestCase {
    private var board: NSPasteboard!

    override func setUp() {
        board = NSPasteboard(name: NSPasteboard.Name("dev.mrtung.mrtv.tests.\(UUID().uuidString)"))
    }

    override func tearDown() {
        board.releaseGlobally()
    }

    func testRestoresEveryType() {
        let item = NSPasteboardItem()
        item.setString("Tiếng Việt", forType: .string)
        item.setData(Data("<b>Tiếng Việt</b>".utf8), forType: .html)
        item.setData(Data([0x89, 0x50, 0x4E, 0x47]), forType: .png)
        board.clearContents()
        board.writeObjects([item])

        let saved = PasteboardSnapshot(board)
        board.clearContents()
        board.setString("chữ tạm", forType: .string)
        saved.restore(to: board)

        XCTAssertEqual(board.string(forType: .string), "Tiếng Việt")
        XCTAssertEqual(board.data(forType: .html), Data("<b>Tiếng Việt</b>".utf8))
        XCTAssertEqual(board.data(forType: .png), Data([0x89, 0x50, 0x4E, 0x47]))
    }

    func testImageOnlyClipboardIsNotEmptied() {
        board.clearContents()
        board.setData(Data([1, 2, 3]), forType: .tiff)

        let saved = PasteboardSnapshot(board)
        board.clearContents()
        board.setString("chữ tạm", forType: .string)
        saved.restore(to: board)

        XCTAssertNil(board.string(forType: .string))
        XCTAssertEqual(board.data(forType: .tiff), Data([1, 2, 3]))
    }

    func testKeepsEveryItem() {
        board.clearContents()
        board.writeObjects(["một" as NSString, "hai" as NSString])

        let saved = PasteboardSnapshot(board)
        saved.restore(to: board)

        XCTAssertEqual(board.pasteboardItems?.compactMap { $0.string(forType: .string) }, ["một", "hai"])
    }
}
