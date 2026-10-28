import Foundation
import MrTVCoreFFI

/// Lớp Swift mỏng bọc lõi Rust. Mỗi tiến trình giữ một `TypingEngine` cho mỗi nơi gõ.
/// Không an toàn khi dùng từ nhiều luồng cùng lúc: chỉ gọi trên luồng chính.
final class TypingEngine {
    struct Edit: Equatable {
        /// true: bộ gõ tự làm chỉnh sửa và nuốt phím; false: để phím đi tiếp sau khi áp chỉnh sửa.
        var consumed: Bool
        /// Số lần bấm phím xoá (đường gõ đè).
        var backspaces: Int
        var text: String
        /// Như `backspaces` nhưng tính theo đơn vị UTF-16 (emoji tính 2), để thay chữ bằng NSRange.
        var deletedUTF16 = 0
        /// Số lần bấm phím xoá thật: emoji ghép nhiều ký tự (👨‍👩‍👧‍👦) chỉ tính một lần.
        var deleteKeys = 0

        static let pass = Edit(consumed: false, backspaces: 0, text: "")
        var hasEdit: Bool { backspaces > 0 || !text.isEmpty }
    }

    private let handle: OpaquePointer

    init(_ settings: EngineSettings = EngineSettings()) {
        var cfg = settings.ffi
        handle = mrtv_engine_new(&cfg)
    }

    deinit {
        mrtv_engine_free(handle)
    }

    func apply(_ settings: EngineSettings) {
        var cfg = settings.ffi
        mrtv_engine_set_config(handle, &cfg)
    }

    func key(_ scalar: Unicode.Scalar) -> Edit {
        edit(mrtv_engine_key(handle, scalar.value))
    }

    func backspace() -> Edit {
        edit(mrtv_engine_key(handle, UInt32(MRTV_KEY_BACKSPACE)))
    }

    func escape() -> Edit {
        edit(mrtv_engine_key(handle, UInt32(MRTV_KEY_ESCAPE)))
    }

    func reset() {
        mrtv_engine_reset(handle)
    }

    /// Con trỏ vừa tới cuối một từ có sẵn: lấy từ đó làm từ đang gõ để sửa hay gõ nối tiếp.
    /// `before` là chữ ngay trước con trỏ.
    func resume(_ before: String) {
        before.withCString { mrtv_engine_resume(handle, $0) }
    }

    /// Từ đang gõ, cho chữ đang soạn (marked text).
    var composingWord: String {
        var len: UInt32 = 0
        guard let ptr = mrtv_engine_word(handle, &len), len > 0 else { return "" }
        return String(utf16CodeUnits: ptr, count: Int(len))
    }

    func setMacros(tsv: String) {
        tsv.withCString { mrtv_engine_set_macros(handle, $0) }
    }

    func setExceptions(_ words: [String]) {
        words.joined(separator: "\n").withCString { mrtv_engine_set_exceptions(handle, $0) }
    }

    func setEnglishOff(_ words: [String]) {
        words.joined(separator: "\n").withCString { mrtv_engine_set_english_off(handle, $0) }
    }

    /// Nạp gõ tắt và các danh sách từ đang lưu trong cài đặt chung.
    func loadWordLists(macros: String, exceptions: [String], englishOff: [String]) {
        setMacros(tsv: macros)
        setExceptions(exceptions)
        setEnglishOff(englishOff)
    }

    /// Danh sách từ tiếng Anh có sẵn trong lõi, xếp theo bảng chữ cái.
    static let englishWords: [String] = {
        guard let p = mrtv_english_list() else { return [] }
        defer { mrtv_string_free(p) }
        return String(cString: p).split(separator: "\n").map(String.init)
    }()

    private func edit(_ o: MrtvOutput) -> Edit {
        let text: String
        if o.text_len > 0, let p = o.text {
            text = String(utf16CodeUnits: p, count: Int(o.text_len))
        } else {
            text = ""
        }
        return Edit(consumed: o.consumed, backspaces: Int(o.backspaces), text: text,
                    deletedUTF16: Int(o.deleted_utf16), deleteKeys: Int(o.delete_keys))
    }

    static var coreVersion: String {
        String(cString: mrtv_version())
    }

    /// Chữ hiện ra khi gõ lần lượt các phím `keys` với cài đặt `settings`. Dùng cho ô gõ thử.
    static func typed(_ keys: String, _ settings: EngineSettings = EngineSettings()) -> String {
        let engine = TypingEngine(settings)
        var screen: [Unicode.Scalar] = []
        for s in keys.unicodeScalars {
            let e = engine.key(s)
            screen.removeLast(min(e.backspaces, screen.count))
            screen.append(contentsOf: e.text.unicodeScalars)
            if !e.consumed { screen.append(s) }
        }
        return String(String.UnicodeScalarView(screen))
    }

    /// Gõ thử một từ qua lõi, dùng cho `--self-test` sau khi build.
    static func selfTest() -> Bool {
        typed("Vieejt ") == "Việt "
    }
}

/// `--self-test`: chạy thử rồi thoát, không mở giao diện. Dùng để kiểm tra bản build
/// nạp đủ thư viện (Sparkle, lõi Rust) và lõi gõ đúng.
func runSelfTestIfAsked(_ name: String) {
    guard CommandLine.arguments.contains("--self-test") else { return }
    let ok = TypingEngine.selfTest()
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    print("\(name) \(version) · lõi \(TypingEngine.coreVersion) · \(ok ? "gõ đúng" : "GÕ SAI")")
    exit(ok ? 0 : 1)
}

/// Các việc chạy bằng quy tắc trong lõi (thanh gợi ý, bảng lệnh).
enum TextTool: UInt32, CaseIterable {
    case nfc = 1, strip, slug, upper, lower, title, sentence, fromVIQR, fromTCVN3, reverseTelex, reverseVNI, numberWords, looksTCVN3

    func run(_ input: String, arg: UInt32 = 0) -> String? {
        let out = input.withCString { mrtv_text(rawValue, $0, arg) }
        guard let out else { return nil }
        defer { mrtv_string_free(out) }
        return String(cString: out)
    }
}

/// Cài đặt của bộ máy gõ, dùng chung cho cả hai tiến trình.
struct EngineSettings: Equatable, Codable {
    enum Method: String, Codable, CaseIterable { case telex, simpleTelex, vni }
    enum ToneStyle: String, Codable, CaseIterable { case new, old }

    var method: Method = .telex
    var toneStyle: ToneStyle = .new
    var restoreEnglish = true
    var macrosEnabled = true

    var ffi: MrtvConfig {
        let m: UInt32
        switch method {
        case .telex: m = UInt32(MRTV_METHOD_TELEX)
        case .simpleTelex: m = UInt32(MRTV_METHOD_SIMPLE_TELEX)
        case .vni: m = UInt32(MRTV_METHOD_VNI)
        }
        let t = toneStyle == .old ? UInt32(MRTV_TONE_OLD) : UInt32(MRTV_TONE_NEW)
        return MrtvConfig(method: m, tone_style: t, restore_english: restoreEnglish, macros_enabled: macrosEnabled)
    }
}
