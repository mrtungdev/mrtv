import AppKit

/// Thẻ việc 8 dòng (xem trang Tổ chức trên canvas): tên, nhóm, khi nào hợp, chạy bằng gì,
/// kết quả, hoàn tác, phím, cách dạy. Thêm việc mới là thêm một thẻ vào `actions.json`.
struct ActionCard: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var group: ActionGroup
    var when: [String]
    var runsOn: [String]
    var tool: String?
    var result: String
    var undo: String
    var tier: String
    var priority: Int
    var tip: String
    var lesson: String
    var ready: Bool?
    /// Việc người dùng tự tạo (không đọc từ actions.json).
    var custom: CustomAction? = nil

    enum CodingKeys: String, CodingKey {
        case id, tip = "meo", lesson = "bai", name = "ten", group = "nhom", when = "khi", runsOn = "chay"
        case tool = "cong_cu", result = "ket_qua", undo = "hoan_tac", tier = "muc", priority = "uu_tien", ready = "san_sang"
    }

    var needsAI: Bool { runsOn.first == "ai_tren_may" || runsOn.first == "khoa_api" }

    /// Chạy được ngay trong bản này chưa. Việc cần AI chờ bản 2.0.
    var isAvailable: Bool { custom != nil || (ready ?? true && !needsAI && tool != nil) }

    /// Biểu tượng: theo loại với việc tự tạo, theo nhóm với việc có sẵn.
    var symbol: String { custom?.kind.symbol ?? group.symbol }

    /// Khi nào việc này hiện trên thanh gợi ý, nói thành lời.
    var whenText: String {
        let parts = when.map { c -> String in
            switch c {
            case "has_letters": return "mọi đoạn chữ"
            case "has_diacritics", "has_vietnamese": return "chữ có dấu"
            case "looks_telex_typed": return "lỡ gõ ở chế độ Anh (tooi ddang)"
            case "looks_tcvn3": return "chữ lỗi font (ViÖt Nam)"
            case "looks_viqr": return "chữ kiểu VIQR (Vie^.t)"
            case "is_nfd": return "chữ bị tách dấu"
            case "is_number": return "một con số"
            case "always": return "mọi đoạn chữ"
            case "no_diacritics": return "chữ không dấu"
            case "is_link": return "đường link"
            case "is_email": return "địa chỉ email"
            case "multiline": return "đoạn nhiều dòng"
            default: return "khi hợp"
            }
        }
        return "Hiện khi bôi đen " + parts.joined(separator: ", ")
    }

    var unavailableReason: String? {
        guard !isAvailable else { return nil }
        return needsAI ? "Cần AI trên máy — có ở bản 2.0" : "Sắp có"
    }
}

enum ActionError: Error {
    case unavailable(String)
    case failed
}

/// Kết quả khi chạy một việc từ thanh gợi ý hay bảng lệnh.
enum ActionOutcome {
    /// Thay đoạn đang bôi đen bằng chữ này.
    case replace(String)
    /// Chép chữ này vào clipboard.
    case copy(String)
    /// Đã mở trang web, không đổi chữ.
    case opened
    case failed(String)
}

@MainActor
final class ActionRegistry {
    static let shared = ActionRegistry()

    let cards: [ActionCard]
    private let usageKey = "actionUsage"
    private let appUsageKey = "actionUsageByApp"

    private init() {
        let url = Bundle.main.url(forResource: "actions", withExtension: "json")
        let data = url.flatMap { try? Data(contentsOf: $0) } ?? Data("[]".utf8)
        cards = (try? JSONDecoder().decode([ActionCard].self, from: data)) ?? []
    }

    /// Việc hiện trên thanh gợi ý lúc mới cài: các việc cơ bản, việc quan trọng trước.
    var defaultQuickBar: [String] {
        // Chỉ việc có sẵn: được gọi lúc AppModel đang khởi tạo, nên không đọc việc tự tạo ở đây.
        cards.filter { $0.isAvailable && $0.tier == "co_ban" }.sorted { $0.priority > $1.priority }.map(\.id)
    }

    /// Việc người dùng cho hiện trên thanh gợi ý, theo thứ tự đã xếp.
    var quickBarCards: [ActionCard] {
        AppModel.shared.quickBarActions.compactMap { id in available.first { $0.id == id } }
    }

    /// Số lần đã dùng mỗi việc, để tự xếp.
    func usage(_ id: String) -> Int {
        (UserDefaults.standard.dictionary(forKey: usageKey) as? [String: Int])?[id] ?? 0
    }

    /// Số lần đã dùng việc này trong một ứng dụng.
    func usage(_ id: String, in app: String?) -> Int {
        guard let app else { return 0 }
        return ((UserDefaults.standard.dictionary(forKey: appUsageKey) as? [String: [String: Int]])?[app])?[id] ?? 0
    }

