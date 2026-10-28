import AppKit
import SwiftUI

/// Màu của Mr TV, đúng bảng Token trên canvas thiết kế: nền và chữ theo kiểu macOS, một màu nhấn
/// thương hiệu. Mọi cặp chữ/nền đạt tương phản tối thiểu 4.5:1 ở cả sáng và tối.
enum Palette {
    // Chữ
    static let ink = dynamic(0x1D1D1F, dark: 0xF2F2F4)
    static let ink2 = dynamic(0x5F5F65, dark: 0xA3A3A9)
    /// Chỉ cho chữ gợi ý trong ô nhập và nút đang tắt.
    static let ink3 = dynamic(0x8A8A8F, dark: 0x6E6E73)
    // Nền
    static let window = dynamic(0xF4F4F6, dark: 0x1F1F21)
    static let sidebar = dynamic(0xE8E8EB, dark: 0x2A2A2D)
    /// Nền một nhóm cài đặt, một bảng.
    static let surface = dynamic(0xFFFFFF, dark: 0x2C2C2F)
    static let raised = dynamic(0xFFFFFF, dark: 0x3A3A3E)
    static let field = dynamic(0xFFFFFF, dark: 0x1C1C1E)
    static let line = dynamic(0x000000, 0.10, dark: 0xFFFFFF, 0.10)
    static let fill = dynamic(0x000000, 0.05, dark: 0xFFFFFF, 0.07)
    static let fill2 = dynamic(0x000000, 0.08, dark: 0xFFFFFF, 0.11)
    static let stroke = dynamic(0x000000, 0.16, dark: 0xFFFFFF, 0.14)
    // Thương hiệu: nhấn Mr TV cho control, trạng thái Việt và logo.
    static let accent = fixed(0x3B5BFF)
    static let electric = accent
    static let link = dynamic(0x3451E6, dark: 0x8FA2FF)
    static let selection = dynamic(0x3B5BFF, 0.12, dark: 0x5B7BFF, 0.22)
    // Nhóm việc
    static let fix = dynamic(0xE11D48, dark: 0xFB7185)
    static let write = dynamic(0x7C3AED, dark: 0xA78BFA)
    static let translate = dynamic(0x0E7490, dark: 0x22D3EE)
    static let transform = dynamic(0x475569, dark: 0x94A3B8)
    // Trạng thái
    static let ok = dynamic(0x1E7F37, dark: 0x4CC36A)
    static let bad = dynamic(0xC4262E, dark: 0xFF6B6B)
    static let warn = dynamic(0xA35200, dark: 0xFFB04D)
    static let warnBg = dynamic(0xFFF3E0, dark: 0xFFB04D, 0.12)
    static let warnLine = dynamic(0xA35200, 0.25, dark: 0xFFB04D, 0.30)
    // Phím
    static let key = dynamic(0xFFFFFF, dark: 0x3A3A3E)
    static let keyLine = dynamic(0x000000, 0.18, dark: 0xFFFFFF, 0.16)

    /// Ô màu của từng mục trên thanh bên Cài đặt: màu cố định, biểu tượng luôn trắng.
    enum Tile {
        static let blue = fixed(0x3B5BFF)
        static let violet = fixed(0x8A4FE0)
        static let teal = fixed(0x0E8F7E)
        static let graphite = fixed(0x6E6E73)
        static let gray = fixed(0x8E8E93)
    }

    static func fixed(_ v: UInt32, _ a: Double = 1) -> Color {
        Color(nsColor: nsHex(v, a))
    }

    static func nsHex(_ v: UInt32, _ a: Double = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: a)
    }

    private static func dynamic(_ light: UInt32, _ la: Double = 1, dark: UInt32, _ da: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? nsHex(dark, da) : nsHex(light, la)
        })
    }
}

/// Nhóm việc trong Bảng lệnh, quyết định màu.
enum ActionGroup: String, Codable, CaseIterable {
    case fix = "sua", write = "viet", translate = "dich", transform = "doi"
    /// Việc người dùng tự tạo.
    case mine = "cua_ban"

    var color: Color {
        switch self {
        case .fix: return Palette.fix
        case .write: return Palette.write
        case .translate: return Palette.translate
        case .transform: return Palette.transform
        case .mine: return Palette.accent
        }
    }

    var badge: Color { color }

