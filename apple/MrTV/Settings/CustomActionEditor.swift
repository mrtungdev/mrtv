import AppKit
import SwiftUI

/// Nhóm "Việc của bạn" trong Cài đặt › Thanh gợi ý: danh sách việc tự tạo, mẫu thêm nhanh, và trình soạn.
struct CustomActionsSection: View {
    @ObservedObject var model: AppModel
    @State private var draft: CustomAction?
    @State private var isNew = false

    /// Chỉ dùng khi chụp giao diện: mở sẵn trình soạn với việc này.
    nonisolated(unsafe) static var snapshotDraft: CustomAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Việc của bạn · \(model.customActions.count)").font(Fonts.text(12, .heavy)).foregroundColor(Palette.ink2)
                Spacer()
                if draft == nil {
                    Button("Tự tạo việc…") { start(CustomAction(name: "", kind: .template, value: "“{chữ}”"), new: true) }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 6)
            if let current = draft ?? (RenderMode.snapshot ? Self.snapshotDraft : nil) {
                CustomActionEditor(draft: current, isNew: isNew || draft == nil) { saved in
                    model.save(saved)
                    draft = nil
                } cancel: {
                    draft = nil
                }
                .id(current.id)
            }
            VStack(spacing: 0) {
                ForEach(Array(model.customActions.enumerated()), id: \.element.id) { i, action in
                    if i > 0 { RowDivider() }
                    HStack(spacing: 10) {
                        IconTile(symbol: action.kind.symbol, color: ActionGroup.mine.color, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(action.name).font(Fonts.text(13, .bold)).foregroundColor(Palette.ink)
                            Text("\(action.kind.title) · \(action.summary)").font(Fonts.text(11.5)).foregroundColor(Palette.ink2)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        IconButton(symbol: "pencil", help: "Sửa") { start(action, new: false) }
                        IconButton(symbol: "trash", help: "Xoá", destructive: true) { model.delete(action) }
                    }
                    .frame(minHeight: 50)
                }
                if model.customActions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tự tạo việc cho thanh gợi ý: ghép mẫu chữ, thay chữ, mở trang web với đoạn đang bôi đen, chạy một phím tắt của ứng dụng Phím tắt (Shortcuts) hay một câu lệnh.")
                            .font(Fonts.text(12)).foregroundColor(Palette.ink2).fixedSize(horizontal: false, vertical: true)
                        Text("Thêm nhanh").font(Fonts.text(11, .heavy)).foregroundColor(Palette.ink3)
                        ChipGrid(items: CustomAction.presets.map(\.name), minWidth: 104) { name in
                            WordChip(text: name) {
                                if var preset = CustomAction.presets.first(where: { $0.name == name }) {
                                    preset.id = "custom." + UUID().uuidString
                                    model.save(preset)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.surface))
        }
    }

    private func start(_ action: CustomAction, new: Bool) {
        isNew = new
        draft = action
    }
}

/// Soạn một việc tự tạo, có phần "Thử với" để xem kết quả trước khi lưu.
struct CustomActionEditor: View {
    @State var draft: CustomAction
    var isNew: Bool
    var save: (CustomAction) -> Void
    var cancel: () -> Void
    @State private var sample = "xin chào Việt Nam"
    @State private var trial: String?
    @State private var running = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isNew ? "Việc mới" : "Sửa “\(draft.name)”").font(Fonts.text(14, .heavy)).foregroundColor(Palette.ink)
            labeled("Tên trên thanh gợi ý") {
                PlainField(placeholder: "Ví dụ: Ngoặc kép, Tìm Google", text: $draft.name, font: Fonts.text(13)).fieldBox(height: 32)
            }
            labeled("Loại") {
                SegControl(selection: $draft.kind, options: CustomAction.Kind.allCases.map { ($0, $0.title) }, size: 11, fill: true)
            }
            fields
            if draft.kind != .link {
                labeled("Kết quả") {
                    SegControl(selection: $draft.output, options: [(.replace, "Thay vào đoạn đang chọn"), (.copy, "Chép vào clipboard")],
                               size: 11.5, fill: true)
                }
            }
            labeled("Hiện khi bôi đen") { WhenPicker(when: $draft.when) }
            tryBox
            HStack(spacing: 8) {
                if let problem = draft.problem {
                    Text(problem).font(Fonts.text(11.5, .semibold)).foregroundColor(Palette.bad).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Huỷ", action: cancel).buttonStyle(SecondaryButtonStyle())
                Button(isNew ? "Thêm việc" : "Lưu") { save(draft) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(draft.problem != nil)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.electric, lineWidth: 1.5))
        .onChange(of: draft) { _ in trial = nil }
    }

