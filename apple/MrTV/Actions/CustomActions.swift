import AppKit

/// Việc người dùng tự tạo cho thanh gợi ý và bảng lệnh.
struct CustomAction: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        /// Ghép đoạn đang bôi đen vào một mẫu: “{chữ}”, **{chữ}**…
        case template
        /// Tìm rồi thay trong đoạn đang bôi đen.
        case replace
        /// Mở một trang web, đoạn đang bôi đen nằm trong địa chỉ.
        case link
        /// Chạy một phím tắt trong ứng dụng Phím tắt (Shortcuts) của Apple.
        case shortcut
        /// Chạy một lệnh: chữ vào stdin, kết quả lấy từ stdout.
        case shell

        var title: String {
            switch self {
            case .template: return "Mẫu chữ"
            case .replace: return "Thay chữ"
            case .link: return "Mở web"
            case .shortcut: return "Phím tắt Apple"
            case .shell: return "Lệnh"
            }
        }

        var symbol: String {
            switch self {
            case .template: return "text.quote"
            case .replace: return "arrow.left.arrow.right"
            case .link: return "safari"
            case .shortcut: return "square.stack.3d.up"
            case .shell: return "terminal"
            }
        }
    }

    enum Output: String, Codable { case replace, copy }

    enum When: String, Codable, CaseIterable {
        case always, vietnamese, plain, number, link, email, multiline

        var title: String {
            switch self {
            case .always: return "Mọi đoạn chữ"
            case .vietnamese: return "Chữ có dấu"
            case .plain: return "Chữ không dấu"
            case .number: return "Một con số"
            case .link: return "Đường link"
            case .email: return "Địa chỉ email"
            case .multiline: return "Nhiều dòng"
            }
        }

        /// Điều kiện của `TextFacts`.
        var condition: String {
            switch self {
            case .always: return "always"
            case .vietnamese: return "has_diacritics"
            case .plain: return "no_diacritics"
            case .number: return "is_number"
            case .link: return "is_link"
            case .email: return "is_email"
            case .multiline: return "multiline"
            }
        }
    }

    var id = "custom." + UUID().uuidString
    var name: String
    var kind: Kind
    /// Mẫu chữ, chữ thay vào, địa chỉ web, tên phím tắt, hay câu lệnh, tuỳ `kind`.
    var value: String
    /// Chữ cần tìm (chỉ dùng cho "Thay chữ").
    var find = ""
    var output: Output = .replace
    var when: When = .always

    static let placeholder = "{chữ}"

    /// Việc phải chạy chương trình ngoài, chỉ chạy khi người dùng chọn.
    var runsExternally: Bool { kind == .shortcut || kind == .shell }

    /// Thiếu gì thì trả về lời nhắc, đủ thì nil.
    var problem: String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return "Đặt tên cho việc này." }
        switch kind {
        case .template where !value.contains(Self.placeholder):
            return "Mẫu cần có \(Self.placeholder) ở chỗ đặt đoạn đang bôi đen."
        case .replace where find.isEmpty:
            return "Nhập chữ cần tìm."
        case .link where URL(string: value.replacingOccurrences(of: Self.placeholder, with: "x")) == nil || !value.contains(Self.placeholder):
            return "Địa chỉ cần bắt đầu bằng https:// và có \(Self.placeholder)."
        case .shortcut, .shell:
            return value.trimmingCharacters(in: .whitespaces).isEmpty ? (kind == .shortcut ? "Nhập tên phím tắt." : "Nhập câu lệnh.") : nil
        default:
            return nil
        }
    }

    /// Kết quả tính ngay được (mẫu chữ, thay chữ). nil với việc mở web hay chạy chương trình.
    func apply(_ text: String) -> String? {
        switch kind {
        case .template: return value.replacingOccurrences(of: Self.placeholder, with: text)
        case .replace: return find.isEmpty ? nil : text.replacingOccurrences(of: find, with: value)
        default: return nil
        }
    }

    /// Mô tả ngắn để hiện trong danh sách thay cho kết quả xem trước.
    var summary: String {
        switch kind {
        case .template: return value
        case .replace: return "“\(find)” → “\(value)”"
        case .link: return "Mở " + (URL(string: value.replacingOccurrences(of: Self.placeholder, with: "x"))?.host ?? value)
        case .shortcut: return "Chạy phím tắt “\(value)”"
        case .shell: return "Chạy: \(value)"
        }
    }

    func linkURL(for text: String) -> URL? {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+?#"))) ?? text
        return URL(string: value.replacingOccurrences(of: Self.placeholder, with: encoded))
    }

    /// Thẻ việc để dùng chung đường với việc có sẵn.
    var card: ActionCard {
        var c = ActionCard(id: id, name: name, group: .mine, when: [when.condition], runsOn: ["nguoi_dung"], tool: nil,
                           result: output == .replace ? "thay_chu" : "chep", undo: "cmd_z", tier: "co_ban", priority: 92,
                           tip: summary, lesson: "", ready: true)
        c.custom = self
        return c
    }

    /// Mẫu tạo nhanh.
    static let presets: [CustomAction] = [
        CustomAction(name: "Ngoặc kép", kind: .template, value: "“{chữ}”"),
        CustomAction(name: "Tìm Google", kind: .link, value: "https://www.google.com/search?q={chữ}"),
        CustomAction(name: "Google Dịch", kind: .link, value: "https://translate.google.com/?sl=auto&tl=en&text={chữ}&op=translate"),
        CustomAction(name: "In đậm", kind: .template, value: "**{chữ}**"),
        CustomAction(name: "Đếm chữ", kind: .shell, value: "wc -w | tr -d ' '", output: .copy),
    ]
}