    var title: String {
        switch self {
        case .fix: return "Sửa"
        case .write: return "Viết"
        case .translate: return "Dịch"
        case .transform: return "Đổi dạng chữ"
        case .mine: return "Của bạn"
        }
    }

    var symbol: String {
        switch self {
        case .fix: return "checkmark"
        case .write: return "pencil"
        case .translate: return "character.book.closed"
        case .transform: return "textformat"
        case .mine: return "star.fill"
        }
    }
}

/// Chữ của hệ thống (SF Pro, SF Mono). Thang chữ: 26 · 20 · 15 · 13 · 11.
enum Fonts {
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum Radius {
    static let key: CGFloat = 5
    static let control: CGFloat = 6
    static let card: CGFloat = 10
    static let window: CGFloat = 12
}

/// Đang chụp giao diện bằng `--snapshot`: lớp kính không vẽ được khi chụp ngoài màn hình,
/// nên thay bằng màu đặc gần đúng.
enum RenderMode {
    nonisolated(unsafe) static var snapshot = false
}

/// Nền kính: NSVisualEffectView, lên Liquid Glass trên macOS 26 trở lên.
struct GlassBackground: View {
    var material: NSVisualEffectView.Material = .popover
    var cornerRadius: CGFloat = Radius.window
    var tint: Color = Palette.window.opacity(0.6)

    var body: some View {
        if RenderMode.snapshot {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Palette.window)
        } else {
            ZStack {
                VisualEffect(material: material, cornerRadius: cornerRadius)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(tint)
            }
        }
    }
}

private struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            return glass
        }
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = cornerRadius
        v.layer?.masksToBounds = true
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: Thành phần dùng ở Cài đặt và Bắt đầu

/// Nhóm cài đặt kiểu System Settings: tiêu đề nhỏ viết hoa, hộp bo 10, các dòng cách nhau bằng `FormDivider`.
struct FormSection<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { SectionTitle(title) }
            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
        }
    }
}

/// Tiêu đề nhóm: 11, đậm, viết hoa, giãn chữ, màu phụ.
struct SectionTitle: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(Fonts.text(11, .semibold)).tracking(0.5).textCase(.uppercase)
            .foregroundColor(Palette.ink2).padding(.leading, 2)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Một dòng cài đặt: tên (13, đậm vừa), mô tả (11, màu phụ), điều khiển bên phải.
struct FormRow<Control: View>: View {
    var title: String
    var detail: String? = nil
    /// Mô tả là ví dụ phím gõ, viết bằng chữ đơn cách.
    var monoDetail = false
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Fonts.text(13, .medium)).foregroundColor(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail).font(monoDetail ? Fonts.mono(11) : Fonts.text(11)).foregroundColor(Palette.ink2)
                        .lineSpacing(1).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(minHeight: 40)
    }
}

/// Đường kẻ mảnh giữa các dòng trong một nhóm.
struct FormDivider: View {
    var body: some View {
        Rectangle().fill(Palette.line).frame(height: 0.5)
    }
}

/// Chú thích dưới một nhóm (11, màu phụ).
struct FormNote: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(Fonts.text(11)).foregroundColor(Palette.ink2).lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 2)
    }
}

/// Công tắc gốc của macOS, cỡ nhỏ, màu nhấn Mr TV.
struct FormSwitch: View {
    var label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn).toggleStyle(.switch).labelsHidden().controlSize(.small).tint(Palette.accent)
    }
}

/// Băng báo ở đầu trang khi có việc cần sửa để gõ được: đúng một nút sửa.
struct Banner<Action: View>: View {
    var title: String
    var detail: String
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 16, weight: .medium)).foregroundColor(Palette.warn)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Fonts.text(13, .semibold)).foregroundColor(Palette.ink)
                Text(detail).font(Fonts.text(11)).foregroundColor(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            action()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.warnBg))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.warnLine, lineWidth: 0.5))
    }
}

/// Trạng thái ngắn bên phải một dòng: dấu tích xanh "Đang dùng", hay chữ phụ "Không cần".
struct StatusLabel: View {
    enum Kind { case ok, muted }
    var kind: Kind
    var text: String