    private func record(_ id: String) {
        let d = UserDefaults.standard
        var all = d.dictionary(forKey: usageKey) as? [String: Int] ?? [:]
        all[id, default: 0] += 1
        d.set(all, forKey: usageKey)
        guard let app = Self.currentApp else { return }
        var byApp = d.dictionary(forKey: appUsageKey) as? [String: [String: Int]] ?? [:]
        byApp[app, default: [:]][id, default: 0] += 1
        d.set(byApp, forKey: appUsageKey)
    }

    /// Ứng dụng đang có ô nhận chữ (bộ gõ báo), không thì ứng dụng đứng trước.
    static var currentApp: String? {
        AppModel.shared.frontApp?.bundleIdentifier ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    /// Điểm để tự xếp: việc quan trọng, việc hay dùng, nhất là việc hay dùng ở chính ứng dụng này.
    private func score(_ card: ActionCard, app: String?) -> Int {
        card.priority + min(usage(card.id), 20) + min(usage(card.id, in: app) * 3, 30)
    }

    /// Kết quả xem trước: chữ sau khi làm (nếu tính ngay được), hoặc mô tả việc sẽ làm.
    func preview(_ card: ActionCard, on text: String) -> String {
        if let custom = card.custom { return custom.apply(text) ?? custom.summary }
        if case .success(let out) = run(card, on: text, record: false) { return out }
        return ""
    }

    /// Bỏ việc chạy xong mà chữ không đổi (VIẾT HOA khi chữ đã hoa), và việc cho cùng kết quả với việc xếp trên.
    private func useful(_ cards: [ActionCard], for text: String) -> [ActionCard] {
        var seen = Set<String>()
        return cards.filter { card in
            if let custom = card.custom, custom.apply(text) == nil { return true }
            let out = preview(card, on: text)
            // Việc không chạy được trên đoạn này (Số thành chữ với số lẻ) thì không gợi ý.
            guard !out.isEmpty, out != text, !seen.contains(out) else { return false }
            seen.insert(out)
            return true
        }
    }

    /// Danh sách đầy đủ cho Phím Mr TV: mọi việc chạy được hợp với chữ đang bôi đen (tối đa 9).
    /// Việc trên thanh gợi ý trước (theo thứ tự đang dùng), rồi tới các việc khác.
    func listSuggestions(for text: String, limit: Int = 9) -> [ActionCard] {
        let facts = TextFacts(text)
        let app = Self.currentApp
        let first = suggestions(for: text, limit: limit)
        let rest = available.filter { card in
            !first.contains(where: { $0.id == card.id }) && card.when.allSatisfy(facts.matches)
        }
        .sorted { score($0, app: app) > score($1, app: app) }
        return Array(useful(first + rest, for: text).prefix(limit))
    }

    /// Tối đa 3 việc hợp nhất với chữ đang bôi đen: luật "thanh gợi ý luôn chỉ 3 việc".
    /// Chỉ lấy việc người dùng cho hiện; tự xếp thì việc hợp nhất và hay dùng (ở ứng dụng này) lên trước,
    /// không thì theo thứ tự người dùng xếp. Việc không làm đổi gì thì không hiện.
    func suggestions(for text: String, limit: Int = 3) -> [ActionCard] {
        let facts = TextFacts(text)
        let app = Self.currentApp
        var fits = quickBarCards.filter { $0.when.allSatisfy(facts.matches) }
        if AppModel.shared.quickBarSmartOrder {
            fits.sort { score($0, app: app) > score($1, app: app) }
        }
        return Array(useful(fits, for: text).prefix(limit))
    }

    /// Chạy một việc. Việc tự tạo có thể mở web hay chạy chương trình ngoài, nên trả kết quả qua `completion`.
    func perform(_ card: ActionCard, on text: String, completion: @escaping @MainActor (ActionOutcome) -> Void) {
        guard let custom = card.custom else {
            switch run(card, on: text) {
            case .success(let out): completion(.replace(out))
            case .failure(.unavailable(let why)): completion(.failed(why))
            case .failure: completion(.failed("Không làm được với chữ này"))
            }
            return
        }
        record(card.id)
        let deliver: (String) -> ActionOutcome = { custom.output == .replace ? .replace($0) : .copy($0) }
        switch custom.kind {
        case .template, .replace:
            completion(custom.apply(text).map(deliver) ?? .failed("Không làm được với chữ này"))
        case .link:
            guard let url = custom.linkURL(for: text) else { return completion(.failed("Địa chỉ web không hợp lệ")) }
            NSWorkspace.shared.open(url)
            completion(.opened)
        case .shortcut, .shell:
            let replace = custom.output == .replace
            ExternalRunner.run(custom, input: text) { result in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        switch result {
                        case .success(let out): completion(replace ? .replace(out) : .copy(out))
                        case .failure(.failed(let why)): completion(.failed(why))
                        }
                    }
                }
            }
        }
    }

    /// Việc chạy được trong bản này, cộng việc người dùng tự tạo. Việc chưa làm xong (cần AI…) ẩn hẳn cho tới khi có.
    /// Việc tự tạo đi cùng thanh gợi ý (chỉ quản lý được ở mục đó), nên ẩn theo nó.
    var available: [ActionCard] {
        cards.filter(\.isAvailable) + (Features.quickBar ? AppModel.shared.customActions.map(\.card) : [])
    }

    /// Tìm việc trong bảng lệnh, gõ không dấu cũng được.
    func search(_ query: String) -> [ActionCard] {
        let q = TextTool.strip.run(query.lowercased()) ?? query.lowercased()
        guard !q.isEmpty else { return available }
        return available.filter { (TextTool.strip.run($0.name.lowercased()) ?? $0.name).contains(q) }
    }

    /// `record` = false khi chỉ xem trước, để không tính là đã dùng.
    func run(_ card: ActionCard, on text: String, record shouldRecord: Bool = true) -> Result<String, ActionError> {
        if let custom = card.custom {
            guard let out = custom.apply(text) else { return .failure(.unavailable("Chạy khi bấm chọn")) }
            if shouldRecord { record(card.id) }
            return .success(out)
        }
        guard card.isAvailable, let name = card.tool, let tool = TextTool.named(name) else {
            return .failure(.unavailable(card.unavailableReason ?? "Sắp có"))
        }
        guard let out = tool.run(text) else { return .failure(.failed) }
        if shouldRecord { record(card.id) }
        return .success(out)
    }
}