    @ViewBuilder private var fields: some View {
        switch draft.kind {
        case .template:
            labeled("Mẫu", hint: "\(CustomAction.placeholder) là đoạn đang bôi đen. Ví dụ: “{chữ}”, **{chữ}**, Kính gửi {chữ},") {
                PlainField(placeholder: "“{chữ}”", text: $draft.value, font: Fonts.mono(12.5)).fieldBox(height: 32)
            }
        case .replace:
            HStack(spacing: 8) {
                labeled("Tìm") { PlainField(placeholder: "ko", text: $draft.find, font: Fonts.mono(12.5)).fieldBox(height: 32) }
                labeled("Thay bằng") { PlainField(placeholder: "không", text: $draft.value, font: Fonts.mono(12.5)).fieldBox(height: 32) }
            }
        case .link:
            labeled("Địa chỉ", hint: "\(CustomAction.placeholder) được thay bằng đoạn đang bôi đen.") {
                PlainField(placeholder: "https://www.google.com/search?q={chữ}", text: $draft.value, font: Fonts.mono(12)).fieldBox(height: 32)
            }
        case .shortcut:
            labeled("Tên phím tắt", hint: "Đoạn đang bôi đen là đầu vào; kết quả của phím tắt thay vào chữ hoặc chép lại.") {
                HStack(spacing: 8) {
                    PlainField(placeholder: "Tên trong ứng dụng Phím tắt", text: $draft.value, font: Fonts.text(13)).fieldBox(height: 32)
                    Button("Chọn…") { pickShortcut() }.buttonStyle(SecondaryButtonStyle())
                }
            }
        case .shell:
            labeled("Lệnh", hint: "Chạy bằng zsh. Đoạn đang bôi đen đưa vào stdin, kết quả lấy từ stdout. Ví dụ: tr a-z A-Z") {
                PlainField(placeholder: "wc -w", text: $draft.value, font: Fonts.mono(12.5)).fieldBox(height: 32)
            }
        }
    }

    private var tryBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Thử với").font(Fonts.text(11.5, .heavy)).foregroundColor(Palette.ink2)
            HStack(spacing: 8) {
                PlainField(placeholder: "Gõ một đoạn để thử", text: $sample, font: Fonts.text(12.5)).fieldBox(height: 30)
                if draft.runsExternally {
                    Button(running ? "Đang chạy…" : "Chạy thử") { runTrial() }
                        .buttonStyle(SecondaryButtonStyle()).disabled(running || draft.problem != nil)
                }
            }
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "arrow.turn.down.right").font(.system(size: 11, weight: .semibold)).foregroundColor(Palette.ink3)
                Text(result).font(Fonts.text(12.5, .semibold)).foregroundColor(Palette.ink).lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.fill))
    }

    private var result: String {
        if let trial { return trial }
        switch draft.kind {
        case .template, .replace: return draft.apply(sample) ?? "…"
        case .link: return draft.linkURL(for: sample)?.absoluteString ?? "Địa chỉ chưa hợp lệ"
        case .shortcut, .shell: return "Bấm Chạy thử để xem kết quả"
        }
    }

    private func runTrial() {
        running = true
        let action = draft
        let input = sample
        ExternalRunner.run(action, input: input) { result in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    running = false
                    switch result {
                    case .success(let out): trial = out.isEmpty ? "(không có kết quả)" : out
                    case .failure(.failed(let why)): trial = "Lỗi: \(why)"
                    }
                }
            }
        }
    }

    private func pickShortcut() {
        ExternalRunner.listShortcuts { names in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let menu = NSMenu()
                    if names.isEmpty {
                        let none = NSMenuItem(title: "Chưa có phím tắt nào trong ứng dụng Phím tắt", action: nil, keyEquivalent: "")
                        none.isEnabled = false
                        menu.addItem(none)
                    }
                    for name in names.prefix(60) {
                        menu.addItem(ClosureMenuItem(title: name, key: "") { draft.value = name })
                    }
                    menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
                }
            }
        }
    }

    private func labeled<Content: View>(_ title: String, hint: String? = nil, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(Fonts.text(11.5, .heavy)).foregroundColor(Palette.ink2)
            content()
            if let hint {
                Text(hint).font(Fonts.text(11)).foregroundColor(Palette.ink3).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Chọn lúc nào việc hiện: một nút mở menu.
private struct WhenPicker: View {
    @Binding var when: CustomAction.When

    var body: some View {
        Button {
            let menu = NSMenu()
            for option in CustomAction.When.allCases {
                let item = ClosureMenuItem(title: option.title, key: "") { when = option }
                item.state = option == when ? .on : .off
                menu.addItem(item)
            }
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } label: {
            HStack(spacing: 6) {
                Text(when.title).font(Fonts.text(12.5, .semibold)).foregroundColor(Palette.ink)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundColor(Palette.ink2)
            }
            .padding(.horizontal, 12).frame(height: 30)
            .background(Capsule().fill(Palette.fill))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
