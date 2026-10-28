import AppKit
@preconcurrency import InputMethodKit

// Tiến trình bộ gõ: chỉ có IMKServer, không có cửa sổ.
runSelfTestIfAsked("Bộ gõ Mr TV")
let connection = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String ?? "dev.mrtung.inputmethod.mrtv_Connection"
let server = IMKServer(name: connection, bundleIdentifier: Bundle.main.bundleIdentifier)
MainActor.assumeIsolated {
    InputMethodState.shared.start()
}
Log.input.info("Bộ gõ Mr TV đã chạy")
NSApplication.shared.run()