/// Chạy chương trình ngoài cho việc tự tạo (Phím tắt Apple, lệnh), ngoài luồng chính, có giới hạn thời gian.
enum ExternalRunner {
    enum Failure: Error { case failed(String) }

    static func run(_ action: CustomAction, input: String, completion: @escaping @Sendable (Result<String, Failure>) -> Void) {
        let kind = action.kind
        let value = action.value
        DispatchQueue.global(qos: .userInitiated).async {
            switch kind {
            case .shell:
                completion(process("/bin/zsh", ["-lc", value], stdin: input, timeout: 10))
            case .shortcut:
                let dir = FileManager.default.temporaryDirectory
                let inURL = dir.appendingPathComponent("mrtv-in-\(UUID().uuidString).txt")
                let outURL = dir.appendingPathComponent("mrtv-out-\(UUID().uuidString).txt")
                defer {
                    try? FileManager.default.removeItem(at: inURL)
                    try? FileManager.default.removeItem(at: outURL)
                }
                do { try input.write(to: inURL, atomically: true, encoding: .utf8) } catch {
                    return completion(.failure(.failed("Không ghi được tệp tạm")))
                }
                let result = process("/usr/bin/shortcuts", ["run", value, "--input-path", inURL.path, "--output-path", outURL.path],
                                     stdin: nil, timeout: 20)
                if case .failure = result { return completion(result) }
                let out = (try? String(contentsOf: outURL, encoding: .utf8)) ?? ""
                completion(.success(out.trimmingCharacters(in: .newlines)))
            default:
                completion(.failure(.failed("Việc này không chạy chương trình ngoài")))
            }
        }
    }

    /// Danh sách phím tắt trong ứng dụng Phím tắt của Apple.
    static func listShortcuts(_ completion: @escaping @Sendable ([String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if case .success(let out) = process("/usr/bin/shortcuts", ["list"], stdin: nil, timeout: 10) {
                completion(out.split(separator: "\n").map(String.init).filter { !$0.isEmpty })
            } else {
                completion([])
            }
        }
    }

    private static func process(_ path: String, _ args: [String], stdin: String?, timeout: TimeInterval) -> Result<String, Failure> {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe(), err = Pipe(), inp = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = inp
        do { try p.run() } catch {
            return .failure(.failed("Không chạy được \(path)"))
        }
        if let stdin { inp.fileHandleForWriting.write(Data(stdin.utf8)) }
        try? inp.fileHandleForWriting.close()
        let deadline = Date().addingTimeInterval(timeout)
        while p.isRunning && Date() < deadline { usleep(20_000) }
        if p.isRunning {
            p.terminate()
            return .failure(.failed("Chạy quá \(Int(timeout)) giây, đã dừng"))
        }
        let output = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard p.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .split(separator: "\n").first.map(String.init) ?? "Lỗi \(p.terminationStatus)"
            return .failure(.failed(message))
        }
        return .success(output.hasSuffix("\n") ? String(output.dropLast()) : output)
    }
}