    var body: some View {
        HStack(spacing: 5) {
            if kind == .ok { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
            Text(text).font(Fonts.text(13))
        }
        .foregroundColor(kind == .ok ? Palette.ok : Palette.ink2)
        .fixedSize()
    }
}

/// Ô màu nhỏ chứa biểu tượng trắng, như trên thanh bên Cài đặt.
struct IconTile: View {
    var symbol: String
    var color: Color
    var size: CGFloat = 20
    var glyph: Color = .white
    /// Chữ thay cho biểu tượng, ví dụ "⌘".
    var text: String? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(label)
    }

    @ViewBuilder private var label: some View {
        if let text {
            Text(text).font(Fonts.text(size * 0.62, .medium)).foregroundColor(glyph)
        } else {
            Image(systemName: symbol).font(.system(size: size * 0.55, weight: .medium)).foregroundColor(glyph)
        }
    }
}

/// Logo Mr TV: chữ V có dấu sắc trên ô xanh, một dấu cho mọi chỗ (khung 64×64 như canvas).
struct MrTVLogo: View {
    var size: CGFloat = 44
    var round = false
    var background = Palette.accent
    var ink = Color.white
    var accent = Color.white

    var body: some View {
        let k = size / 64
        let small = size < 24
        ZStack {
            RoundedRectangle(cornerRadius: (round ? 32 : 15) * k, style: .continuous).fill(background)
            Path { p in
                p.move(to: CGPoint(x: (small ? 17 : 19) * k, y: (small ? 22 : 24) * k))
                p.addLine(to: CGPoint(x: 32 * k, y: (small ? 48 : 47) * k))
                p.addLine(to: CGPoint(x: (small ? 47 : 45) * k, y: (small ? 22 : 24) * k))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: (small ? 10 : 7) * k, lineCap: .round, lineJoin: .round))
            if !small {
                Path { p in
                    p.move(to: CGPoint(x: 35 * k, y: 16 * k)); p.addLine(to: CGPoint(x: 43 * k, y: 9 * k))
                }
                .stroke(accent, style: StrokeStyle(lineWidth: 5 * k, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Mr TV")
    }
}

/// Phím như trên bàn phím Mac.
struct KeyCap: View {
    var label: String
    var big = false

    var body: some View {
        Text(label)
            .font(Fonts.text(big ? 15 : 11, .medium))
            .foregroundColor(Palette.ink)
            .padding(.horizontal, big ? 10 : 5)
            .frame(minWidth: big ? 40 : 20, minHeight: big ? 36 : 20)
            .background(RoundedRectangle(cornerRadius: big ? 7 : Radius.key, style: .continuous).fill(Palette.key))
            .overlay(RoundedRectangle(cornerRadius: big ? 7 : Radius.key, style: .continuous).strokeBorder(Palette.keyLine, lineWidth: 0.5))
            .background(RoundedRectangle(cornerRadius: big ? 7 : Radius.key, style: .continuous)
                .fill(Color.black.opacity(0.12)).offset(y: big ? 1.5 : 1))
            .fixedSize()
    }
}

/// Dãy phím của một tổ hợp, ví dụ ⌥ ⌥ hay ⌘ Z.
struct KeyCaps: View {
    var caps: [String]
    var big = false

    var body: some View {
        HStack(spacing: big ? 6 : 3) {
            ForEach(Array(caps.enumerated()), id: \.offset) { _, c in KeyCap(label: c, big: big) }
        }
    }
}

/// Ô tìm gốc của macOS (NSSearchField).
struct SearchField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String
    var small = false

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.sendsSearchStringImmediately = true
        field.controlSize = small ? .small : .regular
        field.font = .systemFont(ofSize: small ? NSFont.smallSystemFontSize : NSFont.systemFontSize)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ note: Notification) {
            if let field = note.object as? NSSearchField { text.wrappedValue = field.stringValue }
        }
    }
}

/// Liên kết dạng chữ, mở trong trình duyệt hay ứng dụng khác.
struct InlineLink: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) { Text(title).foregroundColor(Palette.link) }
            .buttonStyle(.plain)
            .onHover { inside in inside ? NSCursor.pointingHand.push() : NSCursor.pop() }
    }
}

// MARK: Thành phần của thanh gợi ý và Việc của bạn (đang tạm ngừng)

