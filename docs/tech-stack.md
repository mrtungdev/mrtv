# Tech stack của Mr TV

Mục tiêu: gõ nhanh nhất có thể, trải nghiệm mượt, chạy được trên **macOS 12 trở lên**, cả máy Intel lẫn Apple silicon.
Chưa làm Windows, nhưng lõi được viết để sau này dùng lại được.

## Tóm tắt

| Phần | Chọn | Vì sao |
|---|---|---|
| Lõi gõ | **Rust** (`core/mrtv-core`) | Nhanh và ổn định. Không có giao diện. Dùng lại được cho bàn phím iPhone, sau này cả Windows |
| Nối lõi với Swift | **C ABI viết tay**, header sinh bằng cbindgen (`core/mrtv-ffi`) | Không cấp phát, không chép chữ trên đường gõ phím; dễ kiểm tra hơn UniFFI |
| Bộ gõ macOS (đường A) | **InputMethodKit**, Swift (`apple/MrTVInput`) | Cách chuẩn của macOS. Không cần quyền Trợ năng |
| Ứng dụng trên thanh menu (đường B và giao diện) | **AppKit + SwiftUI** (`apple/MrTV`) | AppKit cho khung (status item, bảng nổi), SwiftUI cho nội dung; chỉ dùng API có trên macOS 12 |
| Dự án Xcode | **XcodeGen** (`apple/project.yml`) | Tệp dự án sinh ra từ YAML, không phải sửa `.pbxproj` |
| Cập nhật | **Sparkle 2.10** | Bản hiện tại cần macOS 12, vừa khớp |
| Kiểm thử | `cargo test` (ca vàng, proptest), criterion, XCTest | Lõi thử độc lập với macOS; logic gõ Swift thử bằng ô nhập chữ giả |

## Kiến trúc: hai tiến trình, một lõi, hai đường đưa chữ

```
               ┌──────────────── mrtv-core (Rust, staticlib) ────────────────┐
               │ âm tiết · Telex/VNI · đặt dấu · tiếng Anh · gõ tắt · công cụ │
               └───────────────▲─────────────────────────────▲──────────────┘
                               │ gọi trong tiến trình         │ gọi trong tiến trình
   MrTVInput.app (InputMethodKit)                MrTV.app (thanh menu)
   Đường A · Gõ chuẩn                            Đường B · Gõ đè / xoá rồi gõ lại (event tap)
   - gõ ngay + replacementRange (không gạch chân) Bảng lệnh, nhãn Việt/Anh
   - chữ đang soạn (không bao giờ mất chữ)        Cài đặt, Bắt đầu, phím fn/⌥⌥, Sparkle
                └──── UserDefaults chung + Darwin notification ────┘
```

- **Đường A** chạy trong bộ gõ chuẩn. Ứng dụng AppKit/WebKit đã kiểm tra thì chèn chữ ngay rồi sửa dấu bằng `insertText(_:replacementRange:)`. Ứng dụng khác dùng chữ đang soạn: không mất chữ, nhưng Chromium vẫn vẽ một gạch chân mảnh (đã kiểm chứng trong mã nguồn Chromium).
- **Đường B** chạy trong MrTV.app bằng CGEventTap, như OpenKey/EVKey/Gõ Nhanh: nuốt phím, phát phím xoá rồi chữ mới, với độ trễ riêng theo ứng dụng. Mọi phím tổng hợp chỉ phát từ MrTV.app (một bộ quyền), mang dấu `eventSourceUserData = "MRTV"` để không bị xử lý lại.
- **Hồ sơ ứng dụng** (`apple/Shared/Resources/app-profiles.json`) chọn đường cho từng ứng dụng. Bộ gõ thấy hồ sơ chọn đường B và MrTV.app đang chạy tap thì để phím đi thẳng. Hồ sơ ban đầu là phỏng đoán; bộ thử ứng dụng sẽ chốt lại (ứng dụng nào 0 lần mất chữ ở cả hai đường thì chọn đường không gạch chân).

## Tốc độ

| Chỉ tiêu | Mục tiêu | Đo được |
|---|---|---|
| Lõi xử lý một phím | < 50 µs | **~0,09 µs** (13,4 µs cho đoạn 152 phím, `cargo bench`, máy Apple silicon) |
| Từ bấm tới hiện chữ | < 5 ms | [CẦN ĐO] bằng Instruments khi có bộ thử ứng dụng |
| RAM của bộ gõ | < 30 MB | [CẦN ĐO] |

Cách giữ tốc độ:
- Đường gõ phím không có IPC, không ghi log, không cấp phát trong lõi.
- Lõi chạy lại toàn bộ luật cho từ đang gõ sau mỗi phím. Việc này đơn giản và đúng kể cả khi đặt dấu tự do, mà vẫn rất nhanh.
- Đường B chạy trên một luồng riêng, ưu tiên `userInteractive`, có run loop riêng.

