import AppKit
import Combine
import SwiftUI

/// Năm mục cài đặt. Mỗi cài đặt nằm đúng một chỗ; menu trên thanh menu chỉ là lối tắt.
enum SettingsPane: String, CaseIterable, Identifiable {
    case typing, macros, apps, keys, general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .typing: return "Gõ chữ"
        case .macros: return "Gõ tắt"
        case .apps: return "Ứng dụng"
        case .keys: return "Phím"
        case .general: return "Chung"
        }
    }

    var symbol: String {
        switch self {
        case .typing: return "keyboard"
        case .macros: return "text.append"
        case .apps: return "square.grid.2x2"
        case .keys: return "command"
        case .general: return "gearshape"
        }
    }

    var color: Color {
        switch self {
        case .typing: return Palette.Tile.blue
        case .macros: return Palette.Tile.violet
        case .apps: return Palette.Tile.teal
        case .keys: return Palette.Tile.graphite
        case .general: return Palette.Tile.gray
        }
    }
}

enum SettingsLayout {
    static let size = CGSize(width: 715, height: 600)
    static let minSize = CGSize(width: 680, height: 520)
    static let sidebarWidth: CGFloat = 200
    /// Cao của thanh tiêu đề (thanh công cụ kiểu unified), để ba nút cửa sổ nằm giữa.
    static let titleBar: CGFloat = 52
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()
    let router = SettingsRouter()

    private init() {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: SettingsLayout.size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: true)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Cài đặt Mr TV"
        // Thanh công cụ rỗng kiểu unified: thanh tiêu đề cao 52, ba nút cửa sổ nằm trên thanh bên.
        window.toolbar = NSToolbar(identifier: "settings")
        window.toolbarStyle = .unified
        window.contentMinSize = SettingsLayout.minSize
        window.contentView = NSHostingView(rootView: SettingsView(router: router, model: AppModel.shared))
        window.center()
        window.setFrameAutosaveName("MrTVSettings")
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func show(_ pane: SettingsPane? = nil) {
        if let pane { router.go(pane) }
        router.tick += 1
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
final class SettingsRouter: ObservableObject {
    @Published private(set) var pane: SettingsPane = .typing
    @Published var search = ""
    /// Tăng mỗi lần mở cửa sổ, để đọc lại trạng thái bộ gõ và quyền.
    @Published var tick = 0
    /// Đang mở sheet Từ tiếng Anh.
    @Published var englishSheet = false
    private var back: [SettingsPane] = []
    private var forward: [SettingsPane] = []

    var canGoBack: Bool { !back.isEmpty }
    var canGoForward: Bool { !forward.isEmpty }

    func go(_ next: SettingsPane) {
        guard next != pane else { return }
        back.append(pane)
        forward.removeAll()
        pane = next
    }

    func goBack() {
        guard let last = back.popLast() else { return }
        forward.append(pane)
        pane = last
    }

    func goForward() {
        guard let next = forward.popLast() else { return }
        back.append(pane)
        pane = next
    }
}

/// Bộ gõ, quyền và chế độ nhập bảo mật: đọc lại vài giây một lần khi cửa sổ đang mở, vì người dùng
/// cấp quyền trong Cài đặt hệ thống mà không quay lại bấm gì.
struct SetupState: Equatable {
    var source: InputSourceInstaller.Status
    var accessibility: Bool
    var inputMonitoring: Bool
    var blocker: String?

    static var current: SetupState {
        SetupState(source: InputSourceInstaller.status, accessibility: Permissions.accessibility,
                   inputMonitoring: Permissions.inputMonitoring, blocker: Permissions.secureInputApp)
    }

    /// Có việc cần sửa: hiện băng báo và chấm trên mục Chung.
    var needsAttention: Bool { source != .ready || !accessibility || blocker != nil }
}

struct SettingsView: View {
    @ObservedObject var router: SettingsRouter
    @ObservedObject var model: AppModel
    @State private var setup = SetupState.current
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(router: router, setup: setup)
                .frame(width: SettingsLayout.sidebarWidth)
            Rectangle().fill(Palette.line).frame(width: 0.5)
            VStack(spacing: 0) {
                header
                Rectangle().fill(Palette.line).frame(height: 0.5)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SetupBanner(setup: setup, refresh: reload)
                        PaneContent(pane: router.pane, model: model, router: router, setup: setup, refresh: reload)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 20)
                    .frame(maxWidth: 620, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .background(Palette.window)
        }
        .font(Fonts.text(13))
        .foregroundColor(Palette.ink)
        .ignoresSafeArea(.container, edges: .top)
        .onReceive(timer) { _ in reload() }
        .onChange(of: router.tick) { _ in reload() }
    }

    private var header: some View {
        HStack(spacing: 2) {
            Button { router.goBack() } label: { Image(systemName: "chevron.left").frame(width: 26, height: 24) }
                .disabled(!router.canGoBack).help("Quay lại")
            Button { router.goForward() } label: { Image(systemName: "chevron.right").frame(width: 26, height: 24) }
                .disabled(!router.canGoForward).help("Tiến tới")
            Text(router.pane.title).font(Fonts.text(15, .semibold)).padding(.leading, 6)
                .accessibilityAddTraits(.isHeader)
            Spacer()
        }
        .buttonStyle(.borderless)
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 14)
        .frame(height: SettingsLayout.titleBar)
    }

