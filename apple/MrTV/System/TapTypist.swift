import AppKit
import CoreGraphics

/// Đường B: gõ bằng event tap cho các ứng dụng mà bộ gõ chuẩn hay bị gạch chân hoặc lệch chữ
/// (Chromium, Electron, JetBrains, Terminal). Chạy trên một luồng riêng có run loop riêng,
/// để việc giao diện trên luồng chính không làm chậm phím.
///
/// Mọi phím tổng hợp đều phát từ đây (một bộ quyền Trợ năng duy nhất) và mang dấu `marker`
/// để không bị xử lý lần nữa.
final class TapTypist: @unchecked Sendable {
    static let shared = TapTypist()
    static let marker: Int64 = 0x4D52_5456 // "MRTV"

    private struct State {
        var path: TypingPath = .composing
        var mode: InputMode = .vietnamese
        var delay: useconds_t = 0
        var fixAutocomplete = false
        /// Ứng dụng đang nhận phím: do bộ gõ báo, hoặc ứng dụng đứng trước.
        var client: String?
        var version = 0
        var needsReset = true
        var quickBarOpen = false
        var quickBarList = false
        var published: Bool?
    }

    private let state = Locked(State())
    private var thread: Thread?
    // Chỉ dùng trên luồng của tap:
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var engine: TypingEngine?
    private var appliedVersion = -1
    private var appliedSettings: EngineSettings?
    /// Con trỏ có thể đã đổi chỗ (bấm chuột, phím mũi tên, đổi ứng dụng): phím chữ tới sẽ đọc từ
    /// trước con trỏ để sửa hay gõ nối tiếp. Chỉ dùng trên luồng của tap.
    private var needsContext = true
    private var source: CGEventSource?

    /// Phím 1, 2, 3, esc khi thanh gợi ý đang mở. Trả về true để nuốt phím. Gọi trên luồng của tap.
    /// Đối số thứ hai: đang mở danh sách đầy đủ (⌥⌥), nhận thêm 4–9, mũi tên và ↩.
    var quickBarKeys: (@Sendable (Int64, Bool) -> Bool)?

    private var observing = false

    var isRunning: Bool { thread != nil }

    /// Ứng dụng có ô đang nhận phím: ứng dụng đứng trước, hoặc ô mà bộ gõ báo (Spotlight và các bảng
    /// nổi nhận phím trong khi ứng dụng khác vẫn đứng trước).
    var client: String? { state.withLock { $0.client } }

    @MainActor
    func start() {
        guard thread == nil else { return }
        guard Permissions.accessibility else {
            publish(active: false)
            return
        }
        if !observing {
            observing = true
            DarwinNotice.settingsChanged.observe {
                TapTypist.shared.state.withLock { $0.version += 1 }
                // Cách gõ của ứng dụng đang dùng có thể vừa đổi (menu, Cài đặt): đọc lại hồ sơ ngay như bộ gõ.
                Task { @MainActor in TapTypist.shared.profileChanged() }
            }
            DarwinNotice.modeChanged.observe {
                Task { @MainActor in TapTypist.shared.frontAppChanged(bundleID: TapTypist.shared.state.current.client) }
            }
        }
        let t = Thread { [weak self] in self?.runTap() }
        t.name = "dev.mrtung.mrtv.tap"
        t.qualityOfService = .userInteractive
        thread = t
        t.start()
    }

    @MainActor
    func stop() {
        if let rl = runLoop { CFRunLoopStop(rl) }
        thread = nil
        publish(active: false)
    }

    @MainActor
    func frontAppChanged(bundleID: String?) {
        let profile = SharedStore.profile(for: bundleID)
        let mode = SharedStore.mode(for: bundleID)
        state.withLock {
            $0.client = bundleID
            Self.apply(profile, to: &$0)
            $0.mode = mode
            $0.needsReset = true
        }
    }

    /// Hồ sơ của ứng dụng đang dùng vừa đổi. Chỉ bỏ từ đang gõ khi cách gõ đổi.
    @MainActor
    func profileChanged() {
        let client = state.withLock { $0.client }
        let profile = SharedStore.profile(for: client)
        state.withLock { Self.apply(profile, to: &$0) }
    }

    private static func apply(_ profile: AppProfile, to s: inout State) {
        if s.path != profile.path { s.needsReset = true }
        s.path = profile.path
        s.delay = useconds_t((profile.delayMs ?? 0) * 1000)
        s.fixAutocomplete = profile.fixAutocomplete ?? false
    }

    func setQuickBarOpen(_ open: Bool, list: Bool = false) {
        state.withLock {
            $0.quickBarOpen = open
            $0.quickBarList = open && list
        }
    }

    /// Báo cho bộ gõ biết đường B có đang chạy không; chỉ báo khi trạng thái đổi.
    private func publish(active: Bool) {
        let changed = state.withLock { s -> Bool in
            guard s.published != active else { return false }
            s.published = active
            return true
        }
        guard changed else { return }
        SharedStore.defaults.set(active, forKey: "tapActive")
        DarwinNotice.settingsChanged.post()
    }

    // MARK: Luồng của tap