extension TextTool {
    static func named(_ name: String) -> TextTool? {
        switch name {
        case "nfc": return .nfc
        case "strip": return .strip
        case "slug": return .slug
        case "upper": return .upper
        case "lower": return .lower
        case "title": return .title
        case "sentence": return .sentence
        case "fromVIQR": return .fromVIQR
        case "fromTCVN3": return .fromTCVN3
        case "reverseTelex": return .reverseTelex
        case "reverseVNI": return .reverseVNI
        case "numberWords": return .numberWords
        default: return nil
        }
    }
}

/// Những gì nhận ra được từ chữ đang bôi đen, để chọn việc hợp ("khi nào hợp" trên thẻ việc).
struct TextFacts {
    let text: String
    let hasLetters: Bool
    let hasDiacritics: Bool
    let isNumber: Bool
    let isNFD: Bool
    let looksTCVN3: Bool
    let looksTelexTyped: Bool
    let looksVIQR: Bool

    init(_ text: String) {
        self.text = text
        hasLetters = text.unicodeScalars.contains { CharacterSet.letters.contains($0) }
        let stripped = TextTool.strip.run(text) ?? text
        hasDiacritics = stripped != text
        isNumber = !text.isEmpty && text.allSatisfy { $0.isNumber || $0 == "." || $0 == "," || $0 == " " }
        isNFD = (TextTool.nfc.run(text) ?? text).unicodeScalars.count != text.unicodeScalars.count
        looksTCVN3 = TextTool.looksTCVN3.run(text) == "1"
        let reversed = TextTool.reverseTelex.run(text) ?? text
        looksTelexTyped = !hasDiacritics && reversed != text
        looksVIQR = text.range(of: #"[aeiouyAEIOUY][\^\(\+]?['`\?~\.]"#, options: .regularExpression) != nil && !hasDiacritics
    }

    func matches(_ condition: String) -> Bool {
        switch condition {
        case "always": return true
        case "has_letters": return hasLetters
        case "has_diacritics": return hasDiacritics
        case "has_vietnamese": return hasDiacritics
        case "vietnamese_no_diacritics": return hasLetters && !hasDiacritics && !looksTelexTyped
        case "looks_telex_typed": return looksTelexTyped
        case "looks_tcvn3": return looksTCVN3
        case "looks_viqr": return looksVIQR
        case "is_nfd": return isNFD
        case "is_number": return isNumber
        case "long_text": return text.count > 280
        case "no_diacritics": return hasLetters && !hasDiacritics
        case "is_link": return text.range(of: #"^\s*(https?://|www\.)\S+\s*$"#, options: .regularExpression) != nil
        case "is_email": return text.range(of: #"^\s*[^@\s]+@[^@\s]+\.[A-Za-z]{2,}\s*$"#, options: .regularExpression) != nil
        case "multiline": return text.contains("\n")
        case "english_text": return hasLetters && !hasDiacritics
        default: return false
        }
    }
}
