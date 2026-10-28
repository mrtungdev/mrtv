import AppKit
import SwiftUI

/// Nút đặt phím cho một việc, trông như nút chọn của macOS: hiện phím đang dùng; bấm để chọn kiểu
/// có sẵn, tự ghi tổ hợp, hoặc tắt.
struct ShortcutField: View {
    var action: ShortcutAction
    @ObservedObject var store: ShortcutStore
    @Binding var message: String?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        let trigger = store.trigger(action)
        Button { recording ? stopRecording() : showMenu() } label: {
            HStack(spacing: 6) {
                if recording {
                    Text("Bấm tổ hợp phím…").font(Fonts.text(12)).foregroundColor(Palette.accent)
                } else if trigger == .off {
                    Text("Tắt").font(Fonts.text(12)).foregroundColor(Palette.ink2)
                } else {
                    KeyCaps(caps: trigger.caps)
                }
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .bold)).foregroundColor(Palette.ink2)
            }
            .padding(.leading, 4).padding(.trailing, 7).frame(height: 26)
            .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Palette.raised))
            .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(recording ? Palette.accent : Palette.stroke, lineWidth: recording ? 1.5 : 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(action.title): \(trigger.spoken)")
        .onDisappear { stopRecording() }
    }

    private func showMenu() {
        let menu = NSMenu()
        let current = store.trigger(action)
        for preset in action.presets {
            let item = ClosureMenuItem(title: preset.spoken, key: "") { apply(preset) }
            item.attributedTitle = Self.title(preset)
            item.state = preset == current ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let custom = ClosureMenuItem(title: "Tự đặt tổ hợp phím…", key: "") { startRecording() }
        if case .combo = current { custom.state = .on }
        menu.addItem(custom)
        let off = ClosureMenuItem(title: "Tắt", key: "") { apply(.off) }
        off.state = current == .off ? .on : .off
        menu.addItem(off)
        if current != action.defaultTrigger {
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem(title: "Về mặc định (\(action.defaultTrigger.label))", key: "") { apply(action.defaultTrigger) })
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    /// "⌥⌥  Chạm ⌥ hai lần thật nhanh", kèm dòng lưu ý nhỏ khi phím dễ trùng ứng dụng khác.
    private static func title(_ trigger: Trigger) -> NSAttributedString {
        let out = NSMutableAttributedString(string: trigger.label, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)])
        out.append(NSAttributedString(string: "   \(trigger.spoken)", attributes: [.font: NSFont.menuFont(ofSize: 13)]))
        if let note = ShortcutStore.note(trigger) {
            out.append(NSAttributedString(string: "\n\(note)", attributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor,
            ]))
        }
        return out
    }

    private func apply(_ trigger: Trigger) {
        message = store.set(trigger, for: action)
    }

    private func startRecording() {
        message = nil
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = event.keyCode
            let flags = event.modifierFlags
            let chars = event.charactersIgnoringModifiers
            // Gọi trên luồng chính; NSEvent không Sendable nên chỉ đưa dữ liệu cần dùng vào.
            MainActor.assumeIsolated { record(code: code, flags: flags, chars: chars) }
            return nil
        }
    }

    private func record(code: UInt16, flags: NSEvent.ModifierFlags, chars: String?) {
        let mods = Modifier.from(flags.intersection(.deviceIndependentFlagsMask))
        if code == 53 && mods.isEmpty {
            stopRecording()
            return
        }
        let key = KeyNames.name(keyCode: code, characters: chars)
        let needsModifier = !KeyNames.isFunctionKey(code)
        if needsModifier && !mods.contains(where: { $0 != .shift }) {
            message = "Cần có ⌘, ⌃ hoặc ⌥ trong tổ hợp. Bấm esc để thôi."
            return
        }
        message = store.set(.combo(keyCode: code, modifiers: mods, key: key), for: action)
        stopRecording()
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}