/// Chọn một trong vài lựa chọn.
struct SegControl<Value: Hashable>: View {
    @Binding var selection: Value
    var options: [(Value, String)]
    var size: CGFloat = 12
    var fill = false
    var height: CGFloat = 22

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let (value, title) = options[i]
                let on = value == selection
                Button { selection = value } label: {
                    Text(title)
                        .font(Fonts.text(size, on ? .medium : .regular))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .frame(maxWidth: fill ? .infinity : nil, minHeight: height - 4)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(on ? Palette.raised : .clear)
                            .shadow(color: .black.opacity(on ? 0.15 : 0), radius: 1, y: 0.5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Palette.fill))
        .fixedSize(horizontal: !fill, vertical: true)
    }
}

/// Cỡ nút: nhỏ 22 (trong Cài đặt), vừa 28, lớn 32 (cuối Bảng lệnh).
enum ButtonSize {
    case small, medium, large

    var height: CGFloat { self == .small ? 22 : self == .medium ? 28 : 32 }
    var font: CGFloat { 13 }
}

/// Nút chính: nền nhấn Mr TV, chữ trắng.
struct PrimaryButtonStyle: ButtonStyle {
    var size: ButtonSize = .small
    /// Giãn hết chiều ngang (nút cuối bảng lệnh).
    var fill = false
    @Environment(\.isEnabled) private var enabled

    init(size: ButtonSize = .small, fill: Bool = false) {
        self.size = size
        self.fill = fill
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fonts.text(size.font, size == .large ? .semibold : .medium))
            .foregroundColor(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: size.height)
            .background(RoundedRectangle(cornerRadius: size == .large ? 8 : Radius.control, style: .continuous).fill(Palette.accent))
            .opacity(!enabled ? 0.45 : configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}

/// Nút phụ: nền control, viền mảnh.
struct SecondaryButtonStyle: ButtonStyle {
    var size: ButtonSize = .small
    var destructive = false
    @Environment(\.isEnabled) private var enabled

    init(size: ButtonSize = .small, destructive: Bool = false) {
        self.size = size
        self.destructive = destructive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fonts.text(size.font))
            .foregroundColor(destructive ? Palette.bad : Palette.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12)
            .frame(minHeight: size.height)
            .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Palette.raised))
            .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 0.5))
            .opacity(!enabled ? 0.45 : configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// Ô nhập chữ không viền. Khi chụp giao diện thì vẽ bằng Text.
struct PlainField: View {
    var placeholder: String
    @Binding var text: String
    var font: Font
    var onSubmit: () -> Void = {}

    var body: some View {
        if RenderMode.snapshot {
            Text(text.isEmpty ? placeholder : text).font(font)
                .foregroundColor(text.isEmpty ? Palette.ink3 : Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(placeholder, text: $text).textFieldStyle(.plain).font(font).onSubmit(onSubmit)
        }
    }
}

/// Khung ô nhập chữ: nền ô nhập, viền mảnh.
extension View {
    func fieldBox(height: CGFloat = 24) -> some View {
        padding(.horizontal, 7)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Palette.field))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 0.5))
    }
}

/// Nút chỉ có biểu tượng (sửa, xoá).
struct IconButton: View {
    var symbol: String
    var help: String
    var destructive = false
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium))
                .foregroundColor(destructive && hover ? Palette.bad : Palette.ink2)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(hover ? Palette.fill2 : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hover = $0 }
    }
}

/// Viên chữ: bấm để bật/tắt, hoặc có nút × để bỏ.
struct WordChip: View {
    var text: String
    var on = true
    var removable = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(text).font(Fonts.mono(12)).strikethrough(!on, color: Palette.ink3)
                    .foregroundColor(on ? Palette.ink : Palette.ink3).lineLimit(1)
                if removable {
                    Image(systemName: "xmark").font(.system(size: 8.5, weight: .bold)).foregroundColor(Palette.ink2)
                }
            }
            .padding(.horizontal, 10).frame(height: 24)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(on ? Palette.fill2 : Color.clear))
            .overlay(Capsule().strokeBorder(on ? Color.clear : Palette.stroke, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Lưới viên chữ tự xuống dòng (LazyVGrid có trên macOS 11; `Layout` cần macOS 13).
struct ChipGrid<Item: Hashable, Chip: View>: View {
    var items: [Item]
    var minWidth: CGFloat = 78
    @ViewBuilder var chip: (Item) -> Chip

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { chip($0) }
        }
    }
}

/// Đường kẻ mảnh, tên cũ của `FormDivider`.
typealias RowDivider = FormDivider

extension Bundle {
    var shortVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    var buildNumber: String { object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
}
