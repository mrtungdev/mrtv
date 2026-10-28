import AppKit
import Combine
import SwiftUI

/// Bắt đầu, 3 bước: chọn kiểu gõ (gõ thử ngay) → bật Mr TV → hai phím cần nhớ.
/// Đóng cửa sổ lúc nào cũng được: coi như đã xong, việc còn thiếu được nhắc ở Cài đặt.
@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    static let shared = OnboardingWindowController()
    static let size = CGSize(width: 640, height: 500)

    private init() {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.size),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: true)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.title = "Bắt đầu với Mr TV"
        window.backgroundColor = NSColor(Palette.window)
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(rootView: OnboardingView(model: AppModel.shared) { [weak self] in
            self?.close()
        })
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppModel.shared.onboardingDone = true
    }
}

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    var finish: () -> Void
    @State private var step: Int
    @State private var trial: String
    @State private var setup = SetupState.current

    /// Đọc lại bộ gõ và quyền: người dùng cấp quyền ở Cài đặt hệ thống khi cửa sổ này đang mở.
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    init(model: AppModel, step: Int = 1, trial: String = "", finish: @escaping () -> Void) {
        self.model = model
        self.finish = finish
        _step = State(initialValue: step)
        _trial = State(initialValue: trial)
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 40).padding(.top, 36)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .frame(width: OnboardingWindowController.size.width, height: OnboardingWindowController.size.height)
        .background(Palette.window)
        .foregroundColor(Palette.ink)
        .font(Fonts.text(13))
        .ignoresSafeArea(.container, edges: .top)
        .onReceive(timer) { _ in reload() }
    }

    private func reload() {
        let now = SetupState.current
        if now != setup { setup = now }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 1: MethodStep(model: model, trial: $trial)
        case 2: EnableStep(setup: setup, reload: reload)
        default: DoneStep()
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step == 1 {
                Button("Để sau", action: finish).buttonStyle(.borderless).foregroundColor(Palette.link)
            } else {
                Button("Quay lại") { step -= 1 }
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { n in
                    Capsule().fill(n == step ? Palette.accent : Palette.fill2).frame(width: n == step ? 16 : 6, height: 6)
                }
            }
            .animation(.easeOut(duration: 0.2), value: step)
            .accessibilityLabel("Bước \(step) trên 3")
            Spacer()
            Button(step == 3 ? "Bắt đầu gõ" : "Tiếp tục") {
                if step == 3 { finish() } else { step += 1 }
            }
            .buttonStyle(PrimaryButtonStyle(size: .medium))
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .overlay(FormDivider(), alignment: .top)
    }
}