    private func reload() {
        let now = SetupState.current
        if now != setup { setup = now }
    }
}

/// Thanh bên: ô tìm, năm mục. Đang tìm thì hiện từng cài đặt khớp, kèm tên mục chứa nó.
struct SettingsSidebar: View {
    @ObservedObject var router: SettingsRouter
    var setup: SetupState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Chỗ cho ba nút cửa sổ.
            Spacer().frame(height: SettingsLayout.titleBar - 6)
            SearchField(placeholder: "Tìm", text: $router.search)
                .frame(height: 24)
                .padding(.bottom, 10)
            if let results = SettingsSearch.find(router.search) {
                searchResults(results)
            } else {
                ForEach(SettingsPane.allCases) { pane in
                    row(pane, title: pane.title, alert: pane == .general && setup.needsAttention)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SidebarMaterial())
    }

    private func row(_ pane: SettingsPane, title: String, subtitle: String? = nil, alert: Bool = false) -> some View {
        let on = router.pane == pane && subtitle == nil
        return Button { router.go(pane) } label: {
            HStack(spacing: 8) {
                IconTile(symbol: pane.symbol, color: pane.color)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.white.opacity(on ? 0.4 : 0), lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(Fonts.text(13)).lineLimit(subtitle == nil ? 1 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle).font(Fonts.text(11)).foregroundColor(on ? .white.opacity(0.85) : Palette.ink2).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if alert {
                    Circle().fill(Palette.warn).frame(width: 7, height: 7).accessibilityLabel("Cần chú ý")
                }
            }
            .foregroundColor(on ? .white : Palette.ink)
            .padding(.horizontal, 6).frame(minHeight: 28)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(on ? Palette.accent : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func searchResults(_ results: [SettingsSearch.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(results.isEmpty ? "Không thấy cài đặt nào" : "\(results.count) kết quả")
                .font(Fonts.text(11)).foregroundColor(Palette.ink2).padding(.horizontal, 6).padding(.bottom, 4)
            ForEach(results.prefix(12)) { entry in
                row(entry.pane, title: entry.title, subtitle: entry.pane.title)
            }
        }
    }
}

/// Nền thanh bên: vật liệu sidebar của macOS (khi chụp giao diện thì dùng màu đặc).
private struct SidebarMaterial: View {
    var body: some View {
        if RenderMode.snapshot {
            Palette.sidebar
        } else {
            SidebarEffect()
        }
    }
}

private struct SidebarEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Băng báo ở đầu mọi trang khi Mr TV chưa gõ được ở đâu đó. Mỗi lúc chỉ báo việc quan trọng nhất.
struct SetupBanner: View {
    var setup: SetupState
    var refresh: () -> Void

    var body: some View {
        if let blocker = setup.blocker {
            Banner(title: "\(blocker) đang chặn bộ gõ",
                   detail: "macOS chặn mọi bộ gõ khi đang nhập mật khẩu. Rời ô mật khẩu là gõ lại được.") { EmptyView() }
        } else if setup.source != .ready {
            Banner(title: setup.source.problem,
                   detail: "Chưa dùng bộ gõ Mr TV thì gõ phím nào cũng ra chữ không dấu.") {
                InputSourceButton(status: setup.source, onChange: refresh)
            }
        } else if !setup.accessibility {
            Banner(title: "Mr TV chưa có quyền Trợ năng",
                   detail: "Chưa gõ được ở Chrome, VS Code, Terminal và chưa đọc được chữ đang bôi đen.") {
                Button("Cấp quyền…") { Permissions.askAccessibility() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

/// Nút sửa bộ gõ ngay tại chỗ: cài, bật hoặc dùng bộ gõ Mr TV.
struct InputSourceButton: View {
    var status: InputSourceInstaller.Status
    var onChange: () -> Void
    @State private var error: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            switch status {
            case .ready: StatusLabel(kind: .ok, text: "Đang dùng")
            case .notSelected: Button("Dùng bộ gõ Mr TV") { act { _ = InputSourceInstaller.select() } }.buttonStyle(PrimaryButtonStyle())
            case .notEnabled: Button("Bật bộ gõ…") { act { try InputSourceInstaller.installAndSelect() } }.buttonStyle(PrimaryButtonStyle())
            case .notInstalled: Button("Cài bộ gõ") { act { try InputSourceInstaller.installAndSelect() } }.buttonStyle(PrimaryButtonStyle())
            }
            if let error {
                Text(error).font(Fonts.text(11)).foregroundColor(Palette.bad).multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func act(_ body: () throws -> Void) {
        do {
            try body()
            error = nil
        } catch {
            self.error = "Không cài được: \(error.localizedDescription)"
        }
        // macOS cần một chút để đổi bộ gõ; đọc lại sau đó.
        onChange()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onChange() }
    }
}
