import AppKit
import CoreGraphics

/// Phím toàn cục theo cài đặt trong `ShortcutStore`: fn, chạm hai lần, giữ, nhấn cùng lúc, hay tổ hợp.
///
/// fn, chạm hai lần, giữ và nhấn cùng lúc đọc từ một event tap trên luồng chính. Có quyền Trợ năng thì
/// dùng tap thường (vẫn cho mọi phím đi qua), không thì tap chỉ nghe (cần quyền Giám sát đầu vào).
/// fn nhận ra theo keyCode 63, không theo cờ fn, vì phím mũi tên và F1–F12 cũng mang cờ này.
/// Tổ hợp có phím thường dùng Carbon (`ComboHotkeys`), không cần quyền.
@MainActor
final class HotkeyService {
    /// Một việc được gọi. Với "giữ", `began` là true khi bắt đầu giữ và false khi thả.
    var onAction: ((ShortcutAction, _ began: Bool) -> Void)?

    private var tap: CFMachPort?
    var isRunning: Bool { tap != nil }
    private var detector = GestureDetector()
    private var holdTimer: Timer?

    func start() {
        registerCombos()
        guard tap == nil, Permissions.accessibility || Permissions.inputMonitoring else { return }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        let me = Unmanaged.passUnretained(self).toOpaque()
        let options: CGEventTapOptions = Permissions.accessibility ? .defaultTap : .listenOnly
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: options,
                                           eventsOfInterest: CGEventMask(mask), callback: { _, type, event, ctx in
            let service = Unmanaged<HotkeyService>.fromOpaque(ctx!).takeUnretainedValue()
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            let synthetic = event.getIntegerValueField(.eventSourceUserData) == TapTypist.marker
            MainActor.assumeIsolated { service.handle(type, keyCode: keyCode, flags: flags, synthetic: synthetic) }
            return Unmanaged.passUnretained(event)
        }, userInfo: me) else {
            Log.app.error("Không tạo được event tap cho phím toàn cục")
            return
        }
        tap = port
        let src = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        Log.app.info("Phím toàn cục đã chạy (\(options == .defaultTap ? "Trợ năng" : "Giám sát đầu vào"))")
    }

    /// Nạp lại sau khi người dùng đổi phím.
    func reload() {
        holdTimer?.invalidate()
        detector = GestureDetector()
        registerCombos()
    }

    private func registerCombos() {
        for (i, action) in ShortcutAction.allCases.enumerated() {
            let id = UInt32(i + 1)
            if case .combo(let code, let mods, _) = ShortcutStore.shared.trigger(action) {
                ComboHotkeys.shared.register(id: id, keyCode: code, modifiers: mods) { [weak self] in
                    self?.onAction?(action, true)
                }
            } else {
                ComboHotkeys.shared.unregister(id)
            }
        }
    }

    private func handle(_ type: CGEventType, keyCode: Int64, flags: CGEventFlags, synthetic: Bool) {
        // Tự bật lại khi macOS tắt tap (chạy quá lâu hoặc người dùng nhập liệu đặc biệt).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        if synthetic {
            // Gõ đè nuốt phím người dùng ở đầu hàng (tap này ở cuối nên không thấy phím gốc) rồi phát
            // phím tổng hợp thay vào: đó vẫn là đang gõ, nên huỷ cử chỉ đang chờ. ⌥, gõ w (ra ư), ⌥
            // không được tính là chạm ⌥ hai lần.
            if type == .keyDown { dispatch(detector.otherInput()) }
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let events: [GestureDetector.Event]
        if type != .flagsChanged {
            events = detector.otherInput()
        } else if keyCode == 63 {
            events = detector.fn(down: flags.contains(.maskSecondaryFn))
        } else {
            events = detector.modifiers(Modifier.from(flags), at: now)
            scheduleHoldCheck()
        }
        dispatch(events)
    }

    private func scheduleHoldCheck() {
        holdTimer?.invalidate()
        guard detector.holdCandidate != nil else { return }
        holdTimer = Timer.scheduledTimer(withTimeInterval: GestureDetector.holdAfter, repeats: false) { _ in
            MainActor.assumeIsolated {
                self.dispatch(self.detector.holdCheck(at: ProcessInfo.processInfo.systemUptime))
            }
        }
    }

    private func dispatch(_ events: [GestureDetector.Event]) {
        let store = ShortcutStore.shared
        for event in events {
            let (trigger, began): (Trigger, Bool) = {
                switch event {
                case .fired(let t): return (t, true)
                case .holdBegan(let m): return (.hold(m), true)
                case .holdEnded(let m): return (.hold(m), false)
                }
            }()
            guard let action = ShortcutAction.allCases.first(where: { store.trigger($0) == trigger }) else { continue }
            onAction?(action, began)
        }
    }
}