    private func runTap() {
        source = CGEventSource(stateID: .privateState)
        source?.userData = Self.marker
        engine = TypingEngine(SharedStore.engine)
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                           eventsOfInterest: CGEventMask(mask), callback: { _, type, event, ctx in
            let typist = Unmanaged<TapTypist>.fromOpaque(ctx!).takeUnretainedValue()
            return typist.handle(type, event)
        }, userInfo: me) else {
            Log.app.error("Không tạo được event tap cho đường B (thiếu quyền Trợ năng?)")
            publish(active: false)
            DispatchQueue.main.async { TapTypist.shared.thread = nil }
            return
        }
        tap = port
        runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        publish(active: true)
        CFRunLoopRun()
        publish(active: false)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.marker { return pass }
        guard let engine else { return pass }
        if type != .keyDown {
            forget(engine)
            return pass
        }
        let st = state.current
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if st.quickBarOpen, let keys = quickBarKeys, keys(keyCode, st.quickBarList) {
            return nil
        }
        guard st.path == .tap, st.mode == .vietnamese else { return pass }
        if st.needsReset {
            forget(engine)
            state.withLock { $0.needsReset = false }
        }
        if appliedVersion != st.version {
            // Chỉ nạp lại kiểu gõ khi nó đổi (nạp lại làm lõi bỏ từ đang gõ); rồi đọc lại chữ trước con trỏ.
            let settings = SharedStore.engine
            if settings != appliedSettings {
                engine.apply(settings)
                appliedSettings = settings
                needsContext = true
            }
            engine.loadWordLists(macros: SharedStore.loadMacros(), exceptions: SharedStore.exceptions,
                                 englishOff: SharedStore.englishOff)
            appliedVersion = st.version
        }
        if !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            forget(engine)
            return pass
        }
        switch keyCode {
        case 51:
            // Ô có gợi ý tự điền (thanh địa chỉ, Excel): phím xoá có thể chỉ xoá phần gợi ý đang bôi đen,
            // chữ đã gõ vẫn nguyên ("hoa|ngdan" ⌫ còn "hoa"). Đang bôi đen thì lõi giữ nguyên từ;
            // không đọc được ô thì bỏ từ, phím chữ tới đọc lại chữ trước con trỏ.
            if st.fixAutocomplete {
                switch AXContext.selectionLength() {
                case 0?: _ = engine.backspace()
                case .some: break
                case nil: forget(engine)
                }
            } else {
                _ = engine.backspace()
            }
            return pass
        case 53:
            // esc: trả lại phím gốc của từ đang gõ, hoặc lấy lại chữ tắt vừa bung.
            let edit = engine.escape()
            guard edit.consumed else {
                forget(engine)
                return pass
            }
            post(backspaces: edit.deleteKeys, text: edit.text, delay: st.delay, fixAutocomplete: false)
            return nil
        case 36, 48, 76, 115, 116, 117, 119, 121, 123, 124, 125, 126:
            forget(engine)
            return pass
        default:
            break
        }
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length == 1, let scalar = Unicode.Scalar(chars[0]) else {
            forget(engine)
            return pass
        }
        if needsContext {
            needsContext = false
            if CharacterSet.alphanumerics.contains(scalar), let before = AXContext.textBeforeCaret() {
                engine.resume(before)
            }
        }
        let edit = engine.key(scalar)
        if !edit.consumed && !edit.hasEdit { return pass }
        var text = edit.text
        if !edit.consumed { text.unicodeScalars.append(scalar) }
        post(backspaces: edit.deleteKeys, text: text, delay: st.delay, fixAutocomplete: st.fixAutocomplete)
        return nil
    }

    /// Bỏ từ đang gõ; phím chữ tới sẽ đọc lại chữ trước con trỏ.
    private func forget(_ engine: TypingEngine) {
        engine.reset()
        needsContext = true
    }

    /// Xoá rồi gõ lại. Chỉ chờ một lần giữa loạt phím xoá và chữ mới (ứng dụng nào cần), không chờ
    /// sau từng phím xoá: chờ từng phím làm chữ hiện chậm thấy rõ khi sửa dấu ở từ dài.
    private func post(backspaces: Int, text: String, delay: useconds_t, fixAutocomplete: Bool) {
        var backspaces = backspaces
        if fixAutocomplete && backspaces > 0 {
            // Thanh địa chỉ đang bôi đen phần gợi ý ("vie|tnamnet.vn"): phím xoá đầu tiên chỉ xoá phần gợi ý.
            // Gõ một ký tự giả để thay phần đó, rồi xoá thêm một lần.
            postText("\u{202F}")
            backspaces += 1
        }
        for _ in 0..<backspaces {
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: down)
                e?.flags = []
                e?.setIntegerValueField(.eventSourceUserData, value: Self.marker)
                e?.post(tap: .cgSessionEventTap)
            }
        }
        if backspaces > 0 && delay > 0 { usleep(delay) }
        postText(text)
    }

    private func postText(_ text: String) {
        for chunk in SyntheticText.chunks(text) {
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
                e?.flags = []
                e?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                e?.setIntegerValueField(.eventSourceUserData, value: Self.marker)
                e?.post(tap: .cgSessionEventTap)
            }
        }
    }
}