## Hỗ trợ theo bản macOS

| Bản macOS | Chạy được | Ghi chú |
|---|---|---|
| 12 Monterey | Có | Mở khi bật máy dùng LaunchAgent (SMAppService cần 13). Khoá dùng `os_unfair_lock` |
| 13–25 | Có | SMAppService |
| 26 Tahoe | Có | Kính Liquid Glass (`NSGlassEffectView`); AI trên máy (bản 2.0) cần chip Apple |
| 27 | Có | Máy build hiện tại |
| Máy Intel | macOS 12–26 | Apple không đưa máy Intel lên quá 26. Bản build là universal (arm64 + x86_64) |

## Những điều đã kiểm chứng (khi chọn stack)

- Xcode 27 build được cho macOS 12–27. Phải đặt rõ `ARCHS = arm64 x86_64` vì Xcode 27 có thể chỉ build arm64.
- `TISRegisterInputSource` chỉ nhận bundle trong `~/Library/Input Methods` hoặc `/Library/Input Methods`. Từ macOS 12, người dùng phải tự cho phép bộ gõ trong Cài đặt hệ thống (ghi nhận trong McBopomofo, commit 120e159).
- Không ẩn được gạch chân của chữ đang soạn trong Chromium. iTerm2 bỏ qua `replacementRange`.
- Phát phím tổng hợp cần quyền Trợ năng; tap chỉ nghe cần Giám sát đầu vào.
- OpenKey, Gõ Nhanh và goxkey đều chỉ dùng event tap. Gõ Nhanh dùng lõi Rust, giao diện Swift, và yêu cầu macOS 13.
- Sparkle 2.10 cần macOS 12.
- ⌘? là phím mở menu Trợ giúp của mọi ứng dụng, nên đã đổi phím mở hướng dẫn thành ⌥⌥ rồi gõ `?`.

## Lựa chọn riêng và lý do

- **Target bộ gõ dùng Swift 5** (`SWIFT_VERSION = 5.0`, strict concurrency `targeted`). InputMethodKit chưa có chú thích concurrency, nên lớp con của `IMKInputController` không qua được kiểm tra của Swift 6. MrTV.app vẫn dùng Swift 6.
- **Logic gõ tách khỏi InputMethodKit** (`apple/Shared/InputSession.swift`), để thử bằng XCTest với ô nhập chữ giả.
- **Thẻ việc dùng JSON** (`apple/MrTV/Resources/actions.json`), thay cho TOML như ví dụ trên canvas, vì Swift đọc JSON sẵn. Các trường giữ đúng tên trên canvas: `ten`, `nhom`, `khi`, `chay`…
- **fn** được nhận theo keyCode 63, không theo cờ fn (phím mũi tên và F1–F12 cũng mang cờ này). Tap chỉ nghe không chặn được phím 🌐 của hệ thống, nên màn Bắt đầu nhắc người dùng đặt "Nhấn phím 🌐 để: Không làm gì".

## Chưa làm, hoặc chưa kiểm chứng

- [CẦN KIỂM TRA] Bảng TCVN3 trong `charset.rs` mới đối chiếu với các mẫu chữ lỗi quen thuộc ("ViÖt Nam", "Hµ Néi"), chưa đối chiếu với bảng chuẩn TCVN 5712:1993.
- Chưa có VNI-Windows, vì chưa có bảng đối chiếu đáng tin.
- Chưa chạy bản x86_64: máy build không cài Rosetta. Cần thử trên máy Intel thật và trên máy ảo macOS 12–15 (Tart hoặc UTM).
- Chưa đo độ trễ thật từ bấm tới hiện chữ, chưa có bộ thử 30 ứng dụng chạy tự động.
- Sửa lỗi chính tả, thêm dấu bằng AI, viết lại, dịch: mới có thẻ việc, chưa có xử lý (bản 1.x và 2.0).
- Nhập gõ tắt từ OpenKey/EVKey/Unikey, đồng bộ iCloud: chưa làm.
- `SUFeedURL` để trống trong mã; `release.sh` đặt địa chỉ cập nhật và khoá EdDSA khi đóng gói. Bản 0.1.0 thiếu khoá nên không tự cài được bản sau. Ký Developer ID và công chứng (notarize) cần tài khoản Apple Developer.

## Thử trên máy

Các lệnh build, kiểm tra và phát hành có ở [CONTRIBUTING.md](../CONTRIBUTING.md#các-lệnh) và [RELEASING.md](RELEASING.md). Gõ `make` để xem danh sách. Bản dev ký bằng chứng chỉ Apple Development nếu máy có (quyền được giữ qua các lần build), không thì ký tạm (ad-hoc) và phải bật lại quyền Trợ năng sau mỗi lần build.