/// Logo, "Bước n / 3" và tiêu đề lớn của một bước.
private struct StepHeader: View {
    var step: Int
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bước \(step) / 3").font(Fonts.text(11)).foregroundColor(Palette.ink2)
                    Text(title).font(Fonts.text(26, .semibold)).accessibilityAddTraits(.isHeader)
                }
            }
            if let subtitle {
                Text(subtitle).font(Fonts.text(13)).foregroundColor(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: Bước 1 · Kiểu gõ

private struct MethodStep: View {
    @ObservedObject var model: AppModel
    @Binding var trial: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(step: 1, title: "Bạn quen gõ kiểu nào?")
            FormSection {
                option(.telex, detail: "Dùng chữ cái để bỏ dấu. Không chắc thì chọn kiểu này.", sample: "tieesng → tiếng")
                FormDivider()
                option(.simpleTelex, detail: "Như Telex, nhưng w đứng một mình không thành ư.", sample: "w → w")
                FormDivider()
                option(.vni, detail: "Dùng phím số 1–9 để bỏ dấu.", sample: "tie61ng → tiếng")
            }
            HStack {
                Text("Đặt dấu").font(Fonts.text(13, .medium))
                Spacer()
                Picker("Đặt dấu", selection: $model.engine.toneStyle) {
                    Text("hoà · mới").tag(EngineSettings.ToneStyle.new)
                    Text("hòa · cũ").tag(EngineSettings.ToneStyle.old)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Gõ thử ở đây").font(Fonts.text(13, .medium))
                HStack(spacing: 10) {
                    TextField(placeholder, text: $trial).font(Fonts.mono(12)).textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                    Image(systemName: "arrow.right").foregroundColor(Palette.ink2).accessibilityHidden(true)
                    Text(trial.isEmpty ? " " : TypingEngine.typed(trial, model.engine))
                        .font(Fonts.text(15, .semibold)).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Mr TV viết ra")
                }
            }
        }
    }

    private var placeholder: String {
        model.engine.method == .vni ? "tie61ng Vie65t, go4 la2 d9u1ng" : "tieesng Vieejt, gox laf ddusng"
    }

    private func option(_ method: EngineSettings.Method, detail: String, sample: String) -> some View {
        let on = model.engine.method == method
        return Button { model.engine.method = method } label: {
            HStack(spacing: 12) {
                Circle().strokeBorder(on ? Palette.accent : Palette.stroke, lineWidth: on ? 5 : 1)
                    .background(Circle().fill(on ? Color.white : Palette.field))
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.title).font(Fonts.text(13, .semibold))
                    Text(detail).font(Fonts.text(11)).foregroundColor(Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(sample).font(Fonts.mono(12)).foregroundColor(Palette.ink2)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}

// MARK: Bước 2 · Bật Mr TV

private struct EnableStep: View {
    var setup: SetupState
    var reload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(step: 2, title: "Bật Mr TV",
                       subtitle: "macOS cần bạn đồng ý một lần. Mr TV không gửi đi và không lưu những gì bạn gõ.")
            FormSection {
                item(1, done: setup.source == .ready, title: "Dùng bộ gõ Mr TV",
                     detail: setup.source == .ready ? "Đã thêm vào máy và đang dùng." : "macOS sẽ hỏi một lần, chọn Cho phép.") {
                    InputSourceButton(status: setup.source, onChange: reload)
                }
                FormDivider()
                item(2, done: setup.accessibility, title: "Cấp quyền Trợ năng",
                     detail: "Để gõ ở Chrome, VS Code, Terminal và đọc chữ đang bôi đen. Mr TV mở sẵn đúng chỗ, bạn chỉ cần bật Mr TV:",
                     path: setup.accessibility ? nil : "Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Trợ năng") {
                    if setup.accessibility {
                        StatusLabel(kind: .ok, text: "Xong")
                    } else {
                        Button("Cấp quyền…") { Permissions.askAccessibility() }.buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            FormNote("Mỗi dòng tự chuyển sang Xong khi bạn bật, không cần mở lại Mr TV. Chưa tiện thì để sau: Mr TV nhắc lại ở Cài đặt › Chung.")
        }
    }

    private func item<Accessory: View>(_ n: Int, done: Bool, title: String, detail: String, path: String? = nil,
                                      @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                if done {
                    Circle().fill(Palette.ok)
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                } else {
                    Circle().strokeBorder(Palette.accent, lineWidth: 1.5)
                    Text("\(n)").font(Fonts.text(12, .semibold)).foregroundColor(Palette.accent)
                }
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Fonts.text(13, .semibold))
                Text(detail).font(Fonts.text(11)).foregroundColor(Palette.ink2).fixedSize(horizontal: false, vertical: true)
                if let path { Text(path).font(Fonts.text(11, .medium)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            accessory()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(done ? "\(title), xong" : title)
    }
}

// MARK: Bước 3 · Xong

private struct DoneStep: View {
    @ObservedObject private var store = ShortcutStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(step: 3, title: "Xong rồi. Gõ thôi!", subtitle: "Hai phím là đủ dùng. Muốn đổi phím: Cài đặt › Phím.")
            HStack(alignment: .top, spacing: 12) {
                card(store.trigger(.toggle), title: "Đổi Việt ⇄ Anh",
                     detail: "Mr TV nhớ riêng cho từng ứng dụng: Slack tiếng Việt, VS Code tiếng Anh.")
                card(store.trigger(.mrtv), title: "Mở Bảng lệnh",
                     detail: "Sửa chữ lỗi font, bỏ dấu, chuyển ngược… trên chữ đang bôi đen. Gõ ? trong bảng để xem hướng dẫn.")
            }
            .fixedSize(horizontal: false, vertical: true)
            if store.trigger(.toggle) == .fn {
                HStack(spacing: 12) {
                    Image(systemName: "globe").font(.system(size: 16)).foregroundColor(Palette.ink2)
                    Text("Để fn chỉ đổi Việt ⇄ Anh, đặt phím địa cầu thành “Không làm gì”.").font(Fonts.text(12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Mở cài đặt Bàn phím…") { InputSourceInstaller.openKeyboardSettings() }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
            }
        }
    }

    private func card(_ trigger: Trigger, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if trigger == .off {
                Text("Chưa đặt phím").font(Fonts.text(13)).foregroundColor(Palette.ink2).frame(height: 36)
            } else {
                KeyCaps(caps: trigger.caps, big: true)
            }
            Text(title).font(Fonts.text(15, .semibold))
            Text(detail).font(Fonts.text(12)).foregroundColor(Palette.ink2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
    }
}
