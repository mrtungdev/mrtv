import XCTest

final class SyntheticTextTests: XCTestCase {
    func testChunksNeverSplitSurrogatePairs() {
        // 19 chữ rồi emoji: chỗ cắt thứ 20 rơi giữa cặp surrogate của 😀.
        let text = String(repeating: "a", count: 19) + "😀" + "b"
        let chunks = SyntheticText.chunks(text)
        XCTAssertEqual(chunks.map(\.count), [19, 3])
        for chunk in chunks {
            XCTAssertNotNil(String(utf16CodeUnits: chunk, count: chunk.count).unicodeScalars.first)
            XCTAssertFalse(UTF16.isLeadSurrogate(chunk.last!))
            XCTAssertFalse(UTF16.isTrailSurrogate(chunk.first!))
        }
        XCTAssertEqual(chunks.flatMap { $0 }, Array(text.utf16))
    }

    func testShortAndLongText() {
        XCTAssertEqual(SyntheticText.chunks(""), [])
        XCTAssertEqual(SyntheticText.chunks("Việt").map(\.count), [4])
        XCTAssertEqual(SyntheticText.chunks(String(repeating: "x", count: 45)).map(\.count), [20, 20, 5])
        let emoji = String(repeating: "😀", count: 15)
        XCTAssertEqual(SyntheticText.chunks(emoji).flatMap { $0 }, Array(emoji.utf16))
        XCTAssertTrue(SyntheticText.chunks(emoji).allSatisfy { $0.count % 2 == 0 })
    }
}
